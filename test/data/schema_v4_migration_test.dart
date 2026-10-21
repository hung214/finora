import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/data/sqlite/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// T-S4 schema v4 遷移回歸（tasks.md §3；F03 掃描前置）。
///
/// v4 範圍（data-spec.dbml v0.3 既有定義）：attachments（FR-S4 附件中繼資——
/// sha256 內容定址，同步去重 SDD §5.5.6；blob 本體存 app 支援目錄 blobs/{sha256}，
/// SDD §4.2 約定，落地於 F03 儲存流程）。
void main() {
  test('全新 DB：直達 schema v4（M1 六表＋v2 三表＋v3 五表＋attachments）', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: '遷移鏈現達 v5（T-S5）——T-S4 表清單不變');
    final tables = db.tableNames();
    for (final t in [
      'accounts',
      'categories',
      'transactions',
      'oplog',
      'settings',
      'templates',
      'budgets',
      'income_goals',
      'credit_card_details',
      'statements',
      'statement_items',
      'refund_links',
      'installment_plans',
      'attachments',
    ]) {
      expect(tables, contains(t), reason: 'schema v4 應含 $t');
    }
  });

  test('v3 舊檔 DB：開啟即自動升級 v4，且舊資料完整（tasks.md §3 回歸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v4');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    // 以 v4 之前的 DDL 手動建 v3 DB（v1 全量＋v2/v3 增量）＋種資料＋標 user_version = 3。
    final raw = sqlite3.open(path);
    for (final s in [
      ...SchemaV1.statements,
      ...SchemaV2.statements,
      ...SchemaV3.statements,
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
    raw.execute('PRAGMA user_version = 3');
    raw.dispose();

    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: '開啟舊檔自動升級至現行版本（遷移鏈）');
    expect(db.tableNames(), contains('attachments'), reason: '升級後不得缺新表');
    expect(
      db.allAccounts().firstWhere((a) => a.id == 'a1').openingAmountMinor,
      50000,
      reason: '升級不得遺失舊資料',
    );
  });

  test('v4 冪等：同檔二次開啟不重跑遷移（DBG-004 回歸延伸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v4_idem');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    var db = AppDatabase.open(path);
    expect(db.schemaVersion, 5);
    db.close();

    db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: '二次開啟維持現行版本（v5）');
  });
}
