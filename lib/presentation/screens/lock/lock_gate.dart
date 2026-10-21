import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/lock/lock_fe_state.dart';
import 'lock_screen.dart';

/// 鎖定閘（FR-X1/AC-09；SDD §7.2）——AppShell 與頁面之間的覆蓋層：
/// ①lifecycle 觀察（背景記錄＋返回門檻判定）②鎖定時全遮蔽渲染 LockScreen
/// （底層不可透視——隱私破口＝Critical）。
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      final lock = ref.read(appLockControllerProvider);
      if (state == AppLifecycleState.paused) {
        lock.onBackground();
      } else if (state == AppLifecycleState.resumed) {
        if (lock.shouldLockOnResume()) {
          ref.read(lockOverlayProvider.notifier).show();
        }
      }
    } on UnimplementedError {
      // 未接線環境（無鎖定設定）——略。
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(lockOverlayProvider);
    return Stack(
      children: [
        widget.child,
        if (locked) const LockScreen(),
      ],
    );
  }
}
