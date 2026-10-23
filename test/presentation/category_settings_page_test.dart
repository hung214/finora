import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/first_run_bootstrap.dart';
import 'package:ledger_sync/application/providers.dart';
import 'package:ledger_sync/presentation/screens/settings/category_settings_page.dart';
import 'package:ledger_sync/presentation/theme/app_theme.dart';

import '../helpers/db_fixture.dart';

/// 分類管理（UI-P6 對照 09 雛型；PM 2026-10-23 restyle）快速護欄：
/// 卡片列（彩色圖示圓＋子分類摘要）＋點列展開＋操作鍵（f11-FE 相依 keys 全保留）。
void main() {
  testWidgets('分類管理：卡片列/摘要/展開/新增子分類（自動展開）/操作鍵', (tester) async {
    final db = DbFixture.create();
    await FirstRunBootstrap.seedIfNeeded(db);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
    ]);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const CategorySettingsPage()),
      ));
      await tester.pumpAndSettle();

      // 卡片列：主類別 14 列（cat-row key）＋摘要（收合語意＝09 雛型）。
      expect(find.byKey(const Key('cat-row-餐飲食品')), findsOneWidget);
      expect(find.text('子分類 7：早餐、中餐、晚餐、下午茶、宵夜、水果、食材'),
          findsOneWidget,
          reason: '09 摘要列（收合預設）');

      // 預設收合：子列不可見；操作鍵齊。
      expect(find.byKey(const Key('cat-sub-row-早餐')), findsNothing);
      expect(find.byKey(const Key('cat-drag-餐飲食品')), findsOneWidget);
      expect(find.byKey(const Key('cat-edit-餐飲食品')), findsOneWidget);
      expect(find.byKey(const Key('cat-delete-餐飲食品')), findsOneWidget);

      // 點卡片列本體 → 展開子分類列。
      await tester.tap(find.text('餐飲食品'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cat-sub-row-早餐')), findsOneWidget,
          reason: '點列展開子分類');

      // ＋子分類 → 自動展開＋表單 → 建立後子列可見（f11 S7 語意）。
      await tester.tap(find.byKey(const Key('cat-sub-餐飲食品')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cat-name')), '甜點');
      await tester.tap(find.byKey(const Key('cat-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cat-sub-row-甜點')), findsOneWidget,
          reason: '新增子分類後自動展開可見');

      // 重名拒絕（同層）。
      await tester.tap(find.byKey(const Key('cat-sub-餐飲食品')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cat-name')), '甜點');
      await tester.tap(find.byKey(const Key('cat-save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('同層已有同名分類'), findsWidgets,
          reason: '重名拒絕提示');

      // 子分類編輯（PM 2026-10-23）：改名＋改圖示 → 全域快取失效（連動）。
      await tester.tap(find.byKey(const Key('cat-edit-甜點')));
      await tester.pumpAndSettle();
      expect(find.text('編輯子分類'), findsOneWidget, reason: '編輯模式標題');
      await tester.enterText(find.byKey(const Key('cat-name')), '甜點心');
      await tester.ensureVisible(find.byKey(const Key('cat-icon-🍰')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cat-icon-🍰')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cat-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cat-sub-row-甜點心')), findsOneWidget,
          reason: '子分類改名即時反映');
      final refreshed = container.read(expenseCategoriesProvider);
      final edited = refreshed.firstWhere((c) => c.name == '甜點心');
      expect(edited.icon, '🍰', reason: '圖示入庫');
      expect(refreshed.any((c) => c.name == '甜點'), isFalse,
          reason: '全域快取已失效（其他頁面會拿到新值）');

      expect(tester.takeException(), isNull);
    } finally {
      container.dispose();
      db.close();
    }
  });
}
