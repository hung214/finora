import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';

import '../../test/helpers/db_fixture.dart';
import '../../test/helpers/gherkin/gherkin.dart';

/// F10-FE 情境執行器（@FE @M2 @FR-R，3 情境：占比趨勢／複合篩選／CSV 匯出）。
///
/// 來源：specs/plan/tests/frontend/F10_reports-search.feature（sync_features.ps1
/// 同步副本，pubspec 資產入包）。句型登記簿：specs/plan/tests/dsl.md §3。
Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final doc = GherkinParser.parse(
      await rootBundle.loadString('integration_test/features/F10_reports-search.feature'));

  testWidgets('F10-FE：報表與搜尋 UI（3 情境：占比趨勢／複合篩選／CSV 匯出）', (tester) async {
    final w = _World(tester);
    final runner = GherkinRunner();
    _bind(runner, w);
    try {
      final executed = await runner.run(
        doc,
        // M2 當前 feature：P0＋P1 皆在範圍（tasks.md T-F10-FE＝3 情境）。
        tagFilter: (tags) => tags.contains('@FE'),
      );
      expect(executed, 3, reason: 'F10-FE 應執行 3 個情境（@FE @P0＋@P1 屬 M2 範圍）');
      // ignore: avoid_print
      print(runner.log.join('\n'));
    } finally {
      Clock.unfreeze();
      for (final db in w.dbs) {
        db.close();
      }
      for (final c in w.containers) {
        c.dispose();
      }
    }
  });
}

class _World {
  _World(this.tester);

  final WidgetTester tester;
  final List<AppDatabase> dbs = [];
  final List<ProviderContainer> containers = [];
  AppDatabase? db;
  ProviderContainer? container;
  bool pumped = false;

  final categories = <String, String>{};
  final seededIdsByMonth = <int, List<String>>{};
}

void _bind(GherkinRunner runner, _World w) {
  // ── Background ───────────────────────────────────────────
  runner.on(r'App 已完成首次設定$', (p) async {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.pumped = false;
    w.categories.clear();
    w.seededIdsByMonth.clear();
  });

  /// `已存在 6 月支出: 餐飲 3 筆共 900、交通 2 筆共 400（經 fixture）`
  runner.on(r'已存在 {month} 月支出: {desc}（經 fixture）$', (p) async {
    final month = int.parse(p['month']!);
    final year = Clock.now().year;
    for (final seg
        in p['desc']!.split('、').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      final m = RegExp(r'^(.+?) (\d+) 筆(?:共 (\d+)| (\d+))$').firstMatch(seg);
      if (m == null) {
        throw FormatException('月支出段落未支援：$seg（dsl.md §2.1）');
      }
      final catName = m.group(1)!;
      final count = int.parse(m.group(2)!);
      final total = _amount(m.group(3) ?? m.group(4)!);
      final catId = _getOrCreateCategory(w, catName);
      final accountId = _getOrCreateAccount(w);
      final each = m.group(3) != null ? total ~/ count : total;
      for (var i = 0; i < count; i++) {
        final id = 'tx-f10fe-${w.db!.allTransactions().length}';
        await DbFixture.seedTx(
          w.db!,
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

  runner.on(r'其中 {n} 筆 {month} 月{cat}備註含「{kw}」$', (p) async {
    final month = int.parse(p['month']!);
    final ids = w.seededIdsByMonth[month] ?? const [];
    final catId = w.categories[p['cat']!];
    var updated = 0;
    for (final id in ids) {
      if (updated >= int.parse(p['n']!)) break;
      final row = w.db!.transactionById(id);
      if (row == null || row.categoryId != catId) continue;
      w.db!.setTransactionNote(id, p['kw']);
      updated++;
    }
  });
}

/// 分類隱式建立。
String _getOrCreateCategory(_World w, String name) {
  final existing = w.categories[name];
  if (existing != null) return existing;
  final id = 'c-${w.categories.length}';
  DbFixture.seedCategory(w.db!, id: id, kind: 'expense', name: name);
  w.categories[name] = id;
  return id;
}

/// 帳戶隱式建立。
String _getOrCreateAccount(_World w) {
  final accounts = w.db!.allAccounts();
  if (accounts.isNotEmpty) return accounts.first.id;
  DbFixture.seedAccount(w.db!, id: 'a-0', type: 'cash', name: '現金');
  return 'a-0';
}

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));
