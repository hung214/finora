import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/core/hlc.dart';

void main() {
  group('HLC（同步版本戳，SDD §5.5.4）', () {
    test('序列化格式：015d 毫秒 + 05d 計數器 + deviceId', () {
      const h = Hlc(1760760000123, 5, 'd-A1B2');
      expect(h.toString(), '001760760000123.00005.d-A1B2');
    });

    test('parse 與 toString 往返一致', () {
      const s = '001760760000123.00005.d-A1B2';
      expect(Hlc.parse(s).toString(), s);
    });

    test('parse 拒絕錯誤格式', () {
      expect(() => Hlc.parse('bad-format'), throwsFormatException);
    });

    test('compareTo：毫秒 → 計數器 → 裝置 ID', () {
      const a = Hlc(100, 1, 'd-A');
      const b = Hlc(200, 0, 'd-A');
      const c = Hlc(100, 2, 'd-A');
      expect(b > a, isTrue);
      expect(c > a, isTrue);
      expect(Hlc(100, 1, 'd-B') > a, isTrue); // 同毫秒同計數器 → 裝置 ID 決勝
    });

    test('receive：遠端較新時採遠端毫秒、計數器歸零', () {
      const local = Hlc(100, 3, 'd-A');
      const remote = Hlc(200, 1, 'd-B');
      final next = local.receive(remote, 'd-A', nowMs: 150);
      expect(next.milliseconds, 200);
      expect(next.counter, 0);
      expect(next.deviceId, 'd-A');
    });

    test('receive：牆鐘超前時以牆鐘為準', () {
      const local = Hlc(100, 3, 'd-A');
      const remote = Hlc(200, 1, 'd-B');
      final next = local.receive(remote, 'd-A', nowMs: 300);
      expect(next.milliseconds, 300);
      expect(next.counter, 0);
    });

    test('receive：同毫秒因果鏈計數器 +1', () {
      final local = Hlc(200, 3, 'd-A');
      const remote = Hlc(200, 1, 'd-B');
      final next = local.receive(remote, 'd-A', nowMs: 150);
      expect(next.milliseconds, 200);
      expect(next.counter, 4);
    });

    test('max 取較新者（LWW 判定）', () {
      const a = Hlc(100, 9, 'd-A');
      const b = Hlc(200, 0, 'd-B');
      expect(Hlc.max(a, b), b);
    });
  });
}
