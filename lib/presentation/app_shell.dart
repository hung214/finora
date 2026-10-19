import 'package:flutter/material.dart';

import 'screens/main_shell_page.dart';

/// M1 主殼 App（真實介面；M0 之 LedgerSyncApp 骨架入口暫保留於 main.dart，
/// production 切換待 path_provider 決策——見 session.md 阻塞清單）。
///
/// 測試以 `UncontrolledProviderScope(overrides: [dbProvider...])` 包裹注入。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

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
      home: const MainShellPage(),
    );
  }
}
