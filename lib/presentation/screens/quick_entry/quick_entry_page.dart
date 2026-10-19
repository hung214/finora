import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import 'amount_keypad.dart';
import 'quick_date_time_picker.dart';
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
              ],
              selected: {state.mode},
              onSelectionChanged: (modes) => controller.setMode(modes.first),
            ),
            const SizedBox(height: 12),
            _pickerField(
              key: const Key('quick-entry-account'),
              label: state.mode == QuickEntryMode.transfer ? '來源帳戶' : '帳戶',
              text: state.account?.name ?? '選擇帳戶',
              entries: accounts.map((a) => (a.id, a.name)),
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
                    .map((a) => (a.id, a.name)),
                onSelected: controller.selectToAccountById,
              ),
              const SizedBox(height: 12),
            ] else ...[
              _pickerField(
                key: const Key('quick-entry-category'),
                label: '分類',
                text: state.category?.name ?? '選擇分類',
                entries: categories.map((c) => (c.id, c.name)),
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
              // F02 S2.1：金額必填且大於 0（空值/0 皆禁用）；轉帳另需目標帳戶。
              onPressed: (int.tryParse(state.amount) ?? 0) <= 0 ||
                      (state.mode == QuickEntryMode.transfer && state.toAccount == null)
                  ? null
                  : controller.save,
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerField({
    required Key key,
    required String label,
    required String text,
    required Iterable<(String, String)> entries,
    required void Function(String?) onSelected,
  }) {
    return PopupMenuButton<String>(
      key: key,
      initialValue: null,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (id, name) in entries)
          PopupMenuItem(value: id, child: Text(name)),
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
