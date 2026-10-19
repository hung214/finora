import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/application/transactions/delete_transaction_use_case.dart';
import 'package:ledger_sync/application/transactions/restore_transaction_use_case.dart';
import 'package:ledger_sync/core/clock.dart';

import '../helpers/db_fixture.dart';

/// 還原交易 UseCase（FR-T3：30 天內可還原；acceptance F02 S2.5 步驟 3；
/// 「最近刪除」還原入口之後端契約——BDD 情境未自動化，QA 手動走查）。
void main() {
  test('還原墓標：deleted_at 歸零＋內容完整無損＋oplog 整列快照（非墓標）', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 1000);
    await DbFixture.seedTx(
      db,
      id: 'tx-1',
      kind: 'expense',
      amountMinor: 120,
      accountId: 'a-0',
      occurredAt: 1000,
    );
    DeleteTransactionUseCase(db).execute('tx-1');
    expect(db.transactionById('tx-1')!.deletedAt, isNotNull, reason: '前置：已軟刪除');

    Clock.freeze(DateTime(2026, 10, 19, 12));
    addTearDown(Clock.unfreeze);
    RestoreTransactionUseCase(db).execute('tx-1');

    final row = db.transactionById('tx-1')!;
    expect(row.deletedAt, isNull, reason: '墓標清除（30 天內可還原）');
    expect(row.amountMinor, 120, reason: '金額完整無損（S2.5 步驟 3）');
    expect(row.accountId, 'a-0');
    expect(row.occurredAt, 1000, reason: '時間完整無損');
    final last = db.allOps().last;
    expect(last.entityId, 'tx-1');
    expect(last.payload, isNotNull, reason: '還原為 UPDATE 快照（有別於刪除墓標 payload=NULL）');
    expect(last.payload!, contains('"deleted_at":null'));
  });

  test('還原未刪除交易 → StateError；不存在 → StateError（防還原幻影）', () async {
    final db = DbFixture.create();
    addTearDown(db.close);
    await DbFixture.seedAccount(db, id: 'a-0', type: 'cash', name: '現金', opening: 0);
    await DbFixture.seedTx(
      db,
      id: 'tx-1',
      kind: 'expense',
      amountMinor: 1,
      accountId: 'a-0',
      occurredAt: 0,
    );
    expect(
      () => RestoreTransactionUseCase(db).execute('tx-1'),
      throwsStateError,
      reason: '未刪除不可還原',
    );
    expect(
      () => RestoreTransactionUseCase(db).execute('tx-missing'),
      throwsStateError,
      reason: '不存在（含保留期屆滿已實體清除）不可還原',
    );
  });
}
