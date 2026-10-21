import '../../data/sqlite/app_database.dart';
import 'sync_coordinator.dart';

/// 自動同步觸發（FR-Y11）：settings sync.mode——
/// - 每筆自動同步：記帳後立即 sync（afterSave 呼叫 [onSaved]）
/// - 節能批次（預設）：記帳後 30s＋閒置 15min（生產 timer；BE 情境由
///   「模擬時間快轉 31 秒並觸發批次同步」顯式觸發——觸發點即 SyncCoordinator）
/// - 僅手動：設定頁「立即同步」
class AutoSyncService {
  AutoSyncService(this._db, this._coordinator);

  final AppDatabase _db;
  final SyncCoordinator _coordinator;

  /// 記帳後鉤子（與 BudgetAlertService.sync 同為 afterSave sync 點）。
  Future<void> onSaved() async {
    final mode = _db.getSetting('sync.mode') ?? 'batch';
    if (mode == 'per-transaction') {
      await _coordinator.sync();
    }
    // 節能批次/僅手動：由生產 timer／設定頁觸發——BE 情境顯式呼叫 coordinator。
  }
}
