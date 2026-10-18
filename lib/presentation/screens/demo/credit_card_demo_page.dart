import 'package:flutter/material.dart';

import 'demo_shared.dart';

/// 信用卡與帳單 Demo（對映 specs/plan/ui/06-credit-card.html；資料 = 虛構劇例）。
class CreditCardDemoContent extends StatelessWidget {
  const CreditCardDemoContent({super.key});

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
                Text('示例卡',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: t.text)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: DemoTheme.teal,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('繳款',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B7A75), Color(0xFF064E4B)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('CREDIT CARD',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                    Icon(Icons.credit_card, color: Colors.white70),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('•••• •••• •••• 1234',
                    style: TextStyle(
                        fontSize: 18,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 10),
                const Text(
                  '結帳日：每月 5 號 ｜ 繳款日：結帳日＋15 天 ｜ 歸屬：當天算本期（FR-C2）\n扣款帳戶：薪轉 ｜ 額度：100,000（已用 8%）',
                  style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DemoCard(
            title: '本期應付（10/6~11/5，未結帳）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('8,000',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800, color: t.text)),
                    Text('3 筆預扣 + 5,000（本期新）',
                        style: TextStyle(fontSize: 12, color: t.faint)),
                  ],
                ),
                const SizedBox(height: 8),
                const _Note('⚠ 銀行帳戶餘額不受預扣影響（FR-C1）'),
              ],
            ),
          ),
          Row(children: [
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                  label: '未繳帳單', value: '0', valueColor: DemoTheme.green),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: _StatCard(
                  label: '未來已承諾（分期）', value: '25,000', sub: '筆電 5/6 期'),
            ),
            const SizedBox(width: 16),
          ]),
          const SizedBox(height: 12),
          DemoCard(
            title: '帳單歷史',
            child: Column(
              children: [
                _BillRow(
                    period: '9/6~10/5 期',
                    badge: '部分繳',
                    badgeColor: const Color(0xFFFFF1D6),
                    badgeText: const Color(0xFFB45309),
                    detail: '已繳 2,000 · 剩餘 3,000 · 10/20 繳款截止',
                    amount: '應繳 5,000',
                    amountColor: null),
                _BillRow(
                    period: '8/6~9/5 期',
                    badge: '已繳',
                    badgeColor: const Color(0xFFE6F4F3),
                    badgeText: DemoTheme.teal,
                    detail: '9/18 全額繳清（含退款負項 −1,000）',
                    amount: '4,000',
                    amountColor: DemoTheme.green),
                _BillRow(
                    period: '7/6~8/5 期',
                    badge: '逾期',
                    badgeColor: const Color(0xFFFBE4E4),
                    badgeText: DemoTheme.red,
                    detail: '8/20 截止未繳清（v1 不計息，持續顯示）',
                    amount: '3,120',
                    amountColor: DemoTheme.red),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, this.valueColor, this.sub});
  final String label;
  final String value;
  final Color? valueColor;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: t.sub)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? t.text)),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 10, color: t.faint)),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.period,
    required this.badge,
    required this.badgeColor,
    required this.badgeText,
    required this.detail,
    required this.amount,
    required this.amountColor,
  });

  final String period;
  final String badge;
  final Color badgeColor;
  final Color badgeText;
  final String detail;
  final String amount;
  final Color? amountColor;

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
              Text(period,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: badgeColor, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeText)),
                ),
                const SizedBox(width: 8),
                Text(amount,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: amountColor ?? t.text)),
              ]),
            ],
          ),
          const SizedBox(height: 3),
          Text(detail, style: TextStyle(fontSize: 11, color: t.faint)),
        ],
      ),
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
