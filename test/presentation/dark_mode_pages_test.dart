import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/providers.dart';
import 'package:ledger_sync/presentation/screens/budget/budget_page.dart';
import 'package:ledger_sync/presentation/screens/ledger/ledger_page.dart';
import 'package:ledger_sync/presentation/screens/overview/overview_page.dart';
import 'package:ledger_sync/presentation/screens/stats/stats_page.dart';
import 'package:ledger_sync/presentation/theme/app_theme.dart';

import '../helpers/db_fixture.dart';

/// 深色模式自動化護欄（M7 UI 統整決策 C 之 CI 前置；PM 走查前的最低保證）。
///
/// 驗證：各主頁於 **深色主題**下可建構、不拋例外、關鍵內容可見——防範
/// 之後新增頁面時漏用 token（硬編碼色）或深色下崩版。視覺美感仍由 PM 走查。
void main() {
  testWidgets('深色模式：四個主分頁不崩且關鍵內容可見', (tester) async {
    final db = DbFixture.create();
    await DbFixture.seedAccount(db,
        id: 'a-0', type: 'cash', name: '現金', opening: 12340);
    await DbFixture.seedCategory(db, id: 'c-1', kind: 'expense', name: '餐飲');
    await DbFixture.seedTx(db,
        id: 't-1',
        kind: 'expense',
        amountMinor: 250,
        accountId: 'a-0',
        category: 'c-1',
        merchant: '早餐店',
        occurredAt: DateTime.now().millisecondsSinceEpoch);
    final container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
    ]);

    final pages = <(String, Widget, String)>[
      ('總覽', const OverviewPage(), '現金'),
      ('明細', const LedgerPage(), '早餐店'),
      ('預算', const BudgetPage(), '預算'),
      ('統計', const StatsPage(), '月趨勢'),
    ];

    try {
      for (final (name, page, probe) in pages) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildAppTheme(Brightness.dark),
              home: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name 頁深色模式建構應無例外');
        expect(find.textContaining(probe), findsWidgets,
            reason: '$name 頁關鍵內容應可見（$probe）');
      }
    } finally {
      db.close();
      container.dispose();
    }
  });

  test('AppTokens：深淺雙組皆齊備且語意色沿用 F05 契約（orange/red 恆等）', () {
    expect(AppTokens.light.danger, Colors.red);
    expect(AppTokens.light.warning, Colors.orange);
    expect(AppTokens.dark.danger, Colors.red);
    expect(AppTokens.dark.warning, Colors.orange);
    // 深淺背景必不相同（深色確實有獨立值）。
    expect(AppTokens.light.bg, isNot(AppTokens.dark.bg));
    expect(AppTokens.light.cardBg, isNot(AppTokens.dark.cardBg));
    // 讀取入口（page 端一律經此——硬編碼色為違規）。
    expect(buildAppTheme(Brightness.dark).extension<AppTokens>(), isNotNull);
    expect(buildAppTheme(Brightness.light).extension<AppTokens>(), isNotNull);
  });
}
