import 'dart:typed_data';

/// Google Drive 最小操作面（seam；SDD §6）。
///
/// **職責**：把 Drive REST v3 的檔案/資料夾操作收斂成 [GoogleDriveAdapter]
/// 所需的最小集合。真實實作（`googleapis` Drive v3 ＋ `googleapis_auth`）
/// 於**憑證就緒後**接線——見 `specs/plan/pm-actions.md` §1。
///
/// 之所以切成 seam：Drive 憑證/審核為外部相依（PM 動作），但 [GoogleDriveAdapter]
/// 的路徑映射／清單／覆寫語意**可完全以 fake 驗證**（見 test/platform/cloud/
/// google_drive_adapter_test.dart）——讓上線前只剩「換 DriveApi 實作」一步。
abstract interface class DriveApi {
  /// 是否已授權可用（token 有效）。
  Future<bool> isAuthorized();

  /// appDataFolder 根 id（Drive 的 `appDataFolder` 別名）。
  Future<String> rootFolderId();

  /// 於 [parentId] 底下以 [name] 建立資料夾，回傳其 id。
  Future<String> createFolder(String name, String parentId);

  /// 列出 [parentId] 直接子項（檔案＋資料夾）。
  Future<List<DriveEntry>> listChildren(String parentId);

  /// 上傳／覆寫檔案：[fileId] null＝新建；否則覆寫該檔內容。
  /// 回傳檔案 id。
  Future<String> uploadFile({
    required String name,
    required String parentId,
    required Uint8List bytes,
    String? fileId,
  });

  /// 下載檔案內容；不存在回 null。
  Future<Uint8List?> downloadFile(String fileId);

  /// 刪除檔案（Drive 檔案層級）。
  Future<void> deleteFile(String fileId);
}

/// Drive 項目（檔案或資料夾）最小表示。
class DriveEntry {
  const DriveEntry({
    required this.id,
    required this.name,
    required this.parentId,
    required this.isFolder,
  });

  final String id;
  final String name;
  final String parentId;
  final bool isFolder;
}
