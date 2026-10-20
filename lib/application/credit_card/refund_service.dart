import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 退款衝銷（FR-C8；acceptance S10.3；⚠️ 待雙重 review）。
///
/// - 針對已結帳交易建立退款：**refund 交易**（掛原卡片、金額正數）＋
///   **refund_links**（refund → original）＋帳單**負項沖減**（total 遞減）。
/// - 退款交易與帳單更新於**同一 DB transaction**（各含 oplog 快照）。
class RefundService {
  RefundService(this._db);

  final AppDatabase _db;

  /// 建立退款；回傳退款交易 id。
  String createRefund({required String originalTxId, required int amountMinor}) {
    final original = _db.transactionById(originalTxId);
    if (original == null) {
      throw StateError('退款失敗：原交易不存在 $originalTxId');
    }
    if (amountMinor <= 0) {
      throw StateError('退款失敗：金額須為正');
    }
    final now = Clock.now();
    final nowMs = now.millisecondsSinceEpoch;
    final hlc = Hlc.now('billing').toString();
    final refundId = const Uuid().v7();

    final refundTx = TxRow(
      id: refundId,
      kind: 'refund',
      amountMinor: amountMinor,
      currency: original.currency,
      accountId: original.accountId, // 掛原卡片（負債沖減）
      toAccountId: null,
      categoryId: original.categoryId,
      merchant: original.merchant,
      note: '退款（原交易 ${_short(originalTxId)}）',
      occurredAt: nowMs,
      source: 'manual',
      settlementStatus: original.settlementStatus, // 已結帳退款同為 billed 語意
      createdAt: nowMs,
      updatedAt: nowMs,
      hlc: hlc,
    );

    _db.runInTransaction(() {
      _db.insertTransaction(refundTx);
      _db.appendOp(OplogRow(
        entity: 'transactions',
        entityId: refundId,
        hlc: hlc,
        payload: jsonEncode(refundTx.toSnapshot()),
        packedSeq: null,
      ));
      _db.insertRefundLink(refundTxId: refundId, originalTxId: originalTxId);
      // 帳單負項沖減（refund 掛同帳單——以 statement_items 反查該筆所屬帳單；
      // M3 簡化：原交易已 billed → 沖減其最近帳單 total）。
      _db.applyRefundToStatement(originalTxId, amountMinor, nowMs, hlc);
    });
    return refundId;
  }

  String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;
}
