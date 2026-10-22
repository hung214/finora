import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/appearance/theme_mode_state.dart';
import '../core/version.dart';
import 'screens/lock/lock_gate.dart';
import 'screens/main_shell_page.dart';
import 'theme/app_theme.dart';

/// M1 主殼 App（真實介面）。
///
/// 視窗標題帶版本號（PM 要求：軟體內可見版本；main.dart 以
/// --dart-define=APP_VERSION 注入，本機顯示 dev）。
/// 測試以 `UncontrolledProviderScope(overrides: [dbProvider...])` 包裹注入。
/// 主題：M7 UI 統整——buildAppTheme 唯一入口；**themeMode 由
/// themeModeProvider 控制（FR-O1：跟隨系統/淺色/深色——設定→外觀）**。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: appVersion == 'dev' ? 'LedgerSync' : 'LedgerSync v$appVersion',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      home: const LockGate(child: MainShellPage()),
    );
  }
}
