import 'invoice_line_item.dart';

/// 確認卡草稿（SDD §5.4 TransactionDraft）——QR 解析／OCR 抽取／回退手動輸入
/// 三來源共用；確認卡呈現與最終 SaveTransactionUseCase 入帳之中間態。
///
/// FR-S4：草稿**不得**未經人工確認入帳；FR-S5：信賴度 < 0.7 欄位須標記
/// 需人工確認（needsReview），無候選欄位為**留空**（null，非猜測值）。
class TransactionDraft {
  const TransactionDraft({
    required this.merchant,
    required this.totalMinor,
    required this.date,
    this.sellerTaxId,
    this.invoiceNo,
    this.lineItems = const [],
    this.isFallback = false,
  });

  /// 商家（QR：右 QR 賣方名稱；OCR：頂部行 heuristic）。
  final DraftField<String> merchant;

  /// 總額（minor units；**一律人工確認**——FR-S4，即使信賴度高）。
  final DraftField<int> totalMinor;

  /// 交易日期（QR：開立日；OCR：日期 heuristic；回退：今天）。
  final DraftField<DateTime> date;

  /// 賣方統編（QR 左碼；OCR：8 碼統編反查——無候選為 null）。
  final String? sellerTaxId;

  /// 發票號（QR 左碼；OCR 無此欄）。
  final String? invoiceNo;

  /// 明細（QR 右碼；OCR 無此欄）。
  final List<InvoiceLineItem> lineItems;

  /// 回退手動輸入之空白草稿（FR-S2；日期=今天、其餘留空）。
  final bool isFallback;

  /// 回退空白確認卡（S3.6 acceptance：日期預填今天，供手動輸入）。
  factory TransactionDraft.blank(DateTime now) => TransactionDraft(
        merchant: const DraftField.none(),
        totalMinor: const DraftField.none(),
        date: DraftField(now, 1.0),
        isFallback: true,
      );

  /// 信賴 < 0.7 且有值之欄位數（S4 斷言：0.7 門檻——FR-S5）。
  int get needsReviewCount =>
      [merchant.needsReview, totalMinor.needsReview, date.needsReview]
          .where((e) => e)
          .length;
}

/// 欄位抽取輸出：(值, 信賴度)。value=null 表示**無法判定**（留空非猜測）。
class DraftField<T> {
  const DraftField(this.value, this.confidence) : assert(confidence >= 0 && confidence <= 1);

  const DraftField.none()
      : value = null,
        confidence = 0;

  final T? value;

  /// 0.0~1.0；< 0.7 → [needsReview]（FR-S5 門檻）。
  final double confidence;

  /// 需人工確認（有值且信賴不足）。
  bool get needsReview => value != null && confidence < 0.7;
}
