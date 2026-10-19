import 'dart:convert';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 還原結果：被還原之交易 id。
class RestoreTransactionResult {
  const RestoreTransactionResult(this.transactionId);
  final String transactionId;
}

/// 還原交易 UseCase（FR-T3：30 天內可還原，acceptance F02 S2.5 步驟 3，
/// 「最近刪除」頁還原入口——F02-FE）。
///
/// 契約（鏡像 Delete/Undo）：
/// - 還原 = 墓標清除（deleted_at → NULL，金額/分類/時間**完整無損**）＋
///   oplog **整列快照**（UPDATE 語意；payload 非 null，有別於刪除墓標），
///   兩者於同一 DB transaction。
/// - 保留期屆滿（已實體清除）或未刪除之交易拋 StateError。
class RestoreTransactionUseCase {
  RestoreTransactionUseCase(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;
  final String deviceId;

  RestoreTransactionResult execute(String transactionId) {
    final tx = _db.transactionById(transactionId);
    if (tx == null) {
      throw StateError('還原失敗：交易不存在 $transactionId');
    }
    if (tx.deletedAt == null) {
      throw StateError('還原失敗：交易未刪除 $transactionId');
    }
    final nowMs = Clock.now().millisecondsSinceEpoch;
    final hlc = Hlc.now(deviceId).toString();
    final restored = TxRow(
      id: tx.id,
      kind: tx.kind,
      amountMinor: tx.amountMinor,
      currency: tx.currency,
      accountId: tx.accountId,
      toAccountId: tx.toAccountId,
      categoryId: tx.categoryId,
      merchant: tx.merchant,
      note: tx.note,
      occurredAt: tx.occurredAt,
      source: tx.source,
      settlementStatus: tx.settlementStatus,
      createdAt: tx.createdAt,
      updatedAt: nowMs,
      hlc: hlc,
      deletedAt: null,
    );
    _db.restoreTransactionWithOplog(
      transactionId,
      OplogRow(
        entity: 'transactions',
        entityId: transactionId,
        hlc: hlc,
        payload: jsonEncode(restored.toSnapshot()), // UPDATE 快照（同步冪等套用）
        packedSeq: null,
      ),
      restoredAt: nowMs,
      hlc: hlc,
    );
    return RestoreTransactionResult(transactionId);
  }
}
