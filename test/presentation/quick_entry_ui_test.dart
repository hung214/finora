import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/first_run_bootstrap.dart';
import 'package:ledger_sync/application/providers.dart';
import 'package:ledger_sync/presentation/screens/quick_entry/quick_entry_page.dart';
import 'package:ledger_sync/presentation/theme/app_theme.dart';

import '../helpers/db_fixture.dart';

/// 快記頁 UI-P4 重整（PM 2026-10-22/23）快速護欄：
/// ①兩層式分類格（常用→主類別→子類別；＋直接新增）
/// ②預算 mode：輸入完成 → 變成預算內容（非交易）
/// ③OK 儲存鈕在計算機上方（鍵面 key 不變）。
void main() {
  testWidgets('快記：主類別格→展開子類別→選取；常用格（有使用紀錄時）', (tester) async {
    final db = DbFixture.create();
    await FirstRunBootstrap.seedIfNeeded(db);
    // 常用（MRU）來源：兩筆歷史交易（分類 餐飲食品/交通運輸）。
    await DbFixture.seedTx(db,
        id: 't1',
        kind: 'expense',
        amountMinor: 100,
        accountId: 'a-seed',
        category: 'c-food',
        occurredAt: DateTime.now().millisecondsSinceEpoch - 3600000);
    await DbFixture.seedTx(db,
        id: 't2',
        kind: 'expense',
        amountMinor: 100,
        accountId: 'a-seed',
        category: 'c-transport',
        occurredAt: DateTime.now().millisecondsSinceEpoch);
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
    ]);
    // 內容長於預設 600px 測試視窗——放大 surface（否則 find 預設略過視口外元素）。
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const QuickEntryPage()),
      ));
      await tester.pumpAndSettle();

      // 主類別格：內建 14 主類別全顯示（chips）。
      expect(find.byKey(const Key('cat-chip-餐飲食品')), findsOneWidget);
      expect(find.byKey(const Key('cat-chip-交通運輸')), findsOneWidget);

      // 常用格：最近使用（MRU）→ 交通運輸（最新）在常用區。
      expect(find.byKey(const Key('recent-chip-交通運輸')), findsOneWidget);

      // 點主類別 → 展開其子分類（早餐…）。
      await tester.tap(find.byKey(const Key('cat-chip-餐飲食品')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cat-chip-早餐')), findsOneWidget,
          reason: '選主類別後展開子分類');
      expect(find.byKey(const Key('cat-add-sub')), findsOneWidget,
          reason: '子分類層尾可直接新增');

      // 選子分類 → 即為選取分類。
      await tester.tap(find.byKey(const Key('cat-chip-早餐')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      container.dispose();
      db.close();
    }
  });

  testWidgets('快記預算 mode：輸入金額→OK→存為預算內容（非交易）', (tester) async {
    final db = DbFixture.create();
    await FirstRunBootstrap.seedIfNeeded(db);
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
    ]);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const QuickEntryPage()),
      ));
      await tester.pumpAndSettle();

      // 切到預算模式。
      await tester.tap(find.text('預算'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('budget-chip-total')), findsOneWidget);

      // 選分類預算目標（餐飲食品）＋輸入金額（計算機鍵）。
      await tester.tap(find.byKey(const Key('budget-chip-餐飲食品')));
      await tester.pumpAndSettle();
      for (final k in ['8', '0', '0', '0']) {
        await tester.tap(find.byKey(Key('keypad-$k')));
        await tester.pump();
      }

      // OK → 存為分類預算（非交易）。
      await tester.tap(find.byKey(const Key('quick-entry-save')));
      await tester.pumpAndSettle();
      expect(db.allBudgets().map((b) => (b.categoryId, b.amountMinor)),
          contains(('c-food', 8000)),
          reason: '輸入完成 → 變成預算內容（PM 2026-10-23）');
      expect(db.allTransactions(), isEmpty, reason: '預算不入交易');

      // 總預算：切總預算 → 30,000 → OK。
      await tester.enterText(find.byKey(const Key('quick-entry-amount')), '');
      await tester.tap(find.byKey(const Key('budget-chip-total')));
      await tester.pumpAndSettle();
      for (final k in ['3', '0', '0', '0', '0']) {
        await tester.tap(find.byKey(Key('keypad-$k')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('quick-entry-save')));
      await tester.pumpAndSettle();
      expect(db.allBudgets().map((b) => (b.categoryId, b.amountMinor)),
          contains((null, 30000)), reason: '總預算（categoryId=null）');
      expect(tester.takeException(), isNull);
    } finally {
      container.dispose();
      db.close();
    }
  });
}
