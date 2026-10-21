import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/data/sqlite/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// T-S3 schema v3 遷移回歸（tasks.md §3；F04 信用卡前置）。
///
/// v3 範圍（data-spec.dbml v0.3 既有定義）：credit_card_details（FR-A3）、
/// statements/statement_items（FR-C3 帳單）、refund_links（FR-C8）、
/// installment_plans（FR-C7）。
void main() {
  test('全新 DB：直達 schema v3（M1 六表＋v2 三表＋v3 五表）', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: '遷移鏈現達 v5（T-S5）——T-S3 表清單不變');
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
    ]) {
      expect(tables, contains(t), reason: 'schema v3 應含 $t');
    }
  });

  test('v2 舊檔 DB：開啟即自動升級 v3，且舊資料完整（tasks.md §3 回歸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v3');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    // 以 v3 之前的 DDL 手動建 v2 DB（v1 全量＋v2 增量）＋種資料＋標 user_version = 2。
    final raw = sqlite3.open(path);
    for (final s in [...SchemaV1.statements, ...SchemaV2.statements]) {
      raw.execute(s);
    }
    for (final s in SchemaV1.indexes) {
      raw.execute(s);
    }
    raw.execute(
      "INSERT INTO accounts (id, type, name, currency, opening_amount_minor, archived,"
      " created_at, updated_at, hlc) VALUES ('a1', 'bank', '薪轉', 'TWD', 50000, 0, 1, 1, '1.0.t')",
    );
    raw.execute('PRAGMA user_version = 2');
    raw.dispose();

    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: '開啟舊檔自動升級至現行版本（遷移鏈）');
    expect(db.tableNames(), containsAll(['credit_card_details', 'statements', 'installment_plans']),
        reason: '升級後不得缺新表');
    expect(
      db.allAccounts().firstWhere((a) => a.id == 'a1').openingAmountMinor,
      50000,
      reason: '升級不得遺失舊資料',
    );
  });

  test('v3 冪等：同檔二次開啟不重跑遷移（DBG-004 回歸延伸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v3_idem');
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
