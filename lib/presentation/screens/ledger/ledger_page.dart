import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../data/sqlite/app_database.dart';
import 'recent_deletions_page.dart';

/// 明細頁（M1）：未刪除交易降冪列表；儲存/復原/刪除後即時刷新（AC-02）。
class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(ledgerProvider);
    final accountById = {
      for (final a in ref.watch(activeAccountsProvider)) a.id: a,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('明細'),
        actions: [
          // 「最近刪除」入口（F02 S2.5-2；M1 無設定頁——整體屬 F07，dsl §3.3）。
          IconButton(
            key: const Key('ledger-recent-deletions'),
            tooltip: '最近刪除',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RecentDeletionsPage()),
            ),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: txs.isEmpty
          ? const Center(child: Text('尚無交易——點右下角快記第一筆'))
          : ListView.builder(
              itemCount: txs.length,
              itemBuilder: (_, i) => TxTile(
                tx: txs[i],
                accountName: accountById[txs[i].accountId]?.name ?? '',
                toAccount: txs[i].toAccountId == null
                    ? null
                    : accountById[txs[i].toAccountId!],
                onDelete: () => _confirmDelete(context, ref, txs[i]),
              ),
            ),
    );
  }

  /// 刪除確認（F02 S2.5）：bottom sheet——軟刪除（30 天內可還原）。
  void _confirmDelete(BuildContext context, WidgetRef ref, TxRow tx) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('刪除這筆交易？'),
              subtitle: Text('30 天內可於「最近刪除」還原'),
            ),
            FilledButton(
              key: const Key('tx-delete'),
              onPressed: () {
                ref.read(deleteTransactionProvider).execute(tx.id);
                ref.invalidate(ledgerProvider);
                ref.invalidate(recentDeletionsProvider);
                Navigator.of(sheetCtx).pop();
              },
              child: const Text('刪除'),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 交易列（BDD：明細頁即時顯示該 N 筆 → 金額文字計數）。
///
/// 轉帳樣式（F02 S2.3-5）：swap 圖示（非支出圖示）＋「轉帳」標籤＋路由副標，
/// 金額無正負號（轉帳不計收支）；目標為電子票證 → 顯示「儲值」（F02 S2.4）。
class TxTile extends StatelessWidget {
  const TxTile({
    super.key,
    required this.tx,
    required this.accountName,
    this.toAccount,
    this.onDelete,
  });

  final TxRow tx;
  final String accountName;
  final AccountRow? toAccount;
  final VoidCallback? onDelete;

  String get _title {
    switch (tx.kind) {
      case 'transfer':
        return toAccount?.type == 'ewallet' ? '儲值' : '轉帳';
      case 'income':
        return tx.merchant ?? '收入';
      default:
        return tx.merchant ?? '支出';
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(tx.occurredAt);
    if (tx.kind == 'transfer') {
      return ListTile(
        onTap: onDelete,
        leading: const Icon(Icons.swap_horiz), // 轉帳樣式（非支出圖示）
        title: Text(_title),
        subtitle: Text(
          '$accountName → ${toAccount?.name ?? ''} · '
          '${DateFormat('yyyy/MM/dd HH:mm').format(time)}',
        ),
        trailing: Text(
          '${tx.amountMinor}', // 轉帳不計收支：無正負號
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    return ListTile(
      onTap: onDelete,
      title: Text(tx.merchant ?? (tx.kind == 'income' ? '收入' : '支出')),
      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(time)),
      trailing: Text(
        tx.kind == 'income' ? '+${tx.amountMinor}' : '-${tx.amountMinor}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
