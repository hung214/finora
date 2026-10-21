import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/recurring/recurring_service.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/core/hlc.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';
import '../helpers/notification_spy.dart';

/// F06-BE 情境執行器（@BE @M6 @FR-T5，5 情境：到期提醒未入帳/確認不回寫/
/// 跳過/刪除/逾期 3 次暫停）。
///
/// 來源：specs/plan/tests/backend/F06_recurring-transactions.feature（同步副本）。
/// 句型登記簿：specs/plan/tests/dsl.md §2（v1.0）。
void main() {
  final source = File('test/bdd/F06_recurring-transactions.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F06-BE：定期交易排程（5 情境）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);
    try {
      final executed = await runner.run(doc, tagFilter: (tags) => tags.contains('@BE'));
      expect(executed, 5, reason: 'F06-BE 應執行 5 個情境');
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

class _World {
  final dbs = <AppDatabase>[];
  final NotificationSpy spy = NotificationSpy();
  late AppDatabase db;
  late RecurringService service;
  final accounts = <String, String>{};
  final categories = <String, String>{};
  final recurringIds = <String, String>{};
}

void _bind(GherkinRunner runner, _World w) {
  // ── Background ───────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.spy.clear();
    w.service = RecurringService(db, w.spy);
    w.accounts.clear();
    w.categories.clear();
    w.recurringIds.clear();
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

  runner.on(r'已建立分類「{name}」$', (p) {
    final id = 'c-${w.categories.length}';
    DbFixture.seedCategory(w.db, id: id, kind: 'expense', name: p['name']!);
    w.categories[p['name']!] = id;
  });

  runner.on(r'已建立定期交易「{name}」每月 {day} 日金額 {amt}$', (p) {
    // frequency=monthly；anchor/next_due=當月 day 日（Background 之模擬時間前）。
    final id = 'r-${w.recurringIds.length}';
    final anchor = DateTime(2026, 6, int.parse(p['day']!), 9);
    final now = Clock.now().millisecondsSinceEpoch;
    final row = RecurringRow(
      id: id,
      name: p['name']!,
      kind: 'expense',
      amountMinor: _amount(p['amt']!),
      accountId: w.accounts.values.first,
      categoryId: w.categories.values.first,
      frequency: 'monthly',
      anchorDate: anchor.millisecondsSinceEpoch,
      endType: 'never',
      nextDueDate: anchor.millisecondsSinceEpoch,
      reminderCount: 0,
      paused: false,
      createdAt: now,
      updatedAt: now,
      hlc: Hlc(now, 0, 'd-local').toString(),
    );
    w.db.insertRecurringWithOplog(
        row,
        OplogRow(
          entity: 'recurring_transactions',
          entityId: id,
          hlc: row.hlc,
          payload: _json(row.toSnapshot()),
          packedSeq: null,
        ));
    w.recurringIds[p['name']!] = id;
  });

  runner.on(r'模擬系統時間為 {date} 並觸發到期檢查（第 {n} 次）$',
      (p) => _freezeAndCheck(w, p['date']!));

  runner.on(r'模擬系統時間為 {date} 並觸發到期檢查$',
      (p) => _freezeAndCheck(w, p['date']!));

  runner.on(r'模擬系統時間為 {dt}$', (p) => Clock.freeze(_dateTime(p['dt']!)));

  // ── When ─────────────────────────────────────────────────
  runner.on(r'觸發定期交易到期檢查$', (p) {
    w.service.runCheck();
  });

  runner.on(r'確認入帳（金額改為 {amt}、日期 {date}）$', (p) {
    w.service.confirm(
      scheduleId: w.recurringIds.values.first,
      amountMinor: _amount(p['amt']!),
      date: _dateTime(p['date']!),
    );
  });

  runner.on(r'按下「本次跳過」$', (p) {
    w.service.skip(scheduleId: w.recurringIds.values.first);
  });

  runner.on(r'刪除排程$', (p) {
    w.service.delete(scheduleId: w.recurringIds.values.first);
  });

  // ── Then ─────────────────────────────────────────────────
  runner.on(r'通知 spy 收到 N-{n} 恰 {k} 次，內容含 "{text}"$', (p) {
    final calls = w.spy.withId(int.parse(p['n']!));
    expect(calls.length, int.parse(p['k']!), reason: 'N-7 提醒次數');
    expect(
        calls.map((c) => c.body).where((b) => b.contains(p['text']!)),
        isNotEmpty,
        reason: '通知內容含「${p['text']}」');
  });

  runner.on(r'通知 spy 收到 N-{n} 恰 {k} 次（第 {m} 次不發）$', (p) {
    expect(w.spy.withId(int.parse(p['n']!)).length, int.parse(p['k']!),
        reason: 'N-7：逾期暫停後不再推播');
  });

  // 帶尾綴（S1）先於無尾綴（S3）——註冊順序教訓。
  runner.on(r'交易資料表無新增（未確認不入帳）$', (p) {
    expect(w.db.allTransactions().where((t) => t.deletedAt == null), isEmpty,
        reason: 'FR-T5：提醒確認制——未確認不入帳');
  });

  runner.on(r'交易資料表無新增$', (p) {
    expect(w.db.allTransactions().where((t) => t.deletedAt == null), isEmpty,
        reason: 'FR-T5：跳過不入帳');
  });

  runner.on(r'待確認佇列(?:仍保留|含)「{name} {date}」$', (p) {
    final row = w.db.recurringById(w.recurringIds[p['name']!]!)!;
    final due = DateTime.fromMillisecondsSinceEpoch(row.nextDueDate);
    expect('${due.month}/${due.day}', p['date']!, reason: '待確認佇列項');
  });

  runner.on(r'交易已入庫且 source = recurring$', (p) {
    final txs = w.db.allTransactions().where((t) => t.deletedAt == null).toList();
    expect(txs, hasLength(1), reason: '確認入帳 1 筆');
    expect(txs.first.source, 'recurring', reason: 'FR-T5：source=recurring');
  });

  runner.on(r'交易金額 = {amt}（模板仍為 {amt2}）$', (p) {
    final tx = w.db.allTransactions().first;
    expect(tx.amountMinor, _amount(p['amt']!), reason: '確認時修改之金額');
    final r = w.db.recurringById(w.recurringIds.values.first)!;
    expect(r.amountMinor, _amount(p['amt2']!), reason: 'FR-T5：模板不回寫');
  });

  runner.on(r'next_due_date = {date}$', (p) {
    final r = w.db.recurringById(w.recurringIds.values.first)!;
    final due = DateTime.fromMillisecondsSinceEpoch(r.nextDueDate);
    final expected = _dateTime(p['date']!);
    expect(
      DateTime(due.year, due.month, due.day),
      DateTime(expected.year, expected.month, expected.day),
      reason: 'FR-T5：下期推進（monthly）',
    );
  });

  runner.on(r'reminder_count 歸零$', (p) {
    expect(w.db.recurringById(w.recurringIds.values.first)!.reminderCount, 0,
        reason: '處理後歸零');
  });

  runner.on(r'recurring_transactions 該列為墓標$', (p) {
    expect(w.db.recurringById(w.recurringIds.values.first), isNull,
        reason: '刪除後不列入（allRecurring 排除墓標）');
    final tombstones = w.db.allOps()
        .where((o) =>
            o.entity == 'recurring_transactions' &&
            o.payload == null &&
            o.entityId == w.recurringIds.values.first);
    expect(tombstones, isNotEmpty, reason: 'oplog 墓標（payload=null）');
  });

  runner.on(r'next_due_date 不再產生提醒$', (p) {
    final before = w.spy.withId(7).length;
    w.service.runCheck();
    expect(w.spy.withId(7).length, before, reason: '刪除後不再提醒');
  });

  runner.on(r'reminder_count = {n} 且 paused = true$', (p) {
    final r = w.db.recurringById(w.recurringIds.values.first)!;
    expect(r.reminderCount, int.parse(p['n']!));
    expect(r.paused, isTrue, reason: 'FR-T5：逾期 3 次暫停推播');
  });
}

// ── 輔助 ─────────────────────────────────────────────

void _freezeAndCheck(_World w, String date) {
  Clock.freeze(_dateTime(date));
  w.service.runCheck();
}

String _json(Map<String, Object?> snapshot) => jsonEncode(snapshot);

int _amount(String s) {
  final m = RegExp(r'^-?[\d,]+').firstMatch(s.trim());
  if (m == null) throw FormatException('金額格式未支援：$s');
  return int.parse(m.group(0)!.replaceAll(',', ''));
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
