import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/budgets/budget_evaluator.dart';
import '../../../application/budgets/budget_period_service.dart';
import '../../../application/providers.dart';
import '../../../application/stats/monthly_stats_service.dart';
import '../../../core/clock.dart';
import '../../../data/sqlite/app_database.dart';
import '../../theme/app_theme.dart';

/// 預算頁（FR-B2~B7 呈現面；UI-P3 對照 04-budget 雛型）。
///
/// - **總預算卡**：週期標題＋百分比（色）＋大金額＋進度條＋
///   「剩餘 · 每日可用 · 月底預測（含預扣）」摘要行（FR-B2/B3）。
/// - **分類預算卡**：各分類 bitem——用量/額度（千分位）＋百分比＋
///   預扣標籤（FR-B5）＋**日均**（已用/經過天數）＋進度條
///   （<80% 主色、≥80% 橙、≥100% 紅——AC-05）＋超支紅字（記帳不封鎖）。
/// - **收入目標卡**（FR-B6）：達標率（>100% 不封頂）＋badge。
/// - **本月結餘卡**（FR-B7）：預計（目標−總預算）／實際（含預扣）兩行並列。
/// - 用量為衍生值（SDD 原則 2）：訂閱 ledgerProvider 即時刷新（AC-02）。
class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 訂閱交易變化（儲存/刪除/還原後即時刷新）。
    ref.watch(ledgerProvider);
    final db = ref.watch(dbProvider);
    final budgets = db.allBudgets();
    final total = budgets.where((b) => b.categoryId == null).toList();
    final categoryBudgets =
        budgets.where((b) => b.categoryId != null).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('預算'),
        actions: [
          IconButton(
            key: const Key('budget-add'),
            tooltip: '新增預算',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('預算編輯將於後續版本提供')),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: budgets.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined,
                      size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 8),
                  const Text('尚無預算'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (total.isNotEmpty)
                  _TotalBudgetCard(budget: total.first),
                if (categoryBudgets.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _CategoryBudgetsCard(budgets: categoryBudgets),
                ],
                const SizedBox(height: 4),
                const _IncomeGoalCard(),
                const SizedBox(height: 4),
                const _BalanceCard(),
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
    final tokens = AppTokens.of(context);
    final over = usageMinor > amountMinor;
    final progressColor =
        over ? tokens.danger : (usageMinor * 5 >= amountMinor * 4 ? tokens.warning : null);
    return LinearProgressIndicator(
      key: Key('budget-progress-$name'),
      value: amountMinor <= 0 ? 0 : min(usageMinor / amountMinor, 1.0),
      color: progressColor,
      backgroundColor: tokens.track,
    );
  }
}

/// 週期摘要（天數計算——每日可用/月底預測共用）。
class _PeriodInfo {
  _PeriodInfo._(this.start, this.endInclusive, this.today);

  factory _PeriodInfo.of(int startDay) {
    final now = Clock.now();
    final period = const BudgetPeriodService().periodOf(startDay, now);
    return _PeriodInfo._(
      DateTime.fromMillisecondsSinceEpoch(period.startMs),
      DateTime.fromMillisecondsSinceEpoch(period.endExclusiveMs)
          .subtract(const Duration(days: 1)),
      DateTime(now.year, now.month, now.day),
    );
  }

  final DateTime start;
  final DateTime endInclusive;
  final DateTime today;

  int get elapsedDays => today.difference(start).inDays + 1; // 含今天
  int get remainingDays => endInclusive.difference(today).inDays + 1; // 含今天
  int get totalDays => endInclusive.difference(start).inDays + 1;

  /// 標題短版（雛型：10/1~10/31）。
  String get displayShort => '${start.month}/${start.day}~${endInclusive.month}/${endInclusive.day}';
}

/// 進度色（<80% 主色、≥80% 橙、≥100% 紅——AC-05）。
Color _pctColor(BuildContext context, double pct) {
  final tokens = AppTokens.of(context);
  if (pct >= 100) return tokens.danger;
  if (pct >= 80) return tokens.warning;
  return Theme.of(context).colorScheme.primary;
}

/// 總預算卡（FR-B2/B3）：摘要行「剩餘 · 每日可用 · 月底預測（含預扣）」。
class _TotalBudgetCard extends ConsumerWidget {
  const _TotalBudgetCard({required this.budget});

  final BudgetRow budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final evaluator = BudgetEvaluator(db);
    final usage = evaluator.totalUsageMinor() ?? 0;
    final amount = budget.amountMinor;
    final info = _PeriodInfo.of(budget.periodStartDay);
    final pct = amount <= 0 ? 0.0 : usage * 100 / amount;
    final remaining = max(amount - usage, 0);
    // 每日可用（FR-B3）＝剩餘 ÷ 剩餘天數（含今天）。
    final dailyAvailable =
        info.remainingDays <= 0 ? 0 : remaining ~/ info.remainingDays;
    // 月底預測（含預扣）＝已用 ÷ 經過天數 × 全月天數。
    final forecast = info.elapsedDays <= 0
        ? 0
        : (usage / info.elapsedDays * info.totalDays).round();
    final fmt = NumberFormat('#,###');

    return Card(
      key: const Key('budget-total-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '總預算（週期 ${info.displayShort}）',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                Text('${pct.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _pctColor(context, pct),
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmt.format(usage),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('/ ${fmt.format(amount)}',
                      style: Theme.of(context).textTheme.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BudgetProgressBar(
              name: '總預算',
              usageMinor: usage,
              amountMinor: amount,
            ),
            const SizedBox(height: 8),
            Text(
              '剩餘 ${fmt.format(remaining)} · '
              '每日可用 ${fmt.format(dailyAvailable)} · '
              '月底預測 ${fmt.format(forecast)}（含預扣）',
              key: const Key('budget-total-summary'),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分類預算卡（單卡多項——雛型 bitem 版式）。
class _CategoryBudgetsCard extends ConsumerWidget {
  const _CategoryBudgetsCard({required this.budgets});

  final List<BudgetRow> budgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final evaluator = BudgetEvaluator(db);
    final fmt = NumberFormat('#,###');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('分類預算',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 4),
            for (final b in budgets)
              _CategoryItem(
                name: db.categoryName(b.categoryId!) ?? '分類預算',
                usage: evaluator.categoryUsage(b.categoryId!),
                amountMinor: b.amountMinor,
                periodStartDay: b.periodStartDay,
                fmt: fmt,
              ),
          ],
        ),
      ),
    );
  }
}

/// 分類預算項（雛型 bitem）：百分比色／用量/額度／預扣標籤／日均／進度條。
class _CategoryItem extends ConsumerWidget {
  const _CategoryItem({
    required this.name,
    required this.usage,
    required this.amountMinor,
    required this.periodStartDay,
    required this.fmt,
  });

  final String name;
  final CategoryUsage? usage;
  final int amountMinor;
  final int periodStartDay;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = usage;
    final total = u?.totalMinor ?? 0;
    final pending = u?.pendingMinor ?? 0;
    final pct = amountMinor <= 0 ? 0.0 : total * 100 / amountMinor;
    final info = _PeriodInfo.of(periodStartDay);
    // 日均（雛型語意）＝已用 ÷ 經過天數。
    final dailyAvg =
        info.elapsedDays <= 0 ? 0 : total ~/ info.elapsedDays;
    final over = total > amountMinor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600))),
              Text('${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _pctColor(context, pct),
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text('${fmt.format(total)} / ${fmt.format(amountMinor)}',
                  style: Theme.of(context).textTheme.bodySmall),
              if (pending > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('預扣 ${fmt.format(pending)}',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
              const Spacer(),
              Text(over ? '超支 ${fmt.format(total - amountMinor)}' : '日均 ${fmt.format(dailyAvg)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: over
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 6),
          BudgetProgressBar(name: name, usageMinor: total, amountMinor: amountMinor),
        ],
      ),
    );
  }
}

/// 收入目標卡（FR-B6）：達標率 badge（>100% 不封頂）＋已入帳/目標。
class _IncomeGoalCard extends ConsumerWidget {
  const _IncomeGoalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final status = BudgetEvaluator(db).incomeGoalStatus();
    if (status == null) {
      return const SizedBox.shrink();
    }
    final pct = status.ratePercent;
    return Card(
      key: const Key('budget-income-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('收入目標',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: status.achieved
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.7)
                        : Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.achieved ? '已達成 $pct%' : '進行中 $pct%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: status.achieved
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(NumberFormat('#,###').format(status.achievedMinor),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: status.achieved
                                ? Theme.of(context).colorScheme.primary
                                : null)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('/ 目標 ${NumberFormat('#,###').format(status.goalMinor)}',
                      style: Theme.of(context).textTheme.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BudgetProgressBar(
              name: '收入目標',
              usageMinor: status.achievedMinor,
              amountMinor: status.goalMinor,
            ),
          ],
        ),
      ),
    );
  }
}

/// 本月結餘卡（FR-B7）：預計（目標−總預算）／實際（含預扣）兩行並列。
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final evaluator = BudgetEvaluator(db);
    final income = MonthlyStatsService(db).incomeMinorThisMonth();
    final expense = MonthlyStatsService(db).expenseMinorThisMonth();
    final totalBudget = db
        .allBudgets()
        .where((b) => b.categoryId == null)
        .map((b) => b.amountMinor)
        .fold(0, (a, b) => a + b);
    final goal = evaluator.incomeGoalStatus()?.goalMinor;
    final projected = goal == null ? null : goal - totalBudget;
    final actual = income - expense;
    final fmt = NumberFormat('#,###');

    Widget row(String label, String value, Color? color) => Row(
          children: [
            Expanded(
                child: Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.outline))),
            Text(value,
                key: Key('balance-$label'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color, fontWeight: FontWeight.w700)),
          ],
        );

    return Card(
      key: const Key('budget-balance-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月結餘',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 8),
            if (projected != null)
              row('預計（目標−總預算）', fmt.format(projected),
                  projected >= 0 ? Theme.of(context).colorScheme.primary : null),
            const SizedBox(height: 6),
            row('實際（含預扣）', fmt.format(actual),
                actual >= 0 ? Theme.of(context).colorScheme.primary : null),
          ],
        ),
      ),
    );
  }
}
