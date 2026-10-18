import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';

import 'db_fixture.dart';

/// T-H1 驗收：記憶體 DB fixture + schema v1（對齊 specs/truth/data-spec.dbml）。
/// T-S1 基線：v1 建表 + 建表回歸（truth 自動對齊測試 T-H9 後續補上）。
void main() {
  late AppDatabase db;

  setUp(() {
    db = DbFixture.create();
  });

  tearDown(() {
    db.close();
  });

  test('T-S1 schema v1：六張核心表存在（accounts/categories/transactions/oplog/settings/templates）',
      () {
    final names = db.tableNames().toSet();
    for (final table in [
      'accounts',
      'categories',
      'transactions',
      'oplog',
      'settings',
      'templates',
    ]) {
      expect(names, contains(table), reason: '缺少資料表 $table');
    }
  });

  test('T-S1 schemaVersion = 1', () {
    expect(db.schemaVersion, 1);
  });

  test('寫入/讀取帳戶：預設值對齊 data-spec（currency=TWD、archived=false、opening=0）',
      () async {
    await DbFixture.seedAccount(db, id: 'a1', type: 'cash', name: '現金');
    final row = db.allAccounts().single;
    expect(row.id, 'a1');
    expect(row.type, 'cash');
    expect(row.name, '現金');
    expect(row.currency, 'TWD');
    expect(row.openingAmountMinor, 0);
    expect(row.archived, isFalse);
  });

  test('寫入交易＋依帳戶查詢（idx_tx_account 語意）＋預設 source/settlement', () async {
    await DbFixture.seedAccount(db, id: 'cash', type: 'cash', name: '現金');
    await DbFixture.seedTx(
      db,
      id: 't1',
      kind: 'expense',
      amountMinor: 120,
      accountId: 'cash',
      category: '餐飲',
      occurredAt: 1760760000000,
    );
    final rows = db.transactionsByAccount('cash');
    expect(rows, hasLength(1));
    expect(rows.single.amountMinor, 120);
    expect(rows.single.settlementStatus, 'none'); // 預設 none（SDD §4.2）
    expect(rows.single.source, 'manual');
  });

  test('儲存事務：交易與 oplog 同一 transaction（SDD §5.1）', () async {
    await DbFixture.seedTx(
      db,
      id: 't1',
      kind: 'expense',
      amountMinor: 120,
      accountId: 'cash',
      occurredAt: 1760760000000,
    );
    final ops = db.allOps();
    expect(ops, hasLength(1));
    expect(ops.single.entity, 'transactions');
    expect(ops.single.entityId, 't1');
    expect(ops.single.packedSeq, isNull); // 未打包
    expect(ops.single.seq, 1); // AUTOINCREMENT
  });

  test('oplog 追加：seq 自增', () async {
    await DbFixture.appendOp(db, entity: 'transactions', entityId: 't1', hlc: 'h1');
    await DbFixture.appendOp(db, entity: 'transactions', entityId: 't2', hlc: 'h2');
    final rows = db.allOps();
    expect(rows, hasLength(2));
    expect(rows[0].seq!, lessThan(rows[1].seq!));
  });

  test('settings 依 key 讀寫（upsert；device.* 為 per-device 不入 oplog）', () async {
    await DbFixture.setSetting(db, key: 'device.sync.mode', value: '"batch"');
    await DbFixture.setSetting(db, key: 'device.sync.mode', value: '"per-tx"');
    expect(db.getSetting('device.sync.mode'), '"per-tx"');
    expect(db.getSetting('nope'), isNull);
  });
}
