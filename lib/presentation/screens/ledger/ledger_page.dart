import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../data/sqlite/app_database.dart';

/// 明細頁（M1）：未刪除交易降冪列表；儲存/復原後即時刷新（AC-02）。
class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(ledgerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('明細')),
      body: txs.isEmpty
          ? const Center(child: Text('尚無交易——點右下角快記第一筆'))
          : ListView.builder(
              itemCount: txs.length,
              itemBuilder: (_, i) => TxTile(tx: txs[i]),
            ),
    );
  }
}

/// 交易列（BDD：明細頁即時顯示該 N 筆 → find.byType(TxTile) 計數）。
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx});

  final TxRow tx;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(tx.occurredAt);
    return ListTile(
      title: Text(tx.merchant ?? '支出'),
      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(time)),
      trailing: Text(
        tx.kind == 'income' ? '+${tx.amountMinor}' : '-${tx.amountMinor}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
