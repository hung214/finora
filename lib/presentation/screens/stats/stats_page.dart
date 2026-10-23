import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../application/reports/report_service.dart';
import '../../theme/app_theme.dart';

/// 統計頁（FR-R2 呈現面；**v2 PM 2026-10-24 對齊 11-stats 雛型**）。
///
/// - **月份列 ◀ 2026/10 ▾ ▶**（有資料月份，降冪；預設最新）。
/// - **三卡**：支出（紅）／收入（綠）／淨額（收−支）。
/// - 分類占比甜甜圈（fl_chart）＋**色點圖例**（`{名稱} {pct}%`，0.1% 四捨五入）
///   ＋合計（千分位）——**既有數值文字全數保留**（F10-FE 斷言不動）。
/// - 月趨勢長條圖（有資料月份升冪）＋`{m}月 {總計}` 明細列。
/// - 訂閱 ledgerProvider 即時刷新（AC-02）。
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  (int, int)? _selected; // (year, month)；null = 最新有資料月份

  /// 月份位移（◀▶；跨年）。
  void _shiftMonth(int delta) {
    final cur = _selected ?? _latest();
    if (cur == null) return;
    final d = DateTime(cur.$1, cur.$2 + delta);
    setState(() => _selected = (d.year, d.month));
  }

  (int, int)? _latest() {
    final db = ref.read(dbProvider);
    final months = db
        .allTransactions()
        .where((t) => t.deletedAt == null)
        .map((t) {
          final d = DateTime.fromMillisecondsSinceEpoch(t.occurredAt);
          return (d.year, d.month);
        })
        .toSet()
        .toList()
      ..sort((a, b) =>
          a.$1 == b.$1 ? b.$2.compareTo(a.$2) : b.$1.compareTo(a.$1));
    return months.isEmpty ? null : months.first;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ledgerProvider); // 交易變化即時刷新
    final db = ref.watch(dbProvider);
    final expenseTxs = db
        .allTransactions()
        .where((t) => t.deletedAt == null && t.kind == 'expense')
        .toList();
    final incomeTxs = db
        .allTransactions()
        .where((t) => t.deletedAt == null && t.kind == 'income')
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
    final tokens = AppTokens.of(context);

    // 月趨勢（僅列出有資料月份，升冪）。
    final trend = <(int, int), int>{};
    for (final t in expenseTxs) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.occurredAt);
      trend[(d.year, d.month)] = (trend[(d.year, d.month)] ?? 0) + t.amountMinor;
    }
    final trendKeys = trend.keys.toList()
      ..sort((a, b) => a.$1.compareTo(b.$1) != 0
          ? a.$1.compareTo(b.$1)
          : a.$2.compareTo(b.$2));

    final report = selected == null
        ? null
        : ReportService(db).aggregate(selected.$1, selected.$2);

    // 收入合計／淨額（選定月份）。
    int incomeTotal = 0;
    if (selected != null) {
      for (final t in incomeTxs) {
        final d = DateTime.fromMillisecondsSinceEpoch(t.occurredAt);
        if (d.year == selected.$1 && d.month == selected.$2) {
          incomeTotal += t.amountMinor;
        }
      }
    }
    final expenseTotal = report?.totalMinor ?? 0;
    final net = incomeTotal - expenseTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('統計')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 月份列（PM 2026-10-24）：◀ 2026/10 ▾ ▶。
          Row(children: [
            IconButton(
              key: const Key('stats-month-prev'),
              tooltip: '上個月',
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
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
                  child: Text(selected == null
                      ? '選擇月份'
                      : '${selected.$1}/${selected.$2.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
            IconButton(
              key: const Key('stats-month-next'),
              tooltip: '下個月',
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 8),
          if (report != null) ...[
            // 三卡：支出／收入／淨額（11-stats 雛型）。
            Row(children: [
              _SummaryCard(
                  label: '支出',
                  value: '-${fmt.format(expenseTotal)}',
                  color: tokens.danger),
              const SizedBox(width: 8),
              _SummaryCard(
                  label: '收入',
                  value: '+${fmt.format(incomeTotal)}',
                  color: tokens.success),
              const SizedBox(width: 8),
              _SummaryCard(
                  label: '淨額',
                  value: '${net < 0 ? '-' : ''}${fmt.format(net.abs())}',
                  color: net < 0 ? tokens.danger : tokens.success),
            ]),
            const SizedBox(height: 12),
            if (report.shares.any((s) => s.amountMinor > 0))
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('分類占比',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _DonutChart(report: report, fmt: fmt),
                    ),
                    const SizedBox(height: 8),
                    // 色點圖例（名稱 % 金額）——色板與甜甜圈一致。
                    for (final (i, share) in report.shares
                        .where((s) => s.amountMinor > 0)
                        .indexed)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: _palette(context)[i % 7],
                              borderRadius: BorderRadius.circular(3)),
                        ),
                        title: Text('${share.name} ${share.percentText}%'),
                        trailing: Text(fmt.format(share.amountMinor)),
                      ),
                  ],
                ),
              )
          ] else
            // 空狀態（M7 UI 統整——無資料月份引導）。
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.query_stats_outlined,
                      size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 8),
                  const Text('尚無資料——記一筆後這裡會出現統計'),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text('月趨勢', style: Theme.of(context).textTheme.labelLarge),
          if (trendKeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 150,
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

/// 白卡（11-stats 雛型）。
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

/// 三卡之一（支出／收入／淨額）。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 4),
          FittedBox(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color))),
        ]),
      ),
    );
  }
}

/// 占比色板（甜甜圈與圖例共用；深淺色自動適配）。
List<Color> _palette(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    scheme.primaryContainer,
    scheme.tertiaryContainer,
    scheme.secondaryContainer,
    scheme.error,
  ];
}

/// 分類占比甜甜圈（fl_chart PieChart；色板取自 ColorScheme——深淺色自動適配）。
class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.report, required this.fmt});

  final ReportAggregate report;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = _palette(context);
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
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
                strokeWidth: 1)),
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
                  width: 18,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
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
