import 'package:flutter/material.dart';

import 'demo_shared.dart';

/// 預算與收入目標 Demo（對映 specs/plan/ui/04-budget.html；資料 = 虛構劇例）。
class BudgetDemoContent extends StatelessWidget {
  const BudgetDemoContent({super.key});

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('預算',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: t.text)),
                Icon(Icons.add_circle_outline, color: t.sub),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DemoCard(
            title: '總預算（週期 10/1~10/31）',
            trailing: const Text('64%',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: DemoTheme.amber)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('19,230',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1C2B2A))),
                    const SizedBox(width: 6),
                    Text('/ 30,000', style: TextStyle(fontSize: 12, color: t.sub)),
                  ],
                ),
                const SizedBox(height: 8),
                const DemoBar(ratio: 0.64),
                const SizedBox(height: 8),
                _Note('剩餘 10,770 · 每日可用 1,196 · 月底預測 26,090（含預扣）'),
              ],
            ),
          ),
          DemoCard(
            title: '分類預算',
            child: Column(
              children: [
                _BudgetItem(
                    name: '餐飲食品',
                    usage: '7,000 / 8,000',
                    pct: '87.5%',
                    pctColor: DemoTheme.amber,
                    ratio: 0.875,
                    barColor: DemoTheme.amber,
                    extra: '預扣 1,000',
                    daily: '日均 388'),
                _BudgetItem(
                    name: '服飾美容',
                    usage: '5,260 / 5,000',
                    pct: '105%',
                    pctColor: DemoTheme.red,
                    ratio: 1,
                    barColor: DemoTheme.red,
                    extra: '超支 260',
                    daily: null),
                _BudgetItem(
                    name: '交通運輸',
                    usage: '840 / 2,000',
                    pct: '42%',
                    pctColor: DemoTheme.green,
                    ratio: 0.42,
                    barColor: DemoTheme.teal,
                    extra: null,
                    daily: '日均 67'),
              ],
            ),
          ),
          DemoCard(
            title: '收入目標（10 月）',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F3), borderRadius: BorderRadius.circular(10)),
              child: const Text('已達成 103%',
                  style: TextStyle(
                      fontSize: 11, color: DemoTheme.teal, fontWeight: FontWeight.w600)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('62,000',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: DemoTheme.green)),
                    const SizedBox(width: 6),
                    Text('/ 目標 60,000',
                        style: TextStyle(fontSize: 12, color: t.sub)),
                  ],
                ),
                const SizedBox(height: 8),
                const DemoBar(ratio: 1),
              ],
            ),
          ),
          DemoCard(
            title: '本月結餘',
            child: Column(children: [
              const _AmountRow('預計（目標 − 總預算）', '30,000', DemoTheme.green),
              const SizedBox(height: 8),
              _AmountRow('實際（含預扣）', '49,660', null),
            ]),
          ),
        ],
      ),
    );
  }
}

class _BudgetItem extends StatelessWidget {
  const _BudgetItem({
    required this.name,
    required this.usage,
    required this.pct,
    required this.pctColor,
    required this.ratio,
    required this.barColor,
    required this.extra,
    required this.daily,
  });

  final String name;
  final String usage;
  final String pct;
  final Color pctColor;
  final double ratio;
  final Color barColor;
  final String? extra;
  final String? daily;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
              Text(pct,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: pctColor)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(usage, style: TextStyle(fontSize: 12, color: t.sub)),
                if (extra != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEDE4FF),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(extra!,
                        style:
                            const TextStyle(fontSize: 10, color: Color(0xFF6D4FC4))),
                  ),
                ],
              ]),
              if (daily != null)
                Text(daily!, style: TextStyle(fontSize: 11, color: t.faint)),
            ],
          ),
          const SizedBox(height: 8),
          DemoBar(ratio: ratio, color: barColor),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, [this.color]);
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: t.sub)),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color ?? t.text)),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Text(text, style: TextStyle(fontSize: 11, color: t.faint));
  }
}
