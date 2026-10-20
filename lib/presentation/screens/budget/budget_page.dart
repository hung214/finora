import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/budgets/budget_evaluator.dart';
import '../../../application/providers.dart';
import '../../../data/sqlite/app_database.dart';

/// 預算頁（FR-B2~B7 呈現面；M2 新增分頁）。
///
/// - 每預算卡：用量/額度（千分位）＋百分比＋進度條
///   （<80% 主色、≥80% 橙、≥100% 紅——AC-05）。
/// - 超支顯示「超支 {金額}」；預扣分量顯示「預扣 {金額}」標籤（FR-B5）。
/// - 用量為衍生值（SDD 原則 2）：訂閱 ledgerProvider 即時刷新（AC-02）。
class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 訂閱交易變化（儲存/刪除/還原後即時刷新）。
    ref.watch(ledgerProvider);
    final budgets = ref.watch(dbProvider).allBudgets();
    return Scaffold(
      appBar: AppBar(title: const Text('預算')),
      body: budgets.isEmpty
          ? const Center(child: Text('尚無預算'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final b in budgets) _BudgetCard(budget: b),
              ],
            ),
    );
  }
}

/// 預算進度條（共用：BudgetPage／總覽橫幅）。
///
/// <80% 主色、≥80% 橙、≥100% 紅（AC-05）；key = budget-progress-{名稱}。
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.name,
    required this.usageMinor,
    required this.amountMinor,
  });

  final String name;
  final int usageMinor;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    final over = usageMinor > amountMinor;
    final progressColor =
        over ? Colors.red : (usageMinor * 5 >= amountMinor * 4 ? Colors.orange : null);
    return LinearProgressIndicator(
      key: Key('budget-progress-$name'),
      value: amountMinor <= 0 ? 0 : min(usageMinor / amountMinor, 1.0),
      color: progressColor,
      backgroundColor: Colors.grey.shade300,
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.budget});

  final BudgetRow budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final evaluator = BudgetEvaluator(db);
    final name = budget.categoryId == null
        ? '總預算'
        : (db.categoryName(budget.categoryId!) ?? '分類預算');
    final usage = budget.categoryId == null
        ? (evaluator.totalUsageMinor() ?? 0)
        : (evaluator.categoryUsage(budget.categoryId!)?.totalMinor ?? 0);
    final pending = budget.categoryId == null
        ? 0
        : (evaluator.categoryUsage(budget.categoryId!)?.pendingMinor ?? 0);
    final amount = budget.amountMinor;
    final pct = amount <= 0 ? 0.0 : usage * 100 / amount;
    final pctText = pct == pct.roundToDouble() ? '${pct.round()}' : '$pct';
    final over = usage > amount;
    final fmt = NumberFormat('#,###');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (pending > 0)
                  Text(
                    '預扣 ${fmt.format(pending)}', // FR-B5：預扣分量可辨識
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.deepPurple),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${fmt.format(usage)} / ${fmt.format(amount)}（$pctText%）'),
            const SizedBox(height: 8),
            BudgetProgressBar(
              name: name,
              usageMinor: usage,
              amountMinor: amount,
            ),
            if (over)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '超支 ${fmt.format(usage - amount)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
