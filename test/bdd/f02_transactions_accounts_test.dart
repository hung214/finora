import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/quick_entry/save_transaction_use_case.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/entities/account.dart';
import 'package:ledger_sync/domain/entities/transaction.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';

/// F02-BE 情境執行器（@BE @M1 @FR-T @FR-A @P0，5 情境）。
///
/// 來源：specs/plan/tests/backend/F02_transactions-accounts.feature（tool/sync_features.ps1
/// 同步至 test/bdd/，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
/// 多幣別情境 @P1 @M2 屬 M2 範圍（M1 僅執行 @P0）。
void main() {
  final source = File('test/bdd/F02_transactions-accounts.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F02-BE：交易與帳戶領域邏輯（5 情境：金額驗證／轉帳守恆／儲值語意／軟刪除／還款）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      final executed =
          await runner.run(doc, tagFilter: (tags) => tags.contains('@BE') && tags.contains('@P0'));
      expect(executed, 5, reason: 'F02-BE 應執行 5 個情境（@BE @P0；多幣別 @P1 @M2 屬 M2）');
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

  /// 名稱 → id 對映（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};

  /// Given 已儲存之「金額 → 交易 id」（軟刪除斷言用）。
  final txIdByAmount = <int, String>{};

  /// When 步驟前的 oplog 數（「oplog 新增 N 筆」之 delta 基準）。
  int opBaseline = 0;

  /// When 步驟前的交易筆數（「且不入庫」之 delta 基準）。
  int txCountBaseline = 0;

  /// 最近一次驗證失敗訊息（未拋例外為 null）。
  String? validationError;
}

void _bind(GherkinRunner runner, _World w) {
  // ── Given：環境 ─────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.accounts.clear();
    w.categories.clear();
    w.txIdByAmount.clear();
    w.opBaseline = 0;
    w.txCountBaseline = 0;
    w.validationError = null;
    w.save = SaveTransactionUseCase(db);
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
      // kind 對齊內建集（first_run_bootstrap）：薪資 = income，其餘 = expense。
      DbFixture.seedCategory(
        w.db,
        id: id,
        kind: name == '薪資' ? 'income' : 'expense',
        name: name,
      );
      w.categories[name] = id;
    }
  });

  // ── When：儲存驗證（F02 S2.1）────────────────────────────
  runner.on(r'呼叫 SaveTransactionUseCase（金額 {amt}）$', (p) {
    w.opBaseline = w.db.allOps().length;
    w.txCountBaseline = w.db.allTransactions().length;
    try {
      w.save.execute(
        accountId: w.accounts['現金']!,
        amountMinor: _amount(p['amt']!),
        occurredAt: Clock.now(),
      );
      w.validationError = null;
    } on TransactionValidationException catch (e) {
      w.validationError = e.message;
    }
  });

  // ── Then：驗證輸出（F02 S2.1）────────────────────────────
  runner.on(r'顯示「{message}」且不入庫$', (p) {
    expect(w.validationError, p['message'], reason: '驗證失敗訊息（FE 顯示契約）');
    expect(w.db.allTransactions().length, w.txCountBaseline, reason: '驗證失敗不得入庫');
  });

  runner.on(r'oplog 新增 {n} 筆且皆未打包$', (p) {
    final ops = w.db.allOps();
    final added = ops.skip(w.opBaseline).toList();
    expect(added.length, int.parse(p['n']!), reason: 'oplog 新增筆數');
    for (final op in added) {
      expect(op.packedSeq, isNull, reason: '未打包（待 SyncCoordinator，F07）');
    }
  });
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

Account _accountEntity(AccountRow r) => Account(
      id: r.id,
      type: AccountType.values.byName(r.type),
      name: r.name,
      currency: r.currency,
      openingAmountMinor: r.openingAmountMinor,
      archived: r.archived,
    );

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));
