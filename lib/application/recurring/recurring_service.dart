
import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';
import '../notifications/notification_service.dart';
import '../quick_entry/save_transaction_use_case.dart';

/// 定期交易排程服務（FR-T5 提醒確認制；AC-12）——**未確認不入帳**。
///
/// - 到期檢查（App 啟動/回前台觸發）：next_due ≤ today 且未暫停 → N-7 提醒
///   （內容含金額千分位）＋ reminder_count+1；**同期累計 3 次 → paused=true
///   停止推播**（佇列保留——確認仍可，僅停推播，S6.5）。
/// - 確認入帳：金額/日期**可改且不回寫模板**（FR-T5）→ source=recurring →
///   next_due 推進（monthly→次月同日，clamp 月底）＋ reminder_count 歸零。
/// - 跳過：不入帳，next_due 推進。
/// - 刪除：軟刪（墓標）→ 不再提醒。
class RecurringService {
  RecurringService(this._db, this._notification);

  final AppDatabase _db;
  final NotificationService _notification;

  static const _reminderLimit = 3; // FR-T5：同期 ≥3 停止推播

  /// 到期檢查（dsl「觸發定期交易到期檢查」）。回傳本次提醒之排程數。
  int runCheck() {
    final today = Clock.now();
    // 日粒度語意：「每月 1 日」到期＝當日全天（next_due 的時刻不影響）。
    final endOfDay =
        DateTime(today.year, today.month, today.day + 1).millisecondsSinceEpoch - 1;
    // dueSchedules 已排除 paused（≥3 停止推播——_reminderLimit）。
    assert(_reminderLimit == 3, 'FR-T5 門檻契約');
    final due = _db.dueSchedules(endOfDay);
    for (final r in due) {
      _notification.notify(NotificationCall(
        id: 7, // N-7 定期交易到期提醒（SDD §5.2）
        title: '定期交易到期',
        body: '${r.name} ${_thousands(r.amountMinor)} 元——待確認入帳',
      ));
      _db.incrementReminder(r.id, _newHlc());
    }
    return due.length;
  }

  /// 確認入帳（金額/日期可改、不回寫模板）。回傳入庫交易 id。
  String confirm({
    required String scheduleId,
    required int amountMinor,
    required DateTime date,
  }) {
    final r = _db.recurringById(scheduleId)!;
    final save = SaveTransactionUseCase(_db, deviceId: 'device-local');
    final result = save.execute(
      accountId: r.accountId,
      categoryId: r.categoryId,
      amountMinor: amountMinor,
      occurredAt: date,
      merchant: r.name,
      source: 'recurring', // FR-T5：定期確認入帳
    );
    // 下期推進＋提醒計數歸零（oplog 由 db 方法內補）。
    final hlc = _newHlc();
    _db.advanceNextDue(scheduleId,
        nextDueFor(r, date).millisecondsSinceEpoch, hlc);
    _db.resetReminder(scheduleId, _newHlc());
    return result.transactionId;
  }

  /// 本次跳過（不入帳；next_due 推進）。
  void skip({required String scheduleId}) {
    final r = _db.recurringById(scheduleId)!;
    _db.advanceNextDue(
        scheduleId,
        nextDueFor(r, DateTime.fromMillisecondsSinceEpoch(r.nextDueDate))
            .millisecondsSinceEpoch,
        _newHlc());
    _db.resetReminder(scheduleId, _newHlc());
  }

  /// 刪除排程（軟刪；不再提醒）。
  void delete({required String scheduleId}) {
    _db.softDeleteRecurring(scheduleId, _newHlc());
  }

  /// monthly 之次月同日推進（clamp 月底；其他頻率 M6 後續擴充）。
  static DateTime nextDueFor(RecurringRow r, DateTime from) {
    switch (r.frequency) {
      case 'monthly':
        final anchorDay = DateTime.fromMillisecondsSinceEpoch(r.anchorDate).day;
        final next = DateTime(from.year, from.month + 1, 1);
        final lastDay = DateTime(next.year, next.month + 1, 0).day;
        return DateTime(
            next.year, next.month, anchorDay > lastDay ? lastDay : anchorDay);
      default:
        throw UnimplementedError('nextDueFor 未支援 frequency：${r.frequency}');
    }
  }

  String _newHlc() => Hlc(Clock.now().millisecondsSinceEpoch, 0, 'device-local')
      .toString();

  String _thousands(int amount) {
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
