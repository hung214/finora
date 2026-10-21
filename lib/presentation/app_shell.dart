import 'package:flutter/material.dart';

import '../core/version.dart';
import 'screens/lock/lock_gate.dart';
import 'screens/main_shell_page.dart';
import 'theme/app_theme.dart';

/// M1 主殼 App（真實介面）。
///
/// 視窗標題帶版本號（PM 要求：軟體內可見版本；main.dart 以
/// --dart-define=APP_VERSION 注入，本機顯示 dev）。
/// 測試以 `UncontrolledProviderScope(overrides: [dbProvider...])` 包裹注入。
/// 主題：M7 UI 統整——buildAppTheme 唯一入口（tokens 定稿見 app_theme.dart）。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appVersion == 'dev' ? 'LedgerSync' : 'LedgerSync v$appVersion',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const LockGate(child: MainShellPage()),
    );
  }
}
