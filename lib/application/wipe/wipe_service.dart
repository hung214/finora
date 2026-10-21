import 'dart:io';

import '../../data/sqlite/app_database.dart';
import '../../platform/cloud/cloud_storage_adapter.dart';

/// 雲端資料已被清除（WipeService 清空後其他裝置之 pull 偵測——FR-O3
/// 「不復活」：vault 缺 → 視為雲端已重置 → 停止同步（不推回舊資料））。
class CloudWipedException implements Exception {
  const CloudWipedException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 資料清除服務（FR-O3；SDD §7.3）：本地全表清空＋附件檔案刪除；
/// 含雲端 → LedgerSync/ 整個資料夾刪除（vault/devices/ops/blobs/backups）。
class WipeService {
  WipeService(this._db, this._cloud, {this.blobsDir});

  final AppDatabase _db;
  final CloudStorageAdapter _cloud;

  /// 本地 blobs 目錄（附件檔案；null＝略）。
  final Directory? blobsDir;

  static const _tables = [
    'statement_items', 'refund_links', 'attachments', 'installment_plans',
    'statements', 'credit_card_details', 'income_goals', 'budgets',
    'recurring_transactions', 'transactions', 'templates', 'categories',
    'accounts', 'oplog', 'settings', 'sync_events',
  ];

  /// 執行清空（FR-O3）：[includeCloud] 時連雲端 LedgerSync/ 一併刪除。
  Future<void> wipe({required bool includeCloud}) async {
    // 本地：全表清空（事務全有全無）。
    _db.runInTransaction(() {
      for (final t in _tables) {
        _db.clearTable(t);
      }
    });
    // 附件檔案刪除。
    final dir = blobsDir;
    if (dir != null && dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    // 雲端：根清單逐一刪除（adapter 無 rmdir——逐檔；資料夾語意由路徑前綴）。
    if (includeCloud) {
      final all = await _cloud.list('');
      for (final path in all) {
        await _cloud.delete(path);
      }
    }
  }
}
