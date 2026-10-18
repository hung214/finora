import 'package:flutter/material.dart';

/// LedgerSync — 本地優先記帳 App（入口）。
/// UI 資訊架構依 SDD §8；畫面雛型見 specs/plan/ui/；正式分頁架構於 M1（F01）實作。
void main() => runApp(const LedgerSyncApp());

class LedgerSyncApp extends StatelessWidget {
  const LedgerSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LedgerSync',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B7A75),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B7A75),
        brightness: Brightness.dark,
      ),
      home: const BootstrapPage(),
    );
  }
}

/// M0 骨架頁：確認四平台可啟動；M1 起由 F01（總覽/明細/快記/預算/設定）取代。
class BootstrapPage extends StatelessWidget {
  const BootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LedgerSync')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('📒 LedgerSync', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('骨架就緒（M0）— 開發計畫見 specs/plan/tasks.md'),
          ],
        ),
      ),
    );
  }
}
