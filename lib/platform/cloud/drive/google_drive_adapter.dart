import 'dart:typed_data';

import '../cloud_storage_adapter.dart';
import 'drive_api.dart';

/// Google Drive 雲端 adapter（FR-Y7；Drive REST v3 ＋ appDataFolder；SDD §5.5.1）。
///
/// **佈局**（與 SyncCoordinator 契約一致，路徑為 LedgerSync/ 內相對路徑）：
/// - 根：`appDataFolder`（App 專屬隱藏資料夾——使用者不需管理；FR-Y7）
/// - `vault.json`／`devices/{id}.json`／`ops/{id}/{seq}.opbundle`
/// - `blobs/{sha256}`／`backups/{ts}.db`
/// 資料夾以 Drive folder 實體對應（`devices`／`ops`／`ops/{id}`／`blobs`／`backups`），
/// 首次使用時 lazy 建置（[list]／[upload] 需要時）。
///
/// **覆寫語意**（SDD §5.5.3）：同名檔案以「找到→覆寫內容」實現冪等覆蓋
/// （Drive 允許同名多檔——故不可直接新建）。
///
/// **環境切換**：憑證以 `--dart-define` 注入；未設定時 [fromEnvironment] 回 null，
/// `main()` 改以 [UnconfiguredCloudAdapter] 降級（UI 顯示未設定，不崩）。
class GoogleDriveAdapter implements CloudStorageAdapter {
  GoogleDriveAdapter(this._api);

  final DriveApi _api;

  /// 已授權可用（token 有效）。
  @override
  Future<bool> isConfigured() => _api.isAuthorized();

  /// 列出 [folder]：空字串＝**遞迴全部檔案**（完整相對路徑——Wipe/GC 用）；
  /// 具名資料夾＝**直接子檔名**（不含子資料夾；SyncCoordinator 契約）。
  @override
  Future<List<String>> list(String folder) async {
    final root = await _api.rootFolderId();
    if (folder.isEmpty) {
      final out = <String>[];
      await _walk(root, '', out);
      out.sort();
      return out;
    }
    final folderId = await _resolveFolder(root, folder);
    if (folderId == null) return const [];
    final children = await _api.listChildren(folderId);
    final names = children.where((e) => !e.isFolder).map((e) => e.name).toList()
      ..sort();
    return names;
  }

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    final root = await _api.rootFolderId();
    final segs = _segments(path);
    final parentId = await _ensureFolderPath(root, segs.sublist(0, segs.length - 1));
    final name = segs.last;
    final existing = (await _api.listChildren(parentId))
        .where((e) => !e.isFolder && e.name == name)
        .firstOrNull;
    await _api.uploadFile(
      name: name,
      parentId: parentId,
      bytes: bytes,
      fileId: existing?.id, // 同名→覆寫（冪等；Drive 允同名多檔）
    );
  }

  @override
  Future<Uint8List?> download(String path) async {
    final id = await _resolveFile(path);
    if (id == null) return null;
    return _api.downloadFile(id);
  }

  @override
  Future<void> delete(String path) async {
    final id = await _resolveFile(path);
    if (id != null) await _api.deleteFile(id);
  }

  // ── 內部：路徑映射 ───────────────────────────────────────

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  /// 遞迴收集 [folderId] 底下所有檔案之完整相對路徑。
  Future<void> _walk(String folderId, String prefix, List<String> out) async {
    for (final e in await _api.listChildren(folderId)) {
      final path = prefix.isEmpty ? e.name : '$prefix/${e.name}';
      if (e.isFolder) {
        await _walk(e.id, path, out);
      } else {
        out.add(path);
      }
    }
  }

  /// 取得（不建立）資料夾 id；不存在回 null。
  Future<String?> _resolveFolder(String root, String folder) async {
    var current = root;
    for (final seg in _segments(folder)) {
      final children = await _api.listChildren(current);
      final next = children
          .where((e) => e.isFolder && e.name == seg)
          .firstOrNull;
      if (next == null) return null;
      current = next.id;
    }
    return current;
  }

  /// 取得（不建立）檔案 id；不存在回 null。
  Future<String?> _resolveFile(String path) async {
    final root = await _api.rootFolderId();
    final segs = _segments(path);
    if (segs.isEmpty) return null;
    final parentId = await _resolveFolder(root, segs.sublist(0, segs.length - 1).join('/'));
    if (parentId == null) return null;
    final file = (await _api.listChildren(parentId))
        .where((e) => !e.isFolder && e.name == segs.last)
        .firstOrNull;
    return file?.id;
  }

  /// 確保資料夾鏈存在，回傳最深層 id（lazy 建置）。
  Future<String> _ensureFolderPath(String root, List<String> segs) async {
    var current = root;
    for (final seg in segs) {
      final children = await _api.listChildren(current);
      final next = children
          .where((e) => e.isFolder && e.name == seg)
          .firstOrNull;
      current = next?.id ?? await _api.createFolder(seg, current);
    }
    return current;
  }

  /// 以 `--dart-define` 憑證建構（未設定回 null → main() 降級）。
  ///
  /// 需要的 define（見 specs/plan/pm-actions.md §2）：
  /// `GOOGLE_OAUTH_CLIENT_ID`／`GOOGLE_OAUTH_CLIENT_SECRET`（桌面 loopback；
  /// 行動改用 google_sign_in 之 client id）。實際 Drive API 實作待接線。
  static GoogleDriveAdapter? fromEnvironment() {
    const clientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');
    if (clientId.isEmpty) return null;
    // TODO(憑證就緒): 以 googleapis/googleapis_auth 建 DriveApi 後回傳
    //   GoogleDriveAdapter(GoogleApisDriveApi(clientId, clientSecret))。
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
