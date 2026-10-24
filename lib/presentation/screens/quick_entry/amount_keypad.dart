import 'package:flutter/material.dart';

/// 金額計算機鍵盤（F02 S2.9：常駐四則運算）。
///
/// **版面（PM 2026-10-24 定稿）**
/// ```
/// [C] [⌫] [OK]      ← 第一排＝C／刪除／OK（OK 取代原「＝」的位置與角色）
/// [7] [8] [9] [÷]
/// [4] [5] [6] [×]
/// [1] [2] [3] [－]
/// [   0   ] [.] [＋]  ← 0 跨兩格；＋ 移至原 ⌫ 位置
/// ```
/// - **無「＝」鍵**：運算式由呼叫端**即時求值**（未完成→儲存禁用）。
/// - [onExprChanged]：運算式狀態變更；呼叫端同步顯示與 controller。
/// - [onOk]／[okEnabled]：OK 儲存（鍵 `quick-entry-save`）。
/// - 慣例：首鍵運算子忽略；連按運算子→**取代**前一運算子。
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.expr,
    required this.onExprChanged,
    this.onOk,
    this.okEnabled = false,
  });

  /// 當前運算式（如 "120＋45"；狀態由呼叫端持有——本元件受控）。
  final String expr;
  final ValueChanged<String> onExprChanged;

  /// OK 儲存（PM 2026-10-24：鍵盤第一排）。
  final VoidCallback? onOk;
  final bool okEnabled;

  static const String _operators = '＋－×÷';

  void _tap(String label) {
    switch (label) {
      case 'C':
        onExprChanged('');
        return;
      case '⌫':
        onExprChanged(expr.isEmpty ? '' : expr.substring(0, expr.length - 1));
        return;
      case '.':
        // 小數點（PM 2026-10-22）：運算子後自動補 0.；同數字 token 內限一個。
        if (expr.isEmpty || _operators.contains(expr[expr.length - 1])) {
          onExprChanged('${expr}0.');
          return;
        }
        final lastNum = expr.split(RegExp(r'[＋－×÷]')).last;
        if (lastNum.contains('.')) return; // 一數一點
        onExprChanged('$expr.');
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

  Widget _key(BuildContext context, String label,
      {bool primary = false, VoidCallback? onTap, int flex = 1}) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          // 圓角矩形（10 雛型；PM 2026-10-24：非膠囊）。
          color: primary ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('keypad-$label'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap ?? () => _tap(label),
            child: SizedBox(
              height: 46,
              child: Center(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 19,
                        color: primary ? scheme.onPrimary : scheme.onSurface)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('amount-keypad'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一排：C／⌫／OK（OK 取代「＝」；key 沿用 quick-entry-save）。
          Row(
            children: [
              _key(context, 'C'),
              _key(context, '⌫'),
              // OK **跨兩格**（10／03 雛型 grid-column:span 2）——第一排共 4 格對齊。
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Material(
                    color: okEnabled
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: const Key('quick-entry-save'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: okEnabled ? onOk : null,
                      child: SizedBox(
                        height: 46,
                        child: Center(
                          child: Text('OK',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: okEnabled
                                      ? scheme.onPrimary
                                      : scheme.outline)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (final row in const [
            ['7', '8', '9', '÷'],
            ['4', '5', '6', '×'],
            ['1', '2', '3', '－'],
          ])
            Row(children: [for (final label in row) _key(context, label)]),
          // 末排：0 跨兩格、小數點、＋（＋ 移至原 ⌫ 位置；＝ 已移除）。
          Row(children: [
            _key(context, '0', flex: 2),
            _key(context, '.'),
            _key(context, '＋'),
          ]),
        ],
      ),
    );
  }
}

/// 運算式求值（純函數；F02 S2.9）。
///
/// 左至右、**無運算子優先權**（計算機慣例，如 2×30＋10 = (2×30)＋10 = 70）；
/// 結果四捨五入至整數（TWD 無小數位，S2.1 邊界）。無效運算式回 null：
/// 空、尾運算子、÷0、非法字元——**即時求值**（PM 2026-10-24 移除 ＝ 鍵：
/// 未完成／無效 → 金額未定 → OK 禁用）。
class AmountKeypadEvaluator {
  AmountKeypadEvaluator._();

  static final _tokenRegex = RegExp(r'\d+(?:\.\d+)?|\.\d+|[＋－×÷]');

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
