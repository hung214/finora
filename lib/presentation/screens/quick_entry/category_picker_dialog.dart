import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../data/sqlite/app_database.dart';
import '../settings/category_settings_page.dart' show categoryEmojis;

/// 分類選擇彈窗結果（PM 2026-10-24）。
sealed class CategoryPick {
  const CategoryPick();
}

/// 選定分類（主類別或子分類）。
class CategoryPicked extends CategoryPick {
  const CategoryPicked(this.categoryId);
  final String categoryId;
}

/// 要求「＋即建即選」（新增主類別／子類別）。
class CategoryAddRequested extends CategoryPick {
  const CategoryAddRequested({required this.asSub, this.parentId});
  final bool asSub;
  final String? parentId;
}

/// 顯示「分類選擇」彈窗：**上方常用／左主類別／右子類別**（PM 2026-10-24）。
///
/// 手機與 PC 共用同一元件（RWD 單碼庫）。回傳 null＝取消（不變更）。
Future<CategoryPick?> showCategoryPicker(
  BuildContext context,
  WidgetRef ref, {
  String? selectedId,
}) {
  return showDialog<CategoryPick>(
    context: context,
    builder: (_) => _CategoryPickerDialog(selectedId: selectedId),
  );
}

class _CategoryPickerDialog extends ConsumerStatefulWidget {
  const _CategoryPickerDialog({this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<_CategoryPickerDialog> createState() =>
      _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends ConsumerState<_CategoryPickerDialog> {
  String? _mainId;

  @override
  void initState() {
    super.initState();
    final cats = ref.read(expenseCategoriesProvider);
    final sel = widget.selectedId;
    CategoryRow? selected;
    for (final c in cats) {
      if (c.id == sel) selected = c;
    }
    // 選中子分類 → 左欄高亮其所屬主類別；選中主類別 → 本身；否則首個主類別。
    _mainId = selected?.parentId ?? selected?.id;
    if (_mainId == null) {
      for (final c in cats) {
        if (c.parentId == null) {
          _mainId = c.id;
          break;
        }
      }
    }
  }

  static String _label(String? icon, String name) =>
      (icon != null && categoryEmojis.contains(icon)) ? '$icon $name' : name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cats = ref.watch(expenseCategoriesProvider);
    final mains = [for (final c in cats) if (c.parentId == null) c];
    final subs = [for (final c in cats) if (c.parentId == _mainId) c];
    final byId = {for (final c in cats) c.id: c};
    final recent = [
      for (final id in ref.watch(recentCategoryIdsProvider))
        if (byId[id] != null) byId[id]!,
    ];

    Widget head(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Text(s, style: text.labelSmall?.copyWith(color: scheme.outline)),
        );

    Widget row({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) =>
        InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: selected ? scheme.onPrimaryContainer : null,
                    fontWeight: selected ? FontWeight.w700 : null)),
          ),
        );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Text('選擇分類',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text('點左欄主類別 → 右欄選子類別（不選＝只記主類別）',
                  style: text.labelSmall?.copyWith(color: scheme.outline)),
            ),
            if (recent.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text('常用',
                    style: text.labelSmall?.copyWith(color: scheme.outline)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in recent)
                      InkWell(
                        key: Key('picker-recent-${c.name}'),
                        onTap: () => Navigator.of(context)
                            .pop(CategoryPicked(c.id)),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_label(c.icon, c.name),
                              style: text.bodySmall?.copyWith(fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 156,
                    // 非懶載清單（SingleChildScrollView+Column）：長清單（15+ 主類別、
                    // 多子類別）全部建出——避免底部項找不到/點不到（PM 2026-10-22 教訓）。
                    child: SingleChildScrollView(
                      key: const Key('picker-mains'),
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        head('主類別'),
                        InkWell(
                          key: const Key('picker-add-main'),
                          onTap: () => Navigator.of(context).pop(
                              const CategoryAddRequested(asSub: false)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Text('＋ 新增主類別',
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.primary)),
                          ),
                        ),
                        for (final m in mains)
                          row(
                            key: Key('picker-main-${m.name}'),
                            label: _label(m.icon, m.name),
                            selected: m.id == _mainId,
                            onTap: () => setState(() => _mainId = m.id),
                          ),
                          ]),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('picker-subs'),
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        head('子類別'),
                        InkWell(
                          key: const Key('picker-add-sub'),
                          onTap: _mainId == null
                              ? null
                              : () => Navigator.of(context).pop(
                                  CategoryAddRequested(
                                      asSub: true, parentId: _mainId)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Text('＋ 新增子類別',
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.primary)),
                          ),
                        ),
                        if (_mainId != null)
                          row(
                            key: const Key('picker-sub-none'),
                            label: '（不分類）',
                            selected: false,
                            onTap: () => Navigator.of(context)
                                .pop(CategoryPicked(_mainId!)),
                          ),
                        for (final s in subs)
                          row(
                            key: Key('picker-sub-${s.name}'),
                            label: _label(s.icon, s.name),
                            selected: s.id == widget.selectedId,
                            onTap: () => Navigator.of(context)
                                .pop(CategoryPicked(s.id)),
                          ),
                          ]),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('picker-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
