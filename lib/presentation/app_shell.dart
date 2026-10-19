import 'package:flutter/material.dart';

import '../core/version.dart';
import 'screens/main_shell_page.dart';

/// M1 主殼 App（真實介面）。
///
/// 視窗標題帶版本號（PM 要求：軟體內可見版本；main.dart 以
/// --dart-define=APP_VERSION 注入，本機顯示 dev）。
/// 測試以 `UncontrolledProviderScope(overrides: [dbProvider...])` 包裹注入。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appVersion == 'dev' ? 'LedgerSync' : 'LedgerSync v$appVersion',
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
