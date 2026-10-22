import '../../data/sqlite/app_database.dart';
import '../../domain/entities/account.dart';
import '../../domain/services/balance_calculator.dart';
import '../mappers.dart';

/// 總覽合計（SPEC FR-A6；FR-A2 include_in_totals 語意）：
/// **僅計入 `includeInTotals && !archived` 之帳戶**。
class TotalsService {
  TotalsService(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;
  final String deviceId;

  static const calc = BalanceCalculator();

  AccountTotals compute() {
    final txs = _db.allTransactions().map(txEntity).toList();
    final accounts = _db
        .allAccounts()
        .where((a) => a.includeInTotals && !a.archived)
        .map(accountEntity)
        .toList();
    final assets = accounts
        .where((a) => a.type != AccountType.credit)
        .fold<int>(0, (s, a) => s + calc.assetBalance(account: a, txs: txs));
    final liabilities = accounts
        .where((a) => a.type == AccountType.credit)
        .fold<int>(0, (s, a) => s + calc.creditUnpaidTotal(card: a, txs: txs));
    return AccountTotals(assetsMinor: assets, liabilitiesMinor: liabilities);
  }
}

class AccountTotals {
  const AccountTotals({required this.assetsMinor, required this.liabilitiesMinor});

  final int assetsMinor;
  final int liabilitiesMinor;

  int get netWorthMinor => assetsMinor - liabilitiesMinor;
}
