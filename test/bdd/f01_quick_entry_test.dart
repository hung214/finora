import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/quick_entry/quick_entry_preset_service.dart';
import 'package:ledger_sync/application/quick_entry/save_transaction_use_case.dart';
import 'package:ledger_sync/application/quick_entry/undo_last_transaction_use_case.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/entities/account.dart';
import 'package:ledger_sync/domain/entities/transaction.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';
import '../helpers/in_memory_cloud_adapter.dart';

/// F01-BE 情境執行器（@BE @M1 @FR-Q @P0，8 情境）。
///
/// 來源：specs/plan/tests/backend/F01_quick-entry.feature（tool/sync_features.ps1
/// 同步至 test/bdd/，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
void main() {
  final source = File('test/bdd/F01_quick-entry.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F01-BE：快速記帳領域邏輯（8 情境：智慧預設×4／儲存事務／Undo／離線／效能）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      final executed =
          await runner.run(doc, tagFilter: (tags) => tags.contains('@BE') && tags.contains('@P0'));
      expect(executed, 9, reason: 'F01-BE 應執行 9 個情境（@BE @P0，含 DBG-003 回歸）');
      // ignore: avoid_print
      print(runner.log.join('\n'));
    } finally {
      Clock.unfreeze();
      for (final db in w.dbs) {
        db.close();
      }
    }
  });
}

/// 情境共享狀態（每 Scenario 由 Background 重置）。
class _World {
  final List<AppDatabase> dbs = [];
  late AppDatabase db;
  late SaveTransactionUseCase save;
  late UndoLastTransactionUseCase undo;
  late QuickEntryPresetService preset;

  QuickEntryPreset? presetResult;
  SaveTransactionResult? lastSave;
  UndoTransactionResult? undoResult;

  /// 名稱 → id 對映（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};

  /// Given 已儲存之「金額 → 交易 id」（Undo 斷言用）。
  final txIdByAmount = <int, String>{};

  /// When 步驟前的 oplog 數（「oplog 新增 N 筆」之 delta 基準）。
  int opBaseline = 0;
  List<Duration> saveTimings = [];
  InMemoryCloudAdapter? cloud;
}

void _bind(GherkinRunner runner, _World w) {
  /// 歷史交易播種（FR-Q4 輸入；帳戶/分類以名稱對映背景已建立者）。
  void seedHistoryTx(
    DateTime at, {
    required String? accountName,
    required String categoryName,
    required int amount,
    String? merchant,
  }) {
    DbFixture.seedTx(
      w.db,
      id: 'tx-h-${w.db.allTransactions().length}',
      kind: 'expense',
      amountMinor: amount,
      accountId: accountName == null
          ? _firstActiveAccount(w.db).id
          : w.accounts[accountName]!,
      category: w.categories[categoryName],
      merchant: merchant,
      occurredAt: at.millisecondsSinceEpoch,
    );
  }

  // ── Given：環境 ─────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.accounts.clear();
    w.categories.clear();
    w.txIdByAmount.clear();
    w.save = SaveTransactionUseCase(db);
    w.undo = UndoLastTransactionUseCase(db);
    w.preset = QuickEntryPresetService(db);
    w.presetResult = null;
    w.lastSave = null;
    w.undoResult = null;
    w.opBaseline = 0;
    w.saveTimings = [];
    w.cloud = null;
  });

  runner.on(r'已建立帳戶「{name}」類型 {type} 期初 {amount}$', (p) {
    final id = 'a-${w.accounts.length}';
    // fixture 內部為同步寫入（Future 僅為介面一致），直接呼叫不 await。
    DbFixture.seedAccount(
      w.db,
      id: id,
      type: p['type']!,
      name: p['name']!,
      opening: _amount(p['amount']!),
    );
    w.accounts[p['name']!] = id;
  });

  runner.on(r'已建立分類{names}$', (p) {
    final names = RegExp('「([^」]+)」')
        .allMatches(p['names']!)
        .map((m) => m.group(1)!)
        .toList();
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final id = 'c-${w.categories.length}';
      DbFixture.seedCategory(
        w.db,
        id: id,
        kind: 'expense',
        name: name,
        isSystem: name == '其他',
      );
      w.categories[name] = id;
    }
  });

  runner.on(r'模擬系統時間為 {dt}$', (p) => Clock.freeze(_dateTime(p['dt']!)));

  runner.on(r'模擬雲端為 in-memory adapter 且已連結$', (p) {
    w.cloud = InMemoryCloudAdapter(configured: true);
  });

  runner.on(r'連線已關閉$', (p) {
    w.cloud!.failing = true; // 模擬離線：任何雲端存取拋 CloudUnavailableException
  });

  // ── Given：歷史資料（FR-Q4 規則輸入）─────────────────────
  runner.on(r'歷史: {desc}$', (p) {
    for (final seg
        in p['desc']!.split(RegExp(r'[；;]')).map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      final single = RegExp(r'^(今日|昨日) (\d{1,2}):(\d{2}) ([^/／]+)/(\S+) (\d[\d,]*)$')
          .firstMatch(seg);
      if (single != null) {
        final base = Clock.now();
        final day = single.group(1) == '昨日' ? 1 : 0;
        seedHistoryTx(
          DateTime(base.year, base.month, base.day - day, int.parse(single.group(2)!),
              int.parse(single.group(3)!)),
          accountName: single.group(4)!,
          categoryName: single.group(5)!,
          amount: _amount(single.group(6)!),
        );
        continue;
      }
      final weekly = RegExp(r'^本週(清晨|上午|下午|晚上)([^/／]+)/(\S+) (\d+) 筆$').firstMatch(seg);
      if (weekly != null) {
        final base = Clock.now();
        final hour = const {'清晨': 3, '上午': 9, '下午': 15, '晚上': 21}[weekly.group(1)!];
        final n = int.parse(weekly.group(4)!);
        for (var k = 1; k <= n; k++) {
          seedHistoryTx(
            DateTime(base.year, base.month, base.day - k, hour!, 0),
            accountName: weekly.group(2)!,
            categoryName: weekly.group(3)!,
            amount: 30,
          );
        }
        continue;
      }
      throw FormatException('歷史段落句型未支援：$seg（請擴充綁定並先登記 specs/plan/tests/dsl.md）');
    }
  });

  runner.on(r'商家「{m}」過去 {n} 筆分類皆為「{c}」$', (p) {
    final base = Clock.now();
    final n = int.parse(p['n']!);
    for (var k = 1; k <= n; k++) {
      final day = DateTime(base.year, base.month, base.day - k, 20, 0); // 20:00 避開上午統計
      seedHistoryTx(day, accountName: null, categoryName: p['c']!, amount: 100, merchant: p['m']);
    }
  });

  runner.on(r'目前時段最常用分類為「{c}」$', (p) {
    final base = Clock.now();
    for (var k = 1; k <= 3; k++) {
      // 過去 3 日同時刻 → 同時段，使該分類成為目前時段最常用。
      final day = DateTime(base.year, base.month, base.day - k, base.hour, base.minute);
      seedHistoryTx(day, accountName: null, categoryName: p['c']!, amount: 50);
    }
  });

  runner.on(r'帳本無任何交易$', (p) {
    expect(w.db.allTransactions(), isEmpty, reason: '背景不應殘留交易');
  });

  runner.on(r'帳本為全新空本（無帳戶/分類/交易）$', (p) {
    // DBG-003 回歸：以全新空 DB 替換——背景所建帳戶/分類/歷史全數作廢，
    // 服務/UseCase 重新指向新 DB（fixture 層，dsl §1.5）。
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.accounts.clear();
    w.categories.clear();
    w.save = SaveTransactionUseCase(db);
    w.undo = UndoLastTransactionUseCase(db);
    w.preset = QuickEntryPresetService(db);
    w.presetResult = null;
    w.opBaseline = 0;
  });

  runner.on(r'設定 {key} = {value}$', (p) => w.db.setSetting(p['key']!, p['value']!));

  runner.on(r'固定預設 = {account}/{category}$', (p) {
    w.db.setSetting(
      'quick_entry.fixed_preset',
      jsonEncode({
        'account_id': w.accounts[p['account']!],
        'category_id': w.categories[p['category']!],
      }),
    );
  });

  runner.on(r'已儲存 {n} 筆（{amounts}）$', (p) {
    final amounts = p['amounts']!.split('、').map(_amount).toList();
    expect(amounts.length, int.parse(p['n']!), reason: '筆數與金額清單不一致');
    final base = Clock.now();
    final accountId = _firstActiveAccount(w.db).id;
    for (var i = 0; i < amounts.length; i++) {
      final id = 'tx-seed-$i';
      // 依清單順序遞減 1 分鐘，保持「先列先存」（Undo 以 oplog 建立序為準）。
      DbFixture.seedTx(
        w.db,
        id: id,
        kind: 'expense',
        amountMinor: amounts[i],
        accountId: accountId,
        category: w.categories['餐飲'],
        occurredAt: base.subtract(Duration(minutes: amounts.length - i)).millisecondsSinceEpoch,
      );
      w.txIdByAmount[amounts[i]] = id;
    }
  });

  // ── When ────────────────────────────────────────────────
  runner.on(r'呼叫 QuickEntryPresetService 計算預設（商家={m}）$', (p) {
    w.presetResult = w.preset.compute(merchant: p['m']);
  });

  runner.on(r'呼叫 QuickEntryPresetService 計算預設$', (p) {
    w.presetResult = w.preset.compute();
  });

  // 計時變體須先登記（純儲存句型為其前綴）。
  runner.on(r'呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）計時 {n} 次$', (p) {
    w.opBaseline = w.db.allOps().length;
    final at = _dateTime(p['t']!);
    final timings = <Duration>[];
    for (var i = 0; i < int.parse(p['n']!); i++) {
      final sw = Stopwatch()..start();
      w.lastSave = w.save.execute(
        accountId: w.accounts[p['a']!]!,
        categoryId: w.categories[p['c']!],
        amountMinor: _amount(p['amt']!),
        occurredAt: at,
      );
      timings.add(sw.elapsed);
    }
    w.saveTimings = timings;
  });

  runner.on(r'呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）$', (p) {
    w.opBaseline = w.db.allOps().length;
    final sw = Stopwatch()..start();
    w.lastSave = w.save.execute(
      accountId: w.accounts[p['a']!]!,
      categoryId: w.categories[p['c']!],
      amountMinor: _amount(p['amt']!),
      occurredAt: _dateTime(p['t']!),
    );
    // ignore: avoid_print
    print('入庫耗時（單筆）：${sw.elapsedMilliseconds}ms');
  });

  runner.on(r'呼叫 UndoLastTransaction$', (p) {
    w.opBaseline = w.db.allOps().length;
    w.undoResult = w.undo.execute();
  });

  // ── Then：預設輸出 ───────────────────────────────────────
  runner.on(r'預設帳戶 = 「{name}」$', (p) {
    expect(w.presetResult, isNotNull);
    expect(w.presetResult!.account?.name, p['name'], reason: 'FR-Q4 預設帳戶');
  });

  runner.on(r'預設帳戶 = 第一個未封存帳戶$', (p) {
    expect(w.presetResult, isNotNull);
    expect(w.presetResult!.account?.id, _firstActiveAccount(w.db).id, reason: 'S1.3 回退規則');
  });

  runner.on(r'預設帳戶為空（待帳戶建立）$', (p) {
    expect(w.presetResult, isNotNull);
    expect(w.presetResult!.account, isNull, reason: 'DBG-003：空帳本不崩潰，帳戶回退 null');
  });

  runner.on(r'預設分類為空（內建集隨首次設定落地）$', (p) {
    expect(w.presetResult!.category, isNull, reason: '內建集 seeding 屬 F02（首次設定）');
  });

  runner.on(r'預設分類 = 「{name}」$', (p) {
    expect(w.presetResult, isNotNull);
    expect(w.presetResult!.category?.name, p['name'], reason: 'FR-Q4 預設分類');
  });

  runner.on(r'預設時間 = {dt}$', (p) {
    expect(w.presetResult, isNotNull);
    expect(
      w.presetResult!.time.millisecondsSinceEpoch,
      _dateTime(p['dt']!).millisecondsSinceEpoch,
      reason: '預填時間 = 現在（SDD §5.1）',
    );
  });

  // ── Then：儲存事務 ───────────────────────────────────────
  runner.on(r'交易已入庫且 settlement_status = {status}$', (p) {
    final row = w.db.transactionById(w.lastSave!.transactionId);
    expect(row, isNotNull, reason: '交易應已入庫');
    expect(row!.settlementStatus, p['status']);
  });

  runner.on(r'oplog 新增 {n} 筆且皆未打包$', (p) {
    final ops = w.db.allOps();
    final added = ops.skip(w.opBaseline).toList();
    expect(added.length, int.parse(p['n']!), reason: 'oplog 新增筆數');
    for (final op in added) {
      expect(op.packedSeq, isNull, reason: '未打包（待 SyncCoordinator，F07）');
    }
  });

  runner.on(r'oplog 與交易位於同一 DB transaction（中斷模擬不產生孤兒）$', (p) {
    final txsBefore = w.db.allTransactions().length;
    final opsBefore = w.db.allOps().length;
    final now = Clock.now().millisecondsSinceEpoch;
    final probe = TxRow(
      id: 'tx-probe-$txsBefore',
      kind: 'expense',
      amountMinor: 1,
      currency: 'TWD',
      accountId: _firstActiveAccount(w.db).id,
      toAccountId: null,
      categoryId: null,
      merchant: null,
      note: null,
      occurredAt: now,
      source: 'manual',
      settlementStatus: 'none',
      createdAt: now,
      updatedAt: now,
      hlc: '1.0.test',
    );
    expect(
      () => w.db.saveTransactionWithOplog(
        probe,
        OplogRow(
          entity: 'transactions',
          entityId: probe.id,
          hlc: '1.0.test',
          payload: '{}',
          packedSeq: null,
        ),
        beforeOplog: (_) => throw Exception('模擬中斷（oplog 前拋錯）'),
      ),
      throwsA(anything),
    );
    expect(w.db.allTransactions().length, txsBefore, reason: '中斷不得殘留孤兒交易');
    expect(w.db.allOps().length, opsBefore, reason: '中斷不得殘留孤兒 oplog');
  });

  // ── Then：Undo ──────────────────────────────────────────
  runner.on(r'交易 {amount} 為軟刪除（deleted_at 非 null）$', (p) {
    final id = w.txIdByAmount[_amount(p['amount']!)];
    expect(id, isNotNull, reason: 'Given 已儲存應登記金額 → id');
    expect(w.db.transactionById(id!)!.deletedAt, isNotNull, reason: '墓標軟刪除（SDD 原則 5）');
  });

  runner.on(r'oplog 新增 {n} 筆（墓標）$', (p) {
    final ops = w.db.allOps();
    final added = ops.skip(w.opBaseline).toList();
    expect(added.length, int.parse(p['n']!), reason: '墓標 oplog 筆數');
    for (final op in added) {
      expect(op.payload, isNull, reason: 'payload=NULL = 刪除墓標（SDD §5.5.4）');
      expect(op.packedSeq, isNull);
    }
  });

  // ── Then：餘額（dsl.md §2.3 既有句型）─────────────────────
  runner.on(r'帳戶「{a}」重算餘額 = {amount}$', (p) {
    final row = w.db.allAccounts().firstWhere((r) => r.name == p['a']);
    final account = Account(
      id: row.id,
      type: AccountType.values.byName(row.type),
      name: row.name,
      currency: row.currency,
      openingAmountMinor: row.openingAmountMinor,
      archived: row.archived,
    );
    final balance = const BalanceCalculator()
        .assetBalance(account: account, txs: w.db.allTransactions().map(_txEntity));
    expect(balance, _amount(p['amount']!), reason: '衍生餘額（SDD 原則 2）');
  });

  // ── Then：效能（NFR-01）─────────────────────────────────
  runner.on(r'效能：入庫耗時 {ms}ms < 300ms（P95）$', (p) {
    expect(w.saveTimings, isNotEmpty);
    final sorted = [...w.saveTimings]..sort();
    final p95 = sorted[(sorted.length * 0.95).ceil() - 1];
    // ignore: avoid_print
    print('P95 入庫耗時實測：${p95.inMilliseconds}ms（${w.saveTimings.length} 次）');
    expect(p95.inMilliseconds, lessThan(300), reason: 'NFR-01：儲存 < 300ms（P95）');
  });
}

AccountRow _firstActiveAccount(AppDatabase db) {
  final active = db.allAccounts().where((a) => !a.archived).toList()
    ..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id); // 依建立順序（S1.3）
    });
  return active.first;
}

Tx _txEntity(TxRow r) => Tx(
      id: r.id,
      kind: TxKind.values.byName(r.kind),
      amountMinor: r.amountMinor,
      accountId: r.accountId,
      toAccountId: r.toAccountId,
      categoryId: r.categoryId,
      merchant: r.merchant,
      note: r.note,
      occurredAt: r.occurredAt,
      source: TxSource.values.byName(r.source),
      settlementStatus: SettlementStatus.values.byName(r.settlementStatus),
      deleted: r.deletedAt != null,
    );

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));

DateTime _dateTime(String s) {
  final m = RegExp(r'^(\d{4})/(\d{2})/(\d{2})(?: (\d{1,2}):(\d{2}))?$').firstMatch(s.trim());
  if (m == null) throw FormatException('日期時間格式未支援：$s（dsl.md §1-3）');
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    m.group(4) == null ? 0 : int.parse(m.group(4)!),
    m.group(5) == null ? 0 : int.parse(m.group(5)!),
  );
}
