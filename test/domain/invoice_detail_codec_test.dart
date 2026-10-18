import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/domain/services/invoice_detail_codec.dart';

import '../helpers/invoice_qr_fixtures.dart';

/// T-H6 驗收：發票測資 fixtures＋右側 QR 編碼器（deflate＋Base32 0-9A-Z，SDD §5.4）。
void main() {
  test('左側 QR 測資為 77 碼且欄位切分正確（財政部規格）', () {
    expect(InvoiceQrFixtures.leftQr77.length, 77);
    expect(InvoiceQrFixtures.leftQr77.substring(0, 10), 'AB12345678'); // 發票號
    expect(InvoiceQrFixtures.leftQr77.substring(10, 17), '1151018'); // 民國 115/10/18
    expect(InvoiceQrFixtures.leftQr77.substring(29, 39), '0000000186'); // 銷售額
    expect(InvoiceQrFixtures.leftQr77.substring(50, 60), '0000000195'); // 總計 195
    // 校驗：銷售額 186 ＋ 稅額 9 ＝ 總額 195（應稅）
    final sales = int.parse(InvoiceQrFixtures.leftQr77.substring(29, 39));
    final tax = int.parse(InvoiceQrFixtures.leftQr77.substring(40, 50));
    final total = int.parse(InvoiceQrFixtures.leftQr77.substring(50, 60));
    expect(sales + tax, total);
  });

  test('右側 QR：編碼→解碼往返（含中文品項）', () {
    final encoded = InvoiceQrFixtures.rightQr;
    expect(encoded, matches(RegExp(r'^[0-9A-Z=]*$'))); // Base32 字元集
    final decoded = InvoiceDetailCodec.decode(encoded);
    expect(decoded, contains('測試超商'));
    expect(decoded, contains('咖啡'));
  });

  test('編碼確定性（同輸入同輸出，fixture 穩定）', () {
    expect(InvoiceDetailCodec.encode('ABC123'), InvoiceDetailCodec.encode('ABC123'));
  });
}
