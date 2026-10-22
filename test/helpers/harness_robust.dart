import 'package:flutter_test/flutter_test.dart';

/// FE harness 穩健化輔助（跨 feature 共用；DBG-007 教訓）。
///
/// **背景**：macOS 視窗非前景／被遮擋時 display link 暫停 → render tree 陳舊
/// → 裸 `tester.tap` 落空（症狀：無限動畫 spinner 永動、`pumpAndSettle` 逾時）。
/// 「聚焦除錯測試」證據：目標 widget 在樹上、`getRect` 正確，但
/// `hitTestOnBinding` 回**空路徑**＝frame 陳舊。
///
/// **對策**：[tapUntil] tap→pump；若 [until] 未成立（tap 未生效）→ 真實等待
/// 後重試。正常情況第一次即成立（**零額外延遲**）；僅失效時才等待。
///
/// 用法：
/// ```dart
/// await tapUntil(tester, find.byKey(const Key('oauth-approve')),
///     () => tester.any(find.text('連結成功')));
/// ```
Future<void> tapUntil(
  WidgetTester tester,
  Finder finder,
  bool Function() until, {
  int retries = 12,
}) async {
  for (var i = 0; i <= retries; i++) {
    if (tester.any(finder)) {
      await tester.tap(finder, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 150));
    if (until()) return;
    // frame 陳舊——讓 OS 有真實時間重新排程 frame 後重試。
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 150));
  }
  expect(until(), isTrue, reason: 'tap 未生效（重試 ${retries + 1} 次）：$finder');
}

/// 真實牆鐘等待＋pumpAndSettle——**僅用於雲端同步等非同步 IO 步驟**
/// （PM 2026-10-21 指示：其他步驟維持原速）。載入中／動畫中請改
/// [waitUntil]（bounded，避免 spinner 永動）。
Future<void> settleReal(WidgetTester tester,
    [Duration d = const Duration(seconds: 3)]) async {
  await Future<void>.delayed(d);
  await tester.pumpAndSettle();
}

/// bounded 等待條件成立（每 [step] 真實等待＋pump；上限 [maxTries]）——
/// 用於「等待非同步完成」且畫面可能有無限動畫（不可用 pumpAndSettle）之情境。
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() until, {
  int maxTries = 25,
  Duration step = const Duration(milliseconds: 200),
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (until()) return;
    await Future<void>.delayed(step);
    await tester.pump(const Duration(milliseconds: 100));
  }
}
