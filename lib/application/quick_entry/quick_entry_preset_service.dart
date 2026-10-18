import '../../data/sqlite/app_database.dart';

/// 快記預填結果（FR-Q4／SDD §5.1 系統預填：帳戶 + 分類 + 時間 = 現在）。
class QuickEntryPreset {
  const QuickEntryPreset({required this.account, this.category, required this.time});

  final AccountRow account;

  /// 預設分類；無歷史且查無內建「其他」時為 null（FE 顯示空欄）。
  final CategoryRow? category;
  final DateTime time;
}

/// 快記智慧預設服務（FR-Q4，F01-BE）。
///
/// 規則（SPEC §5.3 FR-Q4、acceptance F01 S1.1~S1.4）：
/// 1. `quick_entry.smart_preset = off` → 固定預設 `quick_entry.fixed_preset`
///    （JSON：account_id/category_id；帳戶已封存/刪除 → 回退第一個未封存帳戶）。
/// 2. 帳戶預設 = **上一筆交易所用帳戶**（非最常用）；已封存 → 第一個未封存。
/// 3. 分類優先序：同商家歷史最常用 ＞ 目前時段最常用 ＞ 最近使用 ＞ 內建「其他」。
///
/// 時段以**裝置本地時區**計算（acceptance S1.1 邊界）：清晨 00:00–06:00／
/// 上午 06:00–12:00／下午 12:00–18:00／晚上 18:00–24:00。
/// （⚠️ SPEC FR-Q4 文字為「五段」含深夜，acceptance 為四段定義——以 acceptance
/// 為驗收依據，差異待 PM 確認，見 session.md 阻塞清單。）
class QuickEntryPresetService {
  QuickEntryPresetService(this._db);

  // ignore: unused_field — 紅燈階段（TDD）：規則實作後移除本標記。
  final AppDatabase _db;

  /// 計算快記預填（[merchant] 為商家欄目前輸入值，觸發同商家規則）。
  QuickEntryPreset compute({String? merchant}) => throw UnimplementedError('T-F01-BE 紅燈階段');

  /// 時段判定（本地時區；acceptance S1.1 四段表）。
  static QuickEntrySlot slotOf(DateTime t) => throw UnimplementedError('T-F01-BE 紅燈階段');
}

enum QuickEntrySlot { dawn, morning, afternoon, evening }
