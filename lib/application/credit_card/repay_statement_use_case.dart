import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';
import '../notifications/notification_service.dart';

/// 帳單繳款（FR-C4；acceptance S5.6/S5.7；⚠️ 待雙重 review）。
///
/// - 繳款 = **repayment 交易**（來源＝扣款帳戶〔linked_account_id，未設定時
///   回退第一個非信用卡帳戶〕→ 目標＝卡片）＋帳單 paid 累加。
/// - 狀態機：paid ≥ total → **paid**（paid_at 記錄）；否則 **partial**。
/// - 全額繳清 → **取消 N-5 提醒**（notifier.cancel(5)，FR-C4）。
/// - 交易與帳單更新於**同一 DB transaction**（各含 oplog 快照，同步契約）。
class RepayStatementUseCase {
  RepayStatementUseCase(this._db, this._notifier);

  final AppDatabase _db;
  final NotificationService _notifier;

  String execute({required String statementId, required int amountMinor}) {
    final statement = _db.statementById(statementId);
    if (statement == null) {
      throw StateError('繳款失敗：帳單不存在 $statementId');
    }
    if (amountMinor <= 0) {
      throw StateError('繳款失敗：金額須為正');
    }
    final detail = _db.creditCardDetail(statement.accountId);
    final fromAccount = detail?.linkedAccountId ?? _fallbackAccount();
    if (fromAccount == null) {
      throw StateError('繳款失敗：無扣款帳戶（linked_account_id 未設定且無其他帳戶）');
    }

    final now = Clock.now();
    final nowMs = now.millisecondsSinceEpoch;
    final hlc = Hlc.now('billing').toString();

    final paid = statement.paidMinor + amountMinor;
    final status = paid >= statement.totalMinor ? 'paid' : 'partial';
    final paidAt = status == 'paid' ? nowMs : statement.paidAt;

    final txId = const Uuid().v7();
    final tx = TxRow(
      id: txId,
      kind: 'repayment',
      amountMinor: amountMinor,
      currency: 'TWD',
      accountId: fromAccount,
      toAccountId: statement.accountId,
      categoryId: null,
      merchant: null,
      note: '信用卡繳款',
      occurredAt: nowMs,
      source: 'manual',
      settlementStatus: 'none',
      createdAt: nowMs,
      updatedAt: nowMs,
      hlc: hlc,
    );
    final updatedStatement = StatementRow(
      id: statement.id,
      accountId: statement.accountId,
      periodStart: statement.periodStart,
      periodEnd: statement.periodEnd,
      statementDate: statement.statementDate,
      dueDate: statement.dueDate,
      totalMinor: statement.totalMinor,
      paidMinor: paid,
      status: status,
      paidAt: paidAt,
      overdueNotified: statement.overdueNotified,
      createdAt: statement.createdAt,
      updatedAt: nowMs,
      hlc: hlc,
    );

    _db.runInTransaction(() {
      _db.insertTransaction(tx);
      _db.appendOp(OplogRow(
        entity: 'transactions',
        entityId: tx.id,
        hlc: hlc,
        payload: jsonEncode(tx.toSnapshot()),
        packedSeq: null,
      ));
      _db.updateStatementPayment(statement.id, paid, status, paidAt, nowMs, hlc);
      _db.appendOp(OplogRow(
        entity: 'statements',
        entityId: statement.id,
        hlc: hlc,
        payload: jsonEncode(updatedStatement.toSnapshot()),
        packedSeq: null,
      ));
    });

    // FR-C4：全額繳清 → 取消 N-5 提醒。
    if (status == 'paid') {
      _notifier.cancel(5);
    }
    return txId;
  }

  /// 扣款帳戶回退：第一個非信用卡帳戶（薪轉等）。
  String? _fallbackAccount() {
    for (final a in _db.allAccounts()) {
      if (a.type != 'credit' && !a.archived) return a.id;
    }
    return null;
  }
}
