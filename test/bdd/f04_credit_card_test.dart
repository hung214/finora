import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/quick_entry/save_transaction_use_case.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/entities/account.dart';
import 'package:ledger_sync/domain/entities/transaction.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';
import '../helpers/notification_spy.dart';

/// F04-BE 情境執行器（@BE @M3 @FR-C，10 情境：預扣/補算/歸屬 Outline/clamp/
/// 繳款×2/提醒/逾期/分期/退款/生效日）。
///
/// 來源：specs/plan/tests/backend/F04_credit-card-billing.feature（sync_features.ps1
/// 同步副本，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
/// ⚠️ 金額/結帳邏輯模組：待雙重 review（research §1.3）。
void main() {
  final source = File('test/bdd/F04_credit-card-billing.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F04-BE：信用卡帳單引擎（10 情境：P0 8＋P1 2）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      final executed = await runner.run(doc, tagFilter: (tags) => tags.contains('@BE'));
      expect(executed, 10, reason: 'F04-BE 應執行 10 個情境（含 Outline 逐列）');
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
  final NotificationSpy spy = NotificationSpy();
  late SaveTransactionUseCase save;

  /// 名稱 → id 對映（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};

  /// 最近一次記錄之交易 id（settlement 斷言用）。
  String? lastTxId;
}

void _bind(GherkinRunner runner, _World w) {
  // ── Given：環境 ─────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.accounts.clear();
    w.categories.clear();
    w.spy.clear();
    w.lastTxId = null;
    w.save = SaveTransactionUseCase(db);
  });

  runner.on(r'已建立帳戶「{name}」類型 {type} 期初 {amount}$', (p) {
    final id = 'a-${w.accounts.length}';
    DbFixture.seedAccount(
      w.db,
      id: id,
      type: p['type']!,
      name: p['name']!,
      opening: _amount(p['amount']!),
    );
    w.accounts[p['name']!] = id;
  });

  runner.on(r'模擬系統時間為 {dt}$', (p) => Clock.freeze(_dateTime(p['dt']!)));

  // ── Given：信用卡（FR-A3；device-local 明細）──────────────
  runner.on(r'已建立信用卡「{name}」: 結帳日 {day} 號、繳款日加 {offset} 天、歸屬 {rule}$', (p) async {
    final accountId = 'card-${w.accounts.length}';
    await DbFixture.seedCreditCard(
      w.db,
      accountId: accountId,
      name: p['name']!,
      statementDay: int.parse(p['day']!),
      dueOffsetDays: int.parse(p['offset']!),
      boundaryRule: p['rule']!,
    );
    w.accounts[p['name']!] = accountId;
  });

  // ── When：信用卡消費（FR-C1：settlement=pending）──────────
  runner.on(r'以「{card}」記錄支出 {amt}（{cat}）$', (p) {
    final catId = _getOrCreateCategory(w, p['cat']!);
    final result = w.save.execute(
      accountId: w.accounts[p['card']!]!,
      categoryId: catId,
      amountMinor: _amount(p['amt']!),
      occurredAt: Clock.now(),
      settlementStatus: 'pending', // FR-C1：刷卡預扣
    );
    w.lastTxId = result.transactionId;
  });

  // ── Then：預扣與本期應付（FR-C1）─────────────────────────
  runner.on(r'交易 settlement_status = {status}$', (p) {
    final row = w.db.transactionById(w.lastTxId!);
    expect(row, isNotNull, reason: '交易應已入庫');
    expect(row!.settlementStatus, p['status'], reason: 'FR-C1：刷卡預扣');
  });

  runner.on(r'帳戶「{a}」重算餘額 = {amount}（本期應付）$', (p) {
    final row = w.db.allAccounts().firstWhere((r) => r.name == p['a']);
    final account = Account(
      id: row.id,
      type: AccountType.values.byName(row.type),
      name: row.name,
      currency: row.currency,
      openingAmountMinor: row.openingAmountMinor,
      archived: row.archived,
    );
    final open = const BalanceCalculator().creditOpenBalance(
      card: account,
      txs: w.db.allTransactions().map(_txEntity),
    );
    expect(open, _amount(p['amount']!),
        reason: 'FR-C1：本期應付（Σ pending，衍生值）');
  });

  runner.on(r'帳戶「{a}」重算餘額 = {amount}$', (p) {
    final row = w.db.allAccounts().firstWhere((r) => r.name == p['a']);
    final account = Account(
      id: row.id,
      type: AccountType.values.byName(row.type),
      name: row.name,
      currency: row.currency,
      openingAmountMinor: row.openingAmountMinor,
      archived: row.archived,
    );
    final balance = const BalanceCalculator()
        .assetBalance(account: account, txs: w.db.allTransactions().map(_txEntity));
    expect(balance, _amount(p['amount']!), reason: '衍生餘額（SDD 原則 2）');
  });
}

/// 分類隱式建立（F04 Background 無分類 Given）。
String _getOrCreateCategory(_World w, String name) {
  final existing = w.categories[name];
  if (existing != null) return existing;
  final id = 'c-${w.categories.length}';
  DbFixture.seedCategory(w.db, id: id, kind: 'expense', name: name);
  w.categories[name] = id;
  return id;
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

DateTime _dateTime(String s) {
  final m = RegExp(r'^(\d{4})/(\d{2})/(\d{2})(?: (\d{1,2}):(\d{2}))?$').firstMatch(s.trim());
  if (m == null) throw FormatException('日期時間格式未支援：$s（dsl.md §1-3）');
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    m.group(4) == null ? 0 : int.parse(m.group(4)!),
    m.group(5) == null ? 0 : int.parse(m.group(5)!),
  );
}

int _amount(String s) {
  final m = RegExp(r'^-?[\d,]+').firstMatch(s.trim());
  if (m == null) throw FormatException('金額格式未支援：$s');
  return int.parse(m.group(0)!.replaceAll(',', ''));
}
