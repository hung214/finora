import 'package:flutter/material.dart';

import 'demo_shared.dart';

/// 設定與同步 Demo（對映 specs/plan/ui/07-settings-sync.html；含外觀選擇 FR-O1）。
class SettingsDemoContent extends StatelessWidget {
  const SettingsDemoContent({super.key});

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
            child: Text('設定',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: t.text)),
          ),
          const SizedBox(height: 14),
          DemoCard(
            title: '外觀（FR-O1）',
            child: Row(
              children: [
                _Seg(label: '跟隨系統', on: true),
                const SizedBox(width: 6),
                const _Seg(label: '淺色'),
                const SizedBox(width: 6),
                const _Seg(label: '深色'),
              ],
            ),
          ),
          DemoCard(
            title: '雲端與同步（FR-Y）',
            child: Column(
              children: [
                _Item(
                    title: 'Google 帳號',
                    sub: 'demo.user@example.com（已連結 · Drive appDataFolder）',
                    right: const Text('✓ 連結中',
                        style: TextStyle(color: DemoTheme.teal, fontWeight: FontWeight.w700, fontSize: 13))),
                _Item(
                    title: '上次同步',
                    sub: null,
                    right: Text('09:00 · 待同步 3 筆',
                        style: TextStyle(fontSize: 13, color: t.faint))),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: DemoTheme.teal, borderRadius: BorderRadius.circular(12)),
                  child: const Text('⟳ 立即同步',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                const _Item(title: '同步模式（三選一）', sub: null, right: null),
                const _Radio(label: '每筆自動同步（記一筆傳一筆）'),
                const _Radio(label: '節能批次（預設：記帳後 30 秒＋閒置 15 分）', on: true),
                const _Radio(label: '僅手動（啟動同步＋按鈕）'),
                const _Item(
                    title: '啟動同步（必做）',
                    sub: '開啟 App／回前台時自動執行一次',
                    right: Text('固定開啟',
                        style: TextStyle(color: DemoTheme.teal, fontSize: 12, fontWeight: FontWeight.w700))),
                _Item(
                    title: '附件僅 Wi-Fi 同步',
                    sub: null,
                    right: const _Switch(on: true)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(10)),
            child: const Text(
              '🔐 建議為此帳號開啟兩步驟驗證（FR-Y7：同步以帳號授權，無同步密碼）',
              style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.5),
            ),
          ),
          DemoCard(
            title: '安全（FR-X）',
            child: Column(
              children: [
                const _Item(
                    title: 'App 鎖',
                    sub: null,
                    right: Text('Face ID ＋ PIN ✓',
                        style: TextStyle(
                            color: DemoTheme.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w700))),
                _Item(
                    title: '背景鎖定門檻',
                    sub: null,
                    right: Text('30 秒 ▾', style: TextStyle(fontSize: 13, color: t.faint))),
                _Item(title: '隱私遮蔽', sub: null, right: const _Switch(on: false)),
              ],
            ),
          ),
          DemoCard(
            title: '通知（§8 通知總表，逐類開關）',
            child: Column(
              children: const [
                _Item(title: '預算警示（80%/100%/超支）', sub: null, right: _Switch(on: true)),
                _Item(title: '繳款提醒（前 3 天＋當天）', sub: null, right: _Switch(on: true)),
                _Item(title: '定期交易到期', sub: null, right: _Switch(on: true)),
                _Item(title: '同步衝突／備份失敗', sub: null, right: _Switch(on: true)),
                _Item(title: '收入目標達成', sub: null, right: _Switch(on: false)),
              ],
            ),
          ),
          DemoCard(
            title: '資料（FR-O3）',
            child: Column(
              children: [
                _Item(
                    title: '最近刪除（30 天內可還原）',
                    sub: null,
                    right: Text('2 筆 ›', style: TextStyle(fontSize: 13, color: t.faint))),
                _Item(
                    title: '匯出／匯入備份檔',
                    sub: '可選檔案密碼；跨平台遷移',
                    right: Text('›', style: TextStyle(fontSize: 13, color: t.faint))),
                const _Item(
                    title: '清空資料',
                    sub: null,
                    right: Text('›', style: TextStyle(fontSize: 13, color: DemoTheme.red))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, this.on = false});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: on ? DemoTheme.teal : t.track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: on ? FontWeight.w700 : FontWeight.normal,
              color: on ? Colors.white : t.sub)),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.title, required this.sub, required this.right});
  final String title;
  final String? sub;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 14, color: t.text)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub!, style: TextStyle(fontSize: 11, color: t.faint)),
                  ),
              ],
            ),
          ),
          ?right,
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: on ? DemoTheme.teal : const Color(0xFFCBD5D4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.label, this.on = false});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = DemoThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: on ? DemoTheme.teal : const Color(0xFFC9D2D4),
                  width: on ? 5 : 2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: t.text)),
          ),
        ],
      ),
    );
  }
}
