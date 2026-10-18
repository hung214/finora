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
    required int occurredAt,
    String source = 'manual',
    String settlementStatus = 'none',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    db.saveTransactionWithOplog(
      TxRow(
        id: id,
        kind: kind,
        amountMinor: amountMinor,
        currency: 'TWD',
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: category,
        merchant: null,
        note: null,
        occurredAt: occurredAt,
        source: source,
        settlementStatus: settlementStatus,
        createdAt: now,
        updatedAt: now,
        hlc: _hlc,
      ),
      OplogRow(entity: 'transactions', entityId: id, hlc: _hlc, payload: null, packedSeq: null),
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
}
