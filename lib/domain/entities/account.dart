/// 帳戶實體（SDD §4.2 accounts 表的領域對映）。
///
/// 餘額永不儲存於本實體——一律由 [BalanceCalculator] 由交易重算（SDD 原則 2）。
enum AccountType { cash, bank, credit, ewallet, other }

class Account {
  const Account({
    required this.id,
    required this.type,
    required this.name,
    this.currency = 'TWD',
    this.openingAmountMinor = 0,
    this.archived = false,
  });

  final String id;
  final AccountType type;
  final String name;
  final String currency;

  /// 期初餘額（minor units）。
  final int openingAmountMinor;

  final bool archived;
}
