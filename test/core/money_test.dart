import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/core/money.dart';

void main() {
  group('Money（金額一律整數 minor units，禁用浮點）', () {
    test('加減法（TWD 無小數位）', () {
      const a = Money(1000);
      const b = Money(400);
      expect((a - b).minorUnits, 600);
      expect((a + b).minorUnits, 1400);
    });

    test('fromMajor：TWD exponent=0', () {
      expect(Money.fromMajor(100).minorUnits, 100);
    });

    test('fromMajor：USD exponent=2（32.5 → 3250，round 避免浮點誤差）', () {
      expect(Money.fromMajor(32.5, currency: 'USD').minorUnits, 3250);
    });

    test('幣別不一致禁止加減', () {
      expect(() => const Money(100) + const Money(100, currency: 'USD'),
          throwsArgumentError);
    });

    test('format：TWD 含負數', () {
      expect(const Money(-120).format(), r'NT$-120');
      expect(const Money(195).format(withSymbol: false), '195');
    });

    test('format：USD 兩位小數', () {
      expect(const Money(3250, currency: 'USD').format(), r'US$32.50');
    });

    test('isZero / isPositive / isNegative', () {
      expect(const Money(0).isZero, isTrue);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(1).isPositive, isTrue);
    });
  });
}
