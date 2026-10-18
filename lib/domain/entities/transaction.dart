import '../../core/hlc.dart';

/// 交易實體（SDD §4.2 transactions 表的領域對映，M0 骨架版）。
enum TxKind {
  expense,
  income,
  transfer,
  repayment, // 信用卡還款（帳戶間轉帳語意）
  refund, // 退款衝銷（refund_links）
}

enum TxSource { manual, scan, template, recurring, import }

enum SettlementStatus {
  none, // 非信用卡交易
  pending, // 預扣：未結帳，不影響連結銀行帳戶餘額（FR-C1）
  billed, // 已結入帳單（FR-C3）
  settled, // 帳單已繳
}

class Tx {
  const Tx({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.merchant,
    this.note,
    this.occurredAt = 0,
    this.source = TxSource.manual,
    this.settlementStatus = SettlementStatus.none,
    this.deleted = false,
    this.hlc,
  });

  final String id;
  final TxKind kind;

  /// 正數；方向由 [kind] 與帳戶語意決定（SDD §4.2）。
  final int amountMinor;
  final String accountId;

  /// transfer / repayment 的對方帳戶。
  final String? toAccountId;
  final String? categoryId;
  final String? merchant;
  final String? note;

  /// 消費/發生時間（ms, epoch）。
  final int occurredAt;
  final TxSource source;
  final SettlementStatus settlementStatus;

  /// 墓標軟刪除（SDD 原則 5）。
  final bool deleted;
  final Hlc? hlc;

  Tx copyWith({bool? deleted, SettlementStatus? settlementStatus, Hlc? hlc}) => Tx(
        id: id,
        kind: kind,
        amountMinor: amountMinor,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        merchant: merchant,
        note: note,
        occurredAt: occurredAt,
        source: source,
        settlementStatus: settlementStatus ?? this.settlementStatus,
        deleted: deleted ?? this.deleted,
        hlc: hlc ?? this.hlc,
      );
}
