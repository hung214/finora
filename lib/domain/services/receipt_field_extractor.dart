import '../../core/clock.dart';
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
  ///
  /// Heuristics（SDD §5.4）：
  /// - 商家：頂部首行（OCR 無字級資訊之簡化）→ 0.8。
  /// - 總額：關鍵字（總計/合計/總額/TOTAL/應收/實收）鄰近數值 → 0.9；
  ///   無關鍵字回退全場最大數值 → 0.4（<0.7 需確認）；無數值 → null。
  /// - 日期：西元多格式 → 0.9；民國（3 碼年，須 +1911 換算、紀元多義）→ 0.5；
  ///   取最接近今天之候選；無候選 → null。
  /// - 統編：關鍵字（統一編號/統編）鄰近 8 碼 → 0.9；無候選 → null（不猜測）。
  static OcrExtraction extract(String ocrText) {
    final lines =
        ocrText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // ── 商家（頂部行）──
    final merchant = lines.isEmpty
        ? const DraftField<String>.none()
        : DraftField(lines.first, 0.8);

    // ── 總額（關鍵字鄰近 → 最大數值回退）──
    int? total;
    var totalConf = 0.0;
    final totalKw =
        RegExp(r'(?:總計|合計|總額|總金額|TOTAL|應收|實收)\s*[:：]?\s*([0-9,]+)');
    for (final line in lines) {
      final m = totalKw.firstMatch(line);
      if (m == null) continue;
      final v = int.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v != null && (total == null || v > total)) {
        total = v;
        totalConf = 0.9;
      }
    }
    if (total == null) {
      final nums = RegExp(r'(?<![\d,.])(\d+)(?![\d,.])')
          .allMatches(ocrText)
          .map((m) => int.parse(m.group(1)!))
          .toList();
      if (nums.isNotEmpty) {
        total = nums.reduce((a, b) => a >= b ? a : b);
        totalConf = 0.4;
      }
    }

    // ── 日期（西元 0.9／民國 0.5；取最接近今天）──
    final today = Clock.now();
    DateTime? bestDate;
    var bestConf = 0.0;
    var bestDist = 1 << 60;
    void consider(DateTime candidate, double conf) {
      final dist = candidate.difference(today).abs().inDays;
      if (bestDate == null || dist < bestDist) {
        bestDate = candidate;
        bestConf = conf;
        bestDist = dist;
      }
    }

    // 西元：2026/10/18、2026-10-18、2026年10月18日、2026.10.18
    final ce = RegExp(r'(?<!\d)(\d{4})[/年.\-](\d{1,2})[/月.\-](\d{1,2})日?(?!\d)');
    for (final m in ce.allMatches(ocrText)) {
      final d = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!));
      if (d.month == int.parse(m.group(2)!) && d.day == int.parse(m.group(3)!)) {
        consider(d, 0.9);
      }
    }
    // 民國：3 碼年（100~199）→ +1911；格式多義（無紀元標記）→ 低信賴 0.5。
    final roc = RegExp(r'(?<!\d)(\d{3})[/年.\-](\d{1,2})[/月.\-](\d{1,2})日?(?!\d)');
    for (final m in roc.allMatches(ocrText)) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      if (y < 100 || y > 199) continue;
      final g = DateTime(y + 1911, mo, d);
      if (g.month == mo && g.day == d) consider(g, 0.5);
    }

    // ── 統編（關鍵字鄰近 8 碼；無候選不猜測）──
    String? taxId;
    final taxKw = RegExp(r'(?:統一編號|統編|統一編|Uniform\s*Number)\s*[:：]?\s*(\d{8})');
    for (final line in lines) {
      final m = taxKw.firstMatch(line);
      if (m != null) {
        taxId = m.group(1)!;
        break;
      }
    }

    return OcrExtraction(
      merchant: merchant,
      totalMinor:
          total == null ? const DraftField<int>.none() : DraftField(total, totalConf),
      date: bestDate == null
          ? const DraftField<DateTime>.none()
          : DraftField(bestDate, bestConf),
      sellerTaxId:
          taxId == null ? const DraftField<String>.none() : DraftField(taxId, 0.9),
    );
  }
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
