import 'package:flutter/material.dart';

import 'demo_shared.dart';

/// 明細畫面 Demo（對映 specs/plan/ui/02-ledger.html；資料 = 虛構劇例）。
class LedgerDemoContent extends StatelessWidget {
  const LedgerDemoContent({super.key});

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
                Text('明細',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: t.text)),
                const Row(children: [
                  Icon(Icons.filter_list, size: 20, color: Color(0xFF7D8B8A)),
                  SizedBox(width: 8),
                  _ScanButton(),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: const [
                _AcctChip(name: '現金', amount: '\$600', selected: true),
                SizedBox(width: 8),
                _AcctChip(name: '薪轉', amount: '\$45,000'),
                SizedBox(width: 8),
                _AcctChip(name: '示例卡', amount: '應付 8,000'),
                SizedBox(width: 8),
                _AcctChip(name: '票證卡', amount: '\$500'),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _PendingPill()),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              children: [
                _Chip(label: '全部', on: true),
                _Chip(label: '支出'),
                _Chip(label: '收入'),
                _Chip(label: '轉帳'),
                _Chip(label: '10 月 ▾'),
              ],
            ),
          ),
          const _DayHeader(label: '今天 10/18', subtotal: '小計 −315'),
          const DemoCard(
            child: Column(children: [
              DemoTxTile(
                  icon: Icons.shopping_basket_outlined,
                  title: '陽光超商',
                  subtitle: '09:12 · 現金 · 服飾美容 · 掃描入帳',
                  amount: -195,
                  hasAttachment: true),
              DemoTxTile(
                  icon: Icons.bakery_dining_outlined,
                  title: '晨光早餐店',
                  subtitle: '08:15 · 現金 · 餐飲食品',
                  amount: -120),
            ]),
          ),
          const _DayHeader(label: '昨天 10/17', subtotal: '小計 −4,735'),
          const DemoCard(
            child: Column(children: [
              DemoTxTile(
                  icon: Icons.credit_card,
                  title: '信用卡繳款',
                  subtitle: '20:10 · 薪轉 → 示例卡 · 已繳',
                  amount: -5000),
              DemoTxTile(
                  icon: Icons.swap_horiz,
                  title: '轉帳 現金→銀行',
                  subtitle: '12:00 · 轉帳',
                  amount: 400),
              DemoTxTile(
                  icon: Icons.subway_outlined,
                  title: '捷運',
                  subtitle: '票證卡 · 交通運輸',
                  amount: -35),
            ]),
          ),
          const _DayHeader(label: '10/15', subtotal: '小計 −5,000'),
          const DemoCard(
            child: Column(children: [
              DemoTxTile(
                  icon: Icons.laptop_mac,
                  title: '筆電（分期 1/6）',
                  subtitle: '示例卡 · 服飾美容 · 預扣',
                  amount: -5000),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration:
          BoxDecoration(color: DemoTheme.teal, borderRadius: BorderRadius.circular(10)),
      child: const Row(children: [
        Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
        SizedBox(width: 4),
        Text('掃描',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _AcctChip extends StatelessWidget {
  const _AcctChip({required this.name, required this.amount, this.selected = false});
  final String name;
  final String amount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? DemoTheme.teal : t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? DemoTheme.teal : t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: TextStyle(
                  fontSize: 10, color: selected ? Colors.white70 : t.faint)),
          const SizedBox(height: 2),
          Text(amount,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : t.text)),
        ],
      ),
    );
  }
}

class _PendingPill extends StatelessWidget {
  const _PendingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(12)),
      child: const Text('⏳ 待確認 1 筆（房租 15,000）— 點擊處理',
          style: TextStyle(
              fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.on = false});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: on ? DemoTheme.teal : t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? DemoTheme.teal : t.line),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: on ? Colors.white : t.sub)),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.subtotal});
  final String label;
  final String subtotal;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: t.text)),
          Text(subtotal, style: TextStyle(fontSize: 12, color: t.faint)),
        ],
      ),
    );
  }
}
