import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// T-H8：前端測試掛鉤（integration_test 用；M1 起 F01-FE 情境啟用）。
///
/// - [pumpBackground]：模擬 App 切背景 N 秒（App 鎖 F08：背景逾時鎖定 AC-09）。
/// - [pumpForeground]：返回前景。
/// - [pressShortcut]：桌面快捷鍵注入（Ctrl+N / Ctrl+Shift+S，FR-Q7/FR-S6）。
/// - [screenshot]：場景截圖（驗收報告附件）。
///
/// 說明：這些掛鉤需在 integration_test 的真機/模擬器環境執行（`flutter test
/// integration_test`），單元測試無法驗證；M1 FE 首跑時以 F01-S1.11 / F08 情境啟用。
library;

/// 模擬切背景 [duration] 後返回前景（驅動 AppLockController 判定）。
Future<void> pumpBackground(WidgetTester tester, Duration duration) async {
  // TODO(M1-F08): 透過 TestWidgetsFlutterBinding 生命周期事件模擬：
  //   binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  //   await tester.pump(duration);
  //   binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  //   await tester.pump();
  throw UnimplementedError('M1 FE 首跑時實作（T-H8）');
}

/// 桌面快捷鍵注入（以 Keyboard key event 模擬 Ctrl+N 等）。
Future<void> pressShortcut(WidgetTester tester, Set<LogicalKeyboardKey> keys) async {
  // TODO(M1-F01): await tester.sendKeyDownEvent(...) 組合鍵注入。
  throw UnimplementedError('M1 FE 首跑時實作（T-H8）');
}

/// 場景截圖（存至 build/demo_screenshots/{name}.png，供驗收報告）。
Future<void> screenshot(WidgetTester tester, String name) async {
  // TODO(M1): await expectLater(find.byType(MaterialApp), matchesGoldenFile(...))
  //           或 integration_test 的 takeScreenshot。
  throw UnimplementedError('M1 FE 首跑時實作（T-H8）');
}
