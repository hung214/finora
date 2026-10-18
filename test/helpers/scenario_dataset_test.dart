import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/entities/transaction.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

import 'db_fixture.dart';

/// T-H5 驗收：標準劇例資料集（acceptance 各 Feature 背景資料的一鍵建立）。
Tx _toTx(TxRow r) => Tx(
      id: r.id,
      kind: switch (r.kind) {
        'income' => TxKind.income,
        'transfer' => TxKind.transfer,
        'repayment' => TxKind.repayment,
        'refund' => TxKind.refund,
        _ => TxKind.expense,
      },
      amountMinor: r.amountMinor,
      accountId: r.accountId,
      toAccountId: r.toAccountId,
      occurredAt: r.occurredAt,
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    db = DbFixture.create();
    await DbFixture.seedStandardScenario(db);
  });

  tearDown(() {
    db.close();
  });

  test('帳戶：4 個（現金 1,000／銀行 10,000／票證卡 0／示例卡 0）', () {
    final accounts = db.allAccounts();
    expect(accounts, hasLength(4));
    expect(
        accounts.map((a) => a.name), containsAll(['現金', '銀行', '票證卡', '示例卡']));
    expect(accounts.firstWhere((a) => a.id == 'cash').openingAmountMinor, 1000);
  });

  test('分類：支出 4（餐飲/交通/購物/其他-內建）＋收入 1（薪資）', () {
    final expense = db.categoriesByKind('expense');
    expect(expense, hasLength(4));
    expect(expense.where((c) => c.isSystem).map((c) => c.name), contains('其他'));
    expect(db.categoriesByKind('income').map((c) => c.name), contains('薪資'));
  });

  test('交易與 oplog：3 筆交易 → 3 筆未打包 oplog（儲存事務）', () {
    expect(db.transactionsByAccount('cash'), hasLength(2)); // 支出 120＋轉出 400
    expect(db.allTransactions(), hasLength(3));
    final ops = db.allOps();
    expect(ops, hasLength(3));
    expect(ops.every((o) => o.packedSeq == null), isTrue);
  });

  test('衍生餘額由標準資料集重算：現金 480／銀行 40,400（AC-10 語意）', () {
    final accounts = {for (final a in db.allAccounts()) a.id: a};
    final txs = db.allTransactions().map(_toTx).toList();
    const calc = BalanceCalculator();
    expect(calc.assetBalance(account: accounts['cash']!, txs: txs), 480);
    expect(calc.assetBalance(account: accounts['bank']!, txs: txs), 40400);
  });
}
