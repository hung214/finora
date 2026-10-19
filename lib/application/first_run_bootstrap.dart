import 'dart:convert';

import '../core/clock.dart';
import '../core/hlc.dart';
import '../data/sqlite/app_database.dart';

/// 首次啟動播種（M1 過渡，PM 定案 2026-10-19）：空帳本自動建立
/// **內建分類集**（支出：餐飲/交通/購物/其他〔is_system〕＋收入：薪資，
/// FR-B1／acceptance F01 前置條件）＋**預設「現金」帳戶**（期初 0），
/// 使快記與 FR-Q4 預設規則即刻可用（S1.3：分類預填「其他」需內建集存在）。
///
/// - 帳戶/分類管理 UI 屬 F02；本播種為過渡，F02 落地後保留（全新裝置自動
///   給內建集屬合理產品行為）。
/// - 冪等：帳戶或分類任一存在即跳過（避免與使用者資料混雜）。
/// - 寫入走 `insertXxxWithOplog`（SDD §5.1 同一 DB transaction 契約），
///   payload 為整列快照（SDD §5.5.4）。
class FirstRunBootstrap {
  FirstRunBootstrap._();

  static const _device = 'device-local';

  static Future<void> seedIfNeeded(AppDatabase db) async {
    if (db.allAccounts().isNotEmpty || db.categoriesByKind('expense').isNotEmpty) {
      return; // 冪等：已有任何帳戶/分類（部分建立情境由 F02 UI 接手）
    }
    final nowMs = Clock.now().millisecondsSinceEpoch;

    Future<void> seedCategory(String id, String kind, String name, {bool system = false}) async {
      final row = CategoryRow(
        id: id,
        kind: kind,
        parentId: null,
        name: name,
        isSystem: system,
        createdAt: nowMs,
        updatedAt: nowMs,
        hlc: Hlc.now(_device).toString(),
      );
      db.insertCategoryWithOplog(
        row,
        OplogRow(
          entity: 'categories',
          entityId: id,
          hlc: row.hlc,
          payload: jsonEncode(row.toSnapshot()),
          packedSeq: null,
        ),
      );
    }

    await seedCategory('c-food', 'expense', '餐飲');
    await seedCategory('c-traffic', 'expense', '交通');
    await seedCategory('c-shop', 'expense', '購物');
    await seedCategory('c-other', 'expense', '其他', system: true);
    await seedCategory('c-salary', 'income', '薪資');

    final account = AccountRow(
      id: 'a-cash',
      type: 'cash',
      name: '現金',
      currency: 'TWD',
      openingAmountMinor: 0,
      archived: false,
      createdAt: nowMs,
      updatedAt: nowMs,
      hlc: Hlc.now(_device).toString(),
    );
    db.insertAccountWithOplog(
      account,
      OplogRow(
        entity: 'accounts',
        entityId: account.id,
        hlc: account.hlc,
        payload: jsonEncode(account.toSnapshot()),
        packedSeq: null,
      ),
    );
  }
}
