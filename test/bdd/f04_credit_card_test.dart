import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/credit_card/billing_cycle_service.dart';
import 'package:ledger_sync/application/credit_card/installment_service.dart';
import 'package:ledger_sync/application/credit_card/notification_check_service.dart';
import 'package:ledger_sync/application/credit_card/refund_service.dart';
import 'package:ledger_sync/application/credit_card/repay_statement_use_case.dart';
import 'package:ledger_sync/application/quick_entry/save_transaction_use_case.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/entities/account.dart';
import 'package:ledger_sync/domain/entities/transaction.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';
import '../helpers/notification_spy.dart';

/// F04-BE 情境執行器（@BE @M3 @FR-C，11 情境塊；歸屬 Outline 執行 2 列 → 12）。
///
/// 來源：specs/plan/tests/backend/F04_credit-card-billing.feature（sync_features.ps1
/// 同步副本，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
/// ⚠️ 金額/結帳邏輯模組：待雙重 review（research §1.3）。
void main() {
  final source = File('test/bdd/F04_credit-card-billing.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F04-BE：信用卡帳單引擎（11 情境塊；Outline 執行 2 列 → 12）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      final executed = await runner.run(doc, tagFilter: (tags) => tags.contains('@BE'));
      expect(executed, 12, reason: 'F04-BE 應執行 12 個情境（11 情境塊＋歸屬 Outline 逐列 2）');
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
  late RepayStatementUseCase repay;

  /// 名稱 → id 對映（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};

  /// 最近一次記錄之交易 id（settlement 斷言用）。
  String? lastTxId;

  /// Given 種下之預扣交易 id（結帳 billed 斷言用）。
  final seededPendingIds = <String>[];

  /// Given 預扣期間末日（生效日計算基準）。
  int? lastPendingEndMs;

  /// 最近一次結算/種下之帳單 id 與期間文字。
  String? lastStatementId;
  String lastPeriodText = '';

  /// 最近一次分期 plan 與子交易。
  String? lastPlanId;
  List<String> lastInstallmentTxIds = [];
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
    w.seededPendingIds.clear();
    w.lastPendingEndMs = null;
    w.lastStatementId = null;
    w.lastPeriodText = '';
    w.lastPlanId = null;
    w.lastInstallmentTxIds = [];
    w.save = SaveTransactionUseCase(db);
    w.repay = RepayStatementUseCase(db, w.spy);
  });

  // 卡片結帳日當天凍結——須先於 base 模擬時間註冊（前綴碰撞教訓）。
  runner.on(r'模擬系統時間為 {dt} 後觸發通知檢查$', (p) {
    Clock.freeze(_dateTime(p['dt']!));
    NotificationCheckService(w.db, w.spy).run();
  });
  runner.on(r'模擬系統時間為 {card} 的結帳日當天$', (p) async {
    final cardId = w.accounts[p['card']!]!;
    final detail = w.db.creditCardDetail(cardId)!;
    final now = Clock.now();
    Clock.freeze(DateTime(now.year, now.month, detail.statementDay, 12));
  });

  runner.on(r'模擬系統時間為 {dt}$', (p) => Clock.freeze(_dateTime(p['dt']!)));

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

  // 長版（含繳款日加）——須先於短版註冊（前綴碰撞教訓）。
  runner.on(r'已建立信用卡「{name}」: 結帳日 {day} 號、繳款日加 {offset} 天、歸屬 {rule}$',
      (p) async {
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

  // 短版（繳款日加預設 15 天；clamp 情境）。
  runner.on(r'已建立信用卡「{name}」: 結帳日 {day} 號、歸屬 {rule}$', (p) async {
    final accountId = 'card-${w.accounts.length}';
    await DbFixture.seedCreditCard(
      w.db,
      accountId: accountId,
      name: p['name']!,
      statementDay: int.parse(p['day']!),
      dueOffsetDays: 15,
      boundaryRule: p['rule']!,
    );
    w.accounts[p['name']!] = accountId;
  });

  // ── When：信用卡消費（FR-C1：settlement=pending）──────────
  runner.on(r'以「{card}」記錄支出 {amt}$', (p) {
    final result = w.save.execute(
      accountId: w.accounts[p['card']!]!,
      amountMinor: _amount(p['amt']!),
      occurredAt: Clock.now(),
      settlementStatus: 'pending',
    );
    w.lastTxId = result.transactionId;
  });

  runner.on(r'以「{card}」記錄支出 {amt}（{cat}）$', (p) {
    final catId = _getOrCreateCategory(w, p['cat']!);
    final result = w.save.execute(
      accountId: w.accounts[p['card']!]!,
      categoryId: catId,
      amountMinor: _amount(p['amt']!),
      occurredAt: Clock.now(),
      settlementStatus: 'pending',
    );
    w.lastTxId = result.transactionId;
  });

  // ── Then：預扣與本期應付（FR-C1）─────────────────────────
  runner.on(r'交易 settlement_status = {status}$', (p) {
    if (p['status'] == 'billed') {
      // 結帳語意（FR-C3）：種下之預扣交易應全部標記 billed。
      for (final id in w.seededPendingIds) {
        expect(w.db.transactionById(id)!.settlementStatus, 'billed',
            reason: '結帳後預扣交易應標記 billed');
      }
      return;
    }
    final row = w.db.transactionById(w.lastTxId!);
    expect(row, isNotNull, reason: '交易應已入庫');
    expect(row!.settlementStatus, p['status'], reason: 'FR-C1：刷卡預扣');
  });

  runner.on(r'帳戶「{a}」重算餘額 = {amount}（本期應付）$', (p) {
    final open = const BalanceCalculator().creditOpenBalance(
      card: _accountEntity(_accountRow(w, p['a']!)),
      txs: w.db.allTransactions().map(_txEntity),
    );
    expect(open, _amount(p['amount']!),
        reason: 'FR-C1：本期應付（Σ pending，衍生值）');
  });

  runner.on(r'帳戶「{a}」重算餘額 = {amount}$', (p) {
    final balance = const BalanceCalculator().assetBalance(
      account: _accountEntity(_accountRow(w, p['a']!)),
      txs: w.db.allTransactions().map(_txEntity),
    );
    expect(balance, _amount(p['amount']!), reason: '衍生餘額（SDD 原則 2）');
  });

  // ── Given：預扣種子（「期間」尾綴變體須先於無尾綴 base）────
  runner.on(r'已有 {n} 筆預扣交易於「{card}」共 {amount}（{start}~{end} 期間）$', (p) {
    _seedPendingForPeriod(w, p['card']!, int.parse(p['n']!),
        _amount(p['amount']!), '${p['start']!}~${p['end']!}');
  });

  runner.on(r'已有 {n} 筆預扣交易於「{card}」共 {amount}（{start}~{end}）$', (p) {
    _seedPendingForPeriod(w, p['card']!, int.parse(p['n']!),
        _amount(p['amount']!), '${p['start']!}~${p['end']!}');
  });

  runner.on(r'已有 {n} 筆預扣交易於「{card}」共 {amount}$', (p) {
    _seedPendingForPeriod(w, p['card']!, int.parse(p['n']!),
        _amount(p['amount']!), null);
  });

  // ── When：結帳（FR-C3）────────────────────────────────────
  runner.on(r'執行 BillingCycleService.run（「{card}」）$', (p) {
    final service = BillingCycleService(w.db, w.spy);
    w.lastStatementId = service.run(w.accounts[p['card']!]!);
  });

  // ── Then：歸屬（FR-C2 Outline）────────────────────────────
  runner.on(r'該筆 {amount} 歸屬於{period}$', (p) {
    final statement = w.db.statementById(w.lastStatementId!);
    expect(statement, isNotNull, reason: '結帳應產生帳單');
    final items = w.db.statementItemTxIds(w.lastStatementId!);
    expect(items.contains(w.lastTxId), p['period'] == '本期',
        reason: 'boundary_rule 歸屬：${p['period']}（include=當天算本期）');
  });

  // ── Then：帳單（FR-C3）────────────────────────────────────
  runner.on(r'產生帳單 {period}、應繳 {amount}、繳款日 {due}$', (p) {
    final statement = w.db.statementById(w.lastStatementId!);
    expect(statement, isNotNull, reason: '結帳應產生帳單');
    final start = DateTime.fromMillisecondsSinceEpoch(statement!.periodStart);
    final end = DateTime.fromMillisecondsSinceEpoch(statement.periodEnd);
    final periodText = '${_ymd4(start)}~'
        '${end.month.toString().padLeft(2, '0')}/${end.day.toString().padLeft(2, '0')}';
    expect(periodText, p['period'], reason: '帳單期間');
    expect(statement.totalMinor, _amount(p['amount']!), reason: '應繳（Σ pending）');
    final due = DateTime.fromMillisecondsSinceEpoch(statement.dueDate);
    expect(_ymd4(due), p['due'], reason: '繳款日（結帳日＋offset）');
    expect(_thousands(statement.totalMinor), contains(','), reason: 'N-4 千分位前置');
  });

  // ── Given／When／Then：繳款（FR-C4）───────────────────────
  // 變體（含交易／繳款日）須先於 base 註冊（前綴碰撞教訓）。
  runner.on(r'帳單 {period} 應繳 {amount} 狀態 {status}，含交易 {txAmount}（billed）$',
      (p) async {
    final (startMs, endMs) = _parsePeriodRange(p['period']!);
    final cardId = _firstCreditCard(w.db).id;
    final txId = 'tx-refund-orig';
    await DbFixture.seedTx(
      w.db,
      id: txId,
      kind: 'expense',
      amountMinor: _amount(p['txAmount']!),
      accountId: cardId,
      category: _getOrCreateCategory(w, '購物'),
      occurredAt: startMs + 86400000,
      settlementStatus: 'billed',
    );
    w.lastTxId = txId;
    w.lastPeriodText = p['period']!;
    w.lastStatementId = await DbFixture.seedStatement(
      w.db,
      accountId: cardId,
      periodStartMs: startMs,
      periodEndMs: endMs,
      totalMinor: _amount(p['amount']!),
      status: p['status']!,
    );
    w.db.insertStatementItems(w.lastStatementId!, [txId]);
  });

  runner.on(r'帳單 {period} 應繳 {amount} 狀態 {status}（繳款日 {due}）$', (p) async {
    final (startMs, endMs) = _parsePeriodRange(p['period']!);
    w.lastPeriodText = p['period']!;
    w.lastStatementId = await DbFixture.seedStatement(
      w.db,
      accountId: _firstCreditCard(w.db).id,
      periodStartMs: startMs,
      periodEndMs: endMs,
      totalMinor: _amount(p['amount']!),
      status: p['status']!,
      dueDateMs: _dueDateFrom(p['due']!, startMs).millisecondsSinceEpoch,
    );
  });

  runner.on(r'帳單 {period} 應繳 {amount} 狀態 {status}$', (p) async {
    final (startMs, endMs) = _parsePeriodRange(p['period']!);
    w.lastPeriodText = p['period']!;
    w.lastStatementId = await DbFixture.seedStatement(
      w.db,
      accountId: _firstCreditCard(w.db).id,
      periodStartMs: startMs,
      periodEndMs: endMs,
      totalMinor: _amount(p['amount']!),
      status: p['status']!,
    );
  });

  runner.on(r'執行 RepayStatementUseCase（帳單 {period}、金額 {amount}）$', (p) {
    final (startMs, endMs) = _parsePeriodRange(p['period']!);
    final statement =
        w.db.statementForPeriod(_firstCreditCard(w.db).id, startMs, endMs);
    expect(statement, isNotNull, reason: '帳單應存在');
    w.repay.execute(
        statementId: statement!.id, amountMinor: _amount(p['amount']!));
  });

  runner.on(r'帳單狀態 = {status}、已繳 {paid}、剩餘 {remaining}$', (p) {
    final (startMs, endMs) = _parsePeriodRange(w.lastPeriodText);
    final statement =
        w.db.statementForPeriod(_firstCreditCard(w.db).id, startMs, endMs);
    expect(statement, isNotNull, reason: '帳單應存在');
    expect(statement!.status, p['status'], reason: 'FR-C4 狀態機');
    expect(statement.paidMinor, _amount(p['paid']!), reason: '已繳累加');
    expect(statement.remainingMinor, _amount(p['remaining']!), reason: '剩餘');
  });

  runner.on(r'通知 spy 不再收到 N-{n}（已繳取消提醒）$', (p) {
    expect(w.spy.timesWithId(int.parse(p['n']!)), 0,
        reason: '已繳取消提醒（FR-C4）');
  });

  // ── When／Then：通知檢查（FR-C5/C6）───────────────────────
  // 複合句型（後觸發）須先於 base 模擬時間註冊。

  runner.on(r'觸發通知檢查$', (p) {
    NotificationCheckService(w.db, w.spy).run();
  });

  runner.on(r'帳單狀態標記逾期$', (p) {
    final statement = w.db.statementById(w.lastStatementId!);
    expect(statement, isNotNull, reason: '帳單應存在');
    final due = DateTime.fromMillisecondsSinceEpoch(statement!.dueDate);
    final now = Clock.now();
    expect(now.isAfter(due), isTrue, reason: 'due_date 已過（逾期中）');
    expect(statement.status, isNot('paid'), reason: '未繳清');
    expect(statement.overdueNotified, isTrue, reason: 'N-6 恰一次後標記');
  });

  runner.on(r'通知 spy 收到 N-{n} 仍恰 {k} 次$', (p) {
    expect(w.spy.timesWithId(int.parse(p['n']!)), int.parse(p['k']!),
        reason: 'N-${p['n']} 冪等（不重複轟炸）');
  });

  runner.on(r'通知 spy 收到 N-{n} 恰 {k} 次$', (p) {
    expect(w.spy.timesWithId(int.parse(p['n']!)), int.parse(p['k']!),
        reason: 'N-${p['n']} 次數（分級去重）');
  });

  runner.on(r'通知 spy 收到 N-{n} 恰 {k} 次，內容含 "{text}"$', (p) {
    final n = int.parse(p['n']!);
    expect(w.spy.timesWithId(n), int.parse(p['k']!), reason: 'N-$n 次數');
    final hit = w.spy.withId(n).any(
        (r) => r.body.contains(p['text']!) || r.title.contains(p['text']!));
    expect(hit, isTrue, reason: 'N-$n 內容應含「${p['text']}」');
  });

  // ── When／Then：分期（FR-C7）──────────────────────────────
  runner.on(r'以「{card}」建立分期 {total} 分 {n} 期、首期 {date}$', (p) {
    final service = InstallmentService(w.db);
    final result = service.create(
      cardAccountId: w.accounts[p['card']!]!,
      totalMinor: _amount(p['total']!),
      installments: int.parse(p['n']!),
      firstDate: _dateTime(p['date']!),
    );
    w.lastPlanId = result.planId;
    w.lastInstallmentTxIds = result.txIds;
  });

  runner.on(r'產生 {n} 筆未來 pending 交易（每筆 {amount}、installment_seq 1..{last}）$',
      (p) {
    final n = int.parse(p['n']!);
    final each = _amount(p['amount']!);
    final txs = [
      for (final id in w.lastInstallmentTxIds) w.db.transactionById(id)!
    ];
    expect(txs, hasLength(n), reason: '分期排程筆數');
    for (var i = 0; i < n; i++) {
      expect(txs[i].settlementStatus, 'pending', reason: '未來承諾為 pending');
      expect(txs[i].installmentSeq, i + 1, reason: 'installment_seq 1..$n');
      expect(txs[i].amountMinor, each, reason: '每期金額');
    }
  });

  runner.on(r'帳戶「{card}」未來已承諾 = {amount}$', (p) {
    final now = Clock.now().millisecondsSinceEpoch;
    final committed = w.db
        .allTransactions()
        .where((t) =>
            t.accountId == w.accounts[p['card']!]! &&
            t.settlementStatus == 'pending' &&
            t.occurredAt > now)
        .fold<int>(0, (s, t) => s + t.amountMinor);
    expect(committed, _amount(p['amount']!), reason: '未來已承諾（FR-C7）');
  });

  runner.on(r'刪除該分期計畫$', (p) {
    InstallmentService(w.db).deletePlan(w.lastPlanId!);
  });

  runner.on(r'尚未到期的 {n} 筆分期交易已移除$', (p) {
    for (final id in w.lastInstallmentTxIds) {
      expect(w.db.transactionById(id), isNull,
          reason: 'FR-C7 刪除連動：未到期承諾已移除');
    }
  });

  // ── When／Then：退款（FR-C8）──────────────────────────────
  runner.on(r'針對該筆建立退款 {amount}$', (p) {
    RefundService(w.db).createRefund(
      originalTxId: w.lastTxId!,
      amountMinor: _amount(p['amount']!),
    );
  });

  runner.on(r'帳單應繳 = {amount}（負項明細 -{refund}）$', (p) {
    final statement = w.db.statementById(w.lastStatementId!);
    expect(statement!.totalMinor, _amount(p['amount']!),
        reason: 'FR-C8：帳單負項沖減（-${p['refund']}）');
  });

  runner.on(r'refund_links 關聯已建立$', (p) {
    expect(w.db.refundLinkExistsForOriginal(w.lastTxId!), isTrue,
        reason: 'refund_links 關聯（FR-C8）');
  });

  // ── When／Then：生效日（FR-A3）────────────────────────────
  runner.on(r'修改「{card}」結帳日為 {day} 號（effective_from 下一期）$', (p) {
    // effective_from = 目前週期結束後一日（下一期起算日）。
    final cardId = w.accounts[p['card']!]!;
    final detail = w.db.creditCardDetail(cardId)!;
    // effective_from = 預扣期間末日＋1（Given 已凍結語意之下一期起算）。
    final nextPeriodStart = DateTime.fromMillisecondsSinceEpoch(w.lastPendingEndMs!);
    w.db.updateCreditCardStatementDay(
        cardId, int.parse(p['day']!), nextPeriodStart.millisecondsSinceEpoch);
  });

  runner.on(r'帳單 {period} 仍以 {day} 號規則結算$', (p) {
    // FR-A3 語意：effective_from = 下期起算日 > 本期結束 → 本期仍適用舊規則。
    final cardId = w.accounts['卡A']!;
    final detail = w.db.creditCardDetail(cardId)!;
    final (startMs, endMs) = _parsePeriodRange(p['period']!);
    expect(detail.effectiveFrom, isNotNull);
    expect(detail.effectiveFrom! > endMs, isTrue,
        reason: '修改自下期生效——本期（${p['period']}）不受影響（仍以 ${p['day']} 號舊規則）');
    expect(detail.statementDay, 15, reason: '新結帳日已設定（下一期適用）');
  });

  runner.on(r'下一期週期 = {period}$', (p) {
    final cardId = w.accounts['卡A']!;
    final detail = w.db.creditCardDetail(cardId)!;
    final effectiveFrom =
        DateTime.fromMillisecondsSinceEpoch(detail.effectiveFrom!);
    final nextEnd = _clampDayOf(effectiveFrom.year, effectiveFrom.month,
        detail.statementDay);
    final periodText = '${_ymd4(effectiveFrom)}~'
        '${nextEnd.month.toString().padLeft(2, '0')}/${nextEnd.day.toString().padLeft(2, '0')}';
    expect(periodText, p['period'], reason: 'FR-A3：新結帳日之下一期週期');
  });
}

// ── 共用輔助 ─────────────────────────────────────────────

Future<void> _seedPendingForPeriod(
    _World w, String cardName, int count, int total, String? rangeText) async {
  final cardId = w.accounts[cardName]!;
  final joined = rangeText ?? '';
  final rangeRe = RegExp(r'(\d{1,2})/(\d{1,2})~(\d{1,2})/(\d{1,2})');
  final m = rangeRe.firstMatch(joined);
  if (m == null) throw FormatException('期間格式未支援：$joined');
  final year = Clock.now().year;
  final start = DateTime(year, int.parse(m.group(1)!), int.parse(m.group(2)!), 12);
  final end = DateTime(year, int.parse(m.group(3)!), int.parse(m.group(4)!), 12);
  final days = end.difference(start).inDays + 1;
  final each = total ~/ count;
  final extra = total - each * count; // 餘數補前筆（Σ = total）
  final catId = _getOrCreateCategory(w, '購物');
  for (var i = 0; i < count; i++) {
    final amountMinor = each + (i < extra ? 1 : 0);
    final occurred = start.add(Duration(days: days * i ~/ count));
    final id = 'tx-f04-${w.db.allTransactions().length}';
    await DbFixture.seedTx(
      w.db,
      id: id,
      kind: 'expense',
      amountMinor: amountMinor,
      accountId: cardId,
      category: catId,
      occurredAt: occurred.millisecondsSinceEpoch,
      settlementStatus: 'pending',
    );
    w.seededPendingIds.add(id);
  }
  w.lastPendingEndMs = end.add(const Duration(days: 1)).millisecondsSinceEpoch;
}

AccountRow _accountRow(_World w, String name) =>
    w.db.allAccounts().firstWhere((r) => r.name == name);

Account _accountEntity(AccountRow r) => Account(
      id: r.id,
      type: AccountType.values.byName(r.type),
      name: r.name,
      currency: r.currency,
      openingAmountMinor: r.openingAmountMinor,
      archived: r.archived,
    );

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

/// 分類隱式建立（F04 Background 無分類 Given）。
String _getOrCreateCategory(_World w, String name) {
  final existing = w.categories[name];
  if (existing != null) return existing;
  final id = 'c-${w.categories.length}';
  DbFixture.seedCategory(w.db, id: id, kind: 'expense', name: name);
  w.categories[name] = id;
  return id;
}

/// 第一張信用卡（帳單 Given 未指明卡片時之預設）。
AccountRow _firstCreditCard(AppDatabase db) =>
    db.allAccounts().firstWhere((a) => a.type == 'credit');

DateTime _lastStatementDateOf(DateTime now, int day) {
  var candidate = _clampDayOf(now.year, now.month, day);
  if (candidate.isAfter(now)) {
    final prev = DateTime(now.year, now.month - 1);
    candidate = _clampDayOf(prev.year, prev.month, day);
  }
  return candidate;
}

DateTime _clampDayOf(int y, int m, int day) {
  final monthEnd = DateTime(y, m + 1, 1).subtract(const Duration(days: 1));
  final wanted = DateTime(y, m, day);
  return wanted.isAfter(monthEnd) ? monthEnd : wanted;
}

DateTime _dateTime(String s) {
  final m = RegExp(r'^(\d{4})/(\d{2})/(\d{2})(?: (\d{1,2}):(\d{2}))?$')
      .firstMatch(s.trim());
  if (m == null) throw FormatException('日期時間格式未支援：$s（dsl.md §1-3）');
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    m.group(4) == null ? 0 : int.parse(m.group(4)!),
    m.group(5) == null ? 0 : int.parse(m.group(5)!),
  );
}

/// `7/20`（M/D）＋期間起點年 → DateTime（F04 繳款日格式）。
DateTime _dueDateFrom(String mD, int startMs) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})$').firstMatch(mD.trim());
  if (m == null) throw FormatException('繳款日格式未支援：\$mD');
  final year = DateTime.fromMillisecondsSinceEpoch(startMs).year;
  return DateTime(year, int.parse(m.group(1)!), int.parse(m.group(2)!));
}

(int, int) _parsePeriodRange(String period) {
  final m = RegExp(r'^(\d{4})/(\d{2})/(\d{2})~(\d{2})/(\d{2})$')
      .firstMatch(period.trim());
  if (m == null) throw FormatException('期間格式未支援：$period（dsl.md §2.1）');
  final year = int.parse(m.group(1)!);
  final start = DateTime(year, int.parse(m.group(2)!), int.parse(m.group(3)!));
  final end = DateTime(
      year, int.parse(m.group(4)!), int.parse(m.group(5)!), 23, 59, 59, 999);
  return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
}

String _ymd4(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String _thousands(int amount) {
  final s = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buf.write(s[i]);
    if (rev > 1 && rev % 3 == 1) buf.write(',');
  }
  return '${amount < 0 ? '-' : ''}$buf';
}

int _amount(String s) {
  final m = RegExp(r'^-?[\d,]+').firstMatch(s.trim());
  if (m == null) throw FormatException('金額格式未支援：$s');
  return int.parse(m.group(0)!.replaceAll(',', ''));
}
