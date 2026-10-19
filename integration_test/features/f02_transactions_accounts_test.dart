import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';

import '../../test/helpers/db_fixture.dart';
import '../../test/helpers/gherkin/gherkin.dart';

/// F02-FE 情境執行器（@FE @M1 @FR-T @FR-A @P0，4 情境；拆分 @P1 @M2 過濾）。
///
/// 來源：specs/plan/tests/frontend/F02_transactions-accounts.feature（sync_features.ps1
/// 同步副本，pubspec 資產入包——桌面 App 行程 CWD 非專案根，須 rootBundle 讀）。
/// 句型登記簿：specs/plan/tests/dsl.md §3。綁定：T-H7 自製 runner（TR-9）＋
/// integration_test；背景每情境重建 App（in-memory DB 直寫）。
Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final doc = GherkinParser.parse(await rootBundle
      .loadString('integration_test/features/F02_transactions-accounts.feature'));

  testWidgets('F02-FE：交易與帳戶 UI（4 情境：禁用態/轉帳樣式/儲值文案/最近刪除）',
      (tester) async {
    final w = _World(tester);
    final runner = GherkinRunner();
    _bind(runner, w);
    try {
      final executed = await runner.run(doc, tagFilter: (tags) {
        // 檔級標籤含 @P0（預設優先級）——情境級 @P1（拆分 @M2）以明確排除。
        return tags.contains('@FE') && !tags.contains('@P1');
      });
      expect(executed, 4, reason: 'F02-FE 應執行 4 個情境（@FE @P0；拆分 @P1 @M2 排除）');
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

/// 情境共享狀態（每 Scenario 由 Background 重置；dsl.md §1.5 Given 直寫 DB）。
class _World {
  _World(this.tester);

  final WidgetTester tester;
  final List<AppDatabase> dbs = [];
  final List<ProviderContainer> containers = [];
  AppDatabase? db;
  ProviderContainer? container;
  bool pumped = false;

  /// 名稱 → id（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};

  /// 本次 session 所記交易（kind → 金額清單；「明細即時顯示」斷言用）。
  final sessionExpenses = <int>[];
  final sessionTransfers = <int>[];
}

/// 內建集名稱 → 帳戶類型（dsl.md §3.1；F02 儲值語意需 ewallet 類型）。
String _accountType(String name) {
  switch (name) {
    case '票證卡':
      return 'ewallet';
    case '銀行':
      return 'bank';
    default:
      return 'cash';
  }
}

void _bind(GherkinRunner runner, _World w) {
  // ── Background ───────────────────────────────────────────
  runner.on(r'App 已完成首次設定$', (p) async {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.pumped = false;
    w.accounts.clear();
    w.categories.clear();
    w.sessionExpenses.clear();
    w.sessionTransfers.clear();
    // M1 無引導頁：啟動即主殼；帳戶/分類由後續 Given 直寫。
  });

  runner.on(r'已建立帳戶「{name}」\(餘額 {amount}\)$', (p) async {
    final id = 'a-${w.accounts.length}';
    await DbFixture.seedAccount(
      w.db!,
      id: id,
      type: _accountType(p['name']!),
      name: p['name']!,
      opening: _amount(p['amount']!),
    );
    w.accounts[p['name']!] = id;
  });

  runner.on(r'已建立分類{names}$', (p) async {
    final names =
        RegExp('「([^」]+)」').allMatches(p['names']!).map((m) => m.group(1)!).toList();
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final id = 'c-${w.categories.length}';
      // kind 對齊內建集（first_run_bootstrap）：薪資 = income，其餘 = expense。
      await DbFixture.seedCategory(
        w.db!,
        id: id,
        kind: name == '薪資' ? 'income' : 'expense',
        name: name,
      );
      w.categories[name] = id;
    }
  });
}

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));
