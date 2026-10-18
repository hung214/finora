/// Hybrid Logical Clock（SDD §5.5.4）— 多裝置變更排序的唯一版本戳。
///
/// 序列化格式：`{毫秒:015d}.{計數器:05d}.{deviceId}`，例：
/// `0001760760000123.00005.d-A1B2`
///
/// - 本機寫入：[now] 或 [receive]（看過遠端事件後推進）。
/// - 合併判定：[compareTo]（毫秒 → 計數器 → 裝置 ID），保證全網嚴格可比。
class Hlc implements Comparable<Hlc> {
  const Hlc(this.milliseconds, this.counter, this.deviceId);

  final int milliseconds;
  final int counter;
  final String deviceId;

  /// 系統時鐘（可注入以便測試；T-H2 fake clock 原則）。
  static int Function() clock = () => DateTime.now().millisecondsSinceEpoch;

  /// 建立本機新版本戳。
  factory Hlc.now(String deviceId) => Hlc(clock(), 0, deviceId);

  /// 收到遠端版本後推進本地 HLC：取 max(本地, 遠端, 牆鐘)；同毫秒則計數器 +1。
  /// [nowMs] 供測試注入（未提供時用 [clock]）。
  Hlc receive(Hlc remote, String deviceId, {int? nowMs}) {
    final n = nowMs ?? clock();
    var ms = milliseconds;
    if (remote.milliseconds > ms) ms = remote.milliseconds;
    if (n > ms) ms = n;
    final counter = ms == milliseconds ? this.counter + 1 : 0;
    return Hlc(ms, counter, deviceId);
  }

  /// 兩版本取較新者（LWW 判定用，SDD §5.5.4）。
  static Hlc max(Hlc a, Hlc b) => a >= b ? a : b;

  static Hlc parse(String s) {
    final parts = s.split('.');
    if (parts.length != 3) {
      throw FormatException('HLC 格式錯誤: $s');
    }
    return Hlc(int.parse(parts[0]), int.parse(parts[1]), parts[2]);
  }

  @override
  int compareTo(Hlc other) {
    if (milliseconds != other.milliseconds) {
      return milliseconds.compareTo(other.milliseconds);
    }
    if (counter != other.counter) return counter.compareTo(other.counter);
    return deviceId.compareTo(other.deviceId);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >=(Hlc other) => compareTo(other) >= 0;
  bool operator <=(Hlc other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) => other is Hlc && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(milliseconds, counter, deviceId);

  String _pad(int value, int width) => value.toString().padLeft(width, '0');

  @override
  String toString() => '${_pad(milliseconds, 15)}.${_pad(counter, 5)}.$deviceId';
}
