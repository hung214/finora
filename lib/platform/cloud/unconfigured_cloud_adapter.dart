import 'dart:typed_data';

import 'cloud_storage_adapter.dart';

/// 未設定雲端 adapter（憑證未就緒時之降級；不崩、不假裝成功）。
///
/// 用途：`main()` 於 `GoogleDriveAdapter.fromEnvironment()` 回 null（憑證未
/// 以 `--dart-define` 注入）時注入本實作——[isConfigured] 回 false，UI 顯示
/// 「雲端功能尚未設定」；任何雲端操作拋 [CloudUnavailableException]（呼叫端
/// 既有重試/錯誤處理語意不變，且不觸發同步）。
class UnconfiguredCloudAdapter implements CloudStorageAdapter {
  const UnconfiguredCloudAdapter();

  static const _message = '雲端功能尚未設定（Google 憑證未就緒）';

  @override
  Future<bool> isConfigured() async => false;

  @override
  Future<List<String>> list(String folder) async =>
      throw const CloudUnavailableException(_message);

  @override
  Future<void> upload(String path, Uint8List bytes) async =>
      throw const CloudUnavailableException(_message);

  @override
  Future<Uint8List?> download(String path) async =>
      throw const CloudUnavailableException(_message);

  @override
  Future<void> delete(String path) async =>
      throw const CloudUnavailableException(_message);
}
