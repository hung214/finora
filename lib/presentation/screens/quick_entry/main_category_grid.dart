import 'package:flutter/material.dart';

import '../../../data/sqlite/app_database.dart';
import '../settings/category_settings_page.dart' show categoryEmojis;

/// 主類別三欄快捷格（PM 2026-10-24：**手機與桌面共用同一版面**）。
///
/// 點選＝以該**主類別**為分類（子類別另由「分類」欄開啟彈窗選擇）。
/// 選取高亮跟隨主類別（選中子類別時高亮其所屬主類別）。
class MainCategoryGrid extends StatelessWidget {
  const MainCategoryGrid({
    super.key,
    required this.categories,
    this.selectedMainId,
    required this.onSelect,
  });

  final List<CategoryRow> categories;
  final String? selectedMainId;
  final void Function(CategoryRow main) onSelect;

  /// chip 標籤：emoji 前綴（有設定且在圖示庫內才顯示）。
  static String label(String? icon, String name) =>
      (icon != null && categoryEmojis.contains(icon)) ? '$icon $name' : name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mains = [for (final c in categories) if (c.parentId == null) c];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 2.7,
      children: [
        for (final m in mains)
          InkWell(
            key: Key('cat-grid-${m.name}'),
            onTap: () => onSelect(m),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selectedMainId == m.id
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selectedMainId == m.id
                        ? scheme.primary
                        : scheme.outlineVariant),
              ),
              child: Text(
                label(m.icon, m.name),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    color: selectedMainId == m.id ? scheme.onPrimary : null,
                    fontWeight:
                        selectedMainId == m.id ? FontWeight.w700 : null),
              ),
            ),
          ),
      ],
    );
  }
}
