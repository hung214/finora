import '../../domain/entities/transaction_draft.dart';
import '../../domain/services/invoice_detail_codec.dart';

/// 台灣電子發票 QR 解析（SDD §5.4 InvoiceQrParser——領域層純 Dart）。
///
/// 左 QR（77 碼）欄位切片：
/// `[0,10)` 發票字軌號碼、`[10,17)` 開立日期（民國 YYYMMDD）、`[17,21)` 隨機碼、
/// `[21,29)` 賣方統編、`[29,39)` 銷售額、`[39,40)` 課稅別、`[40,50)` 稅額、
/// `[50,60)` 總金額；餘為保留碼。
///
/// 右 QR：deflate(raw)＋Base32（字元集 0-9A-Z，T-H6 codec）解出
/// 「賣方名稱**品項**數量**單價**金額…」。
///
/// 驗證（SDD §5.4）：長度、`銷售額 + 稅額 ≈ 總計`（應稅時）、日期合理性；
/// 不合規回 null → 呼叫端回退手動輸入（FR-S2，訊息 [unrecognizedMessage]）。
class InvoiceQrParser {
  InvoiceQrParser._();

  /// FR-S2 回退訊息（BE/FE 共用常數——acceptance S3.6 文案）。
  static const String unrecognizedMessage = '無法辨識此發票格式';

  /// 解析左 QR（單張：無明細）。無法辨識回 null（不拋錯——回退是正常路徑）。
  ///
  /// 欄位切片（SDD §5.4）：[0,10) 發票號、[10,17) 民國 YYYMMDD、[17,21)
  /// 隨機碼、[21,29) 賣方統編、[29,39) 銷售額、[39,40) 課稅別、[40,50)
  /// 稅額、[50,60) 總金額；[60,77) 保留碼。驗證：長度 77、數值欄可解析、
  /// 應稅（課稅別 1）時銷售額＋稅額＝總計、日期合理（FR-S1；失敗→ FR-S2 回退）。
  static TransactionDraft? parseLeft(String qr) {
    if (qr.length != 77) return null;
    final invoiceNo = qr.substring(0, 10);
    final dateStr = qr.substring(10, 17);
    final sellerTaxId = qr.substring(21, 29);
    final sales = int.tryParse(qr.substring(29, 39));
    final taxType = qr.substring(39, 40);
    final tax = int.tryParse(qr.substring(40, 50));
    final total = int.tryParse(qr.substring(50, 60));
    if (sales == null || tax == null || total == null) return null;

    // 應稅（課稅別 1）：銷售額＋稅額＝總計（SDD §5.4 驗證）。
    if (taxType == '1' && sales + tax != total) return null;

    // 日期合理性：民國 YYYMMDD → 西元（+1911）；2/30 等不存在的日期拒絕。
    final y = int.tryParse(dateStr.substring(0, 3));
    final m = int.tryParse(dateStr.substring(3, 5));
    final d = int.tryParse(dateStr.substring(5, 7));
    if (y == null || m == null || d == null) return null;
    if (y < 100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y + 1911, m, d);
    if (date.year != y + 1911 || date.month != m || date.day != d) return null;

    return TransactionDraft(
      merchant: const DraftField.none(), // 商家名稱在右 QR（明細碼）
      totalMinor: DraftField(total, 1.0),
      date: DraftField(date, 1.0),
      sellerTaxId: sellerTaxId,
      invoiceNo: invoiceNo,
    );
  }

  /// 解析左＋右 QR（雙張合併：商家/明細來自右 QR）。
  /// 右 QR 無法解碼時明細留空、僅以左 QR 欄位建草稿（單 QR 舊式發票邊界，
  /// acceptance S3.2）。左 QR 無法辨識回 null。
  static TransactionDraft? parse(String leftQr, String rightQr) =>
      throw UnimplementedError('F03-BE 紅燈 stub：parse');

  /// 右 QR 明細解碼（測資產生回程對稱；InvoiceDetailCodec）。
  static String decodeDetail(String rightQr) => InvoiceDetailCodec.decode(rightQr);
}
