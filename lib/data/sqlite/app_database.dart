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

  int get schemaVersion => SchemaV1.version;

  void _migrate() {
    _db.execute('BEGIN');
    try {
      for (final s in SchemaV1.statements) {
        _db.execute(s);
      }
      for (final s in SchemaV1.indexes) {
        _db.execute(s);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
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

  // ── 同步日誌（SDD §5.5） ──────────────────────────────────

  void appendOp(OplogRow o) => _db.execute(
        'INSERT INTO oplog (entity, entity_id, hlc, payload, packed_seq) VALUES (?, ?, ?, ?, ?)',
        [o.entity, o.entityId, o.hlc, o.payload, o.packedSeq],
      );

  List<OplogRow> allOps() =>
      _db.select('SELECT * FROM oplog ORDER BY seq').map(OplogRow.fromRow).toList();

  /// 交易寫入 + oplog 追加必須同一 transaction（SDD §5.1 儲存事務）。
  void saveTransactionWithOplog(TxRow t, OplogRow o) {
    _db.execute('BEGIN');
    try {
      insertTransaction(t);
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
  });

  final String id;
  final String kind;
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
      );
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
