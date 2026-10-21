import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../application/reports/report_service.dart';

/// 統計頁（FR-R2 呈現面；M2 新增分頁）。
///
/// - 月份選擇器（有資料月份，降冪；預設最新）。
/// - 分類占比甜甜圈（fl_chart——D10）＋占比列表（`{名稱} {pct}%`，0.1%
///   四捨五入）＋合計（千分位）。
/// - 月趨勢長條圖（有資料月份升冪）＋`{m}月 {總計}` 明細列——**既有數值
///   文字全數保留**（F10-FE 斷言不動；S10.1 自動化以數值文字斷言）。
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
          : b.$2.compareTo(b.$2));
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
            if (report.shares.any((s) => s.amountMinor > 0))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 200,
                  child: _DonutChart(report: report, fmt: fmt),
                ),
              ),
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
          if (trendKeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 140,
                child: _TrendBarChart(trendKeys: trendKeys, trend: trend),
              ),
            ),
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

/// 分類占比甜甜圈（fl_chart PieChart；色板取自 ColorScheme——深淺色自動適配）。
class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.report, required this.fmt});

  final ReportAggregate report;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
      scheme.error,
    ];
    final shares = report.shares.where((s) => s.amountMinor > 0).toList();
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 56,
            sections: [
              for (final (i, share) in shares.indexed)
                PieChartSectionData(
                  value: share.amountMinor.toDouble(),
                  color: palette[i % palette.length],
                  radius: 26,
                  title: '${share.percentText}%',
                  titleStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
            ],
          ),
        ),
        // 中心合計（與頁首文字同值——圖表輔助呈現）。
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('合計', style: Theme.of(context).textTheme.labelSmall),
            Text(fmt.format(report.totalMinor),
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}

/// 月趨勢長條圖（fl_chart BarChart；觸摸顯示金額 tooltip）。
class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.trendKeys, required this.trend});

  final List<(int, int)> trendKeys;
  final Map<(int, int), int> trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
              BarTooltipItem(fmtTrend(rod.toY), TextStyle(color: scheme.onSurface)),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= trendKeys.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${trendKeys[i].$2}月',
                      style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (final (i, k) in trendKeys.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: trend[k]!.toDouble(),
                  color: scheme.primary,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String fmtTrend(double v) {
    final n = v.round();
    return NumberFormat('#,###').format(n);
  }
}
