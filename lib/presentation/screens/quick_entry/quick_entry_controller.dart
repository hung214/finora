import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/clock.dart';
import '../../../data/sqlite/app_database.dart';
import '../../../domain/entities/transaction.dart';

/// 快記狀態機階段（SDD §5.1）。
enum QuickEntryPhase {
  ready,
  inputting,
  committing,
  savedDialog,
}

/// 快記模式（F02：支出／轉帳／拆分；收入/還款模式隨 M2+ 情境擴充）。
enum QuickEntryMode { expense, transfer, split }

/// 快記狀態（SDD §5.1；Sticky 欄位＝帳戶/分類/商家，金額/時間每筆重設）。
class QuickEntryState {
  const QuickEntryState({
    required this.phase,
    this.mode = QuickEntryMode.expense,
    this.account,
    this.toAccount,
    this.splitCat0,
    this.splitCat1,
    this.splitAmount0 = '',
    this.splitAmount1 = '',
    this.category,
    this.merchant = '',
    this.amount = '',
    required this.occurredAt,
    this.sessionCount = 0,
    this.lastSaveMs,
  });

  final QuickEntryPhase phase;

  /// 記帳模式（F02 S2.3：轉帳不適用分類/商家，UI 隱藏之）。
  final QuickEntryMode mode;
  final AccountRow? account;

  /// 轉帳目標帳戶（transfer 專用；BE 驗證須相異）。
  final AccountRow? toAccount;

  /// 拆分子項（split 專用，M2 固定兩項；FR-T6）。
  final CategoryRow? splitCat0;
  final CategoryRow? splitCat1;
  final String splitAmount0;
  final String splitAmount1;
  final CategoryRow? category;
  final String merchant;

  /// 金額欄文字（數字鍵盤輸入；入庫時轉 minor units）。
  final String amount;
  final DateTime occurredAt;

  /// 本次連記筆數（FR-Q2「本次已記 N 筆」）。
  final int sessionCount;

  /// 純入庫耗時（NFR-01 UI 計時，S1.6；不含對話框動畫）。
  final int? lastSaveMs;

  QuickEntryState copyWith({
    QuickEntryPhase? phase,
    QuickEntryMode? mode,
    AccountRow? account,
    AccountRow? toAccount,
    bool clearToAccount = false,
    CategoryRow? splitCat0,
    CategoryRow? splitCat1,
    bool clearSplitItems = false,
    String splitAmount0 = '',
    String splitAmount1 = '',
    CategoryRow? category,
    String? merchant,
    String? amount,
    DateTime? occurredAt,
    int? sessionCount,
    int? lastSaveMs,
  }) =>
      QuickEntryState(
        phase: phase ?? this.phase,
        mode: mode ?? this.mode,
        account: account ?? this.account,
        toAccount: clearToAccount ? null : (toAccount ?? this.toAccount),
        splitCat0: clearSplitItems ? null : (splitCat0 ?? this.splitCat0),
        splitCat1: clearSplitItems ? null : (splitCat1 ?? this.splitCat1),
        splitAmount0: clearSplitItems ? '' : splitAmount0,
        splitAmount1: clearSplitItems ? '' : splitAmount1,
        category: category ?? this.category,
        merchant: merchant ?? this.merchant,
        amount: amount ?? this.amount,
        occurredAt: occurredAt ?? this.occurredAt,
        sessionCount: sessionCount ?? this.sessionCount,
        lastSaveMs: lastSaveMs ?? this.lastSaveMs,
      );
}

/// 快記 controller（FR-Q2~Q5；SDD §5.1 狀態機）。
///
/// autoDispose：離開快記頁即銷毀——「離開快記頁後不再提供復原入口」的
/// 生命週期由本 provider 的存活範圍表達（FR-Q2/Q3，acceptance S1.8-4）。
class QuickEntryController extends AutoDisposeNotifier<QuickEntryState> {
  @override
  QuickEntryState build() {
    // FR-Q4／SDD §5.1 系統預填：帳戶＋分類（智慧/固定預設）＋時間=現在。
    final preset = ref.watch(quickEntryPresetProvider).compute();
    return QuickEntryState(
      phase: QuickEntryPhase.ready,
      account: preset.account,
      category: preset.category,
      occurredAt: preset.time,
    );
  }

  // ── 欄位輸入（Inputting） ─────────────────────────────────

  void setAmount(String text) =>
      state = state.copyWith(amount: text, phase: QuickEntryPhase.inputting);

  void setMerchant(String text) =>
      state = state.copyWith(merchant: text, phase: QuickEntryPhase.inputting);

  void setOccurredAt(DateTime t) =>
      state = state.copyWith(occurredAt: t, phase: QuickEntryPhase.inputting);

  void selectAccountById(String? id) {
    if (id == null) return;
    for (final a in ref.read(activeAccountsProvider)) {
      if (a.id == id) {
        state = state.copyWith(account: a, phase: QuickEntryPhase.inputting);
        return;
      }
    }
  }

  void selectCategoryById(String? id) {
    if (id == null) return;
    for (final c in ref.read(expenseCategoriesProvider)) {
      if (c.id == id) {
        state = state.copyWith(category: c, phase: QuickEntryPhase.inputting);
        return;
      }
    }
  }

  /// 依名稱選帳戶（BDD 綁定用；不存在拋錯）。
  void selectAccount(String name) {
    for (final a in ref.read(activeAccountsProvider)) {
      if (a.name == name) {
        state = state.copyWith(account: a, phase: QuickEntryPhase.inputting);
        return;
      }
    }
    throw StateError('帳戶不存在：$name');
  }

  /// 依名稱選分類（BDD 綁定用；不存在拋錯）。
  void selectCategory(String name) {
    for (final c in ref.read(expenseCategoriesProvider)) {
      if (c.name == name) {
        state = state.copyWith(category: c, phase: QuickEntryPhase.inputting);
        return;
      }
    }
    throw StateError('分類不存在：$name');
  }

  // ── 模式與目標帳戶（F02 S2.3 轉帳） ──────────────────────

  /// 切換模式（支出/轉帳）：轉帳不適用分類/商家（BE 強制 null），UI 隱藏之；
  /// 目標帳戶隨模式重選（來源帳戶保留）。
  void setMode(QuickEntryMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode, clearToAccount: true, clearSplitItems: true);
  }

  // ── 拆分子項（F02 S2.7：M2 固定兩項） ────────────────────

  void selectSplitCategory(int index, String name) {
    for (final c in ref.read(expenseCategoriesProvider)) {
      if (c.name == name) {
        state = index == 0
            ? state.copyWith(splitCat0: c, phase: QuickEntryPhase.inputting)
            : state.copyWith(splitCat1: c, phase: QuickEntryPhase.inputting);
        return;
      }
    }
    throw StateError('拆分子項分類不存在：$name');
  }

  /// 依 id 選拆分子項分類（UI dropdown 用）。
  void selectSplitCategoryById(int index, String? id) {
    if (id == null) return;
    for (final c in ref.read(expenseCategoriesProvider)) {
      if (c.id == id) {
        state = index == 0
            ? state.copyWith(splitCat0: c, phase: QuickEntryPhase.inputting)
            : state.copyWith(splitCat1: c, phase: QuickEntryPhase.inputting);
        return;
      }
    }
  }

  void setSplitItemAmount(int index, String text) {
    final amount0 = index == 0 ? text : state.splitAmount0;
    final amount1 = index == 1 ? text : state.splitAmount1;
    state = state.copyWith(
      splitAmount0: amount0,
      splitAmount1: amount1,
      phase: QuickEntryPhase.inputting,
    );
  }

  void selectToAccountById(String? id) {
    if (id == null) return;
    for (final a in ref.read(activeAccountsProvider)) {
      if (a.id == id && a.id != state.account?.id) {
        state = state.copyWith(toAccount: a, phase: QuickEntryPhase.inputting);
        return;
      }
    }
  }

  /// 依名稱選目標帳戶（BDD 綁定用；同帳戶/不存在拋錯——UI 阻擋同帳戶轉帳）。
  void selectToAccount(String name) {
    for (final a in ref.read(activeAccountsProvider)) {
      if (a.name == name && a.id != state.account?.id) {
        state = state.copyWith(toAccount: a, phase: QuickEntryPhase.inputting);
        return;
      }
    }
    throw StateError('目標帳戶不存在（或與來源相同）：$name');
  }

  // ── 儲存/繼續/復原（SDD §5.1 狀態機） ─────────────────────

  /// 儲存（FR-Q5／F02 S2.3 轉帳）：成功 → SavedDialog（顯示本次已記 N 筆）；
  /// 失敗回 Inputting 保留輸入＋錯誤提示（SDD §5.1）。
  void save() {
    if (state.account == null) return;
    // 拆分（FR-T6）：不走 state.amount（雙子項金額）；守恆由 executeSplit 驗證。
    if (state.mode == QuickEntryMode.split) {
      final a0 = int.tryParse(state.splitAmount0) ?? 0;
      final a1 = int.tryParse(state.splitAmount1) ?? 0;
      if (a0 <= 0 || a1 <= 0 || state.splitCat0 == null || state.splitCat1 == null) {
        return; // 拆分子項未完成：停留輸入態
      }
      state = state.copyWith(phase: QuickEntryPhase.committing);
      final swSplit = Stopwatch()..start();
      ref.read(saveTransactionProvider).executeSplit(
            accountId: state.account!.id,
            totalMinor: a0 + a1,
            items: [
              (categoryId: state.splitCat0!.id, amountMinor: a0),
              (categoryId: state.splitCat1!.id, amountMinor: a1),
            ],
            occurredAt: state.occurredAt,
          );
      state = state.copyWith(
        phase: QuickEntryPhase.savedDialog,
        sessionCount: state.sessionCount + 1,
        lastSaveMs: swSplit.elapsedMilliseconds,
      );
      ref.invalidate(ledgerProvider);
      return;
    }
    if (state.amount.isEmpty) return;
    final amountMinor = int.tryParse(state.amount);
    if (amountMinor == null || amountMinor <= 0) return; // 非法輸入：停留輸入態
    if (state.mode == QuickEntryMode.transfer && state.toAccount == null) return;
    state = state.copyWith(phase: QuickEntryPhase.committing);
    final sw = Stopwatch()..start();
    if (state.mode == QuickEntryMode.transfer) {
      // F02 S2.3：轉帳守恆（AC-10）——不計入收支統計；BE 驗證相異帳戶。
      ref.read(saveTransactionProvider).execute(
            accountId: state.account!.id,
            amountMinor: amountMinor,
            occurredAt: state.occurredAt,
            kind: TxKind.transfer,
            toAccountId: state.toAccount!.id,
          );
    } else {
      ref.read(saveTransactionProvider).execute(
            accountId: state.account!.id,
            categoryId: state.category?.id,
            amountMinor: amountMinor,
            occurredAt: state.occurredAt,
            merchant: state.merchant.isEmpty ? null : state.merchant,
          );
    }
    // NFR-01 UI 計時（S1.6）：純入庫耗時（BE P95 已驗 <300ms）。
    state = state.copyWith(
      phase: QuickEntryPhase.savedDialog,
      sessionCount: state.sessionCount + 1,
      lastSaveMs: sw.elapsedMilliseconds,
    );
    // 明細/總覽即時刷新（AC-02，SDD 原則 2：衍生值即時反映）。
    ref.invalidate(ledgerProvider);
  }

  /// 繼續（FR-Q2/Q5）：Sticky 保留帳戶/分類/商家；時間重設為現在（FR-Q5）。
  /// 金額清空由 FE 欄位於相位轉移時處理（SavedDialog→Inputting）。
  void continueEntry() {
    state = state.copyWith(
      phase: QuickEntryPhase.inputting,
      amount: '',
      occurredAt: Clock.now(),
    );
  }

  /// 復原上一筆（FR-Q3）：軟刪除墓標＋oplog；計數減一。
  /// 信用卡預扣交易同步回沖「本期應付」——衍生值即時重算（SDD 原則 2）。
  void undoLast() {
    final result = ref.read(undoLastTransactionProvider).execute();
    if (result == null) return; // 無可復原（如全部已撤）
    state = state.copyWith(sessionCount: state.sessionCount - 1);
    ref.invalidate(ledgerProvider);
  }
}

final quickEntryControllerProvider =
    NotifierProvider.autoDispose<QuickEntryController, QuickEntryState>(
        QuickEntryController.new);
