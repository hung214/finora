import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/domain/entities/account.dart';
import 'package:ledger_sync/domain/entities/transaction.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';

void main() {
  const calc = BalanceCalculator();

  const cash = Account(id: 'cash', type: AccountType.cash, name: '現金', openingAmountMinor: 1000);
  const bank = Account(id: 'bank', type: AccountType.bank, name: '銀行', openingAmountMinor: 10000);
  const card = Account(id: 'card', type: AccountType.credit, name: '富邦卡');

  group('BalanceCalculator（衍生餘額原則，SDD §4.3）', () {
    test('AC-10 轉帳守恆：現金 1000/銀行 10000 轉帳 400 → 600/10400', () {
      const txs = [
        Tx(id: 't1', kind: TxKind.transfer, amountMinor: 400, accountId: 'cash', toAccountId: 'bank'),
      ];
      expect(calc.assetBalance(account: cash, txs: txs), 600);
      expect(calc.assetBalance(account: bank, txs: txs), 10400);
    });

    test('收入與支出即時反映', () {
      const txs = [
        Tx(id: 't1', kind: TxKind.income, amountMinor: 30000, accountId: 'bank'),
        Tx(id: 't2', kind: TxKind.expense, amountMinor: 120, accountId: 'cash'),
      ];
      expect(calc.assetBalance(account: cash, txs: txs), 880);
      expect(calc.assetBalance(account: bank, txs: txs), 40000);
    });

    test('墓標交易排除（SDD 原則 5）', () {
      const txs = [
        Tx(id: 't1', kind: TxKind.expense, amountMinor: 120, accountId: 'cash', deleted: true),
      ];
      expect(calc.assetBalance(account: cash, txs: txs), 1000);
    });

    test('信用卡還款從扣款帳戶轉出（FR-C4）', () {
      const txs = [
        Tx(id: 't1', kind: TxKind.repayment, amountMinor: 5000, accountId: 'bank', toAccountId: 'card'),
      ];
      expect(calc.assetBalance(account: bank, txs: txs), 5000);
    });

    test('退款不影響資產帳戶（作用於信用卡負債面）', () {
      const txs = [
        Tx(id: 't1', kind: TxKind.refund, amountMinor: 1000, accountId: 'card'),
      ];
      expect(calc.assetBalance(account: bank, txs: txs), 10000);
    });

    test('信用卡本期應付：預扣累加、退款扣減（FR-C1 骨架版）', () {
      const txs = [
        Tx(id: 't1', kind: TxKind.expense, amountMinor: 3000, accountId: 'card', settlementStatus: SettlementStatus.pending),
        Tx(id: 't2', kind: TxKind.expense, amountMinor: 5000, accountId: 'card', settlementStatus: SettlementStatus.pending),
        Tx(id: 't3', kind: TxKind.refund, amountMinor: 1000, accountId: 'card', settlementStatus: SettlementStatus.pending),
        Tx(id: 't4', kind: TxKind.expense, amountMinor: 2000, accountId: 'card', settlementStatus: SettlementStatus.billed),
      ];
      expect(calc.creditOpenBalance(card: card, txs: txs), 7000);
    });
  });
}
