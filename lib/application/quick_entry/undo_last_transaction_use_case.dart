import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 復原結果：被撤銷之交易 id（無可復原者回傳 null）。
class UndoTransactionResult {
  const UndoTransactionResult(this.transactionId);
  final String transactionId;
}

/// 復原上一筆 UseCase（FR-Q3，acceptance F01 S1.8）。
///
/// 契約：
/// - 目標 = **剛儲存**之交易（依 oplog 建立序掃描，非 occurred_at——S1.5 允許回填
///   時間，不能以消費時間取「上一筆」）。
/// - 撤銷 = 軟刪除墓標（deleted_at 非 null）+ oplog 墓標（payload=NULL），兩者
///   位於同一 DB transaction（save 時原子性契約的鏡像）。
/// - 已復原之交易跳過（防重複墓標導致同步後多刪，S1.8 失敗判定）。
/// - 離開快記頁後不再提供入口（FR-Q2；由 FE 控制生命週期，BE 無狀態）。
class UndoLastTransactionUseCase {
  UndoLastTransactionUseCase(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;
  final String deviceId;

  UndoTransactionResult? execute() {
    // oplog 建立序由新到舊找第一筆「未刪除」的交易建立記錄。
    final ops = _db.allOps().reversed;
    for (final op in ops) {
      if (op.entity != 'transactions' || op.payload == null) continue; // 墓標 op 非建立記錄
      final tx = _db.transactionById(op.entityId);
      if (tx == null || tx.deletedAt != null) continue; // 已復原者跳過
      final nowMs = Clock.now().millisecondsSinceEpoch;
      final hlc = Hlc.now(deviceId).toString();
      _db.softDeleteTransactionWithOplog(
        tx.id,
        OplogRow(
          entity: 'transactions',
          entityId: tx.id,
          hlc: hlc,
          payload: null, // 墓標（SDD §5.5.4：NULL=刪除）
          packedSeq: null,
        ),
        deletedAt: nowMs,
        hlc: hlc,
      );
      return UndoTransactionResult(tx.id);
    }
    return null;
  }
}
