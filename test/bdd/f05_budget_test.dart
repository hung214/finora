import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/budgets/budget_alert_service.dart';
import 'package:ledger_sync/application/budgets/budget_evaluator.dart';
import 'package:ledger_sync/application/quick_entry/save_transaction_use_case.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';
import '../helpers/notification_spy.dart';

/// F05-BE 情境執行器（@BE @M2 @FR-B @P0，5 情境）。
///
/// 來源：specs/plan/tests/backend/F05_budget-income-goal.feature（sync_features.ps1
/// 同步副本，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
/// 警示語意：BudgetAlertService.sync 為**冪等 sync 點**（記帳鉤子＋斷言前呼叫）。
void main() {
  final source = File('test/bdd/F05_budget-income-goal.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F05-BE：預算與收入目標計算（5 情境：閾值×2／預扣口徑／達標率／週期邊界）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      final executed =
          await runner.run(doc, tagFilter: (tags) => tags.contains('@BE') && tags.contains('@P0'));
      expect(executed, 5, reason: 'F05-BE 應執行 5 個情境（@BE @P0）');
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
  late BudgetAlertService alerts;

  /// When 步驟前的 oplog 數（delta 基準）。
  int opBaseline = 0;

  /// 名稱 → id 對映（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};
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
    w.opBaseline = 0;
    w.alerts = BudgetAlertService(db, w.spy);
    // 記帳鉤子（sync 點①）：入庫後冪等同步預算警示（FR-B4）。
    w.save = SaveTransactionUseCase(db, afterSave: w.alerts.sync);
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

  runner.on(r'已建立分類{names}$', (p) {
    final names =
        RegExp('「([^」]+)」').allMatches(p['names']!).map((m) => m.group(1)!).toList();
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final id = 'c-${w.categories.length}';
      DbFixture.seedCategory(
        w.db,
        id: id,
        kind: name == '薪資' ? 'income' : 'expense',
        name: name,
      );
      w.categories[name] = id;
    }
  });

  runner.on(r'模擬系統時間為 {dt}$', (p) => Clock.freeze(_dateTime(p['dt']!)));

  // ── Given：預算／收入目標（schema v2；FR-B）───────────────
  runner.on(r'預算「{cat}」金額 {amt}、起始日 {day}$', (p) async {
    await DbFixture.seedBudget(
      w.db,
      id: 'b-${w.db.allBudgets().length}',
      categoryId: w.categories[p['cat']!],
      amountMinor: _amount(p['amt']!),
      periodStartDay: int.parse(p['day']!),
    );
  });

  runner.on(r'預算總額 {amt}、起始日 {day}$', (p) async {
    await DbFixture.seedBudget(
      w.db,
      id: 'b-${w.db.allBudgets().length}',
      categoryId: null, // 總預算（FR-B2）
      amountMinor: _amount(p['amt']!),
      periodStartDay: int.parse(p['day']!),
    );
  });

  runner.on(r'收入目標 {amt}$', (p) async {
    await DbFixture.seedIncomeGoal(
      w.db,
      id: 'g-${w.db.allBudgets().length}',
      amountMinor: _amount(p['amt']!),
    );
  });

  // ── Given：本期資料（F05 S5.1~S5.4）──────────────────────
  runner.on(r'本期{cat}已支出 {amt}$', (p) {
    // 直寫 seed（不觸發警示評估——警示為冪等 sync 點，dsl §2.1 註記）。
    DbFixture.seedTx(
      w.db,
      id: 'tx-base-${w.db.allTransactions().length}',
      kind: 'expense',
      amountMinor: _amount(p['amt']!),
      accountId: _firstActiveAccount(w.db).id,
      category: w.categories[p['cat']!],
      occurredAt: Clock.now().millisecondsSinceEpoch,
    );
  });

  runner.on(r'本月已入帳收入 {amt}$', (p) {
    DbFixture.seedTx(
      w.db,
      id: 'tx-inc-${w.db.allTransactions().length}',
      kind: 'income',
      amountMinor: _amount(p['amt']!),
      accountId: _firstActiveAccount(w.db).id,
      category: w.categories['薪資'],
      occurredAt: Clock.now().millisecondsSinceEpoch,
    );
  });

  runner.on(r'已存在支出 {d1}（{cat1} {a1}）與 {d2}（{cat2} {a2}）$', (p) {
    final base = Clock.now();
    for (final (dateStr, catKey, amountStr) in [
      (p['d1']!, p['cat1']!, p['a1']!),
      (p['d2']!, p['cat2']!, p['a2']!),
    ]) {
      final m = RegExp(r'^(\d{1,2})/(\d{1,2})$').firstMatch(dateStr)!;
      final at = DateTime(base.year, int.parse(m.group(1)!), int.parse(m.group(2)!), 12);
      DbFixture.seedTx(
        w.db,
        id: 'tx-hist-${w.db.allTransactions().length}',
        kind: 'expense',
        amountMinor: _amount(amountStr),
        accountId: _firstActiveAccount(w.db).id,
        category: w.categories[catKey],
        occurredAt: at.millisecondsSinceEpoch,
      );
    }
  });

  // ── When：記帳（F05 S5.1~S5.3）───────────────────────────
  runner.on(r'呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）$', (p) {
    w.opBaseline = w.db.allOps().length;
    w.save.execute(
      accountId: w.accounts[p['a']!]!,
      categoryId: w.categories[p['c']!],
      amountMinor: _amount(p['amt']!),
      occurredAt: _dateTime(p['t']!),
    );
  });

  runner.on(r'以「{card}」記錄支出 {amt}（{cat}，預扣）$', (p) {
    w.opBaseline = w.db.allOps().length;
    // F05 S5.3：信用卡支出 = pending 預扣（承諾支出口徑）。
    w.save.execute(
      accountId: w.accounts[p['card']!]!,
      categoryId: w.categories[p['cat']!],
      amountMinor: _amount(p['amt']!),
      occurredAt: Clock.now(),
      settlementStatus: 'pending',
    );
  });

  // ── Then：用量／達標率／結餘／週期（F05 S5.3~S5.6）─────────
  runner.on(r'{cat}預算用量 = {amt}（{note}）$', (p) => _expectUsage(w, p));
  runner.on(r'{cat}預算用量 = {amt}$', (p) => _expectUsage(w, p));

  runner.on(r'預算明細標記預扣部分 {amt}$', (p) {
    final usage = _evaluator(w).categoryUsage(w.categories['餐飲']!)!;
    expect(usage.pendingMinor, _amount(p['amt']!),
        reason: 'FR-B5：預扣分量可辨識（settlement=pending）');
  });

  runner.on(r'收入目標達標率 = {pct}%（已達成）$', (p) {
    final status = _evaluator(w).incomeGoalStatus();
    expect(status, isNotNull, reason: '收入目標應已設定（FR-B6）');
    expect(status!.ratePercent, int.parse(p['pct']!),
        reason: '達標率（四捨五入；>100% 不封頂）');
    expect(status.achieved, isTrue, reason: '達成狀態明確');
  });

  runner.on(r'本月預計結餘 = {amt}（{expr}）$', (p) {
    expect(_evaluator(w).plannedBalanceMinor(), _amount(p['amt']!),
        reason: 'FR-B7：預計結餘 = 收入目標 − 總預算（${p['expr']}）');
  });

  runner.on(r'目前週期 = {start} ~ {end}$', (p) {
    final period = _evaluator(w).categoryPeriod(w.categories['餐飲']!);
    expect(period, isNotNull, reason: '餐飲預算應已設定（FR-B2）');
    expect(period!.display(), '${p['start']} ~ ${p['end']}',
        reason: 'S5.6：自訂起始日跨月週期');
  });

  // ── Then：預算警示（F05 S5.1/S5.2；斷言前 sync＝警示檢視點，dsl §2.3）──
  runner.on(r'通知 spy 收到 N-{n} 恰 {k} 次，內容含 "{text}"$', (p) {
    w.alerts.sync();
    final n = int.parse(p['n']!);
    expect(w.spy.timesWithId(n), int.parse(p['k']!),
        reason: 'N-$n 次數（每期每級別一次）');
    final hit = w.spy
        .withId(n)
        .any((r) => r.body.contains(p['text']!) || r.title.contains(p['text']!));
    expect(hit, isTrue, reason: 'N-$n 內容應含「${p['text']}」');
  });

  runner.on(r'通知 spy 收到 N-{n} 恰 {k} 次$', (p) {
    w.alerts.sync();
    expect(w.spy.timesWithId(int.parse(p['n']!)), int.parse(p['k']!),
        reason: 'N-${p['n']} 次數');
  });

  runner.on(r'通知 spy 收到 N-{n} 仍恰 {k} 次（不重複）$', (p) {
    w.alerts.sync();
    expect(w.spy.timesWithId(int.parse(p['n']!)), int.parse(p['k']!),
        reason: 'N-${p['n']} 冪等（不重複轟炸）');
  });
}

/// 用量斷言共用（含 pending；S5.3/S5.6）。
void _expectUsage(_World w, Map<String, String> p) {
  final usage = _evaluator(w).categoryUsage(w.categories[p['cat']!]!);
  expect(usage, isNotNull, reason: '${p['cat']} 預算應已設定');
  expect(usage!.totalMinor, _amount(p['amt']!),
      reason: '${p['cat']} 預算用量（承諾支出口徑，含 pending 預扣；${p['note'] ?? ''}）');
}

BudgetEvaluator _evaluator(_World w) => BudgetEvaluator(w.db);

AccountRow _firstActiveAccount(AppDatabase db) => db
    .allAccounts()
    .where((a) => !a.archived)
    .toList()
    .first;

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));

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
