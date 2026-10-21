import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';

/// App 鎖 UI 狀態（F08-FE；SDD §7.2）。

/// AppLockController（鎖定判定；生產由 main() override 或直接以此建構——
/// FE 測試以 controller override 注入凍結時鐘語意）。
final appLockControllerProvider =
    Provider<AppLockController>((ref) => throw UnimplementedError(
        'appLockControllerProvider 須於 main()/測試 override 注入'));

/// 鎖定覆蓋層顯示（MainShellPage lifecycle 判定後設定）。
final lockOverlayProvider =
    NotifierProvider<LockOverlayNotifier, bool>(LockOverlayNotifier.new);

class LockOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void dismiss() => state = false;
}

/// 生物辨識 seam（FR-X1；生產 local_auth——TR-8 回歸；測試 fake 成功/失敗）。
final biometricAuthProvider =
    Provider<Future<bool> Function()>((ref) => throw UnimplementedError(
        'biometricAuthProvider 須於 main()/測試 override 注入'));

/// 隱私遮蔽（FR-X3；總覽 👁 切換——金額 ●●●●）。
final privacyMaskedProvider =
    NotifierProvider<PrivacyMaskedNotifier, bool>(PrivacyMaskedNotifier.new);

class PrivacyMaskedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
