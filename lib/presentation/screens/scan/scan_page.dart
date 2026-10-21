import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 掃描頁（FR-S6/S7）：狀態機——權限閘→掃描中（計數＋縮圖列）→完成掃描
/// →確認清單（ReviewPage）。相機預覽區為行動端 mobile_scanner 接線點
/// （SP-2b；M4 FE 情境以解析結果注入驗 UI 流程，dsl「影像回放注入」）。
class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      throw UnimplementedError('F03-FE 紅燈 stub：ScanPage');
}
