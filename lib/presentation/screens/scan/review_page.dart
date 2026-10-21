import 'package:flutter/material.dart';

import '../../../application/scan/scan_state.dart';

/// 確認清單（FR-S4/S5）：逐張確認卡——總額一律人工檢視（FR-S4）、低信賴
/// 欄位高亮需「已確認」（FR-S5 0.7 門檻）、確認儲存（source=scan＋附件）
/// 後自動跳下一張（acceptance S3.3）。
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key, required this.items});

  /// 待確認清單（掃描結果暫存快照）。
  final List<ScannedItem> items;

  @override
  Widget build(BuildContext context) => throw UnimplementedError('F03-FE 紅燈 stub：ReviewPage');
}
