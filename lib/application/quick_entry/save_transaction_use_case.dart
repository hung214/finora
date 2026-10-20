import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';
import '../../domain/entities/transaction.dart';

/// 交易驗證失敗（[message] 為 FE 顯示契約；BE BDD 斷言同一訊息，F02 S2.1）。
class TransactionValidationException implements Exception {
  const TransactionValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 儲存結果：回傳入庫交易 id（FE 對話框/Undo 用）。
class SaveTransactionResult {
  const SaveTransactionResult(this.transactionId);
  final String transactionId;
}

/// 儲存事務 UseCase（FR-Q5／SDD §5.1）。
///
/// 契約：
/// - 交易與 oplog 於**同一 DB transaction** 寫入（[AppDatabase.saveTransactionWithOplog]），
///   保證不產生「有交易但沒有同步記錄」的孤兒（BDD：中斷模擬不產生孤兒）。
/// - oplog payload 為整列快照、packed_seq = null（待 SyncCoordinator 打包，F07）——
///   離線時僅落地本地（local-first，S1.10），上線後補同步。
/// - 金額一律整數 minor units 且為正（方向由 kind 決定，SDD §4.2）。
class SaveTransactionUseCase {
  SaveTransactionUseCase(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;

  /// HLC 裝置 id（M1 本地單機；F07 多裝置時由裝置註冊提供）。
  final String deviceId;

  /// 記一筆（F02 擴充：kind 預設支出；transfer/repayment 須 [toAccountId]）。
  ///
  /// [occurredAt] 允許回填（S1.5）；id 以 UUIDv7（data-spec）；HLC 依 [Clock] 取時。
  /// 契約：
  /// - 金額一律整數 minor units 且為正（方向由 kind 決定，SDD §4.2）。
  /// - transfer/repayment 須指定**相異**目標帳戶（同帳戶轉帳 UI 阻擋，BE 為後備防線）。
  /// - transfer/repayment 不適用分類（S2.6：還款固定還款語意，無分類選擇器）。
  SaveTransactionResult execute({
    required String accountId,
    String? categoryId,
    required int amountMinor,
    required DateTime occurredAt,
    String? merchant,
    String? note,
    TxKind kind = TxKind.expense,
    String? toAccountId,
    String settlementStatus = 'none',
  }) {
    if (amountMinor <= 0) {
      // F02 S2.1：金額必填且大於 0（0 或空值皆不得入庫；訊息為 FE 顯示契約）。
      throw const TransactionValidationException('驗證失敗：金額必須大於 0');
    }
    final isCrossAccount = kind == TxKind.transfer || kind == TxKind.repayment;
    if (isCrossAccount && (toAccountId == null || toAccountId == accountId)) {
      throw const TransactionValidationException('驗證失敗：轉帳須指定相異目標帳戶');
    }
    final now = Clock.now();
    final row = TxRow(
      id: const Uuid().v7(),
      kind: kind.name,
      amountMinor: amountMinor,
      currency: 'TWD',
      accountId: accountId,
      toAccountId: isCrossAccount ? toAccountId : null,
      categoryId: isCrossAccount ? null : categoryId,
      merchant: merchant,
      note: note,
      occurredAt: occurredAt.millisecondsSinceEpoch,
      source: 'manual',
      // F05 S5.3：信用卡預扣（pending）——預算「承諾支出」口徑；完整帳單語意屬 F04。
      settlementStatus: settlementStatus,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      hlc: Hlc.now(deviceId).toString(),
    );
    _db.saveTransactionWithOplog(
      row,
      OplogRow(
        entity: 'transactions',
        entityId: row.id,
        hlc: row.hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      ),
    );
    return SaveTransactionResult(row.id);
  }
}
