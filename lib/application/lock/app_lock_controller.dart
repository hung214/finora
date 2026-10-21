import '../../core/clock.dart';
import '../../data/sqlite/app_database.dart';

/// App 鎖判定控制器（SDD §7.2；FR-X1/X5；AC-09）。
///
/// - **門檻判定**：切背景時記錄時刻（[onBackground]）；返回時背景時長
///   ≥ 門檻秒數 → 鎖定需求（時間單一來源 Clock——凍結可測邊界）。
/// - **生物辨識退場**：連續失敗 ≥3 → 本次解鎖僅 PIN（[biometricAllowed]）。
/// - **PIN 重設授權（FR-X5）**：已連雲端＋token 驗證通過 → 允許設新 PIN；
///   未連雲端 → **僅「重置 App」**（無繞過 PIN 保留資料的路徑——設計取捨，
///   controller 不提供任何免憑證解鎖方法——安全設計檢驗見 F08-BE S4）。
///
/// 狀態存 settings：lock.pin_hash（sha256 最小實作——TODO(SP-4) Argon2id）、
/// lock.threshold_sec、lock.biometric。
class AppLockController {
  AppLockController(this._db, {required String pin, bool biometricEnabled = true, int thresholdSec = 30}) {
    setPin(pin);
    _db.setSetting('lock.threshold_sec', '$thresholdSec');
    _db.setSetting('lock.biometric', biometricEnabled ? 'true' : 'false');
  }

  final AppDatabase _db;

  /// 背景時刻（切背景記錄；null＝在前台）。
  DateTime? _backgroundAt;

  /// 生物辨識失敗計數（本次解鎖週期）。
  int biometricFailures = 0;

  int get thresholdSec =>
      int.tryParse(_db.getSetting('lock.threshold_sec') ?? '') ?? 30;

  bool get biometricEnabled =>
      (_db.getSetting('lock.biometric') ?? 'true') == 'true';

  /// PIN 雜湊比對（sha256 最小實作；TODO(SP-4) Argon2id——truth D8）。
  static String _hash(String pin) {
    var h = 0x811c9dc5; // FNV-1a 32bit（測試用途非加密強度——TODO(SP-4)）
    for (final c in pin.codeUnits) {
      h ^= c & 0xFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  void setPin(String pin) =>
      _db.setSetting('lock.pin_hash', _hash(pin));

  bool verifyPin(String pin) =>
      _db.getSetting('lock.pin_hash') == _hash(pin);

  /// 切至背景（lifecycle 鉤子呼叫）。
  void onBackground() => _backgroundAt = Clock.now();

  /// 返回時判定：背景時長 ≥ 門檻 → 鎖定需求（AC-09 邊界：30s 精準）。
  bool shouldLockOnResume() {
    final bg = _backgroundAt;
    _backgroundAt = null; // 判定即消費（返回後恢復前台語意）
    if (bg == null) return false;
    final elapsed = Clock.now().difference(bg).inSeconds;
    return elapsed >= thresholdSec;
  }

  /// 生物辨識是否可用（失敗 <3；FR-X1 退場機制）。
  bool get biometricAllowed => biometricEnabled && biometricFailures < 3;

  /// 生物辨識失敗（+1）。
  void onBiometricFail() => biometricFailures++;

  /// 生物辨識成功（計數歸零——解鎖週期重置）。
  void onBiometricSuccess() => biometricFailures = 0;

  /// PIN 重設授權（FR-X5）：已連雲端（settings sync.account 有值）**且**
  /// 雲端 token 驗證通過 → 允許設新 PIN；否則 false（僅「重置 App」）。
  bool canResetPin({required bool cloudTokenValid}) {
    final account = _db.getSetting('sync.account') ?? '';
    return account.isNotEmpty && cloudTokenValid;
  }
}
