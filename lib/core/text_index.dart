/// FTS5 索引文字產生（FR-R3：中文 bigram——unicode61 不切中文，research D13/SP-1）。
///
/// 規則：
/// - CJK 連續段 → 2 字 shingle（空白分隔）；單字段落 → 該字自身。
/// - 非 CJK 連續段（英數）→ 整段一個 token（保留原樣）。
/// - 例：`陽光超商` → `陽光 光超 超商`；`IKEA 午餐` → `IKEA 午餐`。
/// - 查詢側同函式產生 MATCH 字串（FTS5 隱式 AND 各 token）。
class TextIndex {
  TextIndex._();

  /// 產生索引／查詢字串；空值回 null（欄位不入索引）。
  static String? bigram(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final tokens = <String>[];
    final run = StringBuffer();
    var runIsCjk = _isCjk(trimmed[0]);
    void flush() {
      if (run.isEmpty) return;
      final s = run.toString();
      if (runIsCjk) {
        if (s.length == 1) {
          tokens.add(s);
        } else {
          for (var i = 0; i < s.length - 1; i++) {
            tokens.add(s.substring(i, i + 2));
          }
        }
      } else {
        tokens.add(s);
      }
      run.clear();
    }

    for (final ch in trimmed.split('')) {
      final cjk = _isCjk(ch);
      if (ch == ' ' || cjk != runIsCjk) {
        flush();
        runIsCjk = cjk;
      }
      if (ch != ' ') run.write(ch);
    }
    flush();
    return tokens.isEmpty ? null : tokens.join(' ');
  }

  /// CJK 統一表意文字基本區（含常用標點判為 CJK 以利切分——僅取漢字區間）。
  static bool _isCjk(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF);
  }

  /// FTS5 MATCH 查詢字串：token 逐個加引號（防查詢語法注入），隱式 AND。
  static String? matchQuery(String? text) {
    final b = bigram(text);
    if (b == null) return null;
    return b
        .split(' ')
        .map((t) => '"${t.replaceAll('"', '')}"')
        .join(' ');
  }
}
