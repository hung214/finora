import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/quick_entry/save_transaction_use_case.dart';

import '../helpers/db_fixture.dart';

/// 拆分交易（FR-T6，acceptance S2.7）：executeSplit 契約。
/// BE 無 BDD 情境（FE 情境驅動 UI）；本測試覆蓋總額守恆/群組/oplog 原子性。
void main() {
  test('拆分：N 筆子交易同 split_group_id＋總額守恆＋oplog 逐筆（單一 transaction）',
      () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    final useCase = SaveTransactionUseCase(db);

    final ids = useCase.executeSplit(
      accountId: 'a-0',
      totalMinor: 1000,
      items: const [
        (categoryId: 'c-food', amountMinor: 600),
        (categoryId: 'c-shop', amountMinor: 400),
      ],
      occurredAt: DateTime(2026, 10, 20, 12),
    );
    expect(ids, hasLength(2));

    final rows = db.allTransactions();
    expect(rows, hasLength(2));
    // 同群組
    expect(rows[0].splitGroupId, isNotNull);
    expect(rows[0].splitGroupId, rows[1].splitGroupId, reason: 'FR-T6：子交易共享群組');
    // 金額與分類——**順序無關**（DBG-005：allTransactions 之 ORDER BY
    // occurred_at, id 在兩筆同 occurredAt 時由 UUIDv7 字典序決定；系統時鐘
    // 微回退（NTP slew）可使後生成者 id 較小 → 陳列順序翻轉。拆分子交易的
    // 順序非契約，斷言以集合驗兩筆金額皆在。）
    expect(rows.map((r) => r.amountMinor).toSet(), {600, 400});
    expect(rows.map((r) => r.categoryId).toSet(), {'c-food', 'c-shop'});
    // oplog 逐筆（SDD §5.1：同一 transaction，中斷不產生孤兒）
    final ops = db.allOps();
    expect(ops, hasLength(2));
    for (final op in ops) {
      expect(op.entity, 'transactions');
      expect(op.payload, isNotNull);
      expect(op.packedSeq, isNull);
    }
  });

  test('總額守恆：子項加總 ≠ 總額 → 驗證失敗且不入庫', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    final useCase = SaveTransactionUseCase(db);

    expect(
      () => useCase.executeSplit(
        accountId: 'a-0',
        totalMinor: 1000,
        items: const [
          (categoryId: 'c-food', amountMinor: 600),
          (categoryId: 'c-shop', amountMinor: 300), // 加總 900 ≠ 1000
        ],
        occurredAt: DateTime(2026, 10, 20, 12),
      ),
      throwsA(isA<TransactionValidationException>()
          .having((e) => e.message, 'message', contains('總額'))),
    );
    expect(db.allTransactions(), isEmpty, reason: '驗證失敗不得入庫');
    expect(db.allOps(), isEmpty);
  });

  test('空子項 → 驗證失敗', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    final useCase = SaveTransactionUseCase(db);
    expect(
      () => useCase.executeSplit(
        accountId: 'a-0',
        totalMinor: 1000,
        items: const [],
        occurredAt: DateTime(2026, 10, 20, 12),
      ),
      throwsA(isA<TransactionValidationException>()),
    );
  });
}
