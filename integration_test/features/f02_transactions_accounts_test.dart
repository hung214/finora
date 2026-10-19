import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_sync/application/providers.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/presentation/app_shell.dart';
import 'package:ledger_sync/presentation/screens/quick_entry/quick_entry_page.dart';

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

  // ── Given：App 與快記（沿 F01 模式；每情境唯一 Key 強制重建樹）──
  runner.on(r'使用者位於{page}頁$', (p) async {
    await _ensureApp(w);
    // F02 情境僅斷言總覽/明細（分頁斷言綁定於各 Then 內處理）。
  });

  // ── When：金額驗證（F02-FE S1）───────────────────────────
  runner.on(r'開啟支出記錄$', (p) async => _ensureQuickEntry(w));

  runner.on(r'輸入金額 {amount}$', (p) async {
    await _ensureQuickEntry(w);
    await w.tester.enterText(find.byKey(const Key('quick-entry-amount')), p['amount']!);
    await w.tester.pump();
  });

  // ── Then：儲存按鈕狀態（F02-FE S1；dsl §3.3）──────────────
  runner.on(r'儲存按鈕為禁用狀態$', (p) async {
    final btn =
        w.tester.widget<FilledButton>(find.byKey(const Key('quick-entry-save')));
    expect(btn.onPressed, isNull, reason: '儲存應為禁用（dsl §3.3：enabled=false）');
  });

  runner.on(r'顯示「{text}」且為可點擊$', (p) async {
    expect(find.text(p['text']!), findsOneWidget, reason: '應顯示「${p['text']}」');
    final btn =
        w.tester.widget<FilledButton>(find.byKey(const Key('quick-entry-save')));
    expect(btn.onPressed, isNotNull, reason: '「${p['text']}」應為可點擊（enabled）');
  });
}

// ── 綁定輔助（沿 F01 模式）─────────────────────────────────

Future<void> _ensureApp(_World w) async {
  if (w.pumped) return;
  final container = ProviderContainer(overrides: [
    dbProvider.overrideWithValue(w.db!),
  ]);
  w.containers.add(container);
  w.container = container;
  // 每情境以唯一 Key 強制重建整棵樹——否則 const AppShell 會複用 element，
  // Navigator 路由堆疊（前情境的快記頁/對話框）殘留並掛著舊 container/DB。
  await w.tester.pumpWidget(
    KeyedSubtree(
      key: ValueKey('app-shell-${w.dbs.length}'),
      child: UncontrolledProviderScope(container: container, child: const AppShell()),
    ),
  );
  await w.tester.pumpAndSettle();
  w.pumped = true;
}

Future<void> _ensureQuickEntry(_World w) async {
  await _ensureApp(w);
  if (w.tester.any(find.byType(QuickEntryPage))) return;
  await w.tester.tap(find.byKey(const Key('fab-quick-entry')));
  await w.tester.pumpAndSettle();
  expect(w.tester.any(find.byType(QuickEntryPage)), isTrue, reason: '快記頁應已開啟');
}

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));
