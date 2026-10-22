import 'package:flutter/material.dart';

/// 快速記帳 Demo（對映 specs/plan/ui/03-quick-entry.html；固定深色設計）。
/// 呈現：智慧預填 + 大鍵盤 + 「每筆確認」對話框（FR-Q2/Q3/Q4/Q5）。
class QuickEntryDemoContent extends StatelessWidget {
  const QuickEntryDemoContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12312F),
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 880,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('✕ 離開', style: TextStyle(color: Color(0xFF9FD4D0), fontSize: 13)),
                      _TimePill(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Column(children: [
                    Text('1,240',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2)),
                    SizedBox(height: 4),
                    Text('帳戶：現金（Sticky）',
                        style: TextStyle(fontSize: 16, color: Color(0xFF9FD4D0))),
                    SizedBox(height: 8),
                    Text('本次已記 3 筆',
                        style: TextStyle(fontSize: 13, color: Color(0xFFF5C86B))),
                  ]),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _Cat(icon: Icons.ramen_dining, label: '餐飲食品'),
                      _Cat(icon: Icons.shopping_basket, label: '服飾美容', on: true),
                      _Cat(icon: Icons.subway, label: '交通運輸'),
                      _Cat(icon: Icons.home_outlined, label: '居住'),
                      _Cat(icon: Icons.movie_outlined, label: '娛樂'),
                      _Cat(icon: Icons.medical_services_outlined, label: '醫療'),
                      _Cat(icon: Icons.menu_book_outlined, label: '教育'),
                      _Cat(icon: Icons.more_horiz, label: '其他'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: const [
                    _Field(label: '帳戶', value: '現金', flex: 1),
                    SizedBox(width: 8),
                    _Field(label: '商家（Sticky）', value: '陽光超商', flex: 1),
                  ]),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _Field(label: '備註／標籤（選填）', value: '早餐', flex: 2),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5C86B), borderRadius: BorderRadius.circular(16)),
                  child: const Text('儲 存',
                      style: TextStyle(
                          color: Color(0xFF12312F),
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (final row in [
                        ['7', '8', '9'],
                        ['4', '5', '6'],
                        ['1', '2', '3'],
                        ['.', '0', '⌫'],
                      ])
                        Row(
                          children: [
                            for (final k in row)
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0x14FFFFFF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(k,
                                      style: const TextStyle(
                                          color: Color(0xFFE7F2F1), fontSize: 20)),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // 每筆確認對話框（FR-Q2：繼續／復原上一筆／完成）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Text('繼續記下一筆？',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C2B2A))),
                    SizedBox(height: 4),
                    Text('本次已記 3 筆 · 交易已入庫（<300ms）',
                        style: TextStyle(fontSize: 12, color: Color(0xFF98A5A4))),
                    SizedBox(height: 14),
                    _DialogBtn(label: '繼續（保留帳戶/分類/商家）', primary: true),
                    SizedBox(height: 8),
                    _DialogBtn(label: '↩ 復原上一筆'),
                    SizedBox(height: 8),
                    _DialogBtn(label: '完成（回到明細）', danger: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('⏱ 10/18 09:12（可點改）',
          style: TextStyle(color: Color(0xFF9FD4D0), fontSize: 13)),
    );
  }
}

class _Cat extends StatelessWidget {
  const _Cat({required this.icon, required this.label, this.on = false});
  final IconData icon;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: on ? const Color(0xFFF5C86B) : const Color(0x14FFFFFF),
        border: Border.all(color: on ? const Color(0xFFF5C86B) : const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: on ? const Color(0xFF12312F) : const Color(0xFFD9E8E7)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: on ? const Color(0xFF12312F) : const Color(0xFFD9E8E7),
                fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.flex = 1});
  final String label;
  final String value;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          border: Border.all(color: const Color(0x24FFFFFF)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9FD4D0))),
            Text(value,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE7F2F1))),
          ],
        ),
      ),
    );
  }
}

class _DialogBtn extends StatelessWidget {
  const _DialogBtn({required this.label, this.primary = false, this.danger = false});
  final String label;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary
            ? const Color(0xFF0B7A75)
            : (danger ? Colors.white : const Color(0xFFEDF1F2)),
        border: danger ? Border.all(color: const Color(0xFFF3C9C9)) : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primary ? Colors.white : (danger ? const Color(0xFFD64545) : const Color(0xFF1C2B2A)))),
    );
  }
}
