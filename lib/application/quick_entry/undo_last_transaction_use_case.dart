import '../../data/sqlite/app_database.dart';

/// 復原結果：被撤銷之交易 id（無可復原者回傳 null）。
class UndoTransactionResult {
  const UndoTransactionResult(this.transactionId);
  final String transactionId;
}

/// 復原上一筆 UseCase（FR-Q3，acceptance F01 S1.8）。
///
/// 契約：
/// - 目標 = **剛儲存**之交易（依 oplog 建立序，非 occurred_at——S1.5 允許回填時間）。
/// - 撤銷 = 軟刪除墓標（deleted_at 非 null）+ oplog 墓標（payload=NULL），同一 DB transaction。
/// - 已復原之交易跳過（防重複墓標導致同步後多刪）。
/// - 離開快記頁後不再提供入口（FR-Q2；由 FE 控制生命週期）。
class UndoLastTransactionUseCase {
  UndoLastTransactionUseCase(this._db, {this.deviceId = 'device-local'});

  // ignore: unused_field — 紅燈階段（TDD）：實作後移除本標記。
  final AppDatabase _db;
  final String deviceId;

  UndoTransactionResult? execute() => throw UnimplementedError('T-F01-BE 紅燈階段');
}
