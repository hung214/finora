import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/gherkin/gherkin.dart';

void main() {
  test('probe: F06 FE parse', () {
    final doc = GherkinParser.parse(
        File('integration_test/features/F06_recurring-transactions.feature')
            .readAsStringSync());
    for (final sc in doc.scenarios) {
      // ignore: avoid_print
      print('SCENARIO: ${sc.name}');
      for (final s in [...doc.background, ...sc.steps]) {
        // ignore: avoid_print
        print('  ${s.keyword} |${s.text}|');
      }
    }
    expect(doc.scenarios.length, 4);
  });
}
