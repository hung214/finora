import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../application/reports/report_service.dart';

/// 統計頁（FR-R2 呈現面；M2 新增分頁）。
///
/// - 月份選擇器（有資料月份，降冪；預設最新）。
/// - 分類占比列表（`{名稱} {pct}%`，0.1% 四捨五入）＋合計（千分位）。
/// - 月趨勢（有資料月份升冪，`{m}月 {總計}`）——甜甜圈/長條視覺屬 UI 打磨，
///   自動化以數值文字呈現斷言（S10.1）。
/// - 訂閱 ledgerProvider 即時刷新（AC-02）。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  (int, int)? _selected; // (year, month)；null = 最新有資料月份

  @override
  Widget build(BuildContext context) {
    ref.watch(ledgerProvider); // 交易變化即時刷新
    final db = ref.watch(dbProvider);
    final expenseTxs = db
        .allTransactions()
        .where((t) => t.deletedAt == null && t.kind == 'expense')
        .toList();
    final months = expenseTxs
        .map((t) {
          final d = DateTime.fromMillisecondsSinceEpoch(t.occurredAt);
          return (d.year, d.month);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.$1.compareTo(a.$1) != 0
          ? b.$1.compareTo(a.$1)
          : b.$2.compareTo(a.$2));
    final selected = _selected ?? (months.isEmpty ? null : months.first);
    final fmt = NumberFormat('#,###');

    // 月趨勢（僅列出有資料月份，升冪）。
    final trend = <(int, int), int>{};
    for (final t in expenseTxs) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.occurredAt);
      trend[(d.year, d.month)] = (trend[(d.year, d.month)] ?? 0) + t.amountMinor;
    }
    final trendKeys = trend.keys.toList()..sort((a, b) => a.$1.compareTo(b.$1) != 0 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));

    final report =
        selected == null ? null : ReportService(db).aggregate(selected.$1, selected.$2);

    return Scaffold(
      appBar: AppBar(title: const Text('統計')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Text('期間', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 8),
              Expanded(
                child: PopupMenuButton<(int, int)>(
                  key: const Key('stats-month'),
                  tooltip: '選擇月份',
                  onSelected: (m) => setState(() => _selected = m),
                  itemBuilder: (_) => [
                    for (final m in months)
                      PopupMenuItem(value: m, child: Text('${m.$2}月')),
                  ],
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.arrow_drop_down),
                      isDense: true,
                    ),
                    child: Text(selected == null ? '選擇月份' : '${selected.$2}月'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report != null) ...[
            Text(
              '合計 ${fmt.format(report.totalMinor)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final share in report.shares)
              ListTile(
                dense: true,
                title: Text('${share.name} ${share.percentText}%'),
                trailing: Text(fmt.format(share.amountMinor)),
              ),
          ] else
            // 空狀態（M7 UI 統整——無資料月份引導）。
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('尚無資料——記一筆後這裡會出現統計'),
            ),
          const SizedBox(height: 12),
          Text('月趨勢', style: Theme.of(context).textTheme.labelLarge),
          for (final k in trendKeys)
            ListTile(
              dense: true,
              leading: const Icon(Icons.bar_chart),
              title: Text('${k.$2}月 ${fmt.format(trend[k]!)}'),
            ),
        ],
      ),
    );
  }
}
