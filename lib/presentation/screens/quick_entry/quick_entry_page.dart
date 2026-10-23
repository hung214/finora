import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/appearance/theme_mode_state.dart';
import '../../../application/budgets/budget_service.dart';
import '../../../application/categories/category_service.dart';
import '../../../application/providers.dart';
import 'amount_keypad.dart';
import 'quick_date_time_picker.dart';
import '../settings/category_settings_page.dart';
import 'quick_entry_controller.dart';

/// 快記頁（FR-Q1~Q8，acceptance F01）。
///
/// - 欄位：帳戶/分類/商家（Sticky）＋金額/時間（每筆重設）。
/// - 金額欄 autofocus（S1.1-5：數字鍵盤已自動聚焦）。
/// - 時間欄：QuickDateTimePicker bottom sheet，不離開快記頁（FR-Q8，S1.5）。
/// - 儲存 → SavedDialog「繼續記下一筆？」（繼續/復原上一筆/完成，FR-Q2）。
///
/// 帳戶/分類選擇器採 PopupMenuButton（全受控——顯示即 controller 狀態；
/// DropdownButtonFormField.initialValue 為 FormField 初值語意，狀態變更
/// 後不更新顯示，不符合智慧預設/固定預設動態切換）。
class QuickEntryPage extends ConsumerStatefulWidget {
  const QuickEntryPage({super.key});

  @override
  ConsumerState<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends ConsumerState<QuickEntryPage> {
  final _amountCtrl = TextEditingController();

  /// 計算機運算式（F02 S2.9；受控——顯示於金額欄，＝ 求值後為純數字）。
  String _expr = '';

  /// 兩層式分類（PM 2026-10-22）：展開之子類別所屬主類別。
  String? _selectedMainId;

  /// 預算模式目標＝總預算（PM 2026-10-22）。
  bool _budgetIsTotal = false;

  /// 分類即時新增後的刷新（providers 讀 db 快取，需 invalidate）。
  void _refreshCategories() => ref.invalidate(expenseCategoriesProvider);

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  /// 相位轉移驅動（SDD §5.1）：入 SavedDialog → 彈每筆確認；離開 → 金額清空。
  void _onPhaseChange(QuickEntryPhase? prev, QuickEntryPhase next) {
    if (prev == null) return;
    if (next == QuickEntryPhase.savedDialog && prev != QuickEntryPhase.savedDialog) {
      showDialog<void>(
        context: context,
        builder: (_) => SavedDialog(onFinish: () => Navigator.of(context).pop()),
      );
    }
    if (prev == QuickEntryPhase.savedDialog && next != QuickEntryPhase.savedDialog) {
      _amountCtrl.clear(); // 繼續：金額清空（FR-Q5 Sticky 不含金額）
      setState(() => _expr = ''); // 計算機運算式隨金額重設（F02 S2.9）
    }
  }

  /// 計算機輸入（F02 S2.9）：運算式 → 金額欄顯示＋controller 同步
  /// （儲存啟用由 int.tryParse 決定——運算式未完成自然禁用）。
  void _onKeypadExpr(String expr) {
    setState(() => _expr = expr);
    _amountCtrl.text = expr;
    ref.read(quickEntryControllerProvider.notifier).setAmount(expr);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickEntryControllerProvider);
    final controller = ref.read(quickEntryControllerProvider.notifier);
    final accounts = ref.watch(activeAccountsProvider);
    final categories = ref.watch(expenseCategoriesProvider);
    // 常用類別（FR-B1 常用區）：最近使用 10 個，常駐選單最上方。
    final nameById = {for (final c in categories) c.id: c.name};
    final recent = [
      for (final id in ref.watch(recentCategoryIdsProvider))
        if (nameById[id] != null) (id, nameById[id]!),
    ];

    ref.listen(
      quickEntryControllerProvider.select((s) => s.phase),
      (prev, next) => _onPhaseChange(prev, next),
    );

    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('快速記帳'),
        actions: [
          // 主題切換（PM 2026-10-22：亮/暗按鈕——亮色以 01/02 白卡風格為準）。
          IconButton(
            key: const Key('qe-theme-toggle'),
            tooltip: themeMode == ThemeMode.dark ? '切換淺色' : '切換深色',
            onPressed: () => ref.read(themeModeProvider.notifier).set(
                themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
            icon: Icon(themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  // 金額大顯示（03 雛型）。
                  TextField(
                    key: const Key('quick-entry-amount'),
                    controller: _amountCtrl,
                    autofocus: true, // S1.1-5
                    keyboardType: TextInputType.none, // 常駐鍵盤（F02 S2.9）
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(
                        hintText: '0', border: InputBorder.none),
                    onChanged: controller.setAmount,
                  ),
                  // 日期（PM 2026-10-23）：金額下方；◀▶ 快調 ±1 天；
                    // 點擊日期開日曆（可跨月/年，FR-Q8 S1.5 不離開頁）。
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        key: const Key('date-prev'),
                        tooltip: '前一天',
                        onPressed: () => controller.setOccurredAt(
                            state.occurredAt.subtract(const Duration(days: 1))),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      TextButton(
                        key: const Key('quick-entry-time'),
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => QuickDateTimePicker(
                              initial: state.occurredAt,
                              onSelected: controller.setOccurredAt,
                            ),
                          );
                        },
                        child: Text(
                          _dateLabel(state.occurredAt),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      IconButton(
                        key: const Key('date-next'),
                        tooltip: '後一天',
                        onPressed: () => controller.setOccurredAt(
                            state.occurredAt.add(const Duration(days: 1))),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  // F02 S2.3：模式切換（支出/轉帳/拆分）。
                  SegmentedButton<QuickEntryMode>(
                    key: const Key('quick-entry-mode'),
                    segments: const [
                      ButtonSegment(
                          value: QuickEntryMode.expense, label: Text('支出')),
                      ButtonSegment(
                          value: QuickEntryMode.transfer, label: Text('轉帳')),
                      ButtonSegment(
                          value: QuickEntryMode.split, label: Text('拆分')),
                      ButtonSegment(
                          value: QuickEntryMode.budget, label: Text('預算')),
                    ],
                    selected: {state.mode},
                    onSelectionChanged: (modes) => controller.setMode(modes.first),
                  ),
                  const SizedBox(height: 12),
                  _pickerField(
                    key: const Key('quick-entry-account'),
                    label: state.mode == QuickEntryMode.transfer ? '來源帳戶' : '帳戶',
                    text: state.account?.name ?? '選擇帳戶',
                    entries: accounts.map((a) => (a.id, a.name, false)).toList(),
                    recent: const [],
                    onSelected: controller.selectAccountById,
                  ),
                  const SizedBox(height: 12),
                  if (state.mode == QuickEntryMode.transfer) ...[
                    _pickerField(
                      key: const Key('quick-entry-target'),
                      label: '目標帳戶',
                      text: state.toAccount?.name ?? '選擇目標帳戶',
                      // 同帳戶轉帳 UI 阻擋（S2.3 邊界）：目標選項排除來源帳戶。
                      entries: accounts
                          .where((a) => a.id != state.account?.id)
                          .map((a) => (a.id, a.name, false))
                          .toList(),
                      recent: const [],
                      onSelected: controller.selectToAccountById,
                    ),
                  ] else if (state.mode == QuickEntryMode.split) ...[
                    // 拆分子項 ×2（FR-T6；M2 固定兩項；總額守恆由 BE 驗證）。
                    Row(
                      children: [
                        Expanded(
                          child: _pickerField(
                            key: const Key('split-item-0-cat'),
                            label: '子項 1 分類',
                            text: state.splitCat0?.name ?? '選擇分類',
                            entries: _hierarchicalEntries(categories),
                            recent: recent,
                            addCategoryAction: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const CategorySettingsPage())),
                            onSelected: (id) =>
                                controller.selectSplitCategoryById(0, id),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('split-item-0-amount'),
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: '子項 1 金額'),
                            onChanged: (v) => controller.setSplitItemAmount(0, v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerField(
                            key: const Key('split-item-1-cat'),
                            label: '子項 2 分類',
                            text: state.splitCat1?.name ?? '選擇分類',
                            entries: _hierarchicalEntries(categories),
                            recent: recent,
                            addCategoryAction: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const CategorySettingsPage())),
                            onSelected: (id) =>
                                controller.selectSplitCategoryById(1, id),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const Key('split-item-1-amount'),
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: '子項 2 金額'),
                            onChanged: (v) => controller.setSplitItemAmount(1, v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('總額 ${_splitTotal(state)} 元',
                        style: Theme.of(context).textTheme.titleMedium),
                  ] else if (state.mode == QuickEntryMode.budget) ...[
                    // 預算模式（PM 2026-10-22）：預算設定併入快記——
                    // 「總預算」或選定分類 → 金額（計算機）→ OK → 存為預算。
                    _BudgetTargetGrid(
                      categories: categories,
                      isTotal: _budgetIsTotal,
                      selectedCategory: state.category,
                      selectedMainId: _selectedMainId,
                      onSelect: (id, mainId) {
                        controller.selectCategoryById(id);
                        setState(() {
                          _selectedMainId = mainId;
                          _budgetIsTotal = false;
                        });
                      },
                      onSelectTotal: () =>
                          setState(() => _budgetIsTotal = true),
                      onQuickAdd: _quickAddCategory,
                    ),
                  ] else ...[
                    // 兩層式分類（PM 2026-10-22）：常用 → 主類別 → 子類別，
                    // 各層尾部可直接新增。
                    _CategoryGridSection(
                      recent: recent,
                      categories: categories,
                      selectedCategory: state.category,
                      selectedMainId: _selectedMainId,
                      onSelect: (id, mainId) {
                        controller.selectCategoryById(id);
                        setState(() => _selectedMainId = mainId);
                      },
                      onQuickAdd: _quickAddCategory,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('quick-entry-merchant'),
                      decoration: const InputDecoration(labelText: '商家'),
                      onChanged: controller.setMerchant,
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // 浮動底部面板（PM 2026-10-22）：OK 儲存鈕在計算機**上方**，
            // 計算機貼底常駐（不隨內容捲動）。
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .shadow
                        .withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const Key('quick-entry-save'),
                    // F02 S2.1：金額必填且大於 0；轉帳另需目標帳戶；拆分另需雙子項；
                    // 預算模式（PM 2026-10-22）→ 存為預算內容（非交易）。
                    onPressed: _saveEnabled(state)
                        ? (state.mode == QuickEntryMode.budget
                            ? _saveBudget
                            : controller.save)
                        : null,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: Text(_saveEnabled(state) ? 'OK 儲存' : 'OK',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  AmountKeypad(expr: _expr, onExprChanged: _onKeypadExpr),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 預算模式儲存（PM 2026-10-22）：輸入完成 → 變成預算內容
  /// （總預算或選定分類；週期起始日＝1，進階編輯走預算頁表單）。
  void _saveBudget() {
    final state = ref.read(quickEntryControllerProvider);
    final amount = int.tryParse(state.amount) ?? 0;
    if (amount <= 0) return;
    final service = BudgetService(ref.read(dbProvider));
    if (_budgetIsTotal) {
      service.setTotalBudget(amountMinor: amount, periodStartDay: 1);
    } else {
      final cat = state.category;
      if (cat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('請先選擇分類（或「總預算」）')));
        return;
      }
      service.setCategoryBudget(
          categoryId: cat.id, amountMinor: amount, periodStartDay: 1);
    }
    // Sticky 慣例：金額清空；成功提示（預算非交易——不彈每筆確認）。
    setState(() {
      _expr = '';
      _amountCtrl.clear();
    });
    ref.read(quickEntryControllerProvider.notifier).setAmount('');
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('預算已設定（見預算頁）')));
  }

  /// 分類即時新增（PM 2026-10-22：主類別/子類別層尾「＋」）：名稱即建，
  /// 重名走 CategoryService 拒絕提示；建立後立即選取。
  Future<void> _quickAddCategory({required bool asSub}) async {
    final parentId = asSub ? _selectedMainId : null;
    if (asSub && parentId == null) return; // 無選中主類別不可加子分類
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(asSub ? '新增子分類' : '新增主類別'),
        content: TextField(
          key: const Key('quick-add-category-name'),
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分類名稱'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('取消')),
          FilledButton(
              key: const Key('quick-add-category-save'),
              onPressed: () =>
                  Navigator.of(dialogCtx).pop(ctrl.text.trim()),
              child: const Text('建立')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final row = CategoryService(ref.read(dbProvider)).create(
          kind: 'expense', name: name, parentId: parentId);
      _refreshCategories();
      ref.read(quickEntryControllerProvider.notifier).selectCategoryById(row.id);
      if (!asSub) setState(() => _selectedMainId = row.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// 日期顯示（中文星期；不依賴 intl locale 初始化——測試直接 pump 也安全）。
  static const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

  static String _dateLabel(DateTime t) =>
      '${DateFormat('yyyy/MM/dd').format(t)}'
      '（${_weekdays[t.weekday - 1]}） '
      '${DateFormat('HH:mm').format(t)}';

  static String _splitTotal(QuickEntryState state) {
    final a0 = int.tryParse(state.splitAmount0) ?? 0;
    final a1 = int.tryParse(state.splitAmount1) ?? 0;
    return '${a0 + a1}';
  }

  static bool _saveEnabled(QuickEntryState state) {
    final amountOk = (int.tryParse(state.amount) ?? 0) > 0;
    switch (state.mode) {
      case QuickEntryMode.budget:
        return amountOk; // 分類未選 → OK 停留（_saveBudget 提示）
      case QuickEntryMode.transfer:
        return amountOk && state.toAccount != null;
      case QuickEntryMode.split:
        final a0 = int.tryParse(state.splitAmount0) ?? 0;
        final a1 = int.tryParse(state.splitAmount1) ?? 0;
        return a0 > 0 && a1 > 0 && state.splitCat0 != null && state.splitCat1 != null;
      case QuickEntryMode.expense:
        return amountOk;
    }
  }

  /// 分類選單項（主類別→子分類縮排；FR-B1 階層）。
  /// 第三元素＝是否子分類（結構化縮排渲染——文字保持原樣供精確比對）。
  List<(String, String, bool)> _hierarchicalEntries(List<dynamic> categories) {
    final mains = categories.where((c) => c.parentId == null);
    return [
      for (final m in mains) ...[
        (m.id as String, m.name as String, false),
        for (final s in categories.where((c) => c.parentId == m.id))
          (s.id as String, s.name as String, true),
      ],
    ];
  }

  Widget _pickerField({
    required Key key,
    required String label,
    required String text,
    required List<(String, String, bool)> entries,
    required List<(String, String)> recent,
    required void Function(String?) onSelected,
    VoidCallback? addCategoryAction, // 分類選擇器專用：＋新增分類（PM 2026-10-22）
  }) {
    return PopupMenuButton<String>(
      key: key,
      initialValue: null,
      onSelected: onSelected,
      itemBuilder: (_) => [
        // ＋新增分類（PM 2026-10-22）：**選單頂部**常駐（長清單底部
        // 項目在 LazyListView 未建/超出畫面，底部入口會點不到）。
        if (addCategoryAction != null)
          PopupMenuItem<String>(
            key: const Key('picker-add-category'),
            onTap: addCategoryAction,
            child: Row(children: [
              Icon(Icons.add,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              const Text('新增分類'),
            ]),
          ),
        // 常用類別（FR-B1 常用區）：最近使用 10 個，常駐最上方。
        if (recent.isNotEmpty) ...[
          const PopupMenuItem(
            enabled: false,
            height: 34,
            child: Text('常用',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          for (final (id, name) in recent)
            PopupMenuItem(
              key: Key('recent-cat-$name'),
              value: id,
              child: Row(children: [
                Icon(Icons.history,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(name),
              ]),
            ),
          const PopupMenuDivider(),
        ],
        for (final (id, name, isSub) in entries)
          PopupMenuItem(
            value: id,
            child: isSub
                ? Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Row(children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 14),
                      const SizedBox(width: 4),
                      Text(name),
                    ]),
                  )
                : Text(name),
          ),
      ],
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(text),
      ),
    );
  }
}

/// 兩層式分類格（PM 2026-10-22）：**常用 → 主類別 →（展開）子類別**；
/// 主類別格尾「＋主類別」、子分類列尾「＋子分類」皆可直接新增
/// （快速對話框即建即選；重名由 CategoryService 拒絕）。
class _CategoryGridSection extends StatelessWidget {
  const _CategoryGridSection({
    required this.recent,
    required this.categories,
    required this.selectedCategory,
    required this.selectedMainId,
    required this.onSelect,
    required this.onQuickAdd,
  });

  final List<(String, String)> recent;
  final List<dynamic> categories;
  final dynamic selectedCategory; // CategoryRow?
  final String? selectedMainId;
  final void Function(String id, String? mainId) onSelect;
  final Future<void> Function({required bool asSub}) onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final mains = categories.where((c) => c.parentId == null).toList();
    final subs = selectedMainId == null
        ? const <dynamic>[]
        : categories.where((c) => c.parentId == selectedMainId).toList();
    final selectedId = selectedCategory?.id as String?;
    final scheme = Theme.of(context).colorScheme;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.outline)),
        );

    Widget chip({
      required String label,
      required bool selected,
      Key? key,
      VoidCallback? onTap,
      IconData? icon,
    }) =>
        InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 15,
                      color: selected ? scheme.onPrimary : scheme.outline),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : null,
                        color: selected ? scheme.onPrimary : null)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recent.isNotEmpty) ...[
          label('常用'),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (id, name) in recent)
                  chip(
                      label: name,
                      selected: selectedId == id,
                      key: Key('recent-chip-$name'),
                      icon: Icons.history,
                      onTap: () => onSelect(id, selectedMainId)),
              ]),
        ],
        label('主類別'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in mains)
            chip(
                label: m.name as String,
                selected: selectedId == m.id || selectedMainId == m.id,
                key: Key('cat-chip-${m.name}'),
                onTap: () => onSelect(m.id as String, m.id as String)),
          chip(
              label: '主類別',
              selected: false,
              key: const Key('cat-add-main'),
              icon: Icons.add,
              onTap: () => onQuickAdd(asSub: false)),
        ]),
        if (selectedMainId != null) ...[
          label('子分類'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in subs)
              chip(
                  label: s.name as String,
                  selected: selectedId == s.id,
                  key: Key('cat-chip-${s.name}'),
                  onTap: () => onSelect(s.id as String, selectedMainId)),
            chip(
                label: '子分類',
                selected: false,
                key: const Key('cat-add-sub'),
                icon: Icons.add,
                onTap: () => onQuickAdd(asSub: true)),
          ]),
        ],
      ],
    );
  }
}


/// 預算模式目標格（PM 2026-10-22）：**總預算 或 分類**（兩層格同快記）；
/// 選定後金額（計算機）→ OK → 存為預算內容。
class _BudgetTargetGrid extends StatelessWidget {
  const _BudgetTargetGrid({
    required this.categories,
    required this.isTotal,
    required this.selectedCategory,
    required this.selectedMainId,
    required this.onSelect,
    required this.onSelectTotal,
    required this.onQuickAdd,
  });

  final List<dynamic> categories;
  final bool isTotal;
  final dynamic selectedCategory; // CategoryRow?
  final String? selectedMainId;
  final void Function(String id, String? mainId) onSelect;
  final VoidCallback onSelectTotal;
  final Future<void> Function({required bool asSub}) onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final mains = categories.where((c) => c.parentId == null).toList();
    final subs = selectedMainId == null
        ? const <dynamic>[]
        : categories.where((c) => c.parentId == selectedMainId).toList();
    final selectedId = selectedCategory?.id as String?;
    final scheme = Theme.of(context).colorScheme;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.outline)),
        );

    Widget chip({
      required String label,
      required bool selected,
      Key? key,
      VoidCallback? onTap,
      IconData? icon,
    }) =>
        InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 15,
                      color: selected ? scheme.onPrimary : scheme.outline),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : null,
                        color: selected ? scheme.onPrimary : null)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('預算目標'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          chip(
              label: '總預算',
              selected: isTotal,
              key: const Key('budget-chip-total'),
              icon: Icons.savings_outlined,
              onTap: onSelectTotal),
          for (final m in mains)
            chip(
                label: m.name as String,
                selected: !isTotal && selectedId == m.id,
                key: Key('budget-chip-${m.name}'),
                onTap: () => onSelect(m.id as String, m.id as String)),
          chip(
              label: '主類別',
              selected: false,
              key: const Key('cat-add-main'),
              icon: Icons.add,
              onTap: () => onQuickAdd(asSub: false)),
        ]),
        if (selectedMainId != null && !isTotal) ...[
          label('子分類'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in subs)
              chip(
                  label: s.name as String,
                  selected: selectedId == s.id,
                  key: Key('budget-chip-${s.name}'),
                  onTap: () => onSelect(s.id as String, selectedMainId)),
            chip(
                label: '子分類',
                selected: false,
                key: const Key('cat-add-sub'),
                icon: Icons.add,
                onTap: () => onQuickAdd(asSub: true)),
          ]),
        ],
      ],
    );
  }
}

/// 每筆確認對話框（FR-Q2）：繼續／復原上一筆／完成。
class SavedDialog extends ConsumerWidget {
  const SavedDialog({super.key, required this.onFinish});

  /// 「完成」：關閉對話框後返回進入前畫面（FR-Q2，S1.9）。
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickEntryControllerProvider);
    final controller = ref.read(quickEntryControllerProvider.notifier);
    return AlertDialog(
      title: const Text('繼續記下一筆？'),
      content: Text('本次已記 ${state.sessionCount} 筆'),
      actions: [
        TextButton(
          onPressed: () {
            controller.continueEntry();
            Navigator.of(context).pop();
          },
          child: const Text('繼續'),
        ),
        TextButton(
          onPressed: controller.undoLast,
          child: const Text('復原上一筆'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onFinish();
          },
          child: const Text('完成'),
        ),
      ],
    );
  }
}
