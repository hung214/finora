import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/core/hlc.dart';

/// T-H2 驗收：可注入時鐘（fake clock）——結帳日/預算週期/逾期判定之時間相依測試的地基。
/// 紅燈階段：Clock 尚未實作。
void main() {
  tearDown(() {
    Clock.unfreeze();
  });

  test('freeze 凍結後 now 固定不動', () {
    Clock.freeze(DateTime.utc(2026, 10, 18, 9, 0));
    expect(Clock.now(), DateTime.utc(2026, 10, 18, 9, 0));
  });

  test('advance 快轉（模擬時間流逝）', () {
    Clock.freeze(DateTime.utc(2026, 6, 1));
    Clock.advance(const Duration(days: 30));
    expect(Clock.now(), DateTime.utc(2026, 7, 1));
  });

  test('unfreeze 恢復系統時間', () {
    Clock.freeze(DateTime.utc(2026, 1, 1));
    Clock.unfreeze();
    expect(Clock.now().isAfter(DateTime.utc(2026, 1, 2)), isTrue);
  });

  test('advance 未 freeze 時拋錯（避免誤用）', () {
    expect(() => Clock.advance(const Duration(days: 1)), throwsStateError);
  });

  test('nowMs 供 HLC 使用；Hlc.now 跟隨 Clock 凍結（單一時間來源）', () {
    Clock.freeze(DateTime.utc(2026, 10, 18, 9, 30));
    final h = Hlc.now('d-A');
    expect(h.milliseconds, Clock.nowMs());
  });
}
