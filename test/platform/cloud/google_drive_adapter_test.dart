import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/platform/cloud/drive/drive_api.dart';
import 'package:ledger_sync/platform/cloud/drive/google_drive_adapter.dart';
import 'package:ledger_sync/platform/cloud/unconfigured_cloud_adapter.dart';

/// 記憶體 DriveApi（模擬 Drive REST v3 之檔案/資料夾語意——含「允許同名」）。
class _FakeDriveApi implements DriveApi {
  final Map<String, DriveEntry> _entries = {
    'root': const DriveEntry(id: 'root', name: '', parentId: '', isFolder: true),
  };
  final Map<String, Uint8List> _content = {};
  int _seq = 0;
  bool authorized = true;

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<String> rootFolderId() async => 'root';

  @override
  Future<String> createFolder(String name, String parentId) async {
    final id = 'f${++_seq}';
    _entries[id] =
        DriveEntry(id: id, name: name, parentId: parentId, isFolder: true);
    return id;
  }

  @override
  Future<List<DriveEntry>> listChildren(String parentId) async =>
      _entries.values.where((e) => e.parentId == parentId).toList();

  @override
  Future<String> uploadFile({
    required String name,
    required String parentId,
    required Uint8List bytes,
    String? fileId,
  }) async {
    var id = fileId;
    if (id == null) {
      id = 'x${++_seq}';
      _entries[id] =
          DriveEntry(id: id, name: name, parentId: parentId, isFolder: false);
    }
    _content[id] = bytes;
    return id;
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) async => _content[fileId];

  @override
  Future<void> deleteFile(String fileId) async {
    _entries.remove(fileId);
    _content.remove(fileId);
    // 資料夾連動（Drive 檔案層級；測試語意足夠）。
    final children = _entries.values.where((e) => e.parentId == fileId).toList();
    for (final c in children) {
      await deleteFile(c.id);
    }
  }
}

void main() {
  group('GoogleDriveAdapter（Drive v3 appDataFolder 語意）', () {
    late _FakeDriveApi api;
    late GoogleDriveAdapter adapter;

    setUp(() {
      api = _FakeDriveApi();
      adapter = GoogleDriveAdapter(api);
    });

    test('isConfigured 反映授權狀態', () async {
      expect(await adapter.isConfigured(), isTrue);
      api.authorized = false;
      expect(await adapter.isConfigured(), isFalse);
    });

    test('upload 自動 lazy 建立資料夾鏈；download 取回內容', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      await adapter.upload('ops/d-A/00000001.opbundle', bytes);
      // 資料夾實體已建立（ops、ops/d-A）。
      final rootChildren = await api.listChildren('root');
      expect(rootChildren.where((e) => e.isFolder).map((e) => e.name), contains('ops'));
      // 內容可下載。
      expect(await adapter.download('ops/d-A/00000001.opbundle'), bytes);
    });

    test('同名 upload 為冪等覆寫（不產生重複檔）', () async {
      await adapter.upload('vault.json', Uint8List.fromList([1]));
      await adapter.upload('vault.json', Uint8List.fromList([9, 9]));
      final files = (await api.listChildren('root')).where((e) => !e.isFolder);
      expect(files.length, 1, reason: '同名覆寫（Drive 允同名多檔——須找到→覆寫）');
      expect(await adapter.download('vault.json'), Uint8List.fromList([9, 9]));
    });

    test('list("") 遞迴回傳全部檔案完整相對路徑（排序）', () async {
      await adapter.upload('vault.json', Uint8List.fromList([1]));
      await adapter.upload('devices/d-A.json', Uint8List.fromList([2]));
      await adapter.upload('ops/d-A/00000001.opbundle', Uint8List.fromList([3]));
      await adapter.upload('backups/20261022_090000.db', Uint8List.fromList([4]));
      expect(await adapter.list(''), [
        'backups/20261022_090000.db',
        'devices/d-A.json',
        'ops/d-A/00000001.opbundle',
        'vault.json',
      ]);
    });

    test('list(folder) 回直接子檔名（不含子資料夾、不含深層路徑）', () async {
      await adapter.upload('ops/d-A/00000001.opbundle', Uint8List.fromList([1]));
      await adapter.upload('ops/d-B/00000001.opbundle', Uint8List.fromList([2]));
      // ops/ 的直接子項是資料夾（d-A/d-B）——檔案 0 筆。
      expect(await adapter.list('ops'), isEmpty);
      // ops/d-A 的直接子檔名。
      expect(await adapter.list('ops/d-A'), ['00000001.opbundle']);
    });

    test('download 不存在回 null（附件懶下載語意）', () async {
      expect(await adapter.download('blobs/deadbeef'), isNull);
    });

    test('delete 後不再可下載；不存在為 no-op', () async {
      await adapter.upload('vault.json', Uint8List.fromList([1]));
      await adapter.delete('vault.json');
      expect(await adapter.download('vault.json'), isNull);
      await adapter.delete('vault.json'); // no-op（不拋）
    });

    test('清空語意：list("") 逐檔 delete → 根清單空（WipeService 契約）', () async {
      await adapter.upload('vault.json', Uint8List.fromList([1]));
      await adapter.upload('devices/d-A.json', Uint8List.fromList([2]));
      await adapter.upload('blobs/abc', Uint8List.fromList([3]));
      for (final path in await adapter.list('')) {
        await adapter.delete(path);
      }
      expect(await adapter.list(''), isEmpty);
    });
  });

  group('UnconfiguredCloudAdapter（憑證未就緒降級）', () {
    test('isConfigured=false；操作拋 CloudUnavailableException（不崩）', () async {
      const adapter = UnconfiguredCloudAdapter();
      expect(await adapter.isConfigured(), isFalse);
      expect(() => adapter.list(''), throwsA(isA<Exception>()));
      expect(() => adapter.upload('x', Uint8List(0)), throwsA(isA<Exception>()));
      expect(() => adapter.download('x'), throwsA(isA<Exception>()));
      expect(() => adapter.delete('x'), throwsA(isA<Exception>()));
    });
  });
}
