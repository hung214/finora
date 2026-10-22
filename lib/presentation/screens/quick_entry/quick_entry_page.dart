import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('快速記帳')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // F02 S2.3：模式切換（支出/轉帳）——轉帳不適用分類/商家（UI 隱藏）。
            SegmentedButton<QuickEntryMode>(
              key: const Key('quick-entry-mode'),
              segments: const [
                ButtonSegment(value: QuickEntryMode.expense, label: Text('支出')),
                ButtonSegment(value: QuickEntryMode.transfer, label: Text('轉帳')),
                ButtonSegment(value: QuickEntryMode.split, label: Text('拆分')),
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
              const SizedBox(height: 12),
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
                              builder: (_) => const CategorySettingsPage())),
                      onSelected: (id) => controller.selectSplitCategoryById(0, id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('split-item-0-amount'),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '子項 1 金額'),
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
                              builder: (_) => const CategorySettingsPage())),
                      onSelected: (id) => controller.selectSplitCategoryById(1, id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('split-item-1-amount'),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '子項 2 金額'),
                      onChanged: (v) => controller.setSplitItemAmount(1, v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '總額 ${_splitTotal(state)} 元',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
            ] else ...[
              _pickerField(
                key: const Key('quick-entry-category'),
                label: '分類',
                text: state.category?.name ?? '選擇分類',
                entries: _hierarchicalEntries(categories),
                      recent: recent,
                      addCategoryAction: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const CategorySettingsPage())),
                onSelected: controller.selectCategoryById,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('quick-entry-merchant'),
                decoration: const InputDecoration(labelText: '商家'),
                onChanged: controller.setMerchant,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('quick-entry-amount'),
              controller: _amountCtrl,
              autofocus: true, // S1.1-5：金額欄自動聚焦（≤3 次點擊目標）
              // F02 S2.9：常駐計算機鍵盤輸入——none 不彈系統鍵盤（行動端）。
              keyboardType: TextInputType.none,
              decoration: const InputDecoration(labelText: '金額'),
              onChanged: controller.setAmount,
            ),
            // 常駐計算機鍵盤（F02 S2.9）：金額欄下方，＝ 求值即時入欄。
            AmountKeypad(expr: _expr, onExprChanged: _onKeypadExpr),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('quick-entry-time'),
              onPressed: () {
                // FR-Q8（S1.5）：bottom sheet 選擇器，不離開快記頁。
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true, // 內容高於半屏時可捲動（桌面小視窗）
                  builder: (_) => QuickDateTimePicker(
                    initial: state.occurredAt,
                    onSelected: controller.setOccurredAt,
                  ),
                );
              },
              child: Text(
                DateFormat('yyyy/MM/dd HH:mm').format(state.occurredAt),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('quick-entry-save'),
              // F02 S2.1：金額必填且大於 0（空值/0 皆禁用）；轉帳另需目標帳戶；
              // 拆分另需雙子項完成（FR-T6 總額守恆由 BE 驗證）。
              onPressed: _saveEnabled(state) ? controller.save : null,
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  static String _splitTotal(QuickEntryState state) {
    final a0 = int.tryParse(state.splitAmount0) ?? 0;
    final a1 = int.tryParse(state.splitAmount1) ?? 0;
    return '${a0 + a1}';
  }

  static bool _saveEnabled(QuickEntryState state) {
    final amountOk = (int.tryParse(state.amount) ?? 0) > 0;
    switch (state.mode) {
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
