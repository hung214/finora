import 'package:flutter/material.dart';

/// 金額計算機鍵盤（F02 S2.9：常駐四則運算；PM 2026-10-20 增補）。
///
/// - 鍵面：0-9／＋－×÷／＝／C／⌫；TWD 無小數點（依幣別 exponent，S2.1 邊界；
///   多幣別隨 M2 S2.8 擴充）。
/// - 常駐輸入（金額欄 `TextInputType.none` 不彈系統鍵盤）。
/// - [onExprChanged]：運算式狀態變更（含 ＝ 求值結果）；呼叫端同步顯示與
///   controller——儲存啟用由「純數字 > 0」決定，運算式未完成（含尾運算子）
///   自然禁用。
/// - 慣例：首鍵運算子忽略；連按運算子→**取代**前一運算子；＝ 對無效運算式
///   （空/尾運算子/÷0/非法字元）為 no-op（保留原式，不可儲存）。
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.expr, required this.onExprChanged});

  /// 當前運算式（如 "120＋45"；狀態由呼叫端持有——本元件受控）。
  final String expr;
  final ValueChanged<String> onExprChanged;

  static const String _operators = '＋－×÷';

  void _tap(String label) {
    switch (label) {
      case 'C':
        onExprChanged('');
        return;
      case '⌫':
        onExprChanged(expr.isEmpty ? '' : expr.substring(0, expr.length - 1));
        return;
      case '＝':
        final result = AmountKeypadEvaluator.evaluate(expr);
        if (result != null) onExprChanged('$result'); // 無效：保留原式
        return;
      case '＋' || '－' || '×' || '÷':
        if (expr.isEmpty) return; // 首鍵運算子：忽略
        final last = expr[expr.length - 1];
        if (_operators.contains(last)) {
          onExprChanged('${expr.substring(0, expr.length - 1)}$label'); // 連按取代
        } else {
          onExprChanged('$expr$label');
        }
        return;
      default: // 數字
        onExprChanged('$expr$label');
    }
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '－'],
      ['C', '0', '⌫', '＋'],
    ];
    return Container(
      key: const Key('amount-keypad'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Row(
              children: [
                for (final label in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: FilledButton.tonal(
                        key: Key('keypad-$label'),
                        onPressed: () => _tap(label),
                        child: Text(label,
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('keypad-＝'),
                onPressed: () => _tap('＝'),
                child: const Text('＝', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 運算式求值（純函數；F02 S2.9）。
///
/// 左至右、**無運算子優先權**（計算機慣例，如 2×30＋10 = (2×30)＋10 = 70）；
/// 結果四捨五入至整數（TWD 無小數位，S2.1 邊界）。無效運算式回 null：
/// 空、尾運算子、÷0、非法字元——＝ 保持原式（儲存禁用）。
class AmountKeypadEvaluator {
  AmountKeypadEvaluator._();

  static final _tokenRegex = RegExp(r'\d+|[＋－×÷]');

  static int? evaluate(String expr) {
    if (expr.isEmpty) return null;
    if (AmountKeypad._operators.contains(expr[expr.length - 1])) return null;
    final tokens = _tokenRegex.allMatches(expr).map((m) => m.group(0)!).toList();
    if (tokens.join() != expr) return null; // 非法字元
    if (tokens.isEmpty || tokens.length % 2 == 0) return null; // 數字(運算子數字)*
    var acc = num.parse(tokens[0]);
    for (var i = 1; i < tokens.length; i += 2) {
      final operand = num.parse(tokens[i + 1]);
      switch (tokens[i]) {
        case '＋':
          acc += operand;
        case '－':
          acc -= operand;
        case '×':
          acc *= operand;
        case '÷':
          if (operand == 0) return null;
          acc /= operand;
      }
    }
    return acc.round();
  }
}
