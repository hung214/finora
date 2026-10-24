import '../../core/clock.dart';
import '../../data/sqlite/app_database.dart';

/// 永久刪除結果：實際清除筆數（0＝已無墓標——冪等）。
class PurgeTombstoneResult {
  const PurgeTombstoneResult(this.purgedCount);
  final int purgedCount;
}

/// 永久刪除墓標 UseCase（FR-T3：「最近刪除」→ 直接刪除／清空全部；
/// PM 2026-10-24 需求增補）。
///
/// 契約（**鏡像** [TombstonePurgeService] 的 30 天屆滿清除——同一條實體清除路徑）：
/// - **實體刪除** `transactions` 列（**無法還原**）；**oplog 墓標保留**——軟刪除
///   當下已寫入 payload=NULL 墓標，其他裝置的刪除結果不變（同步安全）。
/// - [execute] 僅接受**墓標**：未刪除之交易拋 StateError（防誤刪）；
///   已清除/不存在回 0（冪等——重複點擊不報錯）。
/// - [executeAll] ＝以「現在」為 cutoff 走 [AppDatabase.purgeTransactionsDeletedBefore]
///   （不受 30 天限制；語意與屆滿清除一致，含「oplog 保留」）。
class PurgeTombstoneUseCase {
  PurgeTombstoneUseCase(this._db);

  final AppDatabase _db;

  /// 單筆永久刪除。
  PurgeTombstoneResult execute(String transactionId) =>
      PurgeTombstoneResult(_db.purgeTombstoneById(transactionId));

  /// 清空全部墓標（使用者明示刪除——不受 30 天保留期限制）。
  PurgeTombstoneResult executeAll() => PurgeTombstoneResult(
      _db.purgeTransactionsDeletedBefore(Clock.now().millisecondsSinceEpoch));
}
