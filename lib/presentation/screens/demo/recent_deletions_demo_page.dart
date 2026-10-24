import 'package:flutter/material.dart';

import 'demo_shared.dart';

/// 「最近刪除」DEMO（PM 2026-10-24：**新增**——對齊
/// `specs/plan/ui/12-recent-deletions.html`）。
/// 虛構劇例：3 筆軟刪除（餐飲 120／購物 1,280／咖啡 165）；剩餘 30／12／3 天。
class RecentDeletionsDemoContent extends StatelessWidget {
  const RecentDeletionsDemoContent({super.key});

  static const _rows = [
    ('🍜', '餐飲食品', '120', '10/18 09:12 · 剩餘 30 天'),
    ('🛒', '購物', '1,280', '10/06 20:05 · 剩餘 12 天'),
    ('☕', '咖啡', '165', '09/27 08:40 · 剩餘 3 天'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return DemoPageShell(
      title: '12 最近刪除',
      spec: 'specs/plan/ui/12-recent-deletions.html',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('最近刪除',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Icon(Icons.delete_sweep_outlined,
                    size: 22, color: DemoTheme.teal),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
                '🗓️ 交易刪除後可還原 30 天；逾期自動永久清除。「永久刪除」為立即清除、無法還原。',
                style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
          ),
          DemoCard(
            child: Column(children: [
              for (final (emoji, name, amount, sub) in _rows)
                _Row(emoji: emoji, name: name, amount: amount, sub: sub),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text('二次確認（永久刪除不可逆）',
                style: TextStyle(fontSize: 12, color: Color(0xFF7D8B8A))),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: t.dark ? const Color(0xFF22302F) : const Color(0xFFDDE4E6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('永久刪除？',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: t.text)),
                  const SizedBox(height: 8),
                  Text('此操作無法還原，刪除後不會出現在「最近刪除」。',
                      style: TextStyle(fontSize: 13, color: t.sub)),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('取消',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.sub)),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                          color: DemoTheme.red,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Text('永久刪除',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
                '① 每列＝主類別圖示＋分類名＋金額＋刪除時間／剩餘天數；動作 還原（teal）／永久刪除（紅）'
                '② AppBar 右上＝清空全部（僅有項目時顯示）③ 永久刪除＝實體刪除＋oplog 墓標保留（同步安全）'
                '④ 未刪除交易不出現於本頁；已清除者重複點＝無動作（冪等）',
                style: TextStyle(fontSize: 11, color: Color(0xFF98A5A4))),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.emoji,
      required this.name,
      required this.amount,
      required this.sub});
  final String emoji;
  final String name;
  final String amount;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: t.track, shape: BoxShape.circle),
          child: Text(emoji, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$emoji $name · 支出 $amount',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.text)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, color: t.faint)),
          ]),
        ),
        const Text('還原',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DemoTheme.teal)),
        const SizedBox(width: 8),
        const Text('永久刪除',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DemoTheme.red)),
      ]),
    );
  }
}
