import '../../core/clock.dart';
import '../../data/sqlite/app_database.dart';

/// 墓標清除服務（FR-T3：軟刪除 30 天保留期，acceptance F02 S2.5 步驟 4）。
///
/// 保留期屆滿之墓標**實體清除**（無法還原）；oplog 墓標**保留**——oplog 為
/// 同步日誌（SDD §5.5），GC 屬 F07。排程觸發（App 啟動/每日）屬 F02-FE 接線。
class TombstonePurgeService {
  TombstonePurgeService(this._db);

  final AppDatabase _db;

  /// 軟刪除保留天數（FR-T3）。
  static const int retentionDays = 30;

  /// 清除 deleted_at 超過保留期之墓標，回傳清除筆數（冪等：無候選回 0）。
  int purge() {
    final cutoff = Clock.now()
        .subtract(const Duration(days: retentionDays))
        .millisecondsSinceEpoch;
    return _db.purgeTransactionsDeletedBefore(cutoff);
  }
}
