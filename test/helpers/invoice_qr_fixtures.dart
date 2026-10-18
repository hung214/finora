import 'package:ledger_sync/domain/services/invoice_detail_codec.dart';

/// T-H6：發票掃描標準測資（QR 解析與金測共用；金額與 acceptance AC-03 一致：總額 195）。
class InvoiceQrFixtures {
  InvoiceQrFixtures._();

  /// 左側 QR（77 碼）：
  /// 發票號 AB12345678 ｜ 開立日 民國115/10/18 ｜ 隨機碼 1234 ｜ 賣方統編 12345678
  /// 銷售額 186 ｜ 課稅別 1（應稅）｜ 稅額 9 ｜ 總計 195 ｜ 保留 17 碼
  static const String leftQr77 =
      'AB12345678' '1151018' '1234' '12345678' '0000000186' '1' '0000000009' '0000000195' '00000000000000000';

  /// 右側 QR：明細（deflate＋Base32）。格式：賣方**品項**數量**單價**金額…
  static final String rightQr =
      InvoiceDetailCodec.encode('測試超商**咖啡**2**95**190**茶葉蛋**1**5**5');

  /// 標準欄位期望值（解析器驗收用）。
  static const expected = (
    invoiceNo: 'AB12345678',
    date: '1151018', // 民國 YYYMMDD = 2026-10-18
    sellerTaxId: '12345678',
    salesAmount: 186,
    taxAmount: 9,
    totalAmount: 195,
  );
}
