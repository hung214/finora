import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 相簿/檔案匯入（FR-S6 桌面/無相機路徑）：檔案選擇→OCR→確認清單。
/// 匯入管線經 [importPipelineProvider] 注入（生產：平台層；測試：T-H6 回放）。
class ImportPage extends ConsumerWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      throw UnimplementedError('F03-FE 紅燈 stub：ImportPage');
}
