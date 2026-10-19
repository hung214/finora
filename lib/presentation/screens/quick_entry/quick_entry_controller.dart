import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../data/sqlite/app_database.dart';

/// 快記狀態機階段（SDD §5.1）。
enum QuickEntryPhase {
  ready,
  inputting,
  committing,
  savedDialog,
}

/// 快記狀態（SDD §5.1；Sticky 欄位＝帳戶/分類/商家，金額/時間每筆重設）。
class QuickEntryState {
  const QuickEntryState({
    required this.phase,
    this.account,
    this.category,
    this.merchant = '',
    this.amount = '',
    required this.occurredAt,
    this.sessionCount = 0,
    this.lastSaveMs,
  });

  final QuickEntryPhase phase;
  final AccountRow? account;
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
    AccountRow? account,
    CategoryRow? category,
    String? merchant,
    String? amount,
    DateTime? occurredAt,
    int? sessionCount,
    int? lastSaveMs,
  }) =>
      QuickEntryState(
        phase: phase ?? this.phase,
        account: account ?? this.account,
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

  // ── 儲存/繼續/復原（SDD §5.1 狀態機） ─────────────────────

  /// 儲存（FR-Q5）：成功 → SavedDialog（顯示本次已記 N 筆）；失敗回
  /// Inputting 保留輸入＋錯誤提示。
  void save() => throw UnimplementedError('T-F01-FE 紅燈階段');

  /// 繼續（FR-Q2/Q5）：Sticky 保留帳戶/分類/商家；金額清空（FE 欄位）、
  /// 時間重設為現在（FR-Q5）。
  void continueEntry() => throw UnimplementedError('T-F01-FE 紅燈階段');

  /// 復原上一筆（FR-Q3）：軟刪除墓標＋oplog；計數減一。
  void undoLast() => throw UnimplementedError('T-F01-FE 紅燈階段');
}

final quickEntryControllerProvider =
    NotifierProvider.autoDispose<QuickEntryController, QuickEntryState>(
        QuickEntryController.new);
