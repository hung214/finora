import 'dart:convert';

import '../../core/clock.dart';
import '../../data/sqlite/app_database.dart';
import '../notifications/notification_service.dart';

/// 通知檢查（FR-C5/C6；SPEC §8 N-5/N-6；觸發點＝App 啟動/每日排程）。
///
/// - **N-5 繳款提醒**：繳款日**前 3 天**與**當天**各一次（S7：7/17 發一次、
///   7/18 不重複、7/20 再發一次＝恰 2 次）——去重狀態存 settings
///   `statement.reminder_state`（JSON：`{statementId: [pre, due]}`）。
/// - **N-6 逾期**：due_date 已過且未繳清 → 標記逾期（overdue_notified）＋
///   N-6 **恰一次**（FR-C6）。
/// - 已 paid 之帳單跳過。
class NotificationCheckService {
  NotificationCheckService(this._db, this._notifier);

  final AppDatabase _db;
  final NotificationService _notifier;

  static const String _reminderStateKey = 'statement.reminder_state';

  void run() {
    final now = Clock.now();
    for (final s in _allUnpaidStatements()) {
      if (s.status == 'paid') continue;

      // ── N-6 逾期（due 已過且未繳清，恰一次）────────────────
      final dueDate = DateTime.fromMillisecondsSinceEpoch(s.dueDate);
      final dueEnd = DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59, 999);
      if (now.isAfter(dueEnd) && !s.overdueNotified) {
        _notifier.notify(const NotificationCall(
          id: 6,
          title: '帳單逾期',
          body: '信用卡帳單已逾期，請儘速繳款',
        ));
        _db.updateStatementPayment(
            s.id, s.paidMinor, s.status, s.paidAt, now.millisecondsSinceEpoch, s.hlc);
        _db.markStatementOverdueNotified(s.id);
        continue; // 逾期帳單不再發 N-5
      }

      // ── N-5 提醒（前 3 天與當天，各一次）──────────────────
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final daysToDue = dueDay.difference(today).inDays;
      final sent = _sentReminders(s.id);
      if (daysToDue == 3 && !sent.contains('pre')) {
        _notifier.notify(const NotificationCall(
          id: 5,
          title: '繳款提醒',
          body: '信用卡帳單 3 天後到期，記得繳款',
        ));
        sent.add('pre');
        _saveReminders(s.id, sent);
      } else if (daysToDue == 0 && !sent.contains('due')) {
        _notifier.notify(const NotificationCall(
          id: 5,
          title: '繳款提醒',
          body: '信用卡帳單今日到期，記得繳款',
        ));
        sent.add('due');
        _saveReminders(s.id, sent);
      }
    }
  }

  List<StatementRow> _allUnpaidStatements() {
    // 全部未繳清帳單（語意：通知檢查巡所有卡片）。
    return _db.allStatementsForTest().where((s) => s.status != 'paid').toList();
  }

  Set<String> _sentReminders(String statementId) {
    final raw = _db.getSetting(_reminderStateKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (map[statementId] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>()
        .toSet();
  }

  void _saveReminders(String statementId, Set<String> sent) {
    final raw = _db.getSetting(_reminderStateKey);
    final map =
        raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map<String, dynamic>);
    map[statementId] = sent.toList();
    _db.setSetting(_reminderStateKey, jsonEncode(map));
  }
}
