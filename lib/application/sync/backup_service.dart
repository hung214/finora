import 'dart:convert';

import '../../core/clock.dart';
import '../../data/sqlite/app_database.dart';
import '../../platform/cloud/cloud_storage_adapter.dart';

/// 備份服務（SDD §5.5.1 backups/；FR-Y3 GC＋FR-Y6/AC-14 檔案密碼）。
///
/// 快照格式（M5）：JSON（各表全列）→（密碼→AES-GCM，cryptography D8）→
/// `backups/{yyyyMMdd_HHmmss}.db`。每日自動（>24h）＋保留份數 GC
/// （settings backup.keep，預設 7）。
class BackupService {
  BackupService(this._db, this._cloud, {required this.deviceId});

  // ignore: unused_field —— 紅燈 stub：runIfNeeded/export 實作（F07 綠燈）後使用
  final AppDatabase _db;
  // ignore: unused_field —— 紅燈 stub：runIfNeeded/export 實作（F07 綠燈）後使用
  final CloudStorageAdapter _cloud;

  /// manifest 所屬裝置（備份檔名含裝置語意免衝突——時間戳唯一已足夠）。
  final String deviceId;

  // ignore: unused_element —— 紅燈 stub：runIfNeeded/export 實作（F07 綠燈）後使用
  String _backupPath(DateTime t) =>
      'backups/${t.year.toString().padLeft(4, '0')}'
      '${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}'
      '_${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}'
      '${t.second.toString().padLeft(2, '0')}.db';

  /// 每日自動備份（>24h）＋GC 超額舊份（FR-Y3）。回傳本次是否產生備份。
  Future<bool> runIfNeeded() =>
      throw UnimplementedError('F07-BE 紅燈 stub：runIfNeeded');

  /// 匯出備份（[password] null＝不加密，預設；FR-Y6 Outline 選項）。
  Future<String> export({String? password}) =>
      throw UnimplementedError('F07-BE 紅燈 stub：export');

  /// 匯入備份至 [target]（另一環境/新裝置；錯誤密碼拋例外且 target 不變）。
  Future<void> importInto(
    AppDatabase target,
    String cloudPath, {
    String? password,
  }) => throw UnimplementedError('F07-BE 紅燈 stub：importInto');

  /// 全表快照（匯出用；逐表 SELECT）。
  Map<String, Object?> snapshot() {
    final tables = [
      'accounts', 'categories', 'transactions', 'oplog', 'settings', 'templates',
      'budgets', 'income_goals', 'credit_card_details', 'statements',
      'statement_items', 'refund_links', 'installment_plans', 'attachments',
    ];
    return {
      'schema_ver': _db.schemaVersion,
      'created_at': Clock.now().millisecondsSinceEpoch,
      for (final t in tables)
        t: [
          for (final r in _db.select('SELECT * FROM $t'))
            Map<String, Object?>.from(r),
        ],
    };
  }

  /// 快照 JSON bytes（密碼非 null 時 AES-GCM 加密）。
  Future<List<int>> encode(Map<String, Object?> snapshot, {String? password}) async {
    final plain = utf8.encode(jsonEncode(snapshot));
    if (password == null) return plain;
    // cryptography AES-256-GCM（D8）——M5 紅燈 stub，S8 綠燈實作。
    throw UnimplementedError('F07-BE 紅燈 stub：加密（FR-Y6 密碼選項）');
  }

  /// 快照 JSON bytes 解碼（錯誤密碼拋例外）。
  Future<Map<String, Object?>> decode(List<int> bytes, {String? password}) async {
    if (password != null) {
      throw UnimplementedError('F07-BE 紅燈 stub：解密（FR-Y6 密碼選項）');
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  }
}
