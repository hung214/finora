/// 金額值物件：一律以整數 minor units 儲存與運算，禁用浮點（SDD §4.2 設計要點）。
///
/// - TWD 無小數位（exponent = 0，minor = 元）；USD/EUR 等 exponent = 2。
/// - 幣別不同不可加減（ArgumentError）。
class Money {
  const Money(this.minorUnits, {this.currency = 'TWD'});

  final int minorUnits;
  final String currency;

  static const Map<String, int> _exponents = {
    'TWD': 0, 'JPY': 0,
    'USD': 2, 'EUR': 2, 'CNY': 2,
  };

  static const Map<String, String> _symbols = {
    'TWD': r'NT$', 'JPY': r'¥', 'USD': r'US$', 'EUR': r'€', 'CNY': r'CN¥',
  };

  int get exponent => _exponents[currency] ?? 2;

  /// 由主要單位建立（例：Money.fromMajor(32.5, currency: 'USD') = 3250 minor）。
  factory Money.fromMajor(num major, {String currency = 'TWD'}) {
    final exp = _exponents[currency] ?? 2;
    final factor = exp == 0 ? 1 : 100;
    return Money((major * factor).round(), currency: currency);
  }

  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency: currency);
  }

  Money negated() => Money(-minorUnits, currency: currency);

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  /// 顯示格式：依幣別小數位數（TWD 無小數位）。
  String format({bool withSymbol = true}) {
    final symbol = withSymbol ? (_symbols[currency] ?? '$currency ') : '';
    final exp = exponent;
    if (exp == 0) return '$symbol$minorUnits';
    final sign = minorUnits < 0 ? '-' : '';
    final abs = minorUnits.abs().toString().padLeft(exp + 1, '0');
    final major = abs.substring(0, abs.length - exp);
    final minor = abs.substring(abs.length - exp);
    return '$symbol$sign$major.$minor';
  }

  void _checkSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('幣別不一致: $currency vs ${other.currency}');
    }
  }

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits && other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
