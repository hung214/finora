import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/data/sqlite/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// T-S6（M8）schema v6 遷移回歸（tasks.md §3；F11 帳戶合併計算前置）。
///
/// v6 範圍：`accounts.include_in_totals`（SPEC FR-A2/A6/A7「是否計入合併
/// 統計」）。既有資料以 `DEFAULT 1` 維持計入——升級不改變使用者所見合計。
void main() {
  test('全新 DB：直達 schema v6 且 accounts 具 include_in_totals', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    expect(db.schemaVersion, 6, reason: 'T-S6：schema v6（合併計算欄）');
    final cols = db
        .select('PRAGMA table_info(accounts)')
        .map((r) => r['name'] as String)
        .toList();
    expect(cols, contains('include_in_totals'));
    // 既有 14＋2 表不受影響。
    expect(db.tableNames(), containsAll(['accounts', 'sync_events', 'recurring_transactions']));
  });

  test('v5 舊檔 DB：開啟即自動升級 v6，舊資料完整且預設計入合併（tasks.md §3 回歸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v6');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    final raw = sqlite3.open(path);
    for (final s in [
      ...SchemaV1.statements, ...SchemaV2.statements,
      ...SchemaV3.statements, ...SchemaV4.statements, ...SchemaV5.statements,
    ]) {
      raw.execute(s);
    }
    for (final s in SchemaV1.indexes) {
      raw.execute(s);
    }
    raw.execute(
      "INSERT INTO accounts (id, type, name, currency, opening_amount_minor, archived,"
      " created_at, updated_at, hlc) VALUES ('a1', 'bank', '薪轉', 'TWD', 50000, 0, 1, 1, '1.0.t')",
    );
    raw.execute('PRAGMA user_version = 5');
    raw.dispose();

    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 6, reason: '開啟舊檔應自動升級至 v6');
    expect(
      db.allAccounts().firstWhere((a) => a.id == 'a1').openingAmountMinor,
      50000,
      reason: '升級不得遺失舊資料',
    );
    // 既有帳戶預設 include_in_totals = 1（升級不改變合計語意）。
    final flag = db
        .select("SELECT include_in_totals AS f FROM accounts WHERE id = 'a1'")
        .first['f'] as int;
    expect(flag, 1, reason: 'v5 既有帳戶升級後預設仍計入合併');
  });

  test('v6 冪等：同檔二次開啟不重跑遷移（DBG-004 回歸延伸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v6_idem');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    var db = AppDatabase.open(path);
    expect(db.schemaVersion, 6);
    db.close();

    db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 6, reason: '二次開啟維持 v6（不得重跑 ALTER）');
  });
}
