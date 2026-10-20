import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'budget/budget_page.dart';
import 'ledger/ledger_page.dart';
import 'overview/overview_page.dart';
import 'quick_entry/quick_entry_page.dart';
import 'stats/stats_page.dart';

/// 主殼（SDD §8 IA；RWD 響應式——單碼庫雙殼，ui/08-desktop-shell 雛型落地）：
/// - 窄（< 900px，手機/窄窗）→ 底部 NavigationBar。
/// - 寬（≥ 900px，桌面）→ 左側 NavigationRail（對齊 08 桌面殼雛型側欄）。
/// - 分頁：總覽/明細/預算/統計；桌面快捷鍵 ⌘N/Ctrl+N 開快記（FR-Q7，F01-S1.11）。
/// - 快記為全頁面推入，「完成」返回進入前分頁（FR-Q2）。
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  static const _tabs = [
    (OverviewPage(), '總覽', Icons.home_outlined, Icons.home),
    (LedgerPage(), '明細', Icons.receipt_long_outlined, Icons.receipt_long),
    (BudgetPage(), '預算', Icons.savings_outlined, Icons.savings),
    (StatsPage(), '統計', Icons.query_stats_outlined, Icons.query_stats),
  ];

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _tab = 0;

  void _openQuickEntry() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QuickEntryPage()),
      );

  @override
  Widget build(BuildContext context) {
    final tabs = MainShellPage._tabs;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // FR-Q7 桌面快捷鍵（F01-S1.11）：⌘N（macOS）／Ctrl+N（其餘）。
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): const _OpenQuickEntryIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): const _OpenQuickEntryIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenQuickEntryIntent: CallbackAction<_OpenQuickEntryIntent>(
            onInvoke: (_) => _openQuickEntry(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final body = IndexedStack(
                index: _tab,
                children: [for (final (page, _, _, _) in tabs) page],
              );
              if (!wide) {
                // 手機殼：底部 NavigationBar。
                return Scaffold(
                  body: body,
                  floatingActionButton: FloatingActionButton(
                    key: const Key('fab-quick-entry'),
                    tooltip: '快記',
                    onPressed: _openQuickEntry,
                    child: const Icon(Icons.add),
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: [
                      for (final (_, label, icon, selected) in tabs)
                        NavigationDestination(
                          key: Key('nav-$label'),
                          icon: Icon(icon),
                          selectedIcon: Icon(selected),
                          label: label,
                        ),
                    ],
                  ),
                );
              }
              // 桌面殼：左側 NavigationRail（08-desktop-shell 側欄語意）。
              return Scaffold(
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _tab,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            FloatingActionButton(
                              key: const Key('fab-quick-entry'),
                              tooltip: '快記（⌘N）',
                              onPressed: _openQuickEntry,
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      destinations: [
                        for (final (_, label, icon, selected) in tabs)
                          NavigationRailDestination(
                            icon: Icon(icon),
                            selectedIcon: Icon(selected),
                            label: Text(label, key: Key('nav-$label')),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 快記開啟意圖（快捷鍵動作目標）。
class _OpenQuickEntryIntent extends Intent {
  const _OpenQuickEntryIntent();
}
