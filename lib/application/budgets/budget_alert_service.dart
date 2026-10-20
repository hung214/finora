import 'dart:convert';

import '../../data/sqlite/app_database.dart';
import '../notifications/notification_service.dart';
import 'budget_evaluator.dart';
import 'budget_period_service.dart';

/// 預算警示（FR-B4；acceptance S5.1/S5.2；SPEC §8 通知總表 N-1/N-2/N-3）。
///
/// **冪等 sync 點語意**（dsl §2.1 註記；由 S5.1 內容 87.5% 與 S5.2 N-2 時序反推）：
/// - 觸發時機：①SaveTransactionUseCase 記帳後（afterSave 鉤子）②警示檢視點
///   （BDD 斷言前置／UI 進入預算區）。
/// - 分級補發：≥80% → N-1；≥100% → N-2；>100% → N-3——**每期每預算每級別一次**
///   （跳級 0→105% 依級別依序補發，S5.2 邊界）。去重狀態：settings
///   `budget.notif_state`（JSON：`{periodStartMs|budgetId: [levels]}`）——
///   週期切換 → key 變更 → 自然重置（S5.6）。
/// - 內容：N-1「{name}預算已用 {pct}%」／N-2「{name}預算已用完」／
///   N-3「{name}已超支 {over}」。
/// - 通知 fire-and-forget（非關鍵路徑；spy 於呼叫當下同步記錄，斷言確定）。
/// - 閾值以**整數運算**（usage×5 ≥ amount×4）避免浮點邊界誤差。
class BudgetAlertService {
  BudgetAlertService(this._db, this._notifier)
      : _evaluator = BudgetEvaluator(_db);

  final AppDatabase _db;
  final NotificationService _notifier;
  final BudgetEvaluator _evaluator;

  static const String _stateKey = 'budget.notif_state';
  static const BudgetPeriodService _period = BudgetPeriodService();

  /// 冪等同步：評估全部預算 → 補發未發級別。
  void sync() {
    for (final budget in _db.allBudgets()) {
      final name = budget.categoryId == null
          ? '總預算'
          : (_db.categoryName(budget.categoryId!) ?? '分類預算');
      final usage = budget.categoryId == null
          ? (_evaluator.totalUsageMinor() ?? 0)
          : (_evaluator.categoryUsage(budget.categoryId!)?.totalMinor ?? 0);
      final amount = budget.amountMinor;
      if (amount <= 0) continue;
      final levels = <int>[
        if (usage * 5 >= amount * 4) 1, // ≥80%
        if (usage >= amount) 2, // ≥100%
        if (usage > amount) 3, // >100%（超支）
      ];
      if (levels.isEmpty) continue;

      final stateKey = '${_period.current(budget.periodStartDay).startMs}|${budget.id}';
      final sent = _sentLevels(stateKey);
      for (final level in levels) {
        if (sent.contains(level)) continue;
        // fire-and-forget：本機通知非關鍵路徑（spy 同步記錄）。
        _notifier.notify(_call(level, name, usage, amount));
        sent.add(level);
      }
      _saveSentLevels(stateKey, sent);
    }
  }

  NotificationCall _call(int level, String name, int usage, int amount) {
    switch (level) {
      case 1:
        final pct = usage * 100 / amount;
        final pctText = pct == pct.roundToDouble() ? '${pct.round()}' : '$pct';
        return NotificationCall(id: 1, title: '預算警示', body: '$name預算已用 $pctText%');
      case 2:
        return NotificationCall(id: 2, title: '預算警示', body: '$name預算已用完');
      default:
        return NotificationCall(
            id: 3, title: '預算警示', body: '$name已超支 ${usage - amount}');
    }
  }

  Set<int> _sentLevels(String stateKey) {
    final raw = _db.getSetting(_stateKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = map[stateKey] as List<dynamic>? ?? const <dynamic>[];
    return list.cast<int>().toSet();
  }

  void _saveSentLevels(String stateKey, Set<int> levels) {
    final raw = _db.getSetting(_stateKey);
    final map =
        raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map<String, dynamic>);
    map[stateKey] = levels.toList()..sort();
    _db.setSetting(_stateKey, jsonEncode(map));
  }
}
