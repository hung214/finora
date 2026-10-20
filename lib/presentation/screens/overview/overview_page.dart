import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/budgets/budget_evaluator.dart';
import '../../../application/providers.dart';
import '../../../core/version.dart';
import '../../../domain/services/balance_calculator.dart';
import '../../screens/budget/budget_page.dart';
import '../../screens/credit_card/credit_card_page.dart';
import '../../screens/demo/demo_gallery_page.dart';

/// 總覽頁（M1 精簡）：帳戶餘額＋收入目標卡＋預算進度（SDD 原則 2：衍生值重算）。
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider);
    final txs = ref.watch(ledgerProvider).map(txEntity).toList();
    const calc = BalanceCalculator();
    final db = ref.watch(dbProvider);
    final evaluator = BudgetEvaluator(db);
    final goal = evaluator.incomeGoalStatus();
    final fmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: const Text('總覽'),
        actions: [
          IconButton(
            tooltip: 'UI Demo（設計參考）',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DemoGalleryPage()),
            ),
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final row in accounts)
            Card(
              child: ListTile(
                onTap: row.type == 'credit'
                    ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) =>
                              CreditCardPage(cardAccountId: row.id),
                        ))
                    : null,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(row.name),
                trailing: Text(
                  // F02-FE S2：餘額千分位顯示（10,400）。
                  '餘額 ${NumberFormat('#,###').format(calc.assetBalance(account: accountEntity(row), txs: txs))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          // 收入目標卡（FR-B6；S5.4 達標率不封頂；未設定顯示引導）。
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: goal == null
                  ? const Text('收入目標 未設定')
                  : Text(goal.achieved
                      ? '已達成 ${goal.ratePercent}%'
                      : '進行中 ${goal.ratePercent}%'),
              subtitle: goal == null
                  ? null
                  : Text(
                      '${fmt.format(goal.achievedMinor)} / 目標 ${fmt.format(goal.goalMinor)}'),
            ),
          ),
          // 預算進度（FR-B4 呈現；<80% 主色、≥80% 橙、≥100% 紅——AC-05）。
          for (final b in db.allBudgets())
            if (b.categoryId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: BudgetProgressBar(
                  name: db.categoryName(b.categoryId!) ?? '分類預算',
                  usageMinor:
                      evaluator.categoryUsage(b.categoryId!)?.totalMinor ?? 0,
                  amountMinor: b.amountMinor,
                ),
              ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'LedgerSync v$appVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
