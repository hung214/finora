import '../../data/sqlite/app_database.dart';

/// bundle 套用器（SDD §5.5.2/§5.5.4）：依 (device, seq) 排序、整列快照冪等
/// 套用、LWW（incoming.hlc > local.hlc → 覆蓋；否則忽略）、衝突事件。
///
/// ⚠️ 同步合併模組：待雙重 review（research §1.3）。
class BundleApplier {
  BundleApplier(this._db, {this.onConflictEvent});

  // ignore: unused_field —— 紅燈 stub：apply 實作（F07 綠燈）後使用
  final AppDatabase _db;

  /// 衝突通知鉤子（N-8）——「本機曾寫入該列（oplog 有該 id 之記錄）卻被
  /// 更高 HLC 覆蓋」時觸發（被覆蓋內容存 sync_events.overwritten_row）。
  final void Function(SyncEventRow event)? onConflictEvent;

  /// 套用一個 bundle 的 ops（順序＝bundle 內陣列序；呼叫端保證 bundle 間
  /// 已按 (device, seq) 排序）。回傳實際套用數（LWW 忽略者不計）。
  int apply(String fromDevice, List<Map<String, Object?>> ops) =>
      throw UnimplementedError('F07-BE 紅燈 stub：apply');
}
