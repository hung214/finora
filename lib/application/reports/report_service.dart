import '../../data/sqlite/app_database.dart';

/// 報表聚合（FR-R2；acceptance S10.1；SDD 報表域）。
///
/// - 僅計 **kind=expense**（轉帳/收入不計入支出——S10.1 失敗判定 Critical）。
/// - 期間＝指定年月（YYYY/MM）；墓標排除（transactionsBetween 保證）。
/// - 百分比四捨五入至 **0.1%**（toStringAsFixed(1)；S10.1 通過標準）。
class ReportService {
  const ReportService(this._db);

  final AppDatabase _db;

  ReportAggregate aggregate(int year, int month) {
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch;
    final byCategory = <String?, int>{};
    var total = 0;
    for (final t in _db.transactionsBetween(start, end)) {
      if (t.kind != 'expense') continue;
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amountMinor;
      total += t.amountMinor;
    }
    final shares = byCategory.entries
        .map((e) => CategoryShare(
              name: e.key == null ? '未分類' : (_db.categoryName(e.key!) ?? '未分類'),
              amountMinor: e.value,
              percentText:
                  total <= 0 ? '0.0' : (e.value * 100 / total).toStringAsFixed(1),
            ))
        .toList()
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return ReportAggregate(year: year, month: month, totalMinor: total, shares: shares);
  }
}

/// 聚合結果（分類占比降冪＋總計）。
class ReportAggregate {
  const ReportAggregate({
    required this.year,
    required this.month,
    required this.totalMinor,
    required this.shares,
  });

  final int year;
  final int month;
  final int totalMinor;
  final List<CategoryShare> shares;

  CategoryShare? shareOf(String categoryName) {
    for (final s in shares) {
      if (s.name == categoryName) return s;
    }
    return null;
  }
}

class CategoryShare {
  const CategoryShare({
    required this.name,
    required this.amountMinor,
    required this.percentText,
  });

  final String name;
  final int amountMinor;

  /// 四捨五入至 0.1%（如 '69.2'）。
  final String percentText;
}
