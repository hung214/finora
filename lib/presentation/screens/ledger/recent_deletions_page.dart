import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/clock.dart';

/// 「最近刪除」頁（FR-T3：軟刪除 30 天保留期，acceptance F02 S2.5）。
///
/// - 窗口以**曆日**計（刪除日＋30 曆日為可還原期；保留期屆滿不顯示，
///   實體清除由 TombstonePurgeService 排程——F07 接線）。
/// - 還原（S2.5-3）：墓標清除＋明細即時回復（RestoreTransactionUseCase）。
/// - 入口：明細 AppBar（M1 無設定頁——整體設定屬 F07，dsl §3.3 註記）。
class RecentDeletionsPage extends ConsumerWidget {
  const RecentDeletionsPage({super.key});

  /// 軟刪除保留天數（FR-T3；與 TombstonePurgeService 對齊）。
  static const int retentionDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tombstones = ref.watch(recentDeletionsProvider);
    final visible =
        tombstones.where((t) => remainingDays(t.deletedAt!) > 0).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('最近刪除')),
      body: visible.isEmpty
          ? const Center(child: Text('沒有最近刪除的交易'))
          : ListView.builder(
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final t = visible[i];
                final remaining = remainingDays(t.deletedAt!);
                return ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(
                      '${t.kind == 'income' ? '收入' : '支出'} ${t.amountMinor}'),
                  subtitle: Text('剩餘 $remaining 天'),
                  trailing: TextButton(
                    key: Key('recent-delete-restore-${t.id}'),
                    onPressed: () {
                      ref.read(restoreTransactionProvider).execute(t.id);
                      ref.invalidate(ledgerProvider);
                      ref.invalidate(recentDeletionsProvider);
                    },
                    child: const Text('還原'),
                  ),
                );
              },
            ),
    );
  }

  /// 剩餘可還原天數（曆日）：刪除日＋30 − 今天；0 即屆滿（不顯示）。
  static int remainingDays(int deletedAtMs) {
    final deleted = DateTime.fromMillisecondsSinceEpoch(deletedAtMs);
    final now = Clock.now();
    final elapsedDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(deleted.year, deleted.month, deleted.day))
            .inDays;
    return retentionDays - elapsedDays;
  }
}
