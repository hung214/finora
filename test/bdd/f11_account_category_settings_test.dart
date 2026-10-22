import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/accounts/account_service.dart';
import 'package:ledger_sync/application/accounts/totals_service.dart';
import 'package:ledger_sync/application/categories/category_service.dart';
import 'package:ledger_sync/application/first_run_bootstrap.dart';
import 'package:ledger_sync/application/mappers.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';

/// F11-BE 情境執行器（@BE @M8 @FR-A7/@FR-B1/@FR-O1，8 情境：帳戶 CRUD＋
/// 合併計算／刪除拒絕／分類 CRUD＋排序／一層子分類／外觀持久化）。
///
/// 來源：specs/plan/tests/backend/F11_account-category-settings.feature（同步副本）。
/// 句型登記簿：specs/plan/tests/dsl.md §4.5（v1.6）。
void main() {
  final source =
      File('test/bdd/F11_account-category-settings.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F11-BE：帳戶/分類設定與外觀（9 情境）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);
    try {
      final executed =
          await runner.run(doc, tagFilter: (tags) => tags.contains('@BE'));
      expect(executed, 9, reason: 'F11-BE 應執行 9 個情境（含同層重名拒絕）');
      // ignore: avoid_print
      print(runner.log.join('\n'));
    } finally {
      for (final db in w.dbs) {
        db.close();
      }
    }
  });
}

class _World {
  final dbs = <AppDatabase>[];
  AppDatabase? db;
  String? dbPath; // 檔案 DB 路徑（外觀持久化情境——重啟同一檔）
  AccountService? accounts;
  CategoryService? categories;
  TotalsService? totals;
  int assetTotal = -1;
  Object? lastError;
}

void _bind(GherkinRunner runner, _World w) {
  // ── Background ───────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
  });

  runner.on(r'內建預設帳戶「{name}」與分類集$', (p) async {
    await FirstRunBootstrap.seedIfNeeded(w.db!);
    w.accounts = AccountService(w.db!);
    w.categories = CategoryService(w.db!);
    w.totals = TotalsService(w.db!);
  });

  // ── 帳戶 ────────────────────────────────────────────────
  runner.on(r'建立帳戶「{name}」類型 {type}、期初 {amt}、計入合併={flag}$',
      (p) async {
    w.accounts!.create(
      type: p['type']!,
      name: p['name']!,
      openingMinor: int.parse(p['amt']!),
      includeInTotals: p['flag'] == 'true',
    );
  });

  runner.on(r'accounts 表有「{name}」且 include_in_totals={flag}$', (p) {
    final row = w.db!.allAccounts().firstWhere((a) => a.name == p['name']!);
    expect(row.includeInTotals, p['flag'] == 'true');
  });

  runner.on(r'oplog 有 1 筆 accounts 新增（payload 為整列快照）$', (p) {
    final ops = w.db!.select(
        "SELECT entity_id, payload FROM oplog WHERE entity = 'accounts'"
        " AND entity_id = (SELECT id FROM accounts WHERE name = '緊急金')");
    expect(ops.length, 1, reason: '僅本次新增之 1 筆 op');
    expect((ops.first['payload'] as String), contains('include_in_totals'),
        reason: 'payload 為整列快照（SDD §5.5.4）');
  });

  runner.on(r'帳戶「{name}」期初 {amt} 且計入合併={flag}$', (p) async {
    // 冪等語意：同名帳戶已存在（如播種之「現金」）→ 更新期初/旗標；否則新增。
    final existing = w.db!.allAccounts().where((a) => a.name == p['name']!);
    if (existing.isNotEmpty) {
      w.accounts!.update(existing.first.id,
          openingMinor: int.parse(p['amt']!),
          includeInTotals: p['flag'] == 'true');
      return;
    }
    w.accounts!.create(
      type: 'cash',
      name: p['name']!,
      openingMinor: int.parse(p['amt']!),
      includeInTotals: p['flag'] == 'true',
    );
  });

  runner.on(r'計算資產合計$', (p) async {
    w.assetTotal = w.totals!.compute().assetsMinor;
  });

  runner.on(r'資產合計 = {amt}$', (p) {
    expect(w.assetTotal, int.parse(p['amt']!),
        reason: 'FR-A6：僅計入 include_in_totals=true 之帳戶');
  });

  runner.on(
      r'帳戶「{name}」餘額 {amt}、「{name2}」餘額 {amt2}（各自獨立）$', (p) async {
    const calc = BalanceCalculator();
    final txs = w.db!.allTransactions().map(txEntity).toList();
    for (final e in [
      (p['name']!, int.parse(p['amt']!)),
      (p['name2']!, int.parse(p['amt2']!)),
    ]) {
      final row =
          w.db!.allAccounts().firstWhere((a) => a.name == e.$1);
      expect(
        calc.assetBalance(account: accountEntity(row), txs: txs),
        e.$2,
        reason: '${e.$1} 個別餘額獨立顯示（合計排除不改變個別值）',
      );
    }
  });

  runner.on(r'帳戶「{name}」有本期未繳帳單$', (p) async {
    // 信用卡＋一筆預扣支出（settlement=pending）→ 未繳 > 0。
    w.accounts!.create(type: 'credit', name: p['name']!);
    final card =
        w.db!.allAccounts().firstWhere((a) => a.name == p['name']!);
    await DbFixture.seedTx(w.db!,
        id: 'tx-pending-${p['name']}',
        kind: 'expense',
        amountMinor: 5000,
        accountId: card.id,
        merchant: '預扣商店',
        occurredAt: DateTime.now().millisecondsSinceEpoch,
        settlementStatus: 'pending');
  });

  runner.on(r'刪除帳戶「{name}」$', (p) async {
    try {
      w.accounts!.delete(_idOf(w, p['name']!));
      w.lastError = null;
    } catch (e) {
      w.lastError = e;
    }
  });

  runner.on(r'拋出例外「{msg}」$', (p) {
    expect(w.lastError, isNotNull, reason: '應拋出例外');
    expect(w.lastError.toString(), p['msg']!, reason: '例外訊息應可直接顯示');
  });

  runner.on(r'帳戶「{name}」仍存在$', (p) {
    expect(
      w.db!.allAccounts().any((a) => a.name == p['name']!),
      isTrue,
      reason: '被拒絕的刪除不得影響帳戶',
    );
  });

  runner.on(r'更新帳戶「{from}」為 名稱「{to}」、類型 {type}$', (p) async {
    w.accounts!.update(_idOf(w, p['from']!),
        name: p['to']!, type: p['type']!);
  });

  runner.on(r'帳戶「{name}」類型為 {type}$', (p) {
    final row = w.db!.allAccounts().firstWhere((a) => a.name == p['name']!);
    expect(row.type, p['type']);
  });

  runner.on(r'oplog 有 1 筆 accounts 更新（payload 為整列快照）$', (p) {
    // 最新的 accounts op（本情境之 update）payload 須為整列快照
    // （含 include_in_totals——v6 欄位入 oplog，多裝置 LWW 才能正確合併）。
    final ops = w.db!.select(
        "SELECT payload FROM oplog WHERE entity = 'accounts'"
        ' ORDER BY seq DESC LIMIT 1');
    expect(ops, isNotEmpty);
    expect((ops.first['payload'] as String), contains('include_in_totals'));
  });

  // ── 分類 ────────────────────────────────────────────────
  // 子分類句型先於 `新增{kind}分類` 註冊（lazy 前綴碰撞——「子」會被
  // {kind} 吃掉，session 教訓再現）。
  runner.on(r'於「{parent}」下新增子分類「{name}」$', (p) async {
    // 正常路徑——例外直接拋出（不吞；一層限制屬「嘗試」句型）。
    w.categories!.create(
        kind: 'expense', name: p['name']!, parentId: _catId(w, p['parent']!));
  });

  runner.on(r'於「{parent}」下再新增子分類「{name}」$', (p) async {
    try {
      w.categories!.create(
          kind: 'expense', name: p['name']!, parentId: _catId(w, p['parent']!));
      w.lastError = null;
    } catch (e) {
      w.lastError = e;
    }
  });

  // 嘗試句型先註冊（lazy 前綴碰撞——「嘗試」會被 {kind} 前的「新增」吃掉）。
  runner.on(r'嘗試新增{kind}分類「{name}」$', (p) async {
    try {
      w.categories!.create(
          kind: p['kind'] == '收入' ? 'income' : 'expense',
          name: p['name']!);
      w.lastError = null;
    } catch (e) {
      w.lastError = e;
    }
  });

  runner.on(r'新增{kind}分類「{name}」$', (p) async {
    // {kind} 為中文語意（支出/收入）→ 存表值 expense/income。
    final kind = p['kind']! == '支出' ? 'expense' : 'income';
    w.categories!.create(kind: kind, name: p['name']!);
  });

  runner.on(r'將分類「{a}」排在「{b}」之前$', (p) async {
    w.categories!.reorder(_catId(w, p['a']!), beforeId: _catId(w, p['b']!));
  });

  runner.on(r'分類列表首位為「{a}」、次位為「{b}」$', (p) {
    // 播種子分類後列表含兩層——首位/次位以「主類別層」（parentId=null）為準。
    final list = w
        .db!
        .categoriesByKind('expense')
        .where((c) => c.parentId == null)
        .toList();
    expect(list.first.name, p['a']!);
    expect(list[1].name, p['b']!);
  });

  runner.on(r'各分類 sort_order 為連續遞增整數$', (p) {
    // 不變式為「同層連續」（主類別與各群組子分類各自 0..n-1——
    // 播種子分類後平面清單交錯，不能全域比對）。
    final groups = <String?, List<int>>{};
    for (final c in w.db!.categoriesByKind('expense')) {
      groups.putIfAbsent(c.parentId, () => []).add(c.sortOrder ?? -1);
    }
    for (final orders in groups.values) {
      for (var i = 0; i < orders.length; i++) {
        expect(orders[i], i, reason: '同層 sort_order 連續遞增（reorder 不變式）');
      }
    }
  });

  runner.on(r'分類「{name}」已有 {n} 筆交易$', (p) async {
    final id = _catId(w, p['name']!);
    for (var i = 0; i < int.parse(p['n']!); i++) {
      await DbFixture.seedTx(w.db!,
          id: 'tx-cat-$i',
          kind: 'expense',
          amountMinor: 100,
          accountId: w.db!.allAccounts().first.id,
          category: id,
          occurredAt: DateTime.now().millisecondsSinceEpoch);
    }
  });

  runner.on(r'刪除分類「{name}」$', (p) async {
    try {
      w.categories!.delete(_catId(w, p['name']!));
      w.lastError = null;
    } catch (e) {
      w.lastError = e;
    }
  });

  runner.on(r'分類「{name}」仍存在$', (p) {
    expect(
      w.db!.categoriesByKind('expense').any((c) => c.name == p['name']!),
      isTrue,
      reason: '被拒絕的刪除不得影響分類',
    );
  });

  runner.on(r'分類「{name}」父分類為「{parent}」$', (p) {
    final row = w.db!
        .categoriesByKind('expense')
        .firstWhere((c) => c.name == p['name']!);
    expect(row.parentId, _catId(w, p['parent']!));
  });

  // ── 外觀 ────────────────────────────────────────────────
  runner.on(r'已開啟檔案資料庫（暫存檔）$', (p) async {
    // 持久化驗證須檔案 DB（記憶體 DB 無法重啟）。
    final dir = await Directory.systemTemp.createTemp('ledger_f11_theme');
    final path = '${dir.path}/ledger.db';
    final db = AppDatabase.open(path);
    w.dbs.add(db);
    w.db = db;
    w.dbPath = path;
    await FirstRunBootstrap.seedIfNeeded(db);
    w.accounts = AccountService(db);
    w.categories = CategoryService(db);
    w.totals = TotalsService(db);
  });

  runner.on(r'關閉並重新開啟同一資料庫$', (p) async {
    w.db!.close();
    final db = AppDatabase.open(w.dbPath!);
    w.dbs.add(db);
    w.db = db;
    w.accounts = AccountService(db);
    w.categories = CategoryService(db);
    w.totals = TotalsService(db);
  });

  runner.on(r'設定外觀為 {mode}$', (p) async {
    w.db!.setSetting('app.theme_mode', p['mode']!);
  });

  runner.on(r'settings app.theme_mode = {mode}$', (p) {
    expect(w.db!.getSetting('app.theme_mode'), p['mode']!,
        reason: '外觀設定持久化（FR-O1）');
  });
}

/// 依名稱取帳戶 id（harness 輔助）。
String _idOf(_World w, String name) =>
    w.db!.allAccounts().firstWhere((a) => a.name == name).id;

String _catId(_World w, String name) {
  for (final kind in ['expense', 'income']) {
    for (final c in w.db!.categoriesByKind(kind)) {
      if (c.name == name) return c.id;
    }
  }
  throw StateError('分類不存在：$name');
}
