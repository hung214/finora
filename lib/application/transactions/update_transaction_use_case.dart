import 'dart:convert';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 交易編輯 UseCase（FR-T3；PM 2026-10-24：點明細列 → **編輯**）。
///
/// 契約（鏡像 [DeleteTransactionUseCase]）：
/// - 更新可編輯欄位（金額／日期／帳戶／分類／商家／備註）＋oplog **整列快照**
///   於同一 DB transaction（SDD §5.5.4；多裝置 LWW 合併一致）。
/// - 僅改「值」；id/created_at/source/split_group_id 等不變。
/// - 交易不存在拋 StateError。
class UpdateTransactionUseCase {
  UpdateTransactionUseCase(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;
  final String deviceId;

  TxRow execute(
    String id, {
    int? amountMinor,
    DateTime? occurredAt,
    String? accountId,
    String? categoryId,
    bool clearCategory = false,
    String? merchant,
    bool clearMerchant = false,
    String? note,
    bool clearNote = false,
  }) {
    final cur = _db.transactionById(id);
    if (cur == null) throw StateError('交易不存在：$id');
    final now = Clock.now().millisecondsSinceEpoch;
    final hlc = Hlc.now(deviceId).toString();
    final row = cur.copyWith(
      amountMinor: amountMinor,
      occurredAt: occurredAt?.millisecondsSinceEpoch,
      accountId: accountId,
      categoryId: categoryId,
      clearCategory: clearCategory,
      merchant: merchant,
      clearMerchant: clearMerchant,
      note: note,
      clearNote: clearNote,
      updatedAt: now,
      hlc: hlc,
    );
    _db.updateTransactionWithOplog(
      row,
      OplogRow(
        entity: 'transactions',
        entityId: id,
        hlc: hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      ),
    );
    return row;
  }
}
