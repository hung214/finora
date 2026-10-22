@BE @M8 @FR-A7 @FR-B1 @FR-O1 @P0
Feature: 帳戶與分類設定（後端自動化）
  對應: SPEC §5.1 FR-A2/A6/A7；§5.5 FR-B1；§5.10 FR-O1；SDD §5.6

  Background:
    Given 已重置記憶體資料庫
    And 內建預設帳戶「現金」與分類集

  @P0 @FR-A7 @FR-A2
  Scenario: 新增帳戶寫入 oplog 整列快照
    When 建立帳戶「緊急金」類型 bank、期初 5000、計入合併=false
    Then accounts 表有「緊急金」且 include_in_totals=false
    And oplog 有 1 筆 accounts 新增（payload 為整列快照）

  @P0 @FR-A6 @FR-A2
  Scenario: 不計入合併統計排除於資產合計
    Given 帳戶「現金」期初 1000 且計入合併=true
    And 帳戶「緊急金」期初 5000 且計入合併=false
    When 計算資產合計
    Then 資產合計 = 1000
    And 帳戶「現金」餘額 1000、「緊急金」餘額 5000（各自獨立）

  @P0 @FR-A2 @FR-A7
  Scenario: 刪除有未結算交易的帳戶被拒絕
    Given 帳戶「示例卡」有本期未繳帳單
    When 刪除帳戶「示例卡」
    Then 拋出例外「此帳戶仍有未結算交易，可改為封存」
    And 帳戶「示例卡」仍存在

  @P0 @FR-A2 @FR-A7
  Scenario: 編輯帳戶名稱與類型寫入 oplog
    When 更新帳戶「現金」為 名稱「錢包」、類型 ewallet
    Then 帳戶「錢包」類型為 ewallet
    And oplog 有 1 筆 accounts 更新（payload 為整列快照）

  @P0 @FR-B1
  Scenario: 新增分類並重排 sort_order
    When 新增支出分類「寵物」
    And 將分類「寵物」排在「餐飲食品」之前
    Then 分類列表首位為「寵物」、次位為「餐飲食品」
    And 各分類 sort_order 為連續遞增整數

  @P0 @FR-B1
  Scenario: 刪除有交易引用的分類被拒絕
    Given 分類「餐飲食品」已有 3 筆交易
    When 刪除分類「餐飲食品」
    Then 拋出例外「此分類已有交易引用，可改為封存或改用其他分類」
    And 分類「餐飲食品」仍存在

  @P1 @FR-B1
  Scenario: 一層子分類限制
    When 於「餐飲食品」下新增子分類「早餐」
    Then 分類「早餐」父分類為「餐飲食品」
    When 嘗試於「早餐」下再新增子分類「豆漿」
    Then 拋出例外「僅支援一層子分類」

  @P0 @FR-O1
  Scenario: 外觀設定持久化（檔案 DB）
    Given 已開啟檔案資料庫（暫存檔）
    When 設定外觀為 dark
    And 關閉並重新開啟同一資料庫
    Then settings app.theme_mode = dark
