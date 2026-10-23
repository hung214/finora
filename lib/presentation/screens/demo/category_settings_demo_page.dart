import 'package:flutter/material.dart';

import 'demo_shared.dart';

/// 分類設定 Demo（對映 specs/plan/ui/09-category-settings.html；FR-B1）。
/// 分類可自訂圖示/顏色/排序（拖曳）、一層子分類；內建分類可隱藏不可刪除。
class CategorySettingsDemoContent extends StatelessWidget {
  const CategorySettingsDemoContent({super.key});

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
                Text('分類管理',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: t.text)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: DemoTheme.teal,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('＋ 新增',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              children: const [
                _Tab(label: '支出', on: true),
                _Tab(label: '收入'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text('☰ 拖曳排序 · 快記快捷格依使用頻率排序（FR-Q1）',
                style: TextStyle(fontSize: 11, color: t.faint)),
          ),
          const _CatTile(
              icon: Icons.ramen_dining,
              color: Color(0xFFFFD8A8),
              name: '餐飲食品',
              sub: '子分類 2：咖啡、手搖',
              system: false),
          // 展開態（v3）：子類別列**無圖示**（PM 2026-10-24：圖示跟隨主類別）。
          const _SubRow(name: '咖啡'),
          const _SubRow(name: '手搖'),
          const _CatTile(
              icon: Icons.shopping_basket_outlined,
              color: Color(0xFFB2F2BB),
              name: '服飾美容',
              sub: null,
              system: false),
          const _CatTile(
              icon: Icons.subway_outlined,
              color: Color(0xFFA5D8FF),
              name: '交通運輸',
              sub: null,
              system: false),
          const _CatTile(
              icon: Icons.home_outlined,
              color: Color(0xFFFFC9C9),
              name: '居住',
              sub: '子分類 1：房租',
              system: false),
          const _CatTile(
              icon: Icons.movie_outlined,
              color: Color(0xFFD0BFFF),
              name: '娛樂',
              sub: null,
              system: false),
          const _CatTile(
              icon: Icons.medical_services_outlined,
              color: Color(0xFFFFC9C9),
              name: '醫療',
              sub: null,
              system: false),
          const _CatTile(
              icon: Icons.menu_book_outlined,
              color: Color(0xFFFFF3BF),
              name: '教育',
              sub: null,
              system: false),
          const _CatTile(
              icon: Icons.more_horiz,
              color: Color(0xFFDEE2E6),
              name: '其他',
              sub: null,
              system: true),
          const SizedBox(height: 12),
          DemoCard(
            title: '收入分類（切換「收入」分頁）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('一般收入 · 獎金 · 投資 · 其他',
                    style: TextStyle(fontSize: 13, color: t.text)),
                const SizedBox(height: 6),
                const _Note('收入分類獨立管理（FR-B1）'),
              ],
            ),
          ),
          DemoCard(
            title: '規則（FR-B1）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Note('① 一層子分類（例：餐飲食品 → 咖啡）'),
                const _Note('② 內建分類可隱藏、不可刪除（is_system）'),
                const _Note('③ 已有交易之分類刪除 → 提示轉移或保留歷史'),
                const _Note('④ 圖示／顏色／排序皆可自訂；異動隨雲端同步'),
                const _Note('⑤ 子類別**無圖示**——圖示一律跟隨主類別（PM 2026-10-24）'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, this.on = false});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: on ? DemoTheme.teal : t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? DemoTheme.teal : t.line),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: on ? FontWeight.w700 : FontWeight.normal,
              color: on ? Colors.white : t.sub)),
    );
  }
}

/// 展開態之子類別列（PM 2026-10-24）：結構縮排、**無圖示**。
class _SubRow extends StatelessWidget {
  const _SubRow({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 42, right: 16, top: 2, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
      ),
      child: Row(children: [
        Icon(Icons.subdirectory_arrow_right, size: 16, color: t.faint),
        const SizedBox(width: 6),
        Text(name, style: TextStyle(fontSize: 13, color: t.text)),
        const Spacer(),
        Text('✏️ 🗑 ☰', style: TextStyle(fontSize: 12, color: t.faint)),
      ]),
    );
  }
}

class _CatTile extends StatelessWidget {
  const _CatTile({
    required this.icon,
    required this.color,
    required this.name,
    required this.sub,
    required this.system,
  });

  final IconData icon;
  final Color color;
  final String name;
  final String? sub;
  final bool system;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: const Color(0xFF343A40)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.text)),
                  if (system) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: t.track,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('內建',
                          style: TextStyle(fontSize: 10, color: t.faint)),
                    ),
                  ],
                ]),
                if (sub != null)
                  Text(sub!, style: TextStyle(fontSize: 11, color: t.faint)),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, size: 17, color: t.faint),
          const SizedBox(width: 10),
          Icon(Icons.drag_indicator, size: 19, color: t.faint),
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
