import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/providers.dart';
import 'package:ledger_sync/application/transactions/delete_transaction_use_case.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/presentation/screens/ledger/recent_deletions_page.dart';
import 'package:ledger_sync/presentation/theme/app_theme.dart';

import '../helpers/db_fixture.dart';

/// 「最近刪除」頁（FR-T3）護欄：還原 ＋ **永久刪除**（單筆／清空全部，
/// 二次確認；PM 2026-10-24）。跑純 Dart VM（widget test）。
void main() {
  /// 種 2 筆軟刪除（tx-1／tx-2）＋ 1 筆未刪除（tx-3，不應出現）。
  Future<AppDatabase> seed(WidgetTester tester) async {
    final db = DbFixture.create();
    addTearDown(db.close);
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 0);
    for (final id in ['tx-1', 'tx-2']) {
      await DbFixture.seedTx(
          db, id: id, kind: 'expense', amountMinor: 120, accountId: 'a-0', occurredAt: 0);
      DeleteTransactionUseCase(db).execute(id);
    }
    await DbFixture.seedTx(
        db, id: 'tx-3', kind: 'income', amountMinor: 99, accountId: 'a-0', occurredAt: 0);
    return db;
  }

  Future<void> pump(WidgetTester tester, AppDatabase db) async {
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const RecentDeletionsPage()),
    ));
    await tester.pumpAndSettle();
  }

  /// 收乾 SnackBar（避免 testWidgets 的 pending timer 檢查）。
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('清單：僅列墓標（未刪除不出現）＋剩餘天數＋清空全部鍵', (tester) async {
    final db = await seed(tester);
    await pump(tester, db);

    expect(find.text('最近刪除'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2), reason: '僅 2 筆墓標');
    expect(find.textContaining('剩餘 30 天'), findsNWidgets(2));
    expect(find.byKey(const Key('recent-delete-purge-all')), findsOneWidget);
    expect(find.byKey(const Key('recent-delete-purge-tx-1')), findsOneWidget);
    expect(find.byKey(const Key('recent-delete-restore-tx-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('單筆永久刪除：二次確認後該列消失、DB 列消失、其他墓標保留', (tester) async {
    final db = await seed(tester);
    await pump(tester, db);

    await tester.tap(find.byKey(const Key('recent-delete-purge-tx-1')));
    await tester.pumpAndSettle();
    expect(find.text('永久刪除？'), findsOneWidget, reason: '二次確認');
    expect(db.transactionById('tx-1'), isNotNull, reason: '確認前不動資料');

    await tester.tap(find.byKey(const Key('recent-delete-purge-confirm')));
    await drainSnackBar(tester);

    expect(db.transactionById('tx-1'), isNull, reason: '實體刪除');
    expect(db.transactionById('tx-2')!.deletedAt, isNotNull, reason: '其他墓標保留');
    expect(find.byType(ListTile), findsOneWidget, reason: '清單少一列');
    expect(find.byKey(const Key('recent-delete-purge-tx-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('單筆永久刪除：按取消 → 不刪除', (tester) async {
    final db = await seed(tester);
    await pump(tester, db);

    await tester.tap(find.byKey(const Key('recent-delete-purge-tx-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recent-delete-purge-cancel')));
    await tester.pumpAndSettle();

    expect(db.transactionById('tx-1')!.deletedAt, isNotNull, reason: '取消＝不刪');
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('清空全部：確認後清單空、清空全部鍵消失、未刪除交易保留', (tester) async {
    final db = await seed(tester);
    await pump(tester, db);

    await tester.tap(find.byKey(const Key('recent-delete-purge-all')));
    await tester.pumpAndSettle();
    expect(find.text('清空全部？'), findsOneWidget);
    expect(find.textContaining('將永久刪除 2 筆'), findsOneWidget, reason: '對話框顯示筆數');

    await tester.tap(find.byKey(const Key('recent-delete-purge-confirm')));
    await drainSnackBar(tester);

    expect(db.transactionById('tx-1'), isNull);
    expect(db.transactionById('tx-2'), isNull);
    expect(db.transactionById('tx-3')!.deletedAt, isNull, reason: '未刪除交易保留');
    expect(find.text('沒有最近刪除的交易'), findsOneWidget);
    expect(find.byKey(const Key('recent-delete-purge-all')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
