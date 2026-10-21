import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/data/sqlite/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// T-S5（前段）schema v5 遷移回歸（tasks.md §3；F07 衝突事件前置）。
///
/// v5 範圍（data-spec.dbml v0.3 既有定義）：sync_events（FR-Y5 衝突檢視，
/// **隨 F07/M5 落地**——dbml 已預定義，code schema 對齊）＋
/// recurring_transactions（FR-T5 定期交易；表一次到位避免中途改欄——
/// SDD 原則，recurring 之業務使用屬 M6）。
void main() {
  test('全新 DB：直達 schema v5（v4 既有 14 表＋sync_events＋recurring_transactions）', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: 'T-S5：schema v5（衝突事件/定期交易）');
    final tables = db.tableNames();
    for (final t in [
      'accounts', 'categories', 'transactions', 'oplog', 'settings', 'templates',
      'budgets', 'income_goals', 'credit_card_details', 'statements',
      'statement_items', 'refund_links', 'installment_plans', 'attachments',
      'sync_events', 'recurring_transactions',
    ]) {
      expect(tables, contains(t), reason: 'schema v5 應含 $t');
    }
  });

  test('v4 舊檔 DB：開啟即自動升級 v5，且舊資料完整（tasks.md §3 回歸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v5');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    final raw = sqlite3.open(path);
    for (final s in [
      ...SchemaV1.statements, ...SchemaV2.statements,
      ...SchemaV3.statements, ...SchemaV4.statements,
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
    raw.execute('PRAGMA user_version = 4');
    raw.dispose();

    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: '開啟舊檔應自動升級至 v5');
    expect(db.tableNames(), containsAll(['sync_events', 'recurring_transactions']),
        reason: '升級後不得缺新表');
    expect(
      db.allAccounts().firstWhere((a) => a.id == 'a1').openingAmountMinor,
      50000,
      reason: '升級不得遺失舊資料',
    );
  });

  test('v5 冪等：同檔二次開啟不重跑遷移（DBG-004 回歸延伸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v5_idem');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    var db = AppDatabase.open(path);
    expect(db.schemaVersion, 5);
    db.close();

    db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 5, reason: '二次開啟維持 v5');
  });
}
