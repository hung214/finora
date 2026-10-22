import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/hlc.dart';
import '../../data/sqlite/app_database.dart';

/// 分類操作被拒（FR-B1；訊息可直接顯示給使用者）。
class CategoryException implements Exception {
  const CategoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 分類 CRUD 服務（SPEC FR-B1；SDD §5.6）。
///
/// **契約**：每次變更＝`categories`＋`oplog` 同 transaction（SDD §5.1）。
/// 規則：一層子分類（FR-B1）；排序連續遞增（reorder 維護）；
/// 刪除把關——**有交易引用 → 拒絕**、系統內建 → 僅可封存。
class CategoryService {
  CategoryService(this._db, {this.deviceId = 'device-local'});

  final AppDatabase _db;
  final String deviceId;

  static const _uuid = Uuid();

  /// 新增分類／子分類。
  CategoryRow create({
    required String kind,
    required String name,
    String? parentId,
    String? icon,
    String? color,
  }) {
    if (parentId != null) {
      final parent = _find(parentId);
      if (parent.parentId != null) {
        throw const CategoryException('僅支援一層子分類');
      }
    }
    final siblings = _db.categoriesByKind(kind).where((c) =>
        c.deletedAt == null && c.parentId == parentId);
    // 同層重名拒絕（播種子分類後防呆；FR-B1）。
    if (siblings.any((c) => c.name == name)) {
      throw const CategoryException('同層已有同名分類');
    }
    // 既有分類可能 sort_order=null（播種未寫）——null-safe 取最大值。
    final maxOrder = siblings.fold<int>(
        -1, (m, c) => (c.sortOrder ?? -1) > m ? (c.sortOrder ?? -1) : m);
    final nowMs = Clock.now().millisecondsSinceEpoch;
    final hlc = Hlc.now(deviceId).toString();
    final row = CategoryRow(
      id: _uuid.v7(),
      kind: kind,
      parentId: parentId,
      name: name,
      icon: icon,
      color: color,
      sortOrder: maxOrder + 1,
      isSystem: false,
      createdAt: nowMs,
      updatedAt: nowMs,
      hlc: hlc,
    );
    _db.insertCategoryWithOplog(row, _op(row, hlc));
    return row;
  }

  /// 編輯（名稱／圖示／顏色）。
  CategoryRow update(String id, {String? name, String? icon, String? color}) {
    final current = _find(id);
    final hlc = Hlc.now(deviceId).toString();
    final row = current.copyWith(
      name: name,
      icon: icon,
      color: color,
      updatedAt: Clock.now().millisecondsSinceEpoch,
      hlc: hlc,
    );
    _db.mutateCategoryWithOplog(row, _op(row, hlc), delete: false);
    return row;
  }

  /// 拖曳排序：將 [id] 移到 [beforeId] 之前（同 kind 同層；sort_order 連續化）。
  void reorder(String id, {required String? beforeId}) {
    final moved = _find(id);
    final siblings = _db
        .categoriesByKind(moved.kind)
        .where((c) =>
            c.deletedAt == null && c.parentId == moved.parentId && c.id != id)
        .toList();
    final insertAt = beforeId == null
        ? siblings.length
        : siblings.indexWhere((c) => c.id == beforeId);
    siblings.insert(insertAt < 0 ? siblings.length : insertAt, moved);
    applyOrder(moved.kind, [for (final c in siblings) c.id]);
  }

  /// 套用整份新排序（FR-B1 拖曳後；sort_order＝索引連續化，僅寫變更列之 oplog）。
  void applyOrder(String kind, List<String> orderedIds) {
    final nowMs = Clock.now().millisecondsSinceEpoch;
    final items = <(CategoryRow, OplogRow)>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final row = _find(orderedIds[i]);
      if (row.sortOrder == i) continue; // 未變更不寫 op（避免無謂同步）
      final hlc = Hlc.now(deviceId).toString();
      final updated = row.copyWith(sortOrder: i, updatedAt: nowMs, hlc: hlc);
      items.add((updated, _op(updated, hlc)));
    }
    if (items.isNotEmpty) _db.reorderCategoriesWithOplog(items);
  }

  /// 封存／取消封存（軟刪除——`deleted_at`；FR-B1 系統分類僅可封存）。
  void archive(String id, {bool archived = true}) {
    final current = _find(id);
    if (!archived && current.isSystem) {
      throw const CategoryException('系統內建分類僅可封存');
    }
    final hlc = Hlc.now(deviceId).toString();
    final row = current.copyWith(
      deletedAt: archived ? Clock.now().millisecondsSinceEpoch : null,
      updatedAt: Clock.now().millisecondsSinceEpoch,
      hlc: hlc,
    );
    _db.mutateCategoryWithOplog(row, _op(row, hlc), delete: false);
  }

  /// 刪除分類（FR-B1 把關）：**有交易引用（含子分類）→ 拋
  /// [CategoryException]**；系統內建 → 拒絕。
  void delete(String id) {
    final row = _find(id);
    if (row.isSystem) {
      throw const CategoryException('系統內建分類僅可封存');
    }
    final ids = [id, ...childrenOf(id).map((c) => c.id)];
    final referenced = _db
        .allTransactions()
        .any((t) => t.deletedAt == null && ids.contains(t.categoryId));
    if (referenced) {
      throw const CategoryException('此分類已有交易引用，可改為封存或改用其他分類');
    }
    final hlc = Hlc.now(deviceId).toString();
    _db.mutateCategoryWithOplog(row, _op(row, hlc), delete: true);
  }

  /// 同層、未封存之子分類。
  List<CategoryRow> childrenOf(String parentId) => _db
      .categoriesByKind(_find(parentId).kind)
      .where((c) => c.deletedAt == null && c.parentId == parentId)
      .toList();

  CategoryRow _find(String id) {
    for (final kind in ['expense', 'income']) {
      for (final c in _db.categoriesByKind(kind)) {
        if (c.id == id) return c;
      }
    }
    throw const CategoryException('分類不存在');
  }

  OplogRow _op(CategoryRow row, String hlc) => OplogRow(
        entity: 'categories',
        entityId: row.id,
        hlc: hlc,
        payload: jsonEncode(row.toSnapshot()),
        packedSeq: null,
      );
}
