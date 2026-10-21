import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_sync/application/lock/app_lock_controller.dart';
import 'package:ledger_sync/application/lock/lock_fe_state.dart';
import 'package:ledger_sync/application/providers.dart';
import 'package:ledger_sync/application/sync/sync_fe_state.dart';
import 'package:ledger_sync/application/sync/sync_coordinator.dart';
import 'package:ledger_sync/application/scan/scan_state.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/presentation/app_shell.dart';
import 'package:ledger_sync/presentation/screens/settings/data_management_page.dart';

import '../../test/helpers/db_fixture.dart';
import '../../test/helpers/in_memory_cloud_adapter.dart';
import '../../test/helpers/gherkin/gherkin.dart';

/// F09-FE 情境執行器（@FE @M7 @FR-O3，2 情境：三重防護對話順序/已連雲端
/// 加驗身分）。清除執行契約由 F09-BE 驗證——FE 驗呈現面與流程閘。
///
/// 來源：specs/plan/tests/frontend/F09_data-management.feature（rootBundle）。
/// 句型登記簿：specs/plan/tests/dsl.md §3（v1.5）。
/// 設定入口接線屬 F07-FE 回頭項——harness 以 Navigator.push 等價驅動
/// 「設定→資料管理」導航語意。
Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final doc = GherkinParser.parse(await rootBundle
      .loadString('integration_test/features/F09_data-management.feature'));

  testWidgets('F09-FE：資料清除 UI（2 情境）', (tester) async {
    final w = _World(tester);
    final runner = GherkinRunner();
    _bind(runner, w);
    try {
      final executed = await runner.run(doc, tagFilter: (tags) => tags.contains('@FE'));
      expect(executed, 2, reason: 'F09-FE 應執行 2 個情境');
      // ignore: avoid_print
      print(runner.log.join('\n'));
    } finally {
      for (final db in w.dbs) {
        db.close();
      }
      for (final c in w.containers) {
        c.dispose();
      }
      for (final dir in w.tempDirs) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    }
  });
}

class _World {
  _World(this.tester);

  final WidgetTester tester;
  final List<AppDatabase> dbs = [];
  final List<ProviderContainer> containers = [];
  final List<Directory> tempDirs = [];
  AppDatabase? db;
  ProviderContainer? container;
  bool pumped = false;

  /// Background 記錄之 PIN（_ensureApp 建構 controller 用）。
  String pin = '';

  /// fake OAuth 回傳 email（S2：重新登入完成）。
  String oauthEmail = 'ming@example.com';
}

Future<void> _ensureApp(_World w) async {
  if (w.pumped) return;
  final db = w.db!;
  final blobs = Directory.systemTemp.createTempSync('ledger_blobs_f09fe');
  w.tempDirs.add(blobs);
  final container = ProviderContainer(overrides: [
    dbProvider.overrideWithValue(db),
    appLockControllerProvider.overrideWithValue(
        AppLockController(db, pin: w.pin, thresholdSec: 30)),
    oauthProvider.overrideWithValue(() async => w.oauthEmail),
    cloudAdapterProvider.overrideWithValue(InMemoryCloudAdapter()),
    blobsDirProvider.overrideWithValue(blobs),
    // 啟動同步鉤子（FR-Y11）防 UnimplementedError——隔離雲端空間。
    syncCoordinatorProvider.overrideWithValue(
        SyncCoordinator(db, InMemoryCloudAdapter(), deviceId: 'd-A')),
  ]);
  w.containers.add(container);
  w.container = container;
  await w.tester.pumpWidget(
    KeyedSubtree(
      key: ValueKey('app-shell-${w.containers.length}'),
      child: UncontrolledProviderScope(container: container, child: const AppShell()),
    ),
  );
  await w.tester.pumpAndSettle();
  w.pumped = true;
}

/// 等價驅動「設定→資料管理」導航（推入 DataManagementPage）。
Future<void> _openDataManagement(_World w) async {
  await _ensureApp(w);
  final navigator = w.tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push(
      MaterialPageRoute<void>(builder: (_) => const DataManagementPage()));
  await w.tester.pumpAndSettle();
}

void _bind(GherkinRunner runner, _World w) {
  // ── Background ───────────────────────────────────────────
  runner.on(r'App 已完成首次設定$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.pumped = false;
    w.pin = '';
  });

  runner.on(r'App 鎖已啟用（PIN {pin}）$', (p) {
    w.pin = p['pin']!; // controller 於 _ensureApp override 建構（寫入 pin_hash）
  });

  runner.on(r'帳本含 {n} 筆交易$', (p) async {
    final db = w.db!;
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 50000);
    final n = int.parse(p['n']!);
    for (var i = 0; i < n; i++) {
      await DbFixture.seedTx(db,
          id: 'tx-wipe-$i',
          kind: 'expense',
          amountMinor: 100 + i,
          accountId: 'a-0',
          occurredAt: 1700000000000 + i * 60000);
    }
  });

  // ── Given ────────────────────────────────────────────────
  runner.on(r'App 已連結雲端$', (p) {
    w.db!.setSetting('sync.account', 'ming@example.com');
  });

  runner.on(r'App 未連結雲端$', (p) {
    w.db!.setSetting('sync.account', '');
  });

  // ── When（長句型先登記——lazy 前綴碰撞） ──────────────────
  runner.on(r'設定→資料管理→按下「清空資料」並輸入 PIN 與確認文字$', (p) async {
    await _openDataManagement(w);
    await w.tester.tap(find.byKey(const Key('wipe-start')));
    await w.tester.pumpAndSettle();
    await w.tester.tap(find.byKey(const Key('wipe-warning-continue')));
    await w.tester.pumpAndSettle();
    await w.tester.enterText(find.byKey(const Key('wipe-pin-input')), w.pin);
    await w.tester.pump();
    await w.tester.tap(find.byKey(const Key('wipe-pin-submit')));
    await w.tester.pumpAndSettle();
    await w.tester.enterText(
        find.byKey(const Key('wipe-confirm-input')), '我要清除所有資料');
    await w.tester.pump();
    await w.tester.tap(find.byKey(const Key('wipe-confirm-submit')));
    await w.tester.pumpAndSettle();
  });

  runner.on(r'設定→資料管理→按下「清空資料」$', (p) async {
    await _openDataManagement(w);
    await w.tester.tap(find.byKey(const Key('wipe-start')));
    await w.tester.pumpAndSettle();
  });

  runner.on(r'輸入 PIN {pin}$', (p) async {
    // 警告層「下一步」→ PIN（S1 對話順序：警告已斷言後進入 PIN 層）。
    await w.tester.tap(find.byKey(const Key('wipe-warning-continue')));
    await w.tester.pumpAndSettle();
    await w.tester.enterText(find.byKey(const Key('wipe-pin-input')), p['pin']!);
    await w.tester.pump();
    await w.tester.tap(find.byKey(const Key('wipe-pin-submit')));
    await w.tester.pumpAndSettle();
  });

  runner.on(r'輸入錯誤文字「{text}」$', (p) async {
    await w.tester.enterText(find.byKey(const Key('wipe-confirm-input')), p['text']!);
    await w.tester.pump();
    await w.tester.tap(find.byKey(const Key('wipe-confirm-submit')));
    await w.tester.pumpAndSettle();
  });

  runner.on(r'重新登入完成$', (p) async {
    await w.tester.tap(find.byKey(const Key('wipe-oauth-button')));
    await w.tester.pumpAndSettle();
  });

  // ── Then ─────────────────────────────────────────────────
  runner.on(r'顯示「將刪除所有資料且無雲端可還原」警告$', (p) {
    expect(w.tester.any(find.text('將刪除所有資料且無雲端可還原')), isTrue,
        reason: 'FR-O3 第一層：警告（未連雲端語意）');
  });

  runner.on(r'顯示「可先匯出備份檔」入口$', (p) {
    expect(w.tester.any(find.byKey(const Key('wipe-backup-entry'))), isTrue,
        reason: 'FR-O3 防呆：清空前備份入口（驗收 S9.2 邊界）');
  });

  runner.on(r'顯示「確認文字輸入框」$', (p) {
    expect(w.tester.any(find.byKey(const Key('wipe-confirm-input'))), isTrue,
        reason: 'FR-O3 第三層：確認文字');
  });

  runner.on(r'顯示「確認文字不符」且無法繼續$', (p) {
    expect(w.tester.any(find.text('確認文字不符')), isTrue, reason: '錯誤回饋');
    expect(w.tester.any(find.byKey(const Key('wipe-confirm-input'))), isTrue,
        reason: '停留確認層（無法繼續）');
    expect(w.db!.allTransactions().where((t) => t.deletedAt == null).length, 20,
        reason: '資料未清（防護擋下）');
  });

  runner.on(r'顯示「重新登入雲端帳號」要求$', (p) {
    expect(w.tester.any(find.text('重新登入雲端帳號')), isTrue, reason: 'S9.2 加驗身分');
    expect(w.tester.any(find.byKey(const Key('wipe-oauth-button'))), isTrue);
  });

  runner.on(r'顯示「已清空」並回到首次啟動引導$', (p) async {
    expect(w.tester.any(find.text('已清空')), isTrue, reason: 'S9.2 完成回饋');
    expect(w.db!.allTransactions(), isEmpty, reason: '本地已清空');
    // 回首次啟動引導：pop 回主殼（空帳本＝首次啟動狀態；NextRun 播種重跑；
    // 獨立引導頁（新建/還原/匯入）屬上架前 UI 統整——M7 §4.2）。
    await w.tester.tap(find.byKey(const Key('wipe-done-home')));
    await w.tester.pumpAndSettle();
    expect(w.tester.any(find.byKey(const Key('nav-總覽'))), isTrue,
        reason: '已回到主殼（首次啟動等價狀態）');
  });
}
