import '../../data/sqlite/app_database.dart';

/// 儲存結果：回傳入庫交易 id（FE 對話框/Undo 用）。
class SaveTransactionResult {
  const SaveTransactionResult(this.transactionId);
  final String transactionId;
}

/// 儲存事務 UseCase（FR-Q5／SDD §5.1）。
///
/// 契約：交易與 oplog 於**同一 DB transaction** 寫入（[AppDatabase.saveTransactionWithOplog]），
/// 保證不產生「有交易但沒有同步記錄」的孤兒；oplog payload 為整列快照、
/// packed_seq = null（待 SyncCoordinator 打包，F07）。
class SaveTransactionUseCase {
  SaveTransactionUseCase(this._db, {this.deviceId = 'device-local'});

  // ignore: unused_field — 紅燈階段（TDD）：實作後移除本標記。
  final AppDatabase _db;

  /// HLC 裝置 id（M1 本地單機；F07 多裝置時由裝置註冊提供）。
  final String deviceId;

  /// 記一筆（快記預設為支出；轉帳/收入/還款由 F02 擴充參數）。
  SaveTransactionResult execute({
    required String accountId,
    String? categoryId,
    required int amountMinor,
    required DateTime occurredAt,
    String? merchant,
    String? note,
  }) => throw UnimplementedError('T-F01-BE 紅燈階段');
}
