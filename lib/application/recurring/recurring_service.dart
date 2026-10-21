import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';
import '../notifications/notification_service.dart';
import '../quick_entry/save_transaction_use_case.dart';

/// 定期交易排程服務（FR-T5 提醒確認制；AC-12）——**未確認不入帳**。
///
/// - 到期檢查（App 啟動/回前台）：next_due ≤ today 的排程 → N-7 提醒
///   （內容含金額千分位）＋ reminder_count+1；**同期（同一筆到期）累計 3 次
///   → paused=true 停止推播**（佇列保留——確認仍可，僅停推播，S6.5）。
/// - 確認入帳：金額/日期**可改且不回寫模板**（FR-T5）→ source=recurring →
///   next_due 推進（monthly→次月同日）＋ reminder_count 歸零。
/// - 跳過：不入帳，next_due 推進。
/// - 刪除：軟刪（墓標）→ 不再提醒。
class RecurringService {
  RecurringService(this._db, this._notification);

  final AppDatabase _db;
  final NotificationService _notification;

  /// 到期檢查（觸發點：dsl「觸發定期交易到期檢查」）。
  /// 回傳本次提醒之排程數（冪等：已暫停不再推播）。
  int runCheck() => throw UnimplementedError('F06-BE 紅燈 stub：runCheck');

  /// 確認入帳（金額/日期可改、不回寫模板）。回傳入庫交易 id。
  String confirm({
    required String scheduleId,
    required int amountMinor,
    required DateTime date,
  }) => throw UnimplementedError('F06-BE 紅燈 stub：confirm');

  /// 本次跳過（不入帳；next_due 推進）。
  void skip({required String scheduleId}) =>
      throw UnimplementedError('F06-BE 紅燈 stub：skip');

  /// 刪除排程（軟刪；不再提醒）。
  void delete({required String scheduleId}) =>
      throw UnimplementedError('F06-BE 紅燈 stub：delete');

  /// monthly 頻率之次月同日推進（clamp 月底；其他頻率 M6 後續擴充）。
  static DateTime nextDueFor(RecurringRow r, DateTime from) {
    switch (r.frequency) {
      case 'monthly':
        final day = r.anchorDateDayOfMonth;
        final next = DateTime(from.year, from.month + 1, 1);
        final lastDay = DateTime(next.year, next.month + 1, 0).day;
        return DateTime(next.year, next.month, day > lastDay ? lastDay : day);
      default:
        throw UnimplementedError('nextDueFor 未支援 frequency：${r.frequency}');
    }
  }
}

extension on RecurringRow {
  /// anchor_date 的「日」成分（monthly 之排程日）。
  int get anchorDateDayOfMonth =>
      DateTime.fromMillisecondsSinceEpoch(anchorDate).day;
}
