import 'dart:convert';

import '../../core/clock.dart';
import '../../data/sqlite/app_database.dart';

/// 快記預填結果（FR-Q4／SDD §5.1 系統預填：帳戶 + 分類 + 時間 = 現在）。
class QuickEntryPreset {
  const QuickEntryPreset({required this.account, this.category, required this.time});

  /// 預設帳戶；**空帳本（零帳戶）時為 null**（DBG-003：不得拋錯——
  /// FE 顯示「選擇帳戶」且儲存禁用，帳戶建立 UI 屬 F02）。
  final AccountRow? account;

  /// 預設分類；查無推薦時為 null（回退規則見 S1.3）。
  final CategoryRow? category;
  final DateTime time;
}

/// 快記智慧預設服務（FR-Q4，F01-BE）。
///
/// 規則（SPEC §5.3 FR-Q4、acceptance F01 S1.1~S1.4）：
/// 1. 帳戶預設 = **上一筆交易所用帳戶**（非最常用）；已封存 → 第一個未封存帳戶。
/// 2. 分類預設優先序：同商家歷史最常用 ＞ 目前時段最常用 ＞ 最近使用 ＞ 內建「其他」。
///    （商家規則／回退規則於後續情境 commit 補齊——TDD 情境逐條紅綠。）
/// 3. `quick_entry.smart_preset = off` → 固定預設（S1.4，後續 commit）。
///
/// 時段以**裝置本地時區**計算（acceptance S1.1 邊界）：清晨 00:00–06:00／
/// 上午 06:00–12:00／下午 12:00–18:00／晚上 18:00–24:00。
/// （⚠️ SPEC FR-Q4 文字為「五段」含深夜，acceptance 為四段定義——以 acceptance
/// 為驗收依據，差異待 PM 確認，見 session.md 阻塞清單。）
class QuickEntryPresetService {
  QuickEntryPresetService(this._db);

  final AppDatabase _db;

  /// settings key 命名（truth：data-spec.dbml settings Note，v0.3.1）。
  static const _smartPresetKey = 'quick_entry.smart_preset';
  static const _fixedPresetKey = 'quick_entry.fixed_preset';

  /// 計算快記預填（[merchant] 為商家欄目前輸入值，觸發同商家規則）。
  QuickEntryPreset compute({String? merchant}) {
    final now = Clock.now();

    // S1.4：關閉智慧預設 → 固定預設（不受歷史/上一筆/商家影響）。
    if (_db.getSetting(_smartPresetKey) == 'off') {
      return QuickEntryPreset(
        account: _fixedAccount(),
        category: _fixedCategory(),
        time: now,
      );
    }

    // FR-Q4①：帳戶預設 = 上一筆交易所用帳戶；封存 → 第一個未封存（S1.1 邊界）。
    // 空帳本 → null（DBG-003：呼叫端不得假設有帳戶）。
    final last = _db.lastTransaction();
    AccountRow? account;
    if (last != null) {
      for (final a in _db.allAccounts()) {
        if (a.id == last.accountId && !a.archived) {
          account = a;
          break;
        }
      }
    }
    account ??= _firstActiveAccount();

    // FR-Q4②：分類預設優先序——同商家 ＞ 目前時段 ＞ 最近使用 ＞ 內建「其他」。
    CategoryRow? category;
    if (merchant != null) {
      category = _merchantTopCategory(merchant);
    }
    category ??= _slotTopCategory(now);
    category ??= _recentCategory();
    category ??= _builtinOtherCategory();
    return QuickEntryPreset(account: account, category: category, time: now);
  }

  /// 時段判定（本地時區；acceptance S1.1 四段表）。
  static QuickEntrySlot slotOf(DateTime t) {
    final h = t.hour;
    if (h < 6) return QuickEntrySlot.dawn; // 清晨 00:00–06:00
    if (h < 12) return QuickEntrySlot.morning; // 上午 06:00–12:00
    if (h < 18) return QuickEntrySlot.afternoon; // 下午 12:00–18:00
    return QuickEntrySlot.evening; // 晚上 18:00–24:00
  }

  /// 固定預設帳戶（S1.4）：JSON `{"account_id": ...}`；缺失/已封存/已刪除
  /// → 回退第一個未封存帳戶並由 FE 提示一次（acceptance S1.4 邊界）；
  /// 空帳本 → null（DBG-003）。
  AccountRow? _fixedAccount() {
    final preset = _readFixedPreset();
    if (preset != null) {
      final id = preset['account_id'] as String?;
      if (id != null) {
        for (final a in _db.allAccounts()) {
          if (a.id == id && !a.archived) return a;
        }
      }
    }
    return _firstActiveAccount();
  }

  /// 固定預設分類（S1.4）：JSON `{"category_id": ...}`；查無 → 回退內建「其他」。
  CategoryRow? _fixedCategory() {
    final preset = _readFixedPreset();
    final id = preset?['category_id'] as String?;
    if (id != null) {
      final c = _categoryById(id);
      if (c != null) return c;
    }
    return _builtinOtherCategory();
  }

  Map<String, Object?>? _readFixedPreset() {
    final raw = _db.getSetting(_fixedPresetKey);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, Object?>;
  }

  /// 同商家歷史最常用分類（S1.2）：筆數最多者；同數取最近使用。
  /// 無該商家歷史（或歷史皆未標分類）→ null，交由下一優先序。
  CategoryRow? _merchantTopCategory(String merchant) {
    final stats = <String, (int, int)>{}; // categoryId → (筆數, 最新 occurred_at)
    for (final tx in _db.transactionsByMerchant(merchant)) {
      if (tx.categoryId == null) continue;
      final (count, latest) = stats[tx.categoryId!] ?? (0, 0);
      stats[tx.categoryId!] = (count + 1, latest > tx.occurredAt ? latest : tx.occurredAt);
    }
    if (stats.isEmpty) return null;
    String? top;
    (int, int) topStat = (0, 0);
    for (final entry in stats.entries) {
      final (count, latest) = entry.value;
      final (topCount, topLatest) = topStat;
      final better = count > topCount || (count == topCount && latest >= topLatest);
      if (better) {
        top = entry.key;
        topStat = entry.value;
      }
    }
    return _categoryById(top!);
  }

  /// 目前時段歷史最常用分類：筆數最多者；同數取最近使用。
  CategoryRow? _slotTopCategory(DateTime now) {
    final slot = slotOf(now);
    // M1 規模：全量載入後於 Dart 分組（報表/搜尋優化屬 F10）。
    final stats = <String, (int, int)>{}; // categoryId → (筆數, 最新 occurred_at)
    for (final tx in _db.allTransactions()) {
      if (tx.deletedAt != null || tx.categoryId == null) continue; // 墓標排除
      final at = DateTime.fromMillisecondsSinceEpoch(tx.occurredAt);
      if (slotOf(at) != slot) continue;
      final (count, latest) = stats[tx.categoryId!] ?? (0, 0);
      stats[tx.categoryId!] = (count + 1, latest > tx.occurredAt ? latest : tx.occurredAt);
    }
    if (stats.isEmpty) return null;
    String? top;
    (int, int) topStat = (0, 0);
    for (final entry in stats.entries) {
      final (count, latest) = entry.value;
      final (topCount, topLatest) = topStat;
      final better = count > topCount || (count == topCount && latest >= topLatest);
      if (better) {
        top = entry.key;
        topStat = entry.value;
      }
    }
    return _categoryById(top!);
  }

  /// 最近使用分類（FR-Q4②優先序 3）：上一筆交易所標分類。
  CategoryRow? _recentCategory() {
    final last = _db.lastTransaction();
    if (last?.categoryId == null) return null;
    return _categoryById(last!.categoryId!);
  }

  /// 內建預設「其他」（FR-Q4②優先序 4；S1.3 無任何歷史回退）。
  CategoryRow? _builtinOtherCategory() {
    final expenses = _db.categoriesByKind('expense');
    for (final c in expenses) {
      if (c.name == '其他') return c; // 內建集之「其他」（is_system）
    }
    return expenses.isEmpty ? null : expenses.first;
  }

  CategoryRow? _categoryById(String id) {
    for (final c in _db.categoriesByKind('expense')) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 第一個未封存帳戶（依建立順序；S1.3/S1.1 邊界回退規則）。
  /// 空帳本 → null（DBG-003：不得對空清單取 .first）。
  AccountRow? _firstActiveAccount() {
    final active = _db.allAccounts().where((a) => !a.archived).toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return active.isEmpty ? null : active.first;
  }
}

enum QuickEntrySlot { dawn, morning, afternoon, evening }
