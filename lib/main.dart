import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'application/providers.dart';
import 'data/sqlite/app_database.dart';
import 'presentation/app_shell.dart';

/// LedgerSync — 本地優先記帳 App（production 入口）。
///
/// 啟動流程：文件目錄開檔案 DB（`<documents>/ledger_sync/ledger.db`，
/// path_provider，techstack v0.3.5）→ dbProvider 注入 → [AppShell] 主殼。
/// M1 過渡期 DB 為明文 SQLite（SQLCipher 屬 SP-1，research §3）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final dbDir = Directory('${docs.path}${Platform.pathSeparator}ledger_sync');
  await dbDir.create(recursive: true);
  final db = AppDatabase.open('${dbDir.path}${Platform.pathSeparator}ledger.db');
  runApp(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: const AppShell(),
    ),
  );
}
