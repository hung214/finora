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

/// Schema v2（M2 基線，T-S2）：budgets（FR-B2）＋ income_goals（FR-B6）＋
/// transactions_fts（FTS5 影子表，FR-R3 bigram）——逐句對齊 data-spec.dbml v0.3
/// （表已於 v0.3 全表補完，本版為 code schema 對齊落地）。
class SchemaV2 {
  SchemaV2._();

  static const int version = 2;

  /// 必建表（遷移於交易內全有全無；失敗即阻斷）。
  static const List<String> statements = [
    '''
    CREATE TABLE budgets (
      id TEXT PRIMARY KEY,
      category_id TEXT,
      amount_minor INTEGER NOT NULL,
      period_start_day INTEGER NOT NULL DEFAULT 1,
      rollover INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
    '''
    CREATE TABLE income_goals (
      id TEXT PRIMARY KEY,
      amount_minor INTEGER NOT NULL,
      period_start_day INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
  ];

  /// FTS5 虛擬表（FR-R3：中文 bigram 影子欄位——unicode61 不切中文）。
  ///
  /// **容錯降級**：部分環境（如 winsqlite3.dll）可能缺 FTS5 模組——建表失敗
  /// 不阻斷 v2 遷移（遷移器 try-catch 跳過）；F10 依表存在性分流（FTS5／LIKE）。
  static const List<String> ftsStatements = [
    'CREATE VIRTUAL TABLE transactions_fts USING fts5'
        '(merchant_bigram, note_bigram, rowid_ref UNINDEXED)',
  ];
}

/// Schema v3（M3 基線，T-S3）：credit_card_details（FR-A3）＋statements/
/// statement_items（FR-C3 帳單）＋refund_links（FR-C8）＋installment_plans
/// （FR-C7）——逐句對齊 data-spec.dbml v0.3（表已預定義，code schema 對齊落地）。
class SchemaV3 {
  SchemaV3._();

  static const int version = 3;

  /// 必建表（遷移於交易內全有全無）。
  static const List<String> statements = [
    '''
    CREATE TABLE credit_card_details (
      account_id TEXT PRIMARY KEY,
      last4 TEXT,
      statement_day INTEGER NOT NULL,
      due_offset_days INTEGER NOT NULL,
      linked_account_id TEXT,
      boundary_rule TEXT NOT NULL DEFAULT 'include',
      credit_limit_minor INTEGER,
      effective_from INTEGER
    )
    ''',
    '''
    CREATE TABLE statements (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      period_start INTEGER NOT NULL,
      period_end INTEGER NOT NULL,
      statement_date INTEGER NOT NULL,
      due_date INTEGER NOT NULL,
      total_minor INTEGER NOT NULL,
      paid_minor INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL,
      paid_at INTEGER,
      overdue_notified INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
    '''
    CREATE TABLE statement_items (
      statement_id TEXT NOT NULL,
      transaction_id TEXT NOT NULL,
      PRIMARY KEY (statement_id, transaction_id)
    )
    ''',
    '''
    CREATE TABLE refund_links (
      refund_tx_id TEXT PRIMARY KEY,
      original_tx_id TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE installment_plans (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      total_minor INTEGER NOT NULL,
      installments INTEGER NOT NULL,
      first_date INTEGER NOT NULL,
      note TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
  ];
}

/// Schema v4（M4 基線，T-S4）：attachments（FR-S4 附件中繼資——sha256 內容
/// 定址，同步去重 SDD §5.5.6；blob 本體以 {sha256} 命名存 app 支援目錄
/// blobs/，SDD §4.2 約定，落地於 F03 儲存流程）——逐句對齊 data-spec.dbml
/// v0.3（表已預定義，code schema 對齊落地）。
class SchemaV4 {
  SchemaV4._();

  static const int version = 4;

  /// 必建表（遷移於交易內全有全無）。
  static const List<String> statements = [
    '''
    CREATE TABLE attachments (
      id TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      mime TEXT,
      byte_size INTEGER,
      created_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
  ];
}

/// Schema v5（T-S5 前段，隨 F07/M5）：sync_events（FR-Y5 LWW 落敗事件——
/// 衝突檢視 AC-07）＋ recurring_transactions（FR-T5 定期交易——表一次到位
/// 避免中途改欄，業務使用屬 M6）——逐句對齊 data-spec.dbml v0.3
/// （表已預定義，code schema 對齊落地）。
class SchemaV5 {
  SchemaV5._();

  static const int version = 5;

  /// 必建表（遷移於交易內全有全無）。
  static const List<String> statements = [
    '''
    CREATE TABLE sync_events (
      id TEXT PRIMARY KEY,
      entity TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      incoming_hlc TEXT NOT NULL,
      overwritten_row TEXT,
      created_at INTEGER NOT NULL,
      read_at INTEGER
    )
    ''',
    '''
    CREATE TABLE recurring_transactions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      kind TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      account_id TEXT NOT NULL,
      category_id TEXT NOT NULL,
      frequency TEXT NOT NULL,
      interval_days INTEGER,
      anchor_date INTEGER NOT NULL,
      end_type TEXT NOT NULL,
      end_count INTEGER,
      end_date INTEGER,
      next_due_date INTEGER NOT NULL,
      reminder_count INTEGER NOT NULL DEFAULT 0,
      paused INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      hlc TEXT NOT NULL,
      deleted_at INTEGER
    )
    ''',
  ];
}

/// v6（M8）：帳戶「是否計入合併統計」（SPEC FR-A2/A6/A7）。
///
/// 增量：既有 `accounts` 補欄。`DEFAULT 1` → 既有資料維持「計入合併」語意
/// （升級不改變既有使用者所見合計）。V1 DDL 維持原樣（T-H9 truth 對齊 regex
/// 相容——新裝亦經本增量取得欄位，避免重複欄位）。
class SchemaV6 {
  SchemaV6._();

  static const int version = 6;

  static const List<String> statements = [
    'ALTER TABLE accounts ADD COLUMN include_in_totals INTEGER NOT NULL DEFAULT 1',
  ];
}
