import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/presentation/screens/quick_entry/amount_keypad.dart';

/// 計算機鍵盤（F02 S2.9）：求值器純函數＋鍵盤互動慣例。
void main() {
  group('AmountKeypadEvaluator（左至右、無優先權、TWD 四捨五入）', () {
    test('基本四則', () {
      expect(AmountKeypadEvaluator.evaluate('120＋45'), 165);
      expect(AmountKeypadEvaluator.evaluate('500－80'), 420);
      expect(AmountKeypadEvaluator.evaluate('100÷4'), 25);
      expect(AmountKeypadEvaluator.evaluate('12×30'), 360);
    });

    test('左至右無優先權（計算機慣例）：2×30＋10 = 70', () {
      expect(AmountKeypadEvaluator.evaluate('2×30＋10'), 70);
      expect(AmountKeypadEvaluator.evaluate('10＋2×3'), 36); // (10＋2)×3
    });

    test('四捨五入至整數元（TWD 無小數位，S2.1 邊界）', () {
      expect(AmountKeypadEvaluator.evaluate('100÷3'), 33);
      expect(AmountKeypadEvaluator.evaluate('5÷2'), 3); // 2.5 → 3
    });

    test('無效運算式 → null（＝ 保持原式不可儲存）', () {
      expect(AmountKeypadEvaluator.evaluate(''), isNull);
      expect(AmountKeypadEvaluator.evaluate('120＋'), isNull); // 尾運算子
      expect(AmountKeypadEvaluator.evaluate('100÷0'), isNull); // ÷0
      expect(AmountKeypadEvaluator.evaluate('1a2'), isNull); // 非法字元
    });

    test('純數字＝原值', () {
      expect(AmountKeypadEvaluator.evaluate('120'), 120);
      expect(AmountKeypadEvaluator.evaluate('0'), 0);
    });

    test('小數點（PM 2026-10-22）：.5 簡寫／結果四捨五入至整數元', () {
      expect(AmountKeypadEvaluator.evaluate('.5'), 1); // 0.5 → 1（round）
      expect(AmountKeypadEvaluator.evaluate('99.5＋0.5'), 100);
      expect(AmountKeypadEvaluator.evaluate('1.2×3'), 4); // 3.6 → 4
      expect(AmountKeypadEvaluator.evaluate('1.2.3'), isNull); // 非法
    });
  });

  testWidgets('鍵盤互動：數字／連按運算子取代／⌫／C／＝求值', (tester) async {
    var expr = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AmountKeypad(
            expr: expr,
            onExprChanged: (e) => setState(() => expr = e),
          ),
        ),
      ),
    ));

    Future<void> tap(String label) async {
      await tester.tap(find.byKey(Key('keypad-$label')));
      await tester.pump();
    }

    await tap('＋');
    expect(expr, isEmpty, reason: '首鍵運算子：忽略');
    await tap('1');
    await tap('2');
    await tap('0');
    expect(expr, '120');
    await tap('＋');
    expect(expr, '120＋');
    await tap('×');
    expect(expr, '120×', reason: '連按運算子 → 取代前一運算子');
    await tap('4');
    expect(expr, '120×4');
    await tap('＝');
    expect(expr, '480');
    await tap('⌫');
    expect(expr, '48');
    await tap('C');
    expect(expr, isEmpty);
  });
}
