import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';
import '../notifications/notification_service.dart';

/// 結帳引擎（FR-C3；SDD §5.2 BillingCycleService；⚠️ 待雙重 review）。
///
/// - **期間計算**（FR-C2/C3）：statement_date＝最近一個已過的結帳日
///   （29-31 遇小月 **clamp 月底**）；period_start＝上一次結帳日＋1 天。
/// - **boundary_rule**（FR-C2）：include → 結帳日當天消費算本期；exclude →
///   算下期（期間端點不含結帳日當天）。
/// - **結帳動作**：掃期間內 pending 交易 → 產生 statements（issued）＋
///   statement_items → 交易標記 **billed**（各筆 oplog 快照，同步契約）→
///   **N-4** 帳單通知（金額千分位）。
/// - 冪等：同卡同期間已產生帳單 → 跳過。
class BillingCycleService {
  BillingCycleService(this._db, this._notifier);

  final AppDatabase _db;
  final NotificationService _notifier;

  /// 結算指定卡片「最近一個已關閉週期」。回傳帳單 id；無卡片明細或已結算過
  /// 回 null。
  String? run(String cardAccountId) {
    final detail = _db.creditCardDetail(cardAccountId);
    if (detail == null) return null;
    final cardName = _db.accountName(cardAccountId) ?? '信用卡';
    final now = Clock.now();

    final statementDate = _lastStatementDate(now, detail.statementDay);
    final periodStart =
        _previousStatementDate(statementDate, detail.statementDay)
            .add(const Duration(days: 1));
    // include：期間含結帳日當天；exclude：結帳日當天歸下期（FR-C2）。
    final include = detail.boundaryRule == 'include';
    final periodEndDay = include
        ? statementDate
        : statementDate.subtract(const Duration(days: 1));

    // 冪等：同卡同期間已結算 → 跳過。
    if (_statementExists(cardAccountId,
        periodStart.millisecondsSinceEpoch, periodEndDay.millisecondsSinceEpoch)) {
      return null;
    }

    final periodStartMs = _startOfDay(periodStart).millisecondsSinceEpoch;
    final periodEndMs = include
        ? _endOfDay(periodEndDay).millisecondsSinceEpoch
        : _endOfDay(periodEndDay).millisecondsSinceEpoch;

    final pending = _db
        .transactionsBetween(periodStartMs, periodEndMs)
        .where((t) =>
            t.accountId == cardAccountId &&
            t.settlementStatus == 'pending' &&
            t.deletedAt == null)
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final total = pending.fold<int>(0, (s, t) => s + t.amountMinor);
    final dueDate = statementDate.add(Duration(days: detail.dueOffsetDays));
    final nowMs = now.millisecondsSinceEpoch;
    final hlc = Hlc.now('billing').toString();
    final statementId = const Uuid().v7();

    _db.insertStatement(StatementRow(
      id: statementId,
      accountId: cardAccountId,
      periodStart: periodStartMs,
      periodEnd: _startOfDay(periodEndDay).millisecondsSinceEpoch,
      statementDate: _startOfDay(statementDate).millisecondsSinceEpoch,
      dueDate: _startOfDay(dueDate).millisecondsSinceEpoch,
      totalMinor: total,
      paidMinor: 0,
      status: 'issued',
      overdueNotified: false,
      createdAt: nowMs,
      updatedAt: nowMs,
      hlc: hlc,
    ));
    _db.insertStatementItems(statementId, [for (final t in pending) t.id]);

    // 交易 pending → billed（各筆 oplog 快照，同步契約）。
    for (final t in pending) {
      final updated = TxRow(
        id: t.id,
        kind: t.kind,
        amountMinor: t.amountMinor,
        currency: t.currency,
        fxRate: t.fxRate,
        accountId: t.accountId,
        toAccountId: t.toAccountId,
        categoryId: t.categoryId,
        merchant: t.merchant,
        note: t.note,
        occurredAt: t.occurredAt,
        source: t.source,
        splitGroupId: t.splitGroupId,
        settlementStatus: 'billed',
        createdAt: t.createdAt,
        updatedAt: nowMs,
        hlc: Hlc.now('billing').toString(),
      );
      _db.markTransactionBilled(t.id, nowMs, updated.hlc);
      _db.appendOp(OplogRow(
        entity: 'transactions',
        entityId: t.id,
        hlc: updated.hlc,
        payload: jsonEncode(updated.toSnapshot()),
        packedSeq: null,
      ));
    }

    // N-4 帳單通知（金額千分位）。
    _notifier.notify(NotificationCall(
      id: 4,
      title: '帳單出來囉',
      body: '$cardName 帳單 ${_thousands(total)} 元，繳款日 ${_ymd(dueDate)}',
    ));
    return statementId;
  }

  // ── 週期計算 ─────────────────────────────────────────────

  /// 最近一個已過的結帳日（29-31 遇小月 clamp 月底；FR-C3）。
  DateTime _lastStatementDate(DateTime now, int day) {
    var candidate = _clampDay(now.year, now.month, day);
    if (candidate.isAfter(now)) {
      final prev = DateTime(now.year, now.month - 1);
      candidate = _clampDay(prev.year, prev.month, day);
    }
    return candidate;
  }

  /// 上一次結帳日（同期間起點推算用）。
  DateTime _previousStatementDate(DateTime statementDate, int day) {
    final prevMonth = DateTime(statementDate.year, statementDate.month - 1);
    return _clampDay(prevMonth.year, prevMonth.month, day);
  }

  /// clamp：wanted 超過當月月底 → 月底（FR-C3：31 號遇小月）。
  DateTime _clampDay(int y, int m, int day) {
    final monthEnd = DateTime(y, m + 1, 1).subtract(const Duration(days: 1));
    final wanted = DateTime(y, m, day);
    return wanted.isAfter(monthEnd) ? monthEnd : wanted;
  }

  bool _statementExists(String accountId, int periodStartMs, int periodEndDayMs) {
    return _db.statementExistsForPeriod(accountId, periodStartMs, periodEndDayMs);
  }

  // ── 格式輔助 ─────────────────────────────────────────────

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static String _ymd(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  static String _thousands(int amount) {
    final s = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return '${amount < 0 ? '-' : ''}$buf';
  }
}
