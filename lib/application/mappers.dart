import '../data/sqlite/app_database.dart';
import '../domain/entities/account.dart';
import '../domain/entities/transaction.dart';

/// Row → 領域實體對映（BalanceCalculator／服務介面對齊）。
///
/// 抽至獨立檔（原於 `providers.dart`）——供**服務層**（AccountService／
/// TotalsService 等）與 providers 共用，避免服務反向相依 Riverpod providers
/// 造成循環匯入。
Account accountEntity(AccountRow r) => Account(
      id: r.id,
      type: AccountType.values.byName(r.type),
      name: r.name,
      currency: r.currency,
      openingAmountMinor: r.openingAmountMinor,
      archived: r.archived,
    );

Tx txEntity(TxRow r) => Tx(
      id: r.id,
      kind: TxKind.values.byName(r.kind),
      amountMinor: r.amountMinor,
      currency: r.currency,
      fxRate: r.fxRate,
      splitGroupId: r.splitGroupId,
      accountId: r.accountId,
      toAccountId: r.toAccountId,
      categoryId: r.categoryId,
      merchant: r.merchant,
      note: r.note,
      occurredAt: r.occurredAt,
      source: TxSource.values.byName(r.source),
      settlementStatus: SettlementStatus.values.byName(r.settlementStatus),
      deleted: r.deletedAt != null,
    );
