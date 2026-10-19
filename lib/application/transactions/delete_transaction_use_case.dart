import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 刪除結果：被刪除之交易 id。
class DeleteTransactionResult {
  const DeleteTransactionResult(this.transactionId);
  final String transactionId;
}

/// 刪除交易 UseCase（FR-T3，acceptance F02 S2.5：明細/詳情之使用者刪除）。
///
/// 契約（鏡像 F01 Undo）：
/// - 軟刪除墓標（deleted_at 非 null）+ oplog 墓標（payload=NULL）於**同一 DB
///   transaction**（儲存事務原子性契約的鏡像）。
/// - 30 天保留期內可還原（還原入口屬 F02-FE「最近刪除」；期間屆滿由
///   [TombstonePurgeService] 實體清除）。
/// - 不存在或已刪除之交易拋 StateError（防重複墓標——同步後多刪，S1.8 同因）。
class DeleteTransactionUseCase {
  DeleteTransactionUseCase(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;
  final String deviceId;

  DeleteTransactionResult execute(String transactionId) {
    final nowMs = Clock.now().millisecondsSinceEpoch;
    final hlc = Hlc.now(deviceId).toString();
    _db.softDeleteTransactionWithOplog(
      transactionId,
      OplogRow(
        entity: 'transactions',
        entityId: transactionId,
        hlc: hlc,
        payload: null, // 墓標（SDD §5.5.4：NULL=刪除）
        packedSeq: null,
      ),
      deletedAt: nowMs,
      hlc: hlc,
    );
    return DeleteTransactionResult(transactionId);
  }
}
