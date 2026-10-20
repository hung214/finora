import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 分期服務（FR-C7；acceptance S9）。
///
/// - 建立：N 筆未來 **pending** 交易（每期金額均分、餘數補前筆；
///   `installment_seq` 1..N；每月同日）＋ installment_plans 列。
/// - 刪除連動：計畫刪除（軟刪）＋**未到期**分期交易實體移除（已到期不動）。
class InstallmentService {
  InstallmentService(this._db);

  final AppDatabase _db;

  /// 建立分期；回傳分期 plan id 與子交易 id 清單。
  ({String planId, List<String> txIds}) create({
    required String cardAccountId,
    required int totalMinor,
    required int installments,
    required DateTime firstDate,
    String? note,
  }) {
    if (installments <= 0) {
      throw StateError('分期失敗：期數須為正');
    }
    final now = Clock.now();
    final nowMs = now.millisecondsSinceEpoch;
    final hlc = Hlc.now('billing').toString();
    final planId = const Uuid().v7();
    final each = totalMinor ~/ installments;
    final extra = totalMinor - each * installments;

    final rows = <TxRow>[];
    for (var i = 0; i < installments; i++) {
      final due = DateTime(firstDate.year, firstDate.month + i, firstDate.day, 12);
      rows.add(TxRow(
        id: const Uuid().v7(),
        kind: 'expense',
        amountMinor: each + (i < extra ? 1 : 0),
        currency: 'TWD',
        accountId: cardAccountId,
        toAccountId: null,
        categoryId: null,
        merchant: null,
        note: note,
        occurredAt: due.millisecondsSinceEpoch,
        source: 'manual',
        settlementStatus: 'pending',
        installmentSeq: i + 1,
        createdAt: nowMs,
        updatedAt: nowMs,
        hlc: hlc,
      ));
    }

    _db.runInTransaction(() {
      _db.insertInstallmentPlan(InstallmentPlanRow(
        id: planId,
        accountId: cardAccountId,
        totalMinor: totalMinor,
        installments: installments,
        firstDate: firstDate.millisecondsSinceEpoch,
        note: note,
        createdAt: nowMs,
        updatedAt: nowMs,
        hlc: hlc,
      ));
      for (final r in rows) {
        _db.insertTransaction(r);
        _db.appendOp(OplogRow(
          entity: 'transactions',
          entityId: r.id,
          hlc: hlc,
          payload: jsonEncode(r.toSnapshot()),
          packedSeq: null,
        ));
      }
    });
    return (planId: planId, txIds: [for (final r in rows) r.id]);
  }

  /// 刪除分期計畫：plan 軟刪＋**未到期**分期交易實體移除（FR-C7 刪除連動）。
  void deletePlan(String planId) {
    final plan = _db.installmentPlanById(planId);
    if (plan == null) {
      throw StateError('刪除失敗：分期計畫不存在 $planId');
    }
    final nowMs = Clock.now().millisecondsSinceEpoch;
    final hlc = Hlc.now('billing').toString();
    final futureIds = _db
        .allTransactions()
        .where((t) =>
            t.splitGroupId == null &&
            t.installmentSeq != null &&
            t.accountId == plan.accountId &&
            t.occurredAt > nowMs &&
            t.deletedAt == null)
        .map((t) => t.id)
        .toList();
    _db.runInTransaction(() {
      _db.markInstallmentPlanDeleted(planId, nowMs, hlc);
      _db.deleteTransactionsPhysical(futureIds);
    });
  }
}
