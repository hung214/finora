import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// bundle 套用器（SDD §5.5.2/§5.5.4）：整列快照冪等套用、LWW（incoming.hlc
/// > local.hlc → 覆蓋；否則忽略）、衝突事件（FR-Y5/N-8）。
///
/// 合併規則（SDD §5.5.4）：
/// - 目標列不存在 → insert。
/// - 存在且 incoming.hlc > local.hlc → 整列覆蓋（LWW）。
/// - 否則忽略（本地較新或同版——套用冪等）。
/// - **衝突通知**：本機曾寫入該列（oplog 有該 entity_id 之記錄）卻被更高
///   HLC 覆蓋 → sync_events 記被覆蓋內容唯讀快照＋N-8（同步狀態頁可檢視）。
///   註：SDD §5.5.4 初稿括號「未被打包」由情境釐清為「oplog 曾有該 id」
///   （已打包後被覆蓋同樣應通知使用者——後寫入者勝之教育，SDD R5）。
///
/// 為何安全（SDD）：所有金額衍生值由交易重算；LWW 覆蓋只影響單列欄位。
///
/// ⚠️ 同步合併模組：待雙重 review（research §1.3）。
class BundleApplier {
  BundleApplier(this._db, {this.onConflictEvent});

  final AppDatabase _db;

  /// 衝突通知鉤子（N-8；測試 spy／正式通知服務）。
  final void Function(SyncEventRow event)? onConflictEvent;

  /// 套用一個 bundle 的 ops（順序＝bundle 內陣列序；呼叫端保證 bundle 間
  /// 已按 (device, seq) 排序）。回傳實際套用數（LWW 忽略者不計）。
  int apply(String fromDevice, List<Map<String, Object?>> ops) {
    var applied = 0;
    for (final op in ops) {
      final entity = op['e'] as String;
      final id = op['id'] as String;
      final hlc = op['hlc'] as String;
      final row = op['row'] as Map<String, Object?>?;

      if (row == null) {
        // 墓標（刪除）——冪等套用（oplog 日誌保留）。
        _db.applyTombstone(entity, id);
        applied++;
        continue;
      }

      final local = _db.localHlc(entity, id);
      if (local != null) {
        final incoming = Hlc.parse(hlc);
        final current = Hlc.parse(local);
        if (incoming <= current) continue; // LWW：incoming 較舊/同版 → 忽略
        // 衝突：本機曾寫入該列卻被覆蓋（FR-Y5）。
        if (_db.oplogHasEntityId(entity, id)) {
          final event = SyncEventRow(
            id: const Uuid().v7(),
            entity: entity,
            entityId: id,
            incomingHlc: hlc,
            overwrittenRow: jsonEncode(_db.localRow(entity, id)!),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          _db.insertSyncEvent(event);
          onConflictEvent?.call(event);
        }
      }
      _db.applySnapshot(entity, row);
      applied++;
    }
    return applied;
  }
}
