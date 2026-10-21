import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';

import '../../data/sqlite/app_database.dart';
import '../../platform/cloud/cloud_storage_adapter.dart';
import '../providers.dart';

/// 雲端同步 UI 狀態（F07-FE；SDD §7.1 帳號授權式同步——**無同步密碼**）。

/// 雲端 adapter（FR-Y7：Google Drive appDataFolder——生產由 main() 以
/// GoogleDriveAdapter override；測試以 InMemoryCloudAdapter override。
/// 同 dbProvider 注入約定）。
final cloudAdapterProvider = Provider<CloudStorageAdapter>((ref) {
  throw UnimplementedError('cloudAdapterProvider 須於 main() 或測試 override 注入');
});

/// OAuth 登入 seam（FR-Y7）：回連結後之帳號 email；null＝使用者取消。
/// 生產：google_sign_in（行動）/loopback OAuth（桌面）；測試：fake 回放。
final oauthProvider = Provider<Future<String?> Function()>((ref) {
  throw UnimplementedError('oauthProvider 須於 main() 或測試 override 注入');
});

/// 連結狀態（settings sync.account＝email；null＝未連結）。
final syncAccountProvider = NotifierProvider<SyncAccountNotifier, String?>(
    SyncAccountNotifier.new);

class SyncAccountNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(dbProvider).getSetting('sync.account');

  void link(String email) {
    ref.watch(dbProvider).setSetting('sync.account', email);
    state = email;
  }

  void unlink() {
    ref.watch(dbProvider).setSetting('sync.account', '');
    state = null; // UI 判定以 state 為準（settings 存空字串＝歷史紀錄）
  }
}

/// 待同步筆數（oplog 未打包；同步後 refresh）。
final pendingOpsProvider =
    NotifierProvider<PendingOpsNotifier, int>(PendingOpsNotifier.new);

class PendingOpsNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(dbProvider).unpackedOps().length;

  void refresh() => state = ref.watch(dbProvider).unpackedOps().length;
}

/// 上次同步時間（settings sync.last_at ms；啟動/手動同步完成後寫入）。
final lastSyncAtProvider =
    NotifierProvider<LastSyncAtNotifier, int?>(LastSyncAtNotifier.new);

class LastSyncAtNotifier extends Notifier<int?> {
  @override
  int? build() =>
      int.tryParse(ref.watch(dbProvider).getSetting('sync.last_at') ?? '');

  void refresh() =>
      state = int.tryParse(ref.watch(dbProvider).getSetting('sync.last_at') ?? '');
}

/// 衝突事件列表（AC-07 衝突檢視；套用衝突後 refresh）。
final syncEventsProvider = NotifierProvider<SyncEventsNotifier, List<SyncEventRow>>(
    SyncEventsNotifier.new);

class SyncEventsNotifier extends Notifier<List<SyncEventRow>> {
  @override
  List<SyncEventRow> build() => ref.watch(dbProvider).allSyncEvents();

  void refresh() => state = ref.watch(dbProvider).allSyncEvents();
}

/// 同步完成之共同收尾（寫 last_at＋刷新 pending/lastSync/events——
/// SyncSettingsPage 與啟動同步共用；container 供 widget 外呼叫）。
void afterSyncRefresh(ProviderContainer container) {

  // T-H2 單一時間來源：Clock（凍結時跟隨——acceptance「上次同步 今天 09:00」）。
  container.read(dbProvider).setSetting(
      'sync.last_at', '${Clock.now().millisecondsSinceEpoch}');
  container.read(pendingOpsProvider.notifier).refresh();
  container.read(lastSyncAtProvider.notifier).refresh();
  container.read(syncEventsProvider.notifier).refresh();
}

/// 衝突事件之被覆蓋內容擷取（衝突檢視呈現；row JSON 的 note/關鍵欄位）。
String conflictOverwrittenSummary(SyncEventRow e) {
  try {
    final row = jsonDecode(e.overwrittenRow ?? '{}') as Map<String, Object?>;
    return (row['note'] as String?) ??
        (row['name'] as String?) ??
        (row['merchant'] as String?) ??
        '(無內容)';
  } catch (_) {
    return '(無內容)';
  }
}
