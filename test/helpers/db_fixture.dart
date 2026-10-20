import 'dart:convert';

import 'package:ledger_sync/data/sqlite/app_database.dart';

/// T-H1：記憶體 DB fixture（每個 Scenario 重建；測試環境不啟用 SQLCipher）。
///
/// 資料準備一律經 fixture 直寫 DB（dsl.md §1.5：Given 資料步驟不經 UI）。
class DbFixture {
  DbFixture._();

  static int _seed = 0;

  /// 建立全新記憶體資料庫（每測試獨立，無需 reset）。
  static AppDatabase create() => AppDatabase.inMemory();

  static String get _hlc {
    _seed++;
    return '${DateTime.now().millisecondsSinceEpoch}.$_seed.test';
  }

  static Future<void> seedAccount(
    AppDatabase db, {
    required String id,
    required String type,
    required String name,
    int opening = 0,
    String currency = 'TWD',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    db.insertAccount(AccountRow(
      id: id,
      type: type,
      name: name,
      currency: currency,
      openingAmountMinor: opening,
      archived: false,
      createdAt: now,
      updatedAt: now,
      hlc: _hlc,
    ));
  }

  static Future<void> seedCategory(
    AppDatabase db, {
    required String id,
    required String kind,
    required String name,
    String? parentId,
    bool isSystem = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    db.insertCategory(CategoryRow(
      id: id,
      kind: kind,
      parentId: parentId,
      name: name,
      isSystem: isSystem,
      createdAt: now,
      updatedAt: now,
      hlc: _hlc,
    ));
  }

  static Future<void> seedTx(
    AppDatabase db, {
    required String id,
    required String kind,
    required int amountMinor,
    required String accountId,
    String? toAccountId,
    String? category,
    String? merchant,
    required int occurredAt,
    String source = 'manual',
    String settlementStatus = 'none',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = TxRow(
      id: id,
      kind: kind,
      amountMinor: amountMinor,
      currency: 'TWD',
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: category,
      merchant: merchant,
      note: null,
      occurredAt: occurredAt,
      source: source,
      settlementStatus: settlementStatus,
      createdAt: now,
      updatedAt: now,
      hlc: _hlc,
    );
    // payload = 整列快照（SDD §5.5.4）；NULL 僅用於刪除墓標。
    db.saveTransactionWithOplog(
      row,
      OplogRow(
        entity: 'transactions',
        entityId: id,
        hlc: _hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      ),
    );
  }

  static Future<void> appendOp(
    AppDatabase db, {
    required String entity,
    required String entityId,
    required String hlc,
    String? payload,
  }) async {
    db.appendOp(OplogRow(
        entity: entity, entityId: entityId, hlc: hlc, payload: payload, packedSeq: null));
  }

  static Future<void> setSetting(
    AppDatabase db, {
    required String key,
    required String value,
  }) async {
    db.setSetting(key, value);
  }

  /// 預算重設語意（F05 S5.6 同分類重設）：先清除同 scope（fixture 層實體清除）
  /// 再寫入＋oplog（budgets 屬 sync_entity）。
  static Future<void> seedBudget(
    AppDatabase db, {
    required String id,
    String? categoryId,
    required int amountMinor,
    int periodStartDay = 1,
    bool rollover = false,
  }) async {
    db.deleteBudgetsByCategory(categoryId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = BudgetRow(
      id: id,
      categoryId: categoryId,
      amountMinor: amountMinor,
      periodStartDay: periodStartDay,
      rollover: rollover,
      createdAt: now,
      updatedAt: now,
      hlc: _hlc,
    );
    db.insertBudgetWithOplog(
      row,
      OplogRow(
        entity: 'budgets',
        entityId: id,
        hlc: _hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      ),
    );
  }

  /// 收入目標（單一目標模型）：replace 語意＋oplog。
  static Future<void> seedIncomeGoal(
    AppDatabase db, {
    required String id,
    required int amountMinor,
    int periodStartDay = 1,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = IncomeGoalRow(
      id: id,
      amountMinor: amountMinor,
      periodStartDay: periodStartDay,
      createdAt: now,
      updatedAt: now,
      hlc: _hlc,
    );
    db.replaceIncomeGoal(
      row,
      OplogRow(
        entity: 'budgets', // income_goals 同屬預算域（dbml sync_entity 由 budgets 覆蓋語意）
        entityId: id,
        hlc: _hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      ),
    );
  }

  /// 信用卡帳戶＋明細（FR-A3；F04）。
  static Future<void> seedCreditCard(
    AppDatabase db, {
    required String accountId,
    required String name,
    required int statementDay,
    required int dueOffsetDays,
    String boundaryRule = 'include',
    String? linkedAccountId,
  }) async {
    await seedAccount(db, id: accountId, type: 'credit', name: name);
    db.insertCreditCardDetail(CreditCardDetailRow(
      accountId: accountId,
      statementDay: statementDay,
      dueOffsetDays: dueOffsetDays,
      linkedAccountId: linkedAccountId,
      boundaryRule: boundaryRule,
    ));
  }

    /// NFR-01 效能測資：批次直寫當月 N 筆（略 oplog/FTS——聚合僅讀 transactions）。
  static Future<void> seedBulkTransactions(
    AppDatabase db, {
    required int count,
    String? accountId,
  }) async {
    final now = DateTime.now();
    final acct = accountId ?? 'a-bulk';
    if (db.allAccounts().every((a) => a.id != acct)) {
      await seedAccount(db, id: acct, type: 'cash', name: '效能現金');
    }
    final rows = <TxRow>[];
    for (var i = 0; i < count; i++) {
      final at = DateTime(now.year, now.month, (i % 28) + 1, 12);
      rows.add(TxRow(
        id: 'tx-bulk-$i',
        kind: 'expense',
        amountMinor: 100 + (i % 50),
        currency: 'TWD',
        accountId: acct,
        toAccountId: null,
        categoryId: 'c-bulk-${i % 4}',
        merchant: null,
        note: null,
        occurredAt: at.millisecondsSinceEpoch,
        source: 'manual',
        settlementStatus: 'none',
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        hlc: '${now.millisecondsSinceEpoch}.$i.bulk',
      ));
    }
    db.insertTransactionsBulk(rows);
  }

  /// T-H5：標準劇例資料集（acceptance 背景資料）。
  /// 帳戶 4（現金 1,000／銀行 10,000／票證卡 0／示例卡 0）＋分類 5＋交易 3（→oplog 3）。
  static Future<void> seedStandardScenario(AppDatabase db) async {
    await seedAccount(db, id: 'cash', type: 'cash', name: '現金', opening: 1000);
    await seedAccount(db, id: 'bank', type: 'bank', name: '銀行', opening: 10000);
    await seedAccount(db, id: 'ewallet', type: 'ewallet', name: '票證卡', opening: 0);
    await seedAccount(db, id: 'card', type: 'credit', name: '示例卡', opening: 0);
    await seedCategory(db, id: 'c-food', kind: 'expense', name: '餐飲');
    await seedCategory(db, id: 'c-traffic', kind: 'expense', name: '交通');
    await seedCategory(db, id: 'c-shop', kind: 'expense', name: '購物');
    await seedCategory(db, id: 'c-other', kind: 'expense', name: '其他', isSystem: true);
    await seedCategory(db, id: 'c-salary', kind: 'income', name: '薪資');
    await seedTx(
        db,
        id: 't-1',
        kind: 'expense',
        amountMinor: 120,
        accountId: 'cash',
        category: 'c-food',
        occurredAt: 1760736000000);
    await seedTx(
        db,
        id: 't-2',
        kind: 'income',
        amountMinor: 30000,
        accountId: 'bank',
        category: 'c-salary',
        occurredAt: 1760650000000);
    await seedTx(
        db,
        id: 't-3',
        kind: 'transfer',
        amountMinor: 400,
        accountId: 'cash',
        toAccountId: 'bank',
        occurredAt: 1760650000000);
  }
}
