import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/data/sqlite/schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// T-S2 schema v2 遷移回歸（tasks.md §3：舊版 DB 升級後缺新表/資料遺失即紅燈）。
///
/// v2 範圍（data-spec.dbml v0.3 既有定義）：budgets（FR-B2）、income_goals
/// （FR-B6）、transactions_fts（FTS5 影子表，FR-R3 bigram）。
/// FTS5 於部分環境（如 winsqlite3.dll）可能缺模組——遷移須容錯降級，不得阻斷；
/// FTS 讀寫行為驗證屬 T-F10（本檔僅驗表存在與遷移契約）。
void main() {
  test('全新 DB：直達 schema v2（M1 六表＋budgets＋income_goals）', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    expect(db.schemaVersion, 4, reason: 'T-S2 起始的遷移鏈現達 v4（T-S4 附件）');
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
    ]) {
      expect(tables, contains(t), reason: 'schema v2 應含 $t');
    }
  });

  test('全新 DB：FTS5 影子表存在（環境不支援時容錯跳過）', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    if (!db.tableNames().contains('transactions_fts')) {
      // 環境無 FTS5 模組：遷移仍須成功（budgets/income_goals 必建已由上測覆蓋）。
      return;
    }
    expect(db.tableNames(), contains('transactions_fts'));
  });

  test('v1 舊檔 DB：開啟即自動升級 v2，且舊資料完整（tasks.md §3 回歸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v2');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    // 以 v1 DDL 手動建舊版 DB（M1 期檔案），種資料並標 user_version = 1。
    final raw = sqlite3.open(path);
    for (final s in SchemaV1.statements) {
      raw.execute(s);
    }
    for (final s in SchemaV1.indexes) {
      raw.execute(s);
    }
    raw.execute(
      "INSERT INTO accounts (id, type, name, currency, opening_amount_minor, archived,"
      " created_at, updated_at, hlc) VALUES ('a1', 'cash', '現金', 'TWD', 1000, 0, 1, 1, '1.0.t')",
    );
    raw.execute(
      "INSERT INTO transactions (id, kind, amount_minor, currency, account_id, to_account_id,"
      " category_id, merchant, note, occurred_at, source, settlement_status, created_at,"
      " updated_at, hlc) VALUES ('t1', 'expense', 120, 'TWD', 'a1', NULL, NULL, NULL, NULL,"
      " 1000, 'manual', 'none', 1, 1, '1.1.t')",
    );
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();

    // 開啟 → _migrate 應執行 v1→v2 增量。
    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 4, reason: '開啟舊檔應自動升級至現行版本（遷移鏈）');
    expect(db.tableNames(), containsAll(['budgets', 'income_goals']),
        reason: '升級後不得缺新表（tasks.md §3 紅燈條件）');
    expect(
      db.allAccounts().firstWhere((a) => a.id == 'a1').openingAmountMinor,
      1000,
      reason: '升級不得遺失舊資料',
    );
    expect(
      db.transactionsByAccount('a1').first.amountMinor,
      120,
    );
  });

  test('v2 冪等：同檔二次開啟不重跑遷移，資料不受損（DBG-004 回歸延伸）', () async {
    final dir = await Directory.systemTemp.createTemp('ledger_schema_v2_idem');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/ledger.db';

    var db = AppDatabase.open(path);
    expect(db.schemaVersion, 4);
    DbFixtureSeed.seedAccountForIdempotency(db);
    db.close();

    db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, 4, reason: '二次開啟維持現行版本（user_version 閘）');
    expect(db.allAccounts().length, 1, reason: '重跑遷移不得損毀既有資料');
  });
}

/// 冪等測試之種資料輔助（避免依賴 TS2 新 API——僅用既有 insertAccount）。
class DbFixtureSeed {
  DbFixtureSeed._();

  static void seedAccountForIdempotency(AppDatabase db) {
    final now = DateTime.now().millisecondsSinceEpoch;
    db.insertAccount(AccountRow(
      id: 'a-idem',
      type: 'cash',
      name: '冪等現金',
      currency: 'TWD',
      openingAmountMinor: 0,
      archived: false,
      createdAt: now,
      updatedAt: now,
      hlc: '1.0.idem',
    ));
  }
}
