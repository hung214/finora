/// Schema v1（M1 核心記帳）DDL — 逐句對齊 specs/truth/data-spec.dbml。
/// 變更規則：先改 dbml（truth PR）→ 本檔 + schema 回歸測試（tasks.md §3）。
class SchemaV1 {
  SchemaV1._();

  static const int version = 1;

  static const List<String> statements = [
    '''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      currency TEXT NOT NULL DEFAULT 'TWD',
      opening_amount_minor INTEGER NOT NULL DEFAULT 0,
      color TEXT,
      icon TEXT,
      sort_order INTEGER,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
    '''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      parent_id TEXT,
      name TEXT NOT NULL,
      icon TEXT,
      color TEXT,
      sort_order INTEGER,
      is_system INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
    '''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency TEXT NOT NULL,
      fx_rate REAL,
      account_id TEXT NOT NULL,
      to_account_id TEXT,
      category_id TEXT,
      merchant TEXT,
      note TEXT,
      tags TEXT,
      occurred_at INTEGER NOT NULL,
      source TEXT NOT NULL DEFAULT 'manual',
      split_group_id TEXT,
      settlement_status TEXT NOT NULL DEFAULT 'none',
      installment_plan_id TEXT,
      installment_seq INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
    '''
    CREATE TABLE oplog (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      entity TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      hlc TEXT NOT NULL,
      payload TEXT,
      packed_seq INTEGER
    )
    ''',
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE templates (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      payload TEXT NOT NULL,
      use_count INTEGER NOT NULL DEFAULT 0,
      last_used_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
  ];

  static const List<String> indexes = [
    'CREATE INDEX idx_tx_time ON transactions(occurred_at)',
    'CREATE INDEX idx_tx_account ON transactions(account_id, occurred_at)',
    'CREATE INDEX idx_tx_category ON transactions(category_id, occurred_at)',
  ];
}
