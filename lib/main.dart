import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'application/first_run_bootstrap.dart';
import 'application/providers.dart';
import 'application/scan/scan_state.dart';
import 'application/sync/sync_coordinator.dart';
import 'application/sync/sync_fe_state.dart';
import 'data/sqlite/app_database.dart';
import 'platform/auth/google_oauth.dart';
import 'platform/cloud/drive/google_drive_adapter.dart';
import 'platform/cloud/unconfigured_cloud_adapter.dart';
import 'presentation/app_shell.dart';

/// LedgerSync — 本地優先記帳 App（production 入口）。
///
/// 啟動流程：文件目錄開檔案 DB（`<documents>/ledger_sync/ledger.db`）→
/// 首次啟動播種（空帳本自動建立內建分類集＋預設現金帳戶）→ 注入 provider：
/// - `dbProvider`／`blobsDirProvider`（附件落盤 `<documents>/ledger_sync/blobs`）
/// - `deviceId`（per-device：首次產生並持久化於 settings `device.id`——HLC/同步用）
/// - `cloudAdapterProvider`／`oauthProvider`／`syncCoordinatorProvider`（FR-Y7）
///
/// **雲端憑證**：以 `--dart-define=GOOGLE_OAUTH_CLIENT_ID=…`（＋`…_CLIENT_SECRET`）
/// 注入；未設定 → [UnconfiguredCloudAdapter] 降級（UI 顯示未設定，不崩）——
/// 設定步驟見 `specs/plan/pm-actions.md`。M1 過渡期 DB 為明文 SQLite
/// （SQLCipher 屬 SP-1，research §3）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final root = Directory('${docs.path}${Platform.pathSeparator}ledger_sync');
  final blobsDir = Directory('${root.path}${Platform.pathSeparator}blobs');
  await blobsDir.create(recursive: true);
  final db = AppDatabase.open('${root.path}${Platform.pathSeparator}ledger.db');
  await FirstRunBootstrap.seedIfNeeded(db);

  // 裝置 id（per-device；HLC 與同步 manifest 用）——首次啟動產生並持久化。
  var deviceId = db.getSetting('device.id') ?? '';
  if (deviceId.isEmpty) {
    deviceId = 'd-${const Uuid().v7().substring(0, 8)}';
    db.setSetting('device.id', deviceId);
  }

  // 雲端 adapter（憑證未就緒 → 降級；不影響本地功能）。
  final cloud =
      GoogleDriveAdapter.fromEnvironment() ?? const UnconfiguredCloudAdapter();

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        blobsDirProvider.overrideWithValue(blobsDir),
        cloudAdapterProvider.overrideWithValue(cloud),
        oauthProvider.overrideWithValue(googleOAuthSignIn(cloud)),
        syncCoordinatorProvider.overrideWithValue(SyncCoordinator(db, cloud,
            deviceId: deviceId, blobsDir: blobsDir)),
      ],
      child: const AppShell(),
    ),
  );
}
