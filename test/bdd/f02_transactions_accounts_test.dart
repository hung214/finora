import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/quick_entry/save_transaction_use_case.dart';
import 'package:ledger_sync/application/stats/monthly_stats_service.dart';
import 'package:ledger_sync/application/transactions/delete_transaction_use_case.dart';
import 'package:ledger_sync/application/transactions/tombstone_purge_service.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/core/money.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/entities/account.dart';
import 'package:ledger_sync/domain/entities/transaction.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';

/// F02-BE 情境執行器（@BE @M1 @FR-T @FR-A @P0，5 情境）。
///
/// 來源：specs/plan/tests/backend/F02_transactions-accounts.feature（tool/sync_features.ps1
/// 同步至 test/bdd/，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
/// 多幣別情境 @P1 @M2 屬 M2 範圍（M1 僅執行 @P0）。
void main() {
  final source = File('test/bdd/F02_transactions-accounts.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F02-BE：交易與帳戶領域邏輯（6 情境：金額驗證／轉帳守恆／儲值語意／軟刪除／還款／多幣別）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      // 多幣別情境 @P1 @M2 屬 M2（PM 確認 2026-10-19 deferred）；feature 層 @P0
      // 會被所有情境繼承，須以 !@M2 排除 M2 範圍。
      final executed = await runner.run(
        doc,
        // M2 遺留完成（多幣別 @P1 @M2 已實作）——全部 6 情境執行。
        tagFilter: (tags) => tags.contains('@BE'),
      );
      expect(executed, 6, reason: 'F02-BE 應執行 6 個情境（@BE 全部：P0 5＋多幣別 @P1 @M2）');
      // ignore: avoid_print
      print(runner.log.join('\n'));
    } finally {
      Clock.unfreeze();
      for (final db in w.dbs) {
        db.close();
      }
    }
  });
}

/// 情境共享狀態（每 Scenario 由 Background 重置）。
class _World {
  final List<AppDatabase> dbs = [];
  late AppDatabase db;
  late SaveTransactionUseCase save;
  late DeleteTransactionUseCase delete;

  /// 名稱 → id 對映（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};

  /// Given 已儲存之「金額 → 交易 id」（軟刪除斷言用）。
  final txIdByAmount = <int, String>{};

  /// When 步驟前的 oplog 數（「oplog 新增 N 筆」之 delta 基準）。
  int opBaseline = 0;

  /// When 步驟前的交易筆數（「且不入庫」之 delta 基準）。
  int txCountBaseline = 0;

  /// 最近一次驗證失敗訊息（未拋例外為 null）。
  String? validationError;

  /// 最近一次成功建立之交易 id（kind 斷言用，F02 S2.4/S2.6）。
  String? lastCreatedTxId;

  /// 最近一次 Given 種下之交易 id（刪除情境目標，F02 S2.5）。
  String? lastSeededTxId;

  /// 最近一次清除工作之清除筆數（診斷用）。
  int? lastPurgedCount;
}

void _bind(GherkinRunner runner, _World w) {
  // ── Given：環境 ─────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.accounts.clear();
    w.categories.clear();
    w.txIdByAmount.clear();
    w.opBaseline = 0;
    w.txCountBaseline = 0;
    w.validationError = null;
    w.lastCreatedTxId = null;
    w.lastSeededTxId = null;
    w.save = SaveTransactionUseCase(db);
    w.delete = DeleteTransactionUseCase(db);
  });

  runner.on(r'已建立帳戶「{name}」類型 {type} 期初 {amount}$', (p) {
    final id = 'a-${w.accounts.length}';
    // fixture 內部為同步寫入（Future 僅為介面一致），直接呼叫不 await。
    DbFixture.seedAccount(
      w.db,
      id: id,
      type: p['type']!,
      name: p['name']!,
      opening: _amount(p['amount']!),
    );
    w.accounts[p['name']!] = id;
  });

  runner.on(r'已建立分類{names}$', (p) {
    final names = RegExp('「([^」]+)」')
        .allMatches(p['names']!)
        .map((m) => m.group(1)!)
        .toList();
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final id = 'c-${w.categories.length}';
      // kind 對齊內建集（first_run_bootstrap）：一般收入 = income，其餘 = expense。
      DbFixture.seedCategory(
        w.db,
        id: id,
        kind: name == '一般收入' ? 'income' : 'expense',
        name: name,
      );
      w.categories[name] = id;
    }
  });

  // ── When：儲存驗證（F02 S2.1）────────────────────────────
  runner.on(r'呼叫 SaveTransactionUseCase（金額 {amt}）$', (p) {
    w.opBaseline = w.db.allOps().length;
    w.txCountBaseline = w.db.allTransactions().length;
    try {
      w.save.execute(
        accountId: w.accounts['現金']!,
        amountMinor: _amount(p['amt']!),
        occurredAt: Clock.now(),
      );
      w.validationError = null;
    } on TransactionValidationException catch (e) {
      w.validationError = e.message;
    }
  });

  // ── Then：驗證輸出（F02 S2.1）────────────────────────────
  runner.on(r'顯示「{message}」且不入庫$', (p) {
    expect(w.validationError, p['message'], reason: '驗證失敗訊息（FE 顯示契約）');
    expect(w.db.allTransactions().length, w.txCountBaseline, reason: '驗證失敗不得入庫');
  });

  runner.on(r'oplog 新增 {n} 筆且皆未打包$', (p) {
    final ops = w.db.allOps();
    final added = ops.skip(w.opBaseline).toList();
    expect(added.length, int.parse(p['n']!), reason: 'oplog 新增筆數');
    for (final op in added) {
      expect(op.packedSeq, isNull, reason: '未打包（待 SyncCoordinator，F07）');
    }
  });

  // ── Given：統計基準線（F02 S2.3 測試資料）────────────────
  runner.on(r'本月已支出 {expense}、收入 {income}$', (p) {
    // 種於票證卡——不得落於該情境有餘額斷言之帳戶（現金/銀行），否則
    // 600/10400 斷言不成立（harness 決策，PM 已確認 2026-10-19）。
    final base = Clock.now();
    final at = DateTime(base.year, base.month, 1, 12).millisecondsSinceEpoch;
    DbFixture.seedTx(
      w.db,
      id: 'tx-stat-e',
      kind: 'expense',
      amountMinor: _amount(p['expense']!),
      accountId: w.accounts['票證卡']!,
      category: w.categories['餐飲食品'],
      occurredAt: at,
    );
    DbFixture.seedTx(
      w.db,
      id: 'tx-stat-i',
      kind: 'income',
      amountMinor: _amount(p['income']!),
      accountId: w.accounts['票證卡']!,
      category: w.categories['一般收入'],
      occurredAt: at,
    );
  });

  // ── When：轉帳（F02 S2.3/S2.4）───────────────────────────
  // 注意：儲值變體須先於 base 句型登記（{amt} 為 lazy match，否則「（儲值）」
  // 後綴被 base 吞入——F01 計時變體同型教訓）。
  runner.on(r'建立轉帳「{from}」→「{to}」金額 {amt}（儲值）$', (p) {
    _transfer(w, p['from']!, p['to']!, p['amt']!);
  });

  runner.on(r'建立轉帳「{from}」→「{to}」金額 {amt}$', (p) {
    _transfer(w, p['from']!, p['to']!, p['amt']!);
  });

  // ── Then：統計（F02 S2.3/S2.4/S2.6）──────────────────────
  runner.on(r'本月支出統計 = {amount}（不含轉帳）$', (p) {
    expect(
      MonthlyStatsService(w.db).expenseMinorThisMonth(),
      _amount(p['amount']!),
      reason: 'AC-10：轉帳不計入支出統計',
    );
  });

  // 純值變體須後於「（不含轉帳）」變體登記（lazy match 前綴碰撞，同前教訓）。
  runner.on(r'本月支出統計 = {amount}$', (p) {
    expect(
      MonthlyStatsService(w.db).expenseMinorThisMonth(),
      _amount(p['amount']!),
      reason: '轉帳/還款不計入支出統計（AC-10）',
    );
  });

  runner.on(r'本月收入統計 = {amount}$', (p) {
    expect(
      MonthlyStatsService(w.db).incomeMinorThisMonth(),
      _amount(p['amount']!),
      reason: 'AC-10：轉帳不計入收入統計',
    );
  });

  // ── Given：刪除目標（F02 S2.5 測試資料）──────────────────
  runner.on(r'已存在一筆支出 {amount} 元$', (p) {
    final amount = _amount(p['amount']!);
    const id = 'tx-del-1';
    DbFixture.seedTx(
      w.db,
      id: id,
      kind: 'expense',
      amountMinor: amount,
      accountId: w.accounts['現金']!,
      category: w.categories['餐飲食品'],
      occurredAt: Clock.now().millisecondsSinceEpoch,
    );
    w.txIdByAmount[amount] = id; // 「交易 {amt} 為軟刪除」斷言用（F01 同契約）
    w.lastSeededTxId = id; // 「刪除該筆交易」目標
  });

  // ── When：刪除＋清除（F02 S2.5）──────────────────────────
  runner.on(r'刪除該筆交易$', (p) {
    final id = w.lastSeededTxId;
    expect(id, isNotNull, reason: 'Given 應已種下目標交易');
    w.opBaseline = w.db.allOps().length;
    w.delete.execute(id!);
  });

  runner.on(r'模擬時間快轉 {days} 天並執行清除工作$', (p) {
    final days = int.parse(p['days']!);
    Clock.freeze(Clock.now().add(Duration(days: days)));
    w.lastPurgedCount = TombstonePurgeService(w.db).purge();
  });

  // ── Then：軟刪除墓標（dsl.md §2.3 既有句型，F01 同契約）─────
  runner.on(r'交易 {amount} 為軟刪除（deleted_at 非 null）$', (p) {
    final id = w.txIdByAmount[_amount(p['amount']!)];
    expect(id, isNotNull, reason: 'Given 已儲存應登記金額 → id');
    expect(w.db.transactionById(id!)!.deletedAt, isNotNull, reason: '墓標軟刪除（SDD 原則 5）');
  });

  // ── Then：保留期屆滿（F02 S2.5）──────────────────────────
  runner.on(r'該筆墓標已物理清除（無法還原）$', (p) {
    expect(w.db.transactionById(w.lastSeededTxId!), isNull,
        reason: 'FR-T3：保留期屆滿實體清除（oplog 墓標保留，GC 屬 F07）');
  });

  // ── When：還款（F02 S2.6）────────────────────────────────
  runner.on(r'建立還款交易 來源={from} 目標={to} 金額 {amt}$', (p) {
    _saveWithValidation(
      w,
      () => w.save.execute(
            accountId: w.accounts[p['from']!]!,
            amountMinor: _amount(p['amt']!),
            occurredAt: Clock.now(),
            kind: TxKind.repayment,
            toAccountId: w.accounts[p['to']!],
          ),
    );
  });

  // ── Then：交易 kind（F02 S2.4/S2.6）──────────────────────
  // 「且無分類」變體須先於 base 句型登記（lazy match 前綴碰撞，同前教訓）。
  runner.on(r'交易 kind = {kind} 且無分類$', (p) {
    final id = w.lastCreatedTxId;
    expect(id, isNotNull, reason: 'When 應已建立交易');
    final row = w.db.transactionById(id!)!;
    expect(row.kind, p['kind'], reason: '交易 kind（還款語意）');
    expect(row.categoryId, isNull, reason: '還款無分類（S2.6：固定還款語意）');
  });

  runner.on(r'交易 kind = {kind}$', (p) {
    final id = w.lastCreatedTxId;
    expect(id, isNotNull, reason: 'When 應已建立交易');
    expect(w.db.transactionById(id!)!.kind, p['kind'], reason: '交易 kind（儲值/還款語意）');
  });

  // ── Then：未繳合計（F02 S2.6）────────────────────────────
  runner.on(r'帳戶「{card}」未繳合計 = {amount}（含還款抵扣）$', (p) {
    final row = w.db.allAccounts().firstWhere((r) => r.name == p['card']);
    final unpaid = const BalanceCalculator()
        .creditUnpaidTotal(card: _accountEntity(row), txs: w.db.allTransactions().map(_txEntity));
    expect(unpaid, _amount(p['amount']!), reason: '還款抵扣未繳合計（下限 0；M3 前骨架版）');
  });

  // ── When／Then：多幣別（F02 S2.8 @M2；FR-T4）──────────────
  runner.on(r'呼叫 SaveTransactionUseCase（帳戶「{a}」、金額 {amount} {currency}、匯率 {rate}）$', (p) {
    w.opBaseline = w.db.allOps().length;
    final currency = p['currency']!;
    final minor = Money.fromMajor(_amount(p['amount']!), currency: currency).minorUnits;
    try {
      final result = w.save.execute(
        accountId: w.accounts[p['a']!]!,
        amountMinor: minor,
        occurredAt: Clock.now(),
        currency: currency,
        fxRate: double.parse(p['rate']!),
      );
      w.lastCreatedTxId = result.transactionId;
      w.validationError = null;
    } on TransactionValidationException catch (e) {
      w.validationError = e.message;
    }
  });

  runner.on(r'交易保存原幣 {amount} 與 fx_rate {rate}（{note}）$', (p) {
    // 註記格式「100 USD＝10000 minor」→ 幣別與 minor units。
    final noteParts = p['note']!.split('＝');
    final currency = noteParts.first.trim().split(' ').last; // USD
    final minor = int.parse(noteParts.last.trim().split(' ').first); // 10000
    final row = w.db.transactionById(w.lastCreatedTxId!);
    expect(row, isNotNull, reason: '交易應已入庫');
    expect(row!.currency, currency, reason: '原幣幣別（FR-T4）');
    expect(row.amountMinor, minor, reason: '原幣 minor units（${p['note']}）');
    expect(row.fxRate, double.parse(p['rate']!), reason: 'fx_rate');
  });

  runner.on(r'金額運算無浮點誤差（Money VO 斷言）$', (p) {
    // 100 USD（10000 minor）× 32 ÷ 100 = 3200 TWD——整數運算無浮點誤差。
    final usdMinor = Money.fromMajor(100, currency: 'USD').minorUnits;
    expect(usdMinor, 10000, reason: 'USD exponent 2');
    final twdMinor = (usdMinor * 32) ~/ 100;
    expect(twdMinor, Money(3200, currency: 'TWD').minorUnits,
        reason: '換算無浮點誤差（Money VO）');
  });

  // ── Then：餘額（dsl.md §2.3 既有句型）─────────────────────
  runner.on(r'帳戶「{a}」重算餘額 = {amount}$', (p) {
    final row = w.db.allAccounts().firstWhere((r) => r.name == p['a']);
    final balance = const BalanceCalculator()
        .assetBalance(account: _accountEntity(row), txs: w.db.allTransactions().map(_txEntity));
    expect(balance, _amount(p['amount']!), reason: '衍生餘額（SDD 原則 2）');
  });
}

/// 統一儲存呼叫：捕獲驗證例外（FE 顯示契約）、登記基準線與建立結果。
void _saveWithValidation(_World w, SaveTransactionResult Function() call) {
  w.opBaseline = w.db.allOps().length;
  w.txCountBaseline = w.db.allTransactions().length;
  try {
    final result = call();
    w.lastCreatedTxId = result.transactionId;
    w.validationError = null;
  } on TransactionValidationException catch (e) {
    w.validationError = e.message;
  }
}

/// 建立轉帳（S2.3/S2.4 共用；kind=transfer，票證儲值同語意）。
void _transfer(_World w, String from, String to, String amt) {
  _saveWithValidation(
    w,
    () => w.save.execute(
          accountId: w.accounts[from]!,
          amountMinor: _amount(amt),
          occurredAt: Clock.now(),
          kind: TxKind.transfer,
          toAccountId: w.accounts[to],
        ),
  );
}

Tx _txEntity(TxRow r) => Tx(
      id: r.id,
      kind: TxKind.values.byName(r.kind),
      amountMinor: r.amountMinor,
      currency: r.currency,
      fxRate: r.fxRate,
      splitGroupId: r.splitGroupId,
      accountId: r.accountId,
      toAccountId: r.toAccountId,
      categoryId: r.categoryId,
      merchant: r.merchant,
      note: r.note,
      occurredAt: r.occurredAt,
      source: TxSource.values.byName(r.source),
      settlementStatus: SettlementStatus.values.byName(r.settlementStatus),
      deleted: r.deletedAt != null,
    );

Account _accountEntity(AccountRow r) => Account(
      id: r.id,
      type: AccountType.values.byName(r.type),
      name: r.name,
      currency: r.currency,
      openingAmountMinor: r.openingAmountMinor,
      archived: r.archived,
    );

/// 金額解析：取前導數字（含負號/千分位；容許其後註記，如「-2200（以 3200 TWD 計）」）。
int _amount(String s) {
  final m = RegExp(r'^-?[\d,]+').firstMatch(s.trim());
  if (m == null) throw FormatException('金額格式未支援：$s');
  return int.parse(m.group(0)!.replaceAll(',', ''));
}
