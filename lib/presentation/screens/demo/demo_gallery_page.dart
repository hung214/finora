import 'package:flutter/material.dart';

import 'category_settings_demo_page.dart';
import 'credit_card_demo_page.dart';
import 'dashboard_demo_page.dart';
import 'demo_shared.dart';
import 'ledger_demo_page.dart';
import 'quick_entry_calc_demo_page.dart';
import 'quick_entry_demo_page.dart';
import 'recent_deletions_demo_page.dart';
import 'settings_demo_page.dart';
import 'stats_demo_page.dart';
import 'budget_demo_page.dart';

/// UI Demo 畫廊：瀏覽 7 個主要畫面的靜態呈現（含深色/淺色切換，FR-O1）。
/// 資料為 acceptance 檔之虛構劇例；真實資料由 M1 起 F01~F10 接線（tasks.md §4）。
class DemoGalleryPage extends StatefulWidget {
  const DemoGalleryPage({super.key});

  @override
  State<DemoGalleryPage> createState() => _DemoGalleryPageState();
}

class _DemoGalleryPageState extends State<DemoGalleryPage> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final theme = _dark ? DemoTheme.dark() : DemoTheme.light();
    final items = <(String, String, Widget)>[
      ('01 總覽', 'specs/plan/ui/01-dashboard.html', const DashboardDemoContent()),
      ('02 明細', 'specs/plan/ui/02-ledger.html', const LedgerDemoContent()),
      ('03 快速記帳（含每筆確認）', 'specs/plan/ui/03-quick-entry.html', const QuickEntryDemoContent()),
      ('04 預算與收入目標', 'specs/plan/ui/04-budget.html', const BudgetDemoContent()),
      ('06 信用卡與帳單', 'specs/plan/ui/06-credit-card.html', const CreditCardDemoContent()),
      ('09 分類設定', 'specs/plan/ui/09-category-settings.html', const CategorySettingsDemoContent()),
      ('10 新增資料（金額輸入＋計算機）', 'specs/plan/ui/10-quick-entry-calc.html', const QuickEntryCalcDemoContent()),
      ('11 統計', 'specs/plan/ui/11-stats.html', const StatsDemoContent()),
      ('12 最近刪除（還原／永久刪除）', 'specs/plan/ui/12-recent-deletions.html', const RecentDeletionsDemoContent()),
      ('09 設定與同步', 'specs/plan/ui/07-settings-sync.html', const SettingsDemoContent()),
    ];
    return DemoThemeScope(
      theme: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🎨 UI Demo 畫廊'),
          actions: [
            IconButton(
              tooltip: '深色/淺色切換（FR-O1）',
              icon: Icon(_dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => setState(() => _dark = !_dark),
            ),
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '⚠️ Demo 多為靜態畫面（虛構劇例資料，不含資料庫）；'
                  '「10 新增資料」含可互動計算機（真實 AmountKeypad 元件）。\n'
                  '真實畫面自 M1 起 F01~F10 以紅綠燈流程實作。\n'
                  '版權聲明：商家/卡片名稱皆為虛構，無商標關聯；圖示使用 Material Icons（Apache-2.0）。\n'
                  'HTML 雛型（含規格便利貼）：specs/plan/ui/',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              );
            }
            final (title, spec, page) = items[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.phone_android_outlined),
                title: Text(title),
                subtitle: Text(spec, style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DemoThemeScope(
                      theme: theme,
                      child: DemoPageShell(title: title, spec: spec, child: page),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
