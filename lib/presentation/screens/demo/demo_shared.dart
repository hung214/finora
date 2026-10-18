import 'package:flutter/material.dart';

/// UI Demo 共用元件（靜態展示用；正式元件於 M1 起 F01~F10 實作）。
/// 對映雛型：specs/plan/ui/*.html。
/// 版權注意：Demo 資料皆為虛構（無真實商標）；圖示使用 Flutter Material Icons（Apache-2.0）。

class DemoTheme {
  const DemoTheme({
    required this.dark,
    required this.bg,
    required this.card,
    required this.text,
    required this.sub,
    required this.faint,
    required this.line,
    required this.track,
  });

  final bool dark;
  final Color bg;
  final Color card;
  final Color text;
  final Color sub;
  final Color faint;
  final Color line;
  final Color track;

  // 品牌色（深淺色共用）
  static const teal = Color(0xFF0B7A75);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFD64545);
  static const green = Color(0xFF0B7A75);

  factory DemoTheme.light() => const DemoTheme(
        dark: false,
        bg: Color(0xFFF5F7F8),
        card: Colors.white,
        text: Color(0xFF1C2B2A),
        sub: Color(0xFF7D8B8A),
        faint: Color(0xFF98A5A4),
        line: Color(0xFFE3E7EA),
        track: Color(0xFFEDF1F2),
      );

  factory DemoTheme.dark() => const DemoTheme(
        dark: true,
        bg: Color(0xFF12191A),
        card: Color(0xFF1E2829),
        text: Color(0xFFE6EFEE),
        sub: Color(0xFFA7B5B3),
        faint: Color(0xFF7C8B89),
        line: Color(0xFF2B3637),
        track: Color(0xFF2B3637),
      );
}

/// 深色/淺色切換（FR-O1：深色/淺色/跟隨系統；Demo 以開關呈現）。
class DemoThemeScope extends InheritedWidget {
  const DemoThemeScope({super.key, required this.theme, required super.child});

  final DemoTheme theme;

  static DemoTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoThemeScope>()!.theme;

  @override
  bool updateShouldNotify(DemoThemeScope oldWidget) =>
      oldWidget.theme.dark != theme.dark;
}

/// Demo 頁外殼：寬螢幕（桌面）以 390x844 手機框呈現，窄螢幕全幅。
class DemoPageShell extends StatelessWidget {
  const DemoPageShell({
    super.key,
    required this.title,
    required this.spec,
    required this.child,
  });

  final String title;
  final String spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    final wide = MediaQuery.of(context).size.width > 560;
    final content = Container(
      color: t.bg,
      width: wide ? 390 : double.infinity,
      child: SingleChildScrollView(child: child),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('$title · UI Demo', style: const TextStyle(fontSize: 16)),
        actions: [
          Tooltip(
            message: '雛型：$spec',
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.description_outlined, size: 20),
            ),
          ),
        ],
      ),
      backgroundColor: wide ? (t.dark ? const Color(0xFF0C1011) : const Color(0xFFE8ECEF)) : t.bg,
      body: wide
          ? Center(
              child: Container(
                width: 390,
                height: 844,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1C1F22), width: 10),
                  borderRadius: BorderRadius.circular(40),
                ),
                clipBehavior: Clip.antiAlias,
                child: content,
              ),
            )
          : SafeArea(child: content),
    );
  }
}

class DemoCard extends StatelessWidget {
  const DemoCard({super.key, this.title, required this.child, this.trailing});
  final String? title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title!, style: TextStyle(fontSize: 12, color: t.sub)),
                ?trailing,
              ],
            ),
          if (title != null) const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class DemoBar extends StatelessWidget {
  const DemoBar({super.key, required this.ratio, this.color = DemoTheme.teal});
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: Stack(children: [
          Container(color: t.track),
          FractionallySizedBox(
            widthFactor: ratio.clamp(0, 1),
            child: Container(color: color),
          ),
        ]),
      ),
    );
  }
}

class DemoTxTile extends StatelessWidget {
  const DemoTxTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.hasAttachment = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final int amount;
  final bool hasAttachment;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    final debit = amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Stack(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.track,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: t.text),
            ),
            if (hasAttachment)
              const Positioned(
                right: -2,
                bottom: -2,
                child: Icon(Icons.photo_camera, size: 12, color: DemoTheme.teal),
              ),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        color: t.text,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: t.faint)),
              ],
            ),
          ),
          Text(
            debit ? '−${amount.abs()}' : '+$amount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: debit ? DemoTheme.red : DemoTheme.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部導覽（靜態；中央快記大鈕，SDD §8）。
class DemoBottomNav extends StatelessWidget {
  const DemoBottomNav({super.key, this.activeIndex = 0});
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    Widget item(IconData ic, String label, int i) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic,
                size: 20, color: i == activeIndex ? DemoTheme.teal : t.faint),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color:
                        i == activeIndex ? DemoTheme.teal : t.faint,
                    fontWeight:
                        i == activeIndex ? FontWeight.bold : FontWeight.normal)),
          ],
        );
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          item(Icons.home_outlined, '總覽', 0),
          item(Icons.receipt_long_outlined, '明細', 1),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: DemoTheme.teal,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x660B7A75), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
          item(Icons.track_changes_outlined, '預算', 3),
          item(Icons.settings_outlined, '設定', 4),
        ],
      ),
    );
  }
}
