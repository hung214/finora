import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/transactions/delete_transaction_use_case.dart';
import 'package:ledger_sync/application/transactions/purge_tombstone_use_case.dart';
import 'package:ledger_sync/application/transactions/restore_transaction_use_case.dart';

import '../helpers/db_fixture.dart';

/// 永久刪除墓標 UseCase（FR-T3：「最近刪除」→ 直接刪除／清空全部；
/// PM 2026-10-24 需求增補）。
///
/// 關鍵契約：實體刪除＋**oplog 墓標保留**（同步安全）＋冪等＋僅接受墓標。
void main() {
  test('單筆永久刪除：列實體消失、無法還原、oplog 墓標保留（同步安全）', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 0);
    await DbFixture.seedTx(
        db,
        id: 'tx-1',
        kind: 'expense',
        amountMinor: 120,
        accountId: 'a-0',
        occurredAt: 1000);
    await DbFixture.seedTx(
        db,
        id: 'tx-2',
        kind: 'expense',
        amountMinor: 40,
        accountId: 'a-0',
        occurredAt: 2000);
    DeleteTransactionUseCase(db).execute('tx-1'); // 前置：軟刪除
    expect(db.transactionById('tx-1')!.deletedAt, isNotNull);

    final opsBefore = db.allOps().length;
    final result = PurgeTombstoneUseCase(db).execute('tx-1');

    expect(result.purgedCount, 1, reason: '實際清除 1 筆');
    expect(db.transactionById('tx-1'), isNull, reason: '列實體消失（無法還原）');
    expect(db.transactionById('tx-2')!.deletedAt, isNull, reason: '未刪除交易不受影響');
    expect(db.allOps().length, opsBefore, reason: '不寫任何 oplog（清除為本機維運）');
    expect(db.allOps().last.payload, isNull,
        reason: 'oplog 墓標保留——其他裝置刪除結果不變（同步安全）');
    expect(() => RestoreTransactionUseCase(db).execute('tx-1'), throwsStateError,
        reason: '已實體清除 → 不可還原');
  });

  test('冪等：重複永久刪除同筆回 0；不存在亦回 0（連點不報錯）', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 0);
    await DbFixture.seedTx(
        db, id: 'tx-1', kind: 'expense', amountMinor: 1, accountId: 'a-0', occurredAt: 0);
    DeleteTransactionUseCase(db).execute('tx-1');

    expect(PurgeTombstoneUseCase(db).execute('tx-1').purgedCount, 1);
    expect(PurgeTombstoneUseCase(db).execute('tx-1').purgedCount, 0, reason: '已清除');
    expect(PurgeTombstoneUseCase(db).execute('tx-missing').purgedCount, 0,
        reason: '不存在（含保留期屆滿）');
  });

  test('未刪除之交易拋 StateError（防永久刪除誤傷未刪除資料）', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 0);
    await DbFixture.seedTx(
        db, id: 'tx-1', kind: 'expense', amountMinor: 1, accountId: 'a-0', occurredAt: 0);

    expect(() => PurgeTombstoneUseCase(db).execute('tx-1'), throwsStateError);
    expect(db.transactionById('tx-1'), isNotNull, reason: '未刪除者原樣保留');
  });

  test('清空全部：清除所有墓標（不受 30 天限制）、未刪除交易保留', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 0);
    for (final id in ['tx-1', 'tx-2']) {
      await DbFixture.seedTx(
          db, id: id, kind: 'expense', amountMinor: 10, accountId: 'a-0', occurredAt: 0);
      DeleteTransactionUseCase(db).execute(id);
    }
    await DbFixture.seedTx(
        db, id: 'tx-3', kind: 'income', amountMinor: 99, accountId: 'a-0', occurredAt: 0);

    // 使用者明示刪除 → 不受 30 天保留期限制（剛刪的也清）。
    final result = PurgeTombstoneUseCase(db).executeAll();

    expect(result.purgedCount, 2);
    expect(db.transactionById('tx-1'), isNull);
    expect(db.transactionById('tx-2'), isNull);
    expect(db.transactionById('tx-3')!.deletedAt, isNull, reason: '未刪除交易保留');
    expect(PurgeTombstoneUseCase(db).executeAll().purgedCount, 0, reason: '冪等');
  });
}
