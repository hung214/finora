import '../../core/clock.dart';
import '../../data/sqlite/app_database.dart';

/// 本月收支統計（FR-T1/AC-10：轉帳與還款不計入收支）。
///
/// 統計範圍 = [Clock.now] 所在月（本地時區）；僅計 kind = expense/income 之
/// 未刪除交易（deleted_at IS NULL 由 [AppDatabase.transactionsBetween] 排除）。
/// 報表進階維度（分類占比/趨勢）屬 F10。
class MonthlyStatsService {
  MonthlyStatsService(this._db);

  final AppDatabase _db;

  /// 本月支出合計（minor units）。
  int expenseMinorThisMonth() => _sumKind('expense');

  /// 本月收入合計（minor units）。
  int incomeMinorThisMonth() => _sumKind('income');

  int _sumKind(String kind) {
    final now = Clock.now();
    final start = DateTime(now.year, now.month).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month + 1).millisecondsSinceEpoch;
    return _db
        .transactionsBetween(start, end)
        .where((r) => r.kind == kind)
        .fold(0, (sum, r) => sum + r.amountMinor);
  }
}
