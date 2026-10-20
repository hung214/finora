import '../../domain/entities/transaction_draft.dart';

/// OCR 文字欄位抽取 heuristics（SDD §5.4 ReceiptPipeline——FR-S5）。
///
/// 規則（SDD §5.4）：
/// - 日期：民國/西元多格式 regex，取「最接近今天」候選。
/// - 總額：關鍵字（總計/合計/TOTAL/應收/實收）鄰近數值＋全場最大數值加權。
/// - 商家：頂部最大字級行／8 碼統編反查。
/// - 每欄輸出 (value, confidence)；`confidence < 0.7` → needsReview（FR-S5）。
/// - **無候選 → 留空 null**（不猜測）。
///
/// 全程純本機（FR-S3）：輸入為 OCR 引擎已產出之文字，本抽取無網路依賴。
class ReceiptFieldExtractor {
  ReceiptFieldExtractor._();

  /// 對 OCR 文字執行欄位抽取（T-H6 文字 fixture 為輸入契約）。
  static OcrExtraction extract(String ocrText) =>
      throw UnimplementedError('F03-BE 紅燈 stub：extract');
}

/// OCR 抽取結果：三欄位＋統編（SDD §5.4；draft 由呼叫端組裝）。
class OcrExtraction {
  const OcrExtraction({
    required this.merchant,
    required this.totalMinor,
    required this.date,
    required this.sellerTaxId,
  });

  final DraftField<String> merchant;
  final DraftField<int> totalMinor;
  final DraftField<DateTime> date;

  /// 8 碼統編反查（SDD §10 未決 3——無候選為 null，非猜測）。
  final DraftField<String> sellerTaxId;
}
