import 'dart:io';
import 'dart:typed_data';

import '../../data/sqlite/app_database.dart';

/// 附件儲存服務（SDD §5.4 附件儲存——FR-S4）：
/// 原圖縮至最長邊 1600px → JPEG q70 → sha256 → 存 `blobs/{sha256}` →
/// 寫入 attachments 列（與 oplog 同一 DB transaction——attachments 屬
/// sync_entity，SDD §5.1 契約）。
///
/// 純 Dart `image` 套件壓縮：**跨平台位元組一致** → 同張照片各裝置壓縮後
/// sha256 相同 → 雲端 blobs/ 內容定址去重成立（SDD §5.5.6；techstack v0.3.7）。
class AttachmentStore {
  AttachmentStore(this._db, this._blobsDir);

  // ignore: unused_field —— 紅燈 stub：save 落地（S5 綠燈）後使用
  final AppDatabase _db;

  /// blobs 目錄（app 支援目錄下；測試注入暫存目錄）。
  // ignore: unused_field —— 紅燈 stub：save 落地（S5 綠燈）後使用
  final Directory _blobsDir;

  /// 壓縮最長邊上限（SDD §5.4）。
  static const int maxLongestEdge = 1600;

  /// JPEG 品質（SDD §5.4）。
  static const int jpegQuality = 70;

  /// 儲存附件：壓縮→定址→落盤→DB 列（含 oplog）。回傳落地資訊。
  StoredAttachment save({
    required List<int> imageBytes,
    required String transactionId,
    String? mime,
  }) => throw UnimplementedError('F03-BE 紅燈 stub：save');

  /// 壓縮核心（pure：bytes→bytes；harness 斷言尺寸用）。
  static Uint8List compress(List<int> imageBytes) =>
      throw UnimplementedError('F03-BE 紅燈 stub：compress');
}

/// 附件落地結果（S5 斷言：檔名=blobs/{sha256}、尺寸、關聯）。
class StoredAttachment {
  const StoredAttachment({
    required this.sha256,
    required this.byteSize,
    required this.longestEdge,
    required this.row,
  });

  /// 壓縮後內容之 sha256（檔名與 attachments.sha256 同源）。
  final String sha256;
  final int byteSize;
  final int longestEdge;
  final AttachmentRow row;
}
