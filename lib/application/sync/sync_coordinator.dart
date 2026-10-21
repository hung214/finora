import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';
import '../../platform/cloud/cloud_storage_adapter.dart';

/// 同步協調器（SDD §5.5.3 SyncCoordinator——檔案式 OpLog 合併）。
///
/// 佈局（§5.5.1）：vault.json（首次建置）＋devices/{id}.json（每裝置
/// manifest：last_seq/ack_seq）＋ops/{id}/{seq:08d}.opbundle＋blobs/{sha256}
/// ＋backups/{ts}.db。M5 無加密（.enc 僅 P2 選用，FR-Y7）。
///
/// 流程：pull（每 peer 下載 cursor+1..last_seq 套用）→ push（未打包 oplog
/// → bundle(seq=last_seq+1) → 上傳＋manifest）；冪等（同 seq 覆蓋＋cursor 跳過）。
class SyncCoordinator {
  SyncCoordinator(
    this._db,
    this._cloud, {
    required this.deviceId,
    this.onConflictEvent,
  });

  // ignore: unused_field —— 紅燈 stub：pull/push 實作（F07 綠燈）後使用
  final AppDatabase _db;
  // ignore: unused_field —— 紅燈 stub：pull/push 實作（F07 綠燈）後使用
  final CloudStorageAdapter _cloud;
  final String deviceId;

  /// 網路型態（FR-Y11 附件分流：wifi | mobile；生產由 connectivity 判定，
  /// M5 為可變欄位 seam——情境切換）。
  String networkType = 'wifi';

  /// 衝突通知鉤子（N-8；測試 spy／正式通知）。
  final void Function(SyncEventRow event)? onConflictEvent;

  // ignore: unused_field —— 紅燈 stub：pull/push 實作（F07 綠燈）後使用
  static const _vaultPath = 'vault.json';
  String _manifestPath(String id) => 'devices/$id.json';
  // ignore: unused_element —— 紅燈 stub：pull/push 實作（F07 綠燈）後使用
  String _bundlePath(String id, int seq) => 'ops/$id/${seq.toString().padLeft(8, '0')}.opbundle';

  /// 同步回合（情境觸發點）：pull 套用 peers → push 未打包。
  Future<void> sync() => throw UnimplementedError('F07-BE 紅燈 stub：sync');

  /// pull：各 peer 自 cursor+1 下載 bundle 依序套用（BundleApplier）。
  Future<void> pull() => throw UnimplementedError('F07-BE 紅燈 stub：pull');

  /// push：未打包 oplog → bundle 上傳＋manifest 更新＋附件分流。
  Future<void> push() => throw UnimplementedError('F07-BE 紅燈 stub：push');

  /// 新裝置 bootstrap（FR-Y2/AC-08）：最新備份匯入→全量 replay→寫 manifest
  /// （last_seq=0——尚未 push）。
  Future<void> bootstrap() => throw UnimplementedError('F07-BE 紅燈 stub：bootstrap');

  // ── 雲端檔案 JSON 輔助（harness/模組共用） ────────────────

  Future<Map<String, Object?>?> readJson(String path) async {
    final bytes = await _cloud.download(path);
    if (bytes == null) return null;
    return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  }

  Future<void> writeJson(String path, Map<String, Object?> json) =>
      _cloud.upload(path, utf8.encode(jsonEncode(json)));

  /// 本機 manifest（無則 last_seq=0）。
  Future<int> lastSeqOf(String id) async {
    final m = await readJson(_manifestPath(id));
    return (m?['last_seq'] as int?) ?? 0;
  }
}

/// bundle 上傳之 ops 載荷組裝（未打包 oplog → OpBundle JSON）。
Map<String, Object?> buildBundle(String deviceId, int seq, List<OplogRow> ops) => {
      'device_id': deviceId,
      'seq': seq,
      'schema_ver': 4,
      'ops': [
        for (final o in ops)
          {
            'e': o.entity,
            'id': o.entityId,
            'hlc': o.hlc,
            'row': o.payload == null ? null : jsonDecode(o.payload!) as Map<String, Object?>,
          },
      ],
    };

/// 新 oplog 列（測試/服務共用）。
OplogRow opFor(String entity, String entityId, String hlc, Map<String, Object?> snapshot) =>
    OplogRow(
      entity: entity,
      entityId: entityId,
      hlc: hlc,
      payload: jsonEncode(snapshot),
      packedSeq: null,
    );

/// 新 HLC 版本戳（Clock 單一來源；deviceId 注入）。
String newHlc(String deviceId) => Hlc.now(deviceId).toString();

/// 新實體 id（UUIDv7）。
String newId() => const Uuid().v7();

/// 衝突事件建構（N-8；被覆蓋內容唯讀快照）。
SyncEventRow conflictEvent({
  required String entity,
  required String entityId,
  required String incomingHlc,
  required Map<String, Object?> overwritten,
}) =>
    SyncEventRow(
      id: const Uuid().v7(),
      entity: entity,
      entityId: entityId,
      incomingHlc: incomingHlc,
      overwrittenRow: jsonEncode(overwritten),
      createdAt: Clock.now().millisecondsSinceEpoch,
    );
