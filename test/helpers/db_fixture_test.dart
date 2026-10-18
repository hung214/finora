import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/drift/app_database.dart';

import 'db_fixture.dart';

/// T-H1 驗收：記憶體 DB fixture + drift schema v1（對齊 specs/truth/data-spec.dbml）
/// 紅燈階段：AppDatabase / DbFixture 尚未實作。
void main() {
  late AppDatabase db;

  setUp(() {
    db = DbFixture.create();
  });

  tearDown(() async {
    await db.close();
  });

  test('T-S1 schema v1：六張核心表存在（accounts/categories/transactions/oplog/settings/templates）',
      () async {
    final rows =
        await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get();
    final names = rows.map((r) => r.data['name'] as String).toSet();
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
    final row = await db.select(db.accounts).getSingle();
    expect(row.id, 'a1');
    expect(row.type, 'cash');
    expect(row.name, '現金');
    expect(row.currency, 'TWD');
    expect(row.openingAmountMinor, 0);
    expect(row.archived, isFalse);
  });

  test('寫入交易＋依帳戶查詢（index idx_tx_account 語意）', () async {
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
    final rows = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals('cash')))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.amountMinor, 120);
    expect(rows.single.settlementStatus, 'none'); // 預設 none（SDD §4.2）
    expect(rows.single.source, 'manual');
  });

  test('oplog 追加：seq 自增且未打包時 packed_seq 為 null', () async {
    await DbFixture.appendOp(db, entity: 'transactions', entityId: 't1', hlc: 'h1');
    await DbFixture.appendOp(db, entity: 'transactions', entityId: 't2', hlc: 'h2');
    final rows = await db.select(db.oplog).get();
    expect(rows, hasLength(2));
    expect(rows[0].seq, lessThan(rows[1].seq));
    for (final r in rows) {
      expect(r.packedSeq, isNull);
    }
  });

  test('settings 依 key 讀寫（裝置級設定不經同步的約定欄位）', () async {
    await DbFixture.setSetting(db, key: 'device.sync.mode', value: '"batch"');
    final row = await (db.select(db.settings)..where((s) => s.key.equals('device.sync.mode')))
        .getSingle();
    expect(row.value, '"batch"');
  });
}
