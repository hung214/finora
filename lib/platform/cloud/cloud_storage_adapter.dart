import 'dart:typed_data';

/// 雲端儲存抽象（SDD §6）：同步協議不感知後端差異（Google Drive / iCloud / 測試 fake）。
///
/// - [path] 為相對路徑（雲端 LedgerSync/ 資料夾內），例：
///   `devices/d-A1B2.json`、`ops/d-A1B2/00000001.opbundle`、`blobs/{sha256}.bin`。
/// - [upload] 語意為「暫存 → 原子改名」（SDD §5.5.3）。
/// - [download] 不存在回 null（附件懶下載）。
abstract interface class CloudStorageAdapter {
  /// 已登入且可用（iCloud 於 Android/Windows 恆為 false，UI 顯示說明）。
  Future<bool> isConfigured();

  /// 列出 [folder] 下的相對路徑（不含資料夾前綴；空字串 = 根）。
  Future<List<String>> list(String folder);

  Future<void> upload(String path, Uint8List bytes);

  /// 不存在回 null。
  Future<Uint8List?> download(String path);

  Future<void> delete(String path);
}

/// 雲端操作失敗（網路/授權/配額）；呼叫端依指數退避重試（SDD §9）。
class CloudUnavailableException implements Exception {
  const CloudUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'CloudUnavailableException: $message';
}
