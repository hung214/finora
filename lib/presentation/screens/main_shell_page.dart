import 'package:flutter/material.dart';

import 'ledger/ledger_page.dart';
import 'overview/overview_page.dart';
import 'quick_entry/quick_entry_page.dart';

/// 主殼：總覽/明細雙分頁＋快記 FAB（SDD §8 IA；M1 精簡版——預算/卡片/設定
/// 分頁隨 M2+ 加入）。快記為全頁面推入，「完成」返回進入前分頁（FR-Q2）。
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [OverviewPage(), LedgerPage()],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('fab-quick-entry'),
        tooltip: '快記',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const QuickEntryPage()),
        ),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '總覽',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '明細',
          ),
        ],
      ),
    );
  }
}
