import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

/// Windows 測試環境：系統內建 winsqlite3.dll（App 執行時由 sqlite3_flutter_libs
/// 提供 bundled sqlite3）。須在任何開庫動作前呼叫一次。
void ensureSqliteOpenable() {
  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('winsqlite3.dll'));
  }
}

/// App 資料庫（Schema v1 = M1 核心記帳，逐句對齊 specs/truth/data-spec.dbml）。
///
/// T-S1 過渡實作：sqlite3 直連（drift 暫緩，research TR-7——工具鏈與 Dart 3.13.5
/// 相容問題，M1 前於 CI 重試回歸 drift；屆時本層 API 維持不變，僅換底層）。
class AppDatabase {
  AppDatabase.inMemory() {
    ensureSqliteOpenable();
    _db = sqlite3.openInMemory();
    _migrate();
  }

  AppDatabase.open(String path) {
    ensureSqliteOpenable();
    _db = sqlite3.open(path, mode: OpenMode.readWriteCreate);
    _migrate();
  }

  late final Database _db;
  bool _closed = false;

  int get schemaVersion => SchemaV2.version;

  void _migrate() {
    // DBG-004／T-S2：多版本冪等遷移——
    // ① `PRAGMA user_version` 版本閘：已達最新直接跳過（第二啟動不再重跑 DDL）。
    // ② 既有表偵測：v0.4.x 期間建立、user_version 未標記之舊檔 → 補標 v1。
    // ③ 逐版本增量：每版本於交易內全有全無（v1 全量 DDL／v2 增量表）。
    // DDL 字串維持原樣（T-H9 truth 對齊 regex 相容）。
    var current = _db.select('PRAGMA user_version').first.values.first as int;
    if (current >= SchemaV2.version) return;
    if (current < 1) {
      final tablesExist = _db
          .select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'accounts'")
          .isNotEmpty;
      if (tablesExist) {
        current = 1;
        _db.execute('PRAGMA user_version = ${SchemaV1.version}');
      }
    }
    if (current < 1) {
      _db.execute('BEGIN');
      try {
        for (final s in SchemaV1.statements) {
          _db.execute(s);
        }
        for (final s in SchemaV1.indexes) {
          _db.execute(s);
        }
        _db.execute('PRAGMA user_version = ${SchemaV1.version}');
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
    }
    if (current < 2) {
      _db.execute('BEGIN');
      try {
        for (final s in SchemaV2.statements) {
          _db.execute(s);
        }
        _db.execute('PRAGMA user_version = ${SchemaV2.version}');
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
      // FTS5 虛擬表：環境缺模組時**容錯降級**（不阻斷 v2；F10 依表存在性分流）。
      for (final s in SchemaV2.ftsStatements) {
        try {
          _db.execute(s);
        } catch (e) {
          // ignore: avoid_print
          print('T-S2：FTS5 建表跳過（環境不支援）——$e');
        }
      }
    }
  }

  List<String> tableNames() => _db
      .select("SELECT name FROM sqlite_master WHERE type='table'")
      .map((r) => r['name'] as String)
      .toList();

  void close() {
    if (!_closed) {
      _db.dispose();
      _closed = true;
    }
  }

  // ── 帳戶（FR-A） ──────────────────────────────────────────

  void insertAccount(AccountRow a) => _db.execute(
        'INSERT INTO accounts (id, type, name, currency, opening_amount_minor, archived, created_at, updated_at, hlc)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          a.id, a.type, a.name, a.currency, a.openingAmountMinor,
          a.archived ? 1 : 0, a.createdAt, a.updatedAt, a.hlc,
        ],
      );

  /// 帳戶寫入 + oplog 追加於同一 transaction（SDD §5.1 契約；首次啟動播種用）。
  void insertAccountWithOplog(AccountRow a, OplogRow o) {
    _db.execute('BEGIN');
    try {
      insertAccount(a);
      appendOp(o);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<AccountRow> allAccounts() => _db
      .select('SELECT * FROM accounts ORDER BY sort_order IS NULL, sort_order')
      .map(AccountRow.fromRow)
      .toList();

  // ── 分類（FR-B1） ─────────────────────────────────────────

  void insertCategory(CategoryRow c) => _db.execute(
        'INSERT INTO categories (id, kind, parent_id, name, is_system, created_at, updated_at, hlc)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [c.id, c.kind, c.parentId, c.name, c.isSystem ? 1 : 0, c.createdAt, c.updatedAt, c.hlc],
      );

  /// 分類寫入 + oplog 追加於同一 transaction（SDD §5.1 契約；首次啟動播種用）。
  void insertCategoryWithOplog(CategoryRow c, OplogRow o) {
    _db.execute('BEGIN');
    try {
      insertCategory(c);
      appendOp(o);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<CategoryRow> categoriesByKind(String kind) => _db
      .select('SELECT * FROM categories WHERE kind = ? ORDER BY sort_order IS NULL, sort_order', [kind])
      .map(CategoryRow.fromRow)
      .toList();

  // ── 交易（FR-T） ──────────────────────────────────────────

  void insertTransaction(TxRow t) => _db.execute(
        'INSERT INTO transactions (id, kind, amount_minor, currency, account_id, to_account_id,'
        ' category_id, merchant, note, occurred_at, source, settlement_status, created_at, updated_at, hlc)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          t.id, t.kind, t.amountMinor, t.currency, t.accountId, t.toAccountId,
          t.categoryId, t.merchant, t.note, t.occurredAt, t.source,
          t.settlementStatus, t.createdAt, t.updatedAt, t.hlc,
        ],
      );

  List<TxRow> transactionsByAccount(String accountId) => _db
      .select('SELECT * FROM transactions WHERE account_id = ? ORDER BY occurred_at', [accountId])
      .map(TxRow.fromRow)
      .toList();

  List<TxRow> allTransactions() => _db
      .select('SELECT * FROM transactions ORDER BY occurred_at, id')
      .map(TxRow.fromRow)
      .toList();

  /// 區間內未刪除交易（occurred_at ∈ [start, end)）；本月統計用（F02 S2.3）。
  List<TxRow> transactionsBetween(int startMs, int endMs) => _db
      .select('SELECT * FROM transactions'
              ' WHERE occurred_at >= ? AND occurred_at < ? AND deleted_at IS NULL'
              ' ORDER BY occurred_at, id',
          [startMs, endMs])
      .map(TxRow.fromRow)
      .toList();

  // ── 同步日誌（SDD §5.5） ──────────────────────────────────

  void appendOp(OplogRow o) => _db.execute(
        'INSERT INTO oplog (entity, entity_id, hlc, payload, packed_seq) VALUES (?, ?, ?, ?, ?)',
        [o.entity, o.entityId, o.hlc, o.payload, o.packedSeq],
      );

  List<OplogRow> allOps() =>
      _db.select('SELECT * FROM oplog ORDER BY seq').map(OplogRow.fromRow).toList();

  /// 交易寫入 + oplog 追加必須同一 transaction（SDD §5.1 儲存事務）。
  ///
  /// [beforeOplog] 為測試 seam：於交易列插入後、oplog 追加前呼叫，拋錯即模擬
  /// 「中斷」，驗證整體 ROLLBACK 不產生孤兒（BDD 步驟：中斷模擬不產生孤兒）。
  void saveTransactionWithOplog(TxRow t, OplogRow o, {void Function(TxRow)? beforeOplog}) {
    _db.execute('BEGIN');
    try {
      insertTransaction(t);
      beforeOplog?.call(t);
      appendOp(o);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// 依 id 讀取單筆交易（含墓標）。
  TxRow? transactionById(String id) {
    final rows = _db.select('SELECT * FROM transactions WHERE id = ?', [id]);
    return rows.isEmpty ? null : TxRow.fromRow(rows.first);
  }

  /// 上一筆未刪除交易（FR-Q4 帳戶預設 = 上一筆所用帳戶）。
  /// 排序：occurred_at → created_at → id（後者為同刻之確定性打破）。
  TxRow? lastTransaction() {
    final rows = _db.select(
      'SELECT * FROM transactions WHERE deleted_at IS NULL'
      ' ORDER BY occurred_at DESC, created_at DESC, id DESC LIMIT 1',
    );
    return rows.isEmpty ? null : TxRow.fromRow(rows.first);
  }

  /// 指定商家的未刪除交易（FR-Q4 同商家歷史分類）。
  List<TxRow> transactionsByMerchant(String merchant) => _db
      .select('SELECT * FROM transactions WHERE merchant = ? AND deleted_at IS NULL'
          ' ORDER BY occurred_at DESC', [merchant])
      .map(TxRow.fromRow)
      .toList();

  /// 軟刪除墓標（SDD 原則 5）：UPDATE deleted_at + oplog 墓標（payload=NULL）
  /// 於**同一 transaction**（鏡像 [saveTransactionWithOplog] 契約）。
  /// 已刪除者拋 StateError（防重複墓標——同步後多刪，acceptance F01 S1.8）。
  void softDeleteTransactionWithOplog(
    String id,
    OplogRow o, {
    required int deletedAt,
    required String hlc,
  }) {
    final tx = transactionById(id);
    if (tx == null) {
      throw StateError('軟刪除失敗：交易不存在 $id');
    }
    if (tx.deletedAt != null) {
      throw StateError('軟刪除失敗：交易已為墓標 $id');
    }
    _db.execute('BEGIN');
    try {
      _db.execute(
        'UPDATE transactions SET deleted_at = ?, updated_at = ?, hlc = ? WHERE id = ?',
        [deletedAt, deletedAt, hlc, id],
      );
      appendOp(o);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// 實體清除 deleted_at <= cutoffMs 之墓標列（FR-T3 保留期屆滿，F02 S2.5）。
  /// oplog 墓標保留（同步日誌完整性，GC 屬 F07）。回傳清除筆數；冪等（無候選回 0）。
  int purgeTransactionsDeletedBefore(int cutoffMs) {
    _db.execute('BEGIN');
    try {
      final count = _db
          .select(
              'SELECT COUNT(*) AS c FROM transactions'
              ' WHERE deleted_at IS NOT NULL AND deleted_at <= ?',
              [cutoffMs])
          .first['c'] as int;
      if (count > 0) {
        _db.execute(
          'DELETE FROM transactions WHERE deleted_at IS NOT NULL AND deleted_at <= ?',
          [cutoffMs],
        );
      }
      _db.execute('COMMIT');
      return count;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// 還原墓標（FR-T3 30 天內，acceptance F02 S2.5 步驟 3）：deleted_at → NULL
  /// + oplog **整列快照**（非墓標——還原是 UPDATE，同步端以快照覆蓋）於
  /// **同一 transaction**（鏡像 [softDeleteTransactionWithOplog] 契約）。
  /// 未刪除/不存在者拋 StateError（防還原幻影）。
  void restoreTransactionWithOplog(
    String id,
    OplogRow o, {
    required int restoredAt,
    required String hlc,
  }) {
    final tx = transactionById(id);
    if (tx == null) {
      throw StateError('還原失敗：交易不存在 $id');
    }
    if (tx.deletedAt == null) {
      throw StateError('還原失敗：交易未刪除 $id');
    }
    _db.execute('BEGIN');
    try {
      _db.execute(
        'UPDATE transactions SET deleted_at = NULL, updated_at = ?, hlc = ? WHERE id = ?',
        [restoredAt, hlc, id],
      );
      appendOp(o);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // ── 設定（key-value；device.* 為 per-device 不入 oplog） ──

  void setSetting(String key, String value) => _db.execute(
        'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)'
        ' ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
        [key, value, DateTime.now().millisecondsSinceEpoch],
      );

  String? getSetting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }
}

// ── Row 型別（欄位對映 data-spec.dbml） ──────────────────────

class AccountRow {
  const AccountRow({
    required this.id,
    required this.type,
    required this.name,
    required this.currency,
    required this.openingAmountMinor,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    required this.hlc,
  });

  final String id;
  final String type;
  final String name;
  final String currency;
  final int openingAmountMinor;
  final bool archived;
  final int createdAt;
  final int updatedAt;
  final String hlc;

  factory AccountRow.fromRow(Map<String, Object?> r) => AccountRow(
        id: r['id'] as String,
        type: r['type'] as String,
        name: r['name'] as String,
        currency: r['currency'] as String,
        openingAmountMinor: r['opening_amount_minor'] as int,
        archived: (r['archived'] as int) == 1,
        createdAt: r['created_at'] as int,
        updatedAt: r['updated_at'] as int,
        hlc: r['hlc'] as String,
      );

  /// oplog payload 之整列快照（SDD §5.5.4）。
  Map<String, Object?> toSnapshot() => {
        'id': id,
        'type': type,
        'name': name,
        'currency': currency,
        'opening_amount_minor': openingAmountMinor,
        'archived': archived,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'hlc': hlc,
      };
}

class CategoryRow {
  const CategoryRow({
    required this.id,
    required this.kind,
    required this.parentId,
    required this.name,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    required this.hlc,
  });

  final String id;
  final String kind;
  final String? parentId;
  final String name;
  final bool isSystem;
  final int createdAt;
  final int updatedAt;
  final String hlc;

  factory CategoryRow.fromRow(Map<String, Object?> r) => CategoryRow(
        id: r['id'] as String,
        kind: r['kind'] as String,
        parentId: r['parent_id'] as String?,
        name: r['name'] as String,
        isSystem: (r['is_system'] as int) == 1,
        createdAt: r['created_at'] as int,
        updatedAt: r['updated_at'] as int,
        hlc: r['hlc'] as String,
      );

  /// oplog payload 之整列快照（SDD §5.5.4）。
  Map<String, Object?> toSnapshot() => {
        'id': id,
        'kind': kind,
        'parent_id': parentId,
        'name': name,
        'is_system': isSystem,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'hlc': hlc,
      };
}

class TxRow {
  const TxRow({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.currency,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.merchant,
    required this.note,
    required this.occurredAt,
    required this.source,
    required this.settlementStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.hlc,
    this.deletedAt,
  });

  final String id;
  final String kind;

  /// 正數；方向由 [kind] 與帳戶語意決定（SDD §4.2）。
  final int amountMinor;
  final String currency;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? merchant;
  final String? note;
  final int occurredAt;
  final String source;
  final String settlementStatus;
  final int createdAt;
  final int updatedAt;
  final String hlc;

  /// 墓標（SDD 原則 5）；null = 未刪除。
  final int? deletedAt;

  factory TxRow.fromRow(Map<String, Object?> r) => TxRow(
        id: r['id'] as String,
        kind: r['kind'] as String,
        amountMinor: r['amount_minor'] as int,
        currency: r['currency'] as String,
        accountId: r['account_id'] as String,
        toAccountId: r['to_account_id'] as String?,
        categoryId: r['category_id'] as String?,
        merchant: r['merchant'] as String?,
        note: r['note'] as String?,
        occurredAt: r['occurred_at'] as int,
        source: r['source'] as String,
        settlementStatus: r['settlement_status'] as String,
        createdAt: r['created_at'] as int,
        updatedAt: r['updated_at'] as int,
        hlc: r['hlc'] as String,
        deletedAt: r['deleted_at'] as int?,
      );

  /// oplog payload 之整列快照（SDD §5.5.4：非欄位 diff，套用冪等）。
  Map<String, Object?> toSnapshot() => {
        'id': id,
        'kind': kind,
        'amount_minor': amountMinor,
        'currency': currency,
        'account_id': accountId,
        'to_account_id': toAccountId,
        'category_id': categoryId,
        'merchant': merchant,
        'note': note,
        'occurred_at': occurredAt,
        'source': source,
        'settlement_status': settlementStatus,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'hlc': hlc,
        'deleted_at': deletedAt,
      };
}

class OplogRow {
  const OplogRow({
    required this.entity,
    required this.entityId,
    required this.hlc,
    required this.payload,
    required this.packedSeq,
    this.seq,
  });

  final int? seq;
  final String entity;
  final String entityId;
  final String hlc;
  final String? payload;
  final int? packedSeq;

  factory OplogRow.fromRow(Map<String, Object?> r) => OplogRow(
        seq: r['seq'] as int,
        entity: r['entity'] as String,
        entityId: r['entity_id'] as String,
        hlc: r['hlc'] as String,
        payload: r['payload'] as String?,
        packedSeq: r['packed_seq'] as int?,
      );
}
