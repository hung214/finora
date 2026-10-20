import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/reports/search_service.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';

/// F10-BE 情境執行器（@BE @M2 @FR-R，5 情境：占比／FTS bigram／AND 篩選／CSV／效能）。
///
/// 來源：specs/plan/tests/backend/F10_reports-search.feature（sync_features.ps1
/// 同步副本，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
/// M2 範圍內 P0＋P1 皆執行（tasks.md §4.1 T-F10-BE＝5 情境）。
void main() {
  final source = File('test/bdd/F10_reports-search.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F10-BE：報表聚合與搜尋（5 情境：占比／FTS bigram／AND 篩選／CSV／效能）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      final executed = await runner.run(doc, tagFilter: (tags) => tags.contains('@BE'));
      expect(executed, 5, reason: 'F10-BE 應執行 5 個情境（@BE；M2 含 P1）');
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

/// 情境共享狀態（每 Scenario 由 Background 重置）。
class _World {
  final List<AppDatabase> dbs = [];
  late AppDatabase db;

  /// 名稱 → id（隱式建立登記）。
  final categories = <String, String>{};

  /// 月份（Clock.now().year）→ 該月已種交易 id 清單（備註句型定位用）。
  final seededIdsByMonth = <int, List<String>>{};

  /// 最近一次聚合結果（C3 接 ReportAggregate）。
  Object? report;

  /// 最近一次搜尋／篩選結果（C2 接 SearchService）。
  List<TxRow>? searchResults;

  /// 複合篩選狀態（AND 條件累積）。
  String? filterPeriod;
  String? filterCategory;
  String? filterKeyword;
  int? filterMin;
  int? filterMax;

  /// CSV 輸出（C5 接 CsvExporter）。
  String? csv;

  /// 聚合耗時（效能情境）。
  Duration? aggregateElapsed;
}

void _bind(GherkinRunner runner, _World w) {
  // ── Given：環境 ─────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.categories.clear();
    w.seededIdsByMonth.clear();
    w.report = null;
    w.searchResults = null;
    w.filterPeriod = null;
    w.filterCategory = null;
    w.filterKeyword = null;
    w.filterMin = null;
    w.filterMax = null;
    w.csv = null;
    w.aggregateElapsed = null;
  });

  /// `已存在 6 月支出: 餐飲 3 筆共 900、交通 2 筆共 400（經 fixture）`
  runner.on(r'已存在 {month} 月支出: {desc}（經 fixture）$', (p) {
    final month = int.parse(p['month']!);
    final year = Clock.now().year;
    for (final seg
        in p['desc']!.split('、').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      final m =
          RegExp(r'^(.+?) (\d+) 筆(?:共 (\d+)| (\d+))$').firstMatch(seg);
      if (m == null) {
        throw FormatException('月支出段落未支援：$seg（dsl.md §2.1）');
      }
      final catName = m.group(1)!;
      final count = int.parse(m.group(2)!);
      // 兩種段落格式：`N 筆共 TOTAL`（均分）／`1 筆 AMOUNT`（單筆直接金額）。
      final total = _amount(m.group(3) ?? m.group(4)!);
      final catId = _getOrCreateCategory(w, catName);
      final each = m.group(3) != null ? total ~/ count : total;
      final accountId = _getOrCreateAccount(w);
      for (var i = 0; i < count; i++) {
        final id = 'tx-f10-${w.db.allTransactions().length}';
        DbFixture.seedTx(
          w.db,
          id: id,
          kind: 'expense',
          amountMinor: each,
          accountId: accountId,
          category: catId,
          occurredAt: DateTime(year, month, i + 1, 12).millisecondsSinceEpoch,
        );
        w.seededIdsByMonth.putIfAbsent(month, () => []).add(id);
      }
    }
  });

  /// `其中 1 筆 6 月餐飲備註含「陽光超商」`
  runner.on(r'其中 {n} 筆 {month} 月{cat}備註含「{kw}」$', (p) {
    final month = int.parse(p['month']!);
    final ids = w.seededIdsByMonth[month] ?? const [];
    final catId = w.categories[p['cat']!];
    final n = int.parse(p['n']!);
    var updated = 0;
    for (final id in ids) {
      if (updated >= n) break;
      final row = w.db.transactionById(id);
      if (row == null || row.categoryId != catId) continue;
      w.db.setTransactionNote(id, p['kw']);
      updated++;
    }
    expect(updated, n, reason: '備註句型應命中 $n 筆（fixture 追蹤）');
  });

  // ── When：搜尋（F10 S10.2；FR-R3）────────────────────────
  runner.on(r'搜尋 "{kw}"$', (p) {
    w.searchResults = SearchService(w.db).search(keyword: p['kw']);
  });

  // ── Then：搜尋結果（F10 S10.2）───────────────────────────
  runner.on(r'搜尋 "{kw}" 命中 {n} 筆（命中「{hit}」）$', (p) {
    final rows = w.searchResults ?? const <TxRow>[];
    expect(rows, hasLength(int.parse(p['n']!)), reason: 'FTS5 bigram 搜尋「${p['kw']}」');
    final hit = rows.any((r) =>
        (r.note ?? '').contains(p['hit']!) || (r.merchant ?? '').contains(p['hit']!));
    expect(hit, isTrue, reason: '命中應含「${p['hit']}」');
  });

  runner.on(r'搜尋 "{kw}" 命中 {n} 筆$', (p) {
    final rows = w.searchResults ?? const <TxRow>[];
    expect(rows, hasLength(int.parse(p['n']!)), reason: 'FTS5 bigram 搜尋「${p['kw']}」');
  });
}

/// 帳戶隱式建立（F10 Background 無帳戶 Given）。
String _getOrCreateAccount(_World w) {
  final accounts = w.db.allAccounts();
  if (accounts.isNotEmpty) return accounts.first.id;
  DbFixture.seedAccount(w.db, id: 'a-0', type: 'cash', name: '現金');
  return 'a-0';
}

/// 分類隱式建立（F10 Background 無分類 Given）。
String _getOrCreateCategory(_World w, String name) {
  final existing = w.categories[name];
  if (existing != null) return existing;
  final id = 'c-${w.categories.length}';
  DbFixture.seedCategory(w.db, id: id, kind: 'expense', name: name);
  w.categories[name] = id;
  return id;
}

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));
