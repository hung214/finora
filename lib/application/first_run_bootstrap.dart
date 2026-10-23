import 'dart:convert';

import '../core/clock.dart';
import '../core/hlc.dart';
import '../data/sqlite/app_database.dart';

/// 首次啟動播種（M1 過渡，PM 定案 2026-10-19）：空帳本自動建立
/// **內建分類集**（PM 2026-10-22：支出 14 項〔其他 is_system〕＋收入 2 項，
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

    Future<void> seedCategory(String id, String kind, String name,
        {bool system = false, String? parentId, int? sortOrder,
        String? icon}) async {
      final row = CategoryRow(
        id: id,
        kind: kind,
        parentId: parentId,
        name: name,
        icon: icon,
        sortOrder: sortOrder,
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

    // 內建主類別集（PM 2026-10-22 定稿：支出 14＋收入 2；
    // 轉帳為交易類型非分類，不需分類列）。
    // 內建主類別＋emoji 圖示（PM 2026-10-23：對齊 DEMO 活潑圖示）。
    const expenseMains = [
      ('c-food', '餐飲食品', '🍜'),
      ('c-beauty', '服飾美容', '👗'),
      ('c-home', '居家生活', '🏠'),
      ('c-transport', '交通運輸', '🚇'),
      ('c-edu', '教育學習', '🎓'),
      ('c-fun', '休閒娛樂', '🎬'),
      ('c-3c', '3C通訊', '📱'),
      ('c-books', '圖書刊物', '📖'),
      ('c-vehicle', '汽機車', '🚗'),
      ('c-health', '醫療保健', '💊'),
      ('c-social', '人情交際', '🎁'),
      ('c-invest', '理財投資', '💰'),
      ('c-fee', '費用', '🧾'),
    ];
    for (final (id, name, emoji) in expenseMains) {
      await seedCategory(id, 'expense', name, icon: emoji);
    }
    await seedCategory('c-other', 'expense', '其他',
        system: true, icon: '📦');
    await seedCategory('c-income-general', 'income', '一般收入',
        icon: '💵');
    await seedCategory('c-income-invest', 'income', '投資收入',
        icon: '📈');

    // 內建子分類（PM 2026-10-22 簽核：全部主類別都配；sort_order＝索引）。
    const subs = <String, List<String>>{
      'c-food': ['早餐', '中餐', '晚餐', '下午茶', '宵夜', '水果', '食材'],
      'c-beauty': ['衣著鞋包', '美髮', '保養美妝', '洗衣'],
      'c-home': ['房租房貸', '水電瓦斯', '家具家電', '清潔用品', '日用雜貨'],
      'c-transport': ['大眾運輸', '計程車', '共享運具', '機票', '過路費'],
      'c-edu': ['學費', '課程講座', '文具', '教材'],
      'c-fun': ['電影展覽', '旅遊', '訂閱服務', '遊戲', '運動健身'],
      'c-3c': ['手機通訊', '周邊配件', '通話費網路', '維修'],
      'c-books': ['書籍', '雜誌', '電子書'],
      'c-vehicle': ['油費', '停車費', '稅金保險', '保養維修', '洗車'],
      'c-health': ['看診', '藥品', '保健食品', '牙科', '眼睛'],
      'c-social': ['紅包禮金', '聚餐', '賀禮', '公益'],
      'c-invest': ['手續費', '利息', '保險費'],
      'c-other': ['雜支', '罰單'],
      'c-fee': ['服務費', '會費'],
      'c-income-general': ['本薪', '加班費', '獎金', '津貼'],
      'c-income-invest': ['股利', '利息', '基金收益'],
    };
    final kindByParent = <String, String>{
      for (final (id, _, _) in expenseMains) id: 'expense',
      'c-other': 'expense',
      'c-income-general': 'income',
      'c-income-invest': 'income',
    };
    for (final e in subs.entries) {
      final parent = e.key;
      final names = e.value;
      for (var i = 0; i < names.length; i++) {
        await seedCategory('$parent-s$i', kindByParent[parent]!, names[i],
            parentId: parent, sortOrder: i);
      }
    }

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
