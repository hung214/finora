/// 可注入時鐘（T-H2）：所有時間相依邏輯（結帳日、預算週期、逾期判定、定期交易）
/// 一律經 [Clock.now] 取時，測試以 [freeze]/[advance]/[unfreeze] 控制——
/// 這是 fake clock 掛鉤的單一來源（specs/plan/tasks.md §2、dsl.md §2.1）。
class Clock {
  Clock._();

  static DateTime? _frozen;

  /// 目前時間：凍結時回傳凍結值，否則回傳系統時間。
  static DateTime now() => _frozen ?? DateTime.now();

  static int nowMs() => now().millisecondsSinceEpoch;

  /// 凍結時間（測試用）。
  static void freeze(DateTime dateTime) => _frozen = dateTime;

  /// 自凍結點快轉；未凍結時拋錯（避免誤改系統時間）。
  static void advance(Duration duration) {
    final frozen = _frozen;
    if (frozen == null) {
      throw StateError('Clock.advance 需在 freeze 之後使用');
    }
    _frozen = frozen.add(duration);
  }

  /// 解除凍結，恢復系統時間。
  static void unfreeze() => _frozen = null;
}
