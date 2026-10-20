/// 電子發票明細列（右 QR `品名**數量**單價**金額` 分段；SDD §5.4）。
class InvoiceLineItem {
  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  final String name;

  /// 數量（minor 不適用——整數件數）。
  final int quantity;

  /// 單價（minor units）。
  final int unitPrice;

  /// 金額（minor units；= 數量 × 單價，codec 端點對端點驗）。
  final int amount;
}
