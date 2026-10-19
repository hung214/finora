import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/version.dart';
import '../../../domain/services/balance_calculator.dart';
import '../../screens/demo/demo_gallery_page.dart';

/// 總覽頁（M1 精簡）：帳戶與衍生餘額（SDD 原則 2：餘額一律由交易重算）。
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider);
    final txs = ref.watch(ledgerProvider).map(txEntity).toList();
    const calc = BalanceCalculator();

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
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(row.name),
                trailing: Text(
                  // F02-FE S2：餘額千分位顯示（10,400）。
                  '餘額 ${NumberFormat('#,###').format(calc.assetBalance(account: accountEntity(row), txs: txs))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
