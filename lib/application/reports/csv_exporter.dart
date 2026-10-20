import '../../data/sqlite/app_database.dart';

/// CSV 匯出（FR-R4；acceptance S10.3）。
///
/// - **UTF-8 with BOM**（EF BB BF）——Windows Excel 直接開啟中文不亂碼。
/// - 欄位：日期/時間、類型、金額、幣別、帳戶、分類、商家、備註、標籤、source
///   （S10.3-3；標籤 M2 未使用輸出空值）。
/// - 金額欄為**純整數**（minor units，可 SUM；S10.3-4）。
/// - 欄值含逗號/引號/換行 → CSV 標準逸出（雙引號包裹＋引號加倍）。
class CsvExporter {
  const CsvExporter({
    this.categoryName,
    this.accountName,
  });

  final String Function(String id)? categoryName;
  final String Function(String id)? accountName;

  static const List<String> header = [
    '日期/時間', '類型', '金額', '幣別', '帳戶', '分類', '商家', '備註', '標籤', 'source',
  ];

  String export(List<TxRow> txs) {
    final buf = StringBuffer('\uFEFF'); // UTF-8 BOM（EF BB BF）
    buf.writeln(header.map(_escape).join(','));
    for (final t in txs) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t.occurredAt);
      final date = '${dt.year}/${dt.month.toString().padLeft(2, '0')}/'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      final cells = [
        date,
        t.kind,
        '${t.amountMinor}', // 純數字（minor units 可 SUM）
        t.currency,
        accountName?.call(t.accountId) ?? t.accountId,
        t.categoryId == null ? '' : (categoryName?.call(t.categoryId!) ?? t.categoryId!),
        t.merchant ?? '',
        t.note ?? '',
        '', // 標籤（M2 未使用）
        t.source,
      ];
      buf.writeln(cells.map(_escape).join(','));
    }
    return buf.toString();
  }

  String _escape(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }
}
