import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 預算服務（F05 補全：App 內建立/編輯/刪除——本機可用性缺口 2026-10-22）。
///
/// 規則（SDD §5.1 契約）：
/// - 總預算＝單一列（category_id NULL）；分類預算＝每分類一列（同 scope upsert）。
/// - 寫入/更新/軟刪除皆同 transaction 附 oplog（budgets 屬 sync_entity，
///   payload＝整列快照——多裝置 LWW）。
/// - 收入目標＝單一目標模型（dbml v0.3；replace 語意）。
class BudgetService {
  BudgetService(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;
  final String deviceId;

  static const _uuid = Uuid();

  /// 設定總預算（FR-B2/B3：週期起始日可自訂 1~28）。
  void setTotalBudget({required int amountMinor, required int periodStartDay}) {
    _upsert(categoryId: null, amountMinor: amountMinor, periodStartDay: periodStartDay);
  }

  /// 設定分類預算（同分類重設語意——F05 S5.6）。
  void setCategoryBudget({
    required String categoryId,
    required int amountMinor,
    required int periodStartDay,
  }) {
    _upsert(
        categoryId: categoryId,
        amountMinor: amountMinor,
        periodStartDay: periodStartDay);
  }

  /// 刪除預算（軟刪除；多裝置合併一致）。
  void remove(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hlc = Hlc.now(deviceId).toString();
    _db.softDeleteBudgetWithOplog(
      id,
      now,
      OplogRow(
        entity: 'budgets',
        entityId: id,
        hlc: hlc,
        payload: jsonEncode({'id': id, 'deletedAt': now}),
        packedSeq: null,
      ),
    );
  }

  /// 設定收入目標（FR-B6；單一目標——replace）。
  void setIncomeGoal({required int amountMinor, required int periodStartDay}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hlc = Hlc.now(deviceId).toString();
    final existing = _db.activeIncomeGoal();
    final row = IncomeGoalRow(
      id: existing?.id ?? _uuid.v7(),
      amountMinor: amountMinor,
      periodStartDay: periodStartDay,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      hlc: hlc,
    );
    _db.replaceIncomeGoal(
      row,
      OplogRow(
        entity: 'income_goals',
        entityId: row.id,
        hlc: hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      ),
    );
  }

  /// 同 scope upsert：存在→更新（整列快照 oplog）；不存在→建立。
  void _upsert({
    required String? categoryId,
    required int amountMinor,
    required int periodStartDay,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        _db.allBudgets().where((b) => b.categoryId == categoryId).toList();
    if (existing.isNotEmpty) {
      final old = existing.first;
      final hlc = Hlc.now(deviceId).toString();
      final row = BudgetRow(
        id: old.id,
        categoryId: old.categoryId,
        amountMinor: amountMinor,
        periodStartDay: periodStartDay,
        rollover: old.rollover,
        createdAt: old.createdAt,
        updatedAt: now,
        hlc: hlc,
      );
      _db.updateBudgetWithOplog(
        row,
        OplogRow(
          entity: 'budgets',
          entityId: row.id,
          hlc: hlc,
          payload: jsonEncode(row.toSnapshot()),
          packedSeq: null,
        ),
      );
      return;
    }
    final id = _uuid.v7();
    final hlc = Hlc.now(deviceId).toString();
    final row = BudgetRow(
      id: id,
      categoryId: categoryId,
      amountMinor: amountMinor,
      periodStartDay: periodStartDay,
      rollover: false,
      createdAt: now,
      updatedAt: now,
      hlc: hlc,
    );
    _db.insertBudgetWithOplog(
      row,
      OplogRow(
        entity: 'budgets',
        entityId: id,
        hlc: hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      ),
    );
  }
}

/// App 內現有總預算（編輯表單預填用）。
BudgetRow? activeTotalBudgetOf(AppDatabase db) {
  final rows = db.allBudgets().where((b) => b.categoryId == null).toList();
  return rows.isEmpty ? null : rows.first;
}
