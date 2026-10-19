import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/first_run_bootstrap.dart';

import '../helpers/db_fixture.dart';

/// M1 過渡：首次啟動播種（acceptance F01 前置條件之內建集；帳戶/分類管理 UI 屬 F02）。
void main() {
  test('空 DB 首次啟動：播種內建分類集（支出 4＋收入薪資）＋預設現金帳戶', () async {
    final db = DbFixture.create();
    await FirstRunBootstrap.seedIfNeeded(db);

    final accounts = db.allAccounts();
    expect(accounts.map((a) => a.name), contains('現金'), reason: 'S1.3 回退基準帳戶');
    expect(accounts.first.type, 'cash');

    final expenses = db.categoriesByKind('expense');
    expect(expenses.map((c) => c.name),
        containsAll(['餐飲', '交通', '購物', '其他']), reason: 'FR-B1 內建集');
    final other = expenses.firstWhere((c) => c.name == '其他');
    expect(other.isSystem, isTrue, reason: '內建「其他」為系統分類');
    expect(db.categoriesByKind('income').map((c) => c.name), contains('薪資'));

    // SDD §5.1：業務表寫入必同步 oplog（同一 DB transaction）
    final ops = db.allOps();
    expect(ops.where((o) => o.entity == 'accounts'), isNotEmpty, reason: '帳戶種子須入 oplog');
    expect(ops.where((o) => o.entity == 'categories'), isNotEmpty, reason: '分類種子須入 oplog');
    for (final op in ops) {
      expect(op.payload, isNotNull, reason: '種子為建立記錄，payload 不得為墓標');
    }
  });

  test('冪等：帳戶或分類任一存在即跳過（避免與使用者資料混雜）', () async {
    final db = DbFixture.create();
    await DbFixture.seedAccount(db, id: 'a-x', type: 'cash', name: '我的錢包');
    final accountsBefore = db.allAccounts().length;
    final opsBefore = db.allOps().length;

    await FirstRunBootstrap.seedIfNeeded(db);

    expect(db.allAccounts().length, accountsBefore, reason: '不得新增種子帳戶');
    expect(db.allOps().length, opsBefore, reason: '不得新增任何寫入');
  });
}
