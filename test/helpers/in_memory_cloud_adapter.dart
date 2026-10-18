import 'dart:typed_data';

import 'package:ledger_sync/platform/cloud/cloud_storage_adapter.dart';

/// T-H3：in-memory 雲端 adapter（SDD §6 之 fake 實作）。
///
/// - 檔案存於記憶體 Map，提供故障注入（[failing]）與呼叫計數，供同步測試使用。
/// - 架構核心：**每個裝置各自持有本地 SQLite**，裝置間僅經此 adapter 交換檔案。
class InMemoryCloudAdapter implements CloudStorageAdapter {
  InMemoryCloudAdapter({this.configured = true});

  bool configured;

  /// 故障注入：true 時所有讀寫拋 [CloudUnavailableException]（重試測試用）。
  bool failing = false;

  int uploadCount = 0;
  int downloadCount = 0;

  final Map<String, Uint8List> _files = {};

  void reset() {
    _files.clear();
    uploadCount = 0;
    downloadCount = 0;
    failing = false;
  }

  void _guard() {
    if (failing) {
      throw const CloudUnavailableException('模擬網路/服務不可用');
    }
  }

  @override
  Future<bool> isConfigured() async => configured;

  @override
  Future<List<String>> list(String folder) async {
    _guard();
    if (folder.isEmpty) {
      // 根目錄：回傳全部檔案（遞迴，完整相對路徑）。
      final all = _files.keys.toList()..sort();
      return all;
    }
    final prefix = '$folder/';
    return _files.keys
        .where((p) => p.startsWith(prefix) && p != folder)
        .map((p) => p.substring(prefix.length))
        .where((p) => !p.contains('/')) // 僅直接子層
        .toList()
      ..sort();
  }

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    _guard();
    uploadCount++;
    _files[path] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> download(String path) async {
    _guard();
    downloadCount++;
    final f = _files[path];
    return f == null ? null : Uint8List.fromList(f);
  }

  @override
  Future<void> delete(String path) async {
    _guard();
    _files.remove(path);
  }
}
