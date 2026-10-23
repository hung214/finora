import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/first_run_bootstrap.dart';
import 'package:ledger_sync/application/providers.dart';
import 'package:ledger_sync/application/sync/sync_coordinator.dart';
import 'package:ledger_sync/presentation/screens/quick_entry/quick_entry_page.dart';
import 'package:ledger_sync/presentation/theme/app_theme.dart';

import '../helpers/db_fixture.dart';
import '../helpers/in_memory_cloud_adapter.dart';

/// 暫時用：把快記頁渲染成 golden 圖片（人工核對計算機版面）。
void main() {
  testWidgets('GOLDEN 快記頁（手機）', (tester) async {
    final db = DbFixture.create();
    await FirstRunBootstrap.seedIfNeeded(db);
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      syncCoordinatorProvider.overrideWithValue(
          SyncCoordinator(db, InMemoryCloudAdapter(), deviceId: 'd-g')),
    ]);
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: buildAppTheme(Brightness.light), home: const QuickEntryPage()),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(QuickEntryPage),
        matchesGoldenFile('goldens/qe_mobile.png'));
    container.dispose();
    db.close();
  });
}
