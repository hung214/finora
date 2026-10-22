import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/lock/lock_fe_state.dart';
import '../../../application/providers.dart';
import '../../../application/reports/csv_exporter.dart';
import '../../../application/reports/search_service.dart';
import '../../../application/scan/scan_state.dart';
import '../../../data/sqlite/app_database.dart';
import '../../../domain/services/balance_calculator.dart';
import '../../theme/app_theme.dart';
import 'recent_deletions_page.dart';
import '../recurring/recurring_queue_page.dart';
import '../scan/scan_page.dart';

/// 明細頁（FR-R3 呈現面）：未刪除交易列表＋複合篩選（期間/分類/關鍵字，
/// AND 語意＋chips 可逐一移除＋清除全部）＋匯出 CSV（FR-R4）。
/// 儲存/復原/刪除後即時刷新（AC-02）。
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  int? _periodMonth; // null = 全部（月，取 Clock.now().year）
  String? _categoryFilter; // null = 全部（category id）
  String? _accountFilter; // null = 全部帳戶（P2 雛型帳戶 chips）
  String? _kindFilter; // null = 全部（expense/income/transfer；P2 篩選 chips）
  String _keyword = '';

  bool get _hasFilter =>
      _periodMonth != null ||
      _categoryFilter != null ||
      _accountFilter != null ||
      _kindFilter != null ||
      _keyword.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // 訂閱交易變化（儲存/復原/刪除後即時刷新 AC-02——快記 controller 會 invalidate）。
    ref.watch(ledgerProvider);
    final dueCount = ref.watch(recurringDueCountProvider);
    final db = ref.watch(dbProvider);
    final search = SearchService(db);
    final range = _periodRange(_periodMonth);
    var rows = search.search(
      keyword: _keyword.isEmpty ? null : _keyword,
      startMs: range?.$1,
      endMs: range?.$2,
      categoryId: _categoryFilter,
    );
    // P2（雛型 02-ledger）：帳戶／收支性質維度（預設全部——不影響既有交集語意）。
    if (_accountFilter != null) {
      rows = rows
          .where((r) =>
              r.accountId == _accountFilter || r.toAccountId == _accountFilter)
          .toList();
    }
    if (_kindFilter != null) {
      rows = rows.where((r) => r.kind == _kindFilter).toList();
    }
    final accountById = {
      for (final a in ref.watch(activeAccountsProvider)) a.id: a,
    };
    // 附件索引（📷 標記；掃描儲存附件後 refresh——F03-FE S3）。
    final attachmentTxIds = ref.watch(attachmentTxIdsProvider);
    final months = _availableMonths(db);

    return Scaffold(
      appBar: AppBar(
        title: const Text('明細'),
        actions: [
          // 待確認定期交易 badge（FR-T5 呈現面；F06-FE——0 亦顯示，S2 契約）。
          TextButton(
              key: const Key('recurring-badge'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const RecurringQueuePage()),
              ),
              child: Text('待確認 $dueCount'),
            ),
          // 掃描入口（FR-S6：獨立於快記大鈕；F03 S1）。
          IconButton(
            key: const Key('scan-entry'),
            tooltip: '掃描',
            onPressed: () => openScanFlow(context, ref),
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          TextButton(
            key: const Key('export-csv'),
            onPressed: () => _exportCsv(context, rows),
            child: const Text('匯出 CSV'),
          ),
          // 「最近刪除」入口（F02 S2.5-2；M1 無設定頁——整體屬 F07，dsl §3.3）。
          IconButton(
            key: const Key('ledger-recent-deletions'),
            tooltip: '最近刪除',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RecentDeletionsPage()),
            ),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // P2（雛型 02-ledger）：帳戶 chips 橫列＋收支性質篩選 chips。
          _accountChips(context, db),
          _kindChips(context),
          _filterBar(context, db, months),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasFilter
                              ? Icons.search_off_outlined
                              : Icons.receipt_long_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(_hasFilter ? '無符合結果' : '尚無交易——點右下角快記第一筆'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) => TxTile(
                      tx: rows[i],
                      accountName: accountById[rows[i].accountId]?.name ?? '',
                      toAccount: rows[i].toAccountId == null
                          ? null
                          : accountById[rows[i].toAccountId!],
                      categoryName: rows[i].categoryId == null
                          ? '未分類'
                          : (db.categoryName(rows[i].categoryId!) ?? '未分類'),
                      hasAttachment: attachmentTxIds.contains(rows[i].id),
                      onDelete: () => _confirmDelete(context, ref, rows[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 帳戶 chips 橫列（雛型 02-ledger）：名稱＋餘額（信用卡顯示「應付」）；
  /// 點選＝以該帳戶篩選（再點取消）。隱私遮蔽時金額 ●●●●。
  Widget _accountChips(BuildContext context, AppDatabase db) {
    final accounts = ref.watch(activeAccountsProvider);
    if (accounts.isEmpty) return const SizedBox.shrink();
    const calc = BalanceCalculator();
    final txs = ref.watch(ledgerProvider).map(txEntity).toList();
    final masked = ref.watch(privacyMaskedProvider);
    final fmt = NumberFormat('#,###');
    final tokens = AppTokens.of(context);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (final a in accounts) ...[
            ChoiceChip(
              key: Key('acct-chip-${a.id}'),
              label: Text(
                a.type == 'credit'
                    ? '${a.name} 應付 ${masked ? '●●●●' : fmt.format(calc.creditUnpaidTotal(card: accountEntity(a), txs: txs))}'
                    : '${a.name} ${masked ? '●●●●' : fmt.format(calc.assetBalance(account: accountEntity(a), txs: txs))}',
              ),
              selected: _accountFilter == a.id,
              selectedColor: tokens.success.withValues(alpha: 0.16),
              onSelected: (on) =>
                  setState(() => _accountFilter = on ? a.id : null),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// 收支性質篩選 chips（雛型 02-ledger：全部/支出/收入/轉帳）。
  Widget _kindChips(BuildContext context) {
    const kinds = <(String, String?)>[
      ('全部', null),
      ('支出', 'expense'),
      ('收入', 'income'),
      ('轉帳', 'transfer'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 6,
        children: [
          for (final (label, kind) in kinds)
            FilterChip(
              key: Key('kind-chip-$label'),
              label: Text(label),
              selected: _kindFilter == kind,
              onSelected: (_) => setState(() => _kindFilter = kind),
            ),
        ],
      ),
    );
  }

  Widget _filterBar(BuildContext context, AppDatabase db, List<int> months) {
    final chips = <Widget>[
      if (_periodMonth != null)
        InputChip(
          key: const Key('chip-期間'),
          label: Text('期間 $_periodMonth 月'),
          onDeleted: () => setState(() => _periodMonth = null),
        ),
      if (_categoryFilter != null)
        InputChip(
          key: const Key('chip-分類'),
          label: Text('分類 ${db.categoryName(_categoryFilter!) ?? ''}'),
          onDeleted: () => setState(() => _categoryFilter = null),
        ),
      if (_keyword.isNotEmpty)
        InputChip(
          key: const Key('chip-關鍵字'),
          label: Text('關鍵字 $_keyword'),
          onDeleted: () => setState(() => _keyword = ''),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: PopupMenuButton<int>(
                  key: const Key('filter-period'),
                  tooltip: '期間',
                  onSelected: (m) => setState(() => _periodMonth = m),
                  itemBuilder: (_) => [
                    for (final m in months) PopupMenuItem(value: m, child: Text('$m 月')),
                  ],
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '期間', isDense: true),
                    child: Text(_periodMonth == null ? '全部' : '$_periodMonth 月'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PopupMenuButton<String>(
                  key: const Key('filter-category'),
                  tooltip: '分類',
                  onSelected: (id) => setState(() => _categoryFilter = id),
                  itemBuilder: (_) => [
                    for (final c in db.categoriesByKind('expense'))
                      PopupMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '分類', isDense: true),
                    child: Text(_categoryFilter == null
                        ? '全部'
                        : (db.categoryName(_categoryFilter!) ?? '')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('filter-keyword'),
                  decoration:
                      const InputDecoration(labelText: '關鍵字', isDense: true),
                  onChanged: (v) => setState(() => _keyword = v.trim()),
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty)
            Row(
              children: [
                ...chips.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: c,
                    )),
                TextButton(
                  key: const Key('filter-clear'),
                  onPressed: () => setState(() {
                    _periodMonth = null;
                    _categoryFilter = null;
                    _keyword = '';
                  }),
                  child: const Text('清除篩選'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  (int, int)? _periodRange(int? month) {
    if (month == null) return null;
    final year = DateTime.now().year;
    return (
      DateTime(year, month).millisecondsSinceEpoch,
      DateTime(year, month + 1).millisecondsSinceEpoch,
    );
  }

  /// 有交易之月份（升冪；期間選項）。
  List<int> _availableMonths(AppDatabase db) {
    final months = <int>{};
    for (final t in db.allTransactions()) {
      if (t.deletedAt != null) continue;
      months.add(DateTime.fromMillisecondsSinceEpoch(t.occurredAt).month);
    }
    return months.toList()..sort();
  }

  void _exportCsv(BuildContext context, List<TxRow> rows) {
    final db = ref.read(dbProvider);
    final csv = CsvExporter(
      categoryName: (id) => db.categoryName(id) ?? id,
      accountName: (id) {
        final names =
            db.allAccounts().where((a) => a.id == id).map((a) => a.name).toList();
        return names.isEmpty ? id : names.first;
      },
    ).export(rows);
    // ignore: avoid_print
    print('CSV 匯出（${rows.length} 筆，UTF-8 BOM）：${csv.length} 字元');
    final label = _periodMonth == null ? '全部' : '$_periodMonth 月';
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('匯出 CSV'),
        content: Text(
            '已匯出 $label交易（${NumberFormat('#,###').format(rows.length)} 筆，UTF-8）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  /// 刪除確認（F02 S2.5）：bottom sheet——軟刪除（30 天內可還原）。
  void _confirmDelete(BuildContext context, WidgetRef ref, TxRow tx) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('刪除這筆交易？'),
              subtitle: Text('30 天內可於「最近刪除」還原'),
            ),
            FilledButton(
              key: const Key('tx-delete'),
              onPressed: () {
                ref.read(deleteTransactionProvider).execute(tx.id);
                ref.invalidate(ledgerProvider);
                ref.invalidate(recentDeletionsProvider);
                Navigator.of(sheetCtx).pop();
              },
              child: const Text('刪除'),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 交易列（BDD：明細頁即時顯示該 N 筆 → 金額文字計數）。
///
/// 轉帳樣式（F02 S2.3-5）：swap 圖示（非支出圖示）＋「轉帳」標籤＋路由副標，
/// 金額無正負號（轉帳不計收支）；目標為電子票證 → 顯示「儲值」（F02 S2.4）。
class TxTile extends StatelessWidget {
  const TxTile({
    super.key,
    required this.tx,
    required this.accountName,
    this.toAccount,
    this.categoryName = '未分類',
    this.hasAttachment = false,
    this.onDelete,
  });

  final TxRow tx;
  final String accountName;
  final AccountRow? toAccount;

  /// 分類名稱（拆分樣式副標用）。
  final String categoryName;

  /// 掃描附件標記（FR-S4 呈現面：📷；F03-FE S3）。
  final bool hasAttachment;
  final VoidCallback? onDelete;

  String get _title {
    switch (tx.kind) {
      case 'transfer':
        return toAccount?.type == 'ewallet' ? '儲值' : '轉帳';
      case 'income':
        return tx.merchant ?? '收入';
      default:
        return tx.merchant ?? '支出';
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(tx.occurredAt);
    if (tx.splitGroupId != null) {
      // 拆分樣式（FR-T6）：call_split 圖示＋「拆分 · {分類}」＋群組副標。
      return ListTile(
        onTap: onDelete,
        leading: const Icon(Icons.call_split),
        title: Text('拆分 · $categoryName'),
        subtitle: Text(
          '群組 ${tx.splitGroupId!.substring(0, 8)}… · '
          '${DateFormat('yyyy/MM/dd HH:mm').format(time)}',
        ),
        trailing: Text(
          '-${tx.amountMinor}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    if (tx.kind == 'transfer') {
      return ListTile(
        onTap: onDelete,
        leading: const Icon(Icons.swap_horiz), // 轉帳樣式（非支出圖示）
        title: Text(_title),
        subtitle: Text(
          '$accountName → ${toAccount?.name ?? ''} · '
          '${DateFormat('yyyy/MM/dd HH:mm').format(time)}',
        ),
        trailing: Text(
          '${tx.amountMinor}', // 轉帳不計收支：無正負號
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    return ListTile(
      onTap: onDelete,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(tx.merchant ?? (tx.kind == 'income' ? '收入' : '支出'))),
          if (hasAttachment) ...[
            const SizedBox(width: 4),
            const Text('📷', key: Key('tx-attachment')),
          ],
        ],
      ),
      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(time)),
      trailing: Text(
        tx.kind == 'income' ? '+${tx.amountMinor}' : '-${tx.amountMinor}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
