import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 雲端與同步設定頁（FR-Y7/Y11；SDD §8 IA「設定同步」——07-prototype）：
/// 連結授權（帳號授權式——**無同步密碼**）／立即同步（同步中…→已同步 N 筆）
/// ／待同步計數／上次同步時間／衝突檢視入口／從雲端還原（新裝置）。
class SettingsSyncPage extends ConsumerWidget {
  const SettingsSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      throw UnimplementedError('F07-FE 紅燈 stub：SettingsSyncPage');
}
