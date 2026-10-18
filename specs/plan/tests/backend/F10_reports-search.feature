@BE @M2 @FR-R @P0
Feature: 報表聚合與搜尋（後端自動化）
  對應: acceptance F10；SDD §4.2 FTS5、NFR-01 效能

  Background:
    Given 已重置記憶體資料庫
    And 已存在 6 月支出: 餐飲 3 筆共 900、交通 2 筆共 400（經 fixture）
    And 已存在 7 月支出: 餐飲 1 筆 500（經 fixture）
    And 其中 1 筆 6 月餐飲備註含「陽光超商」

  @P0 @FR-R2
  Scenario: 分類占比聚合
    When 執行報表聚合（期間=2026/06）
    Then 餐飲占比 = 69.2%（900/1300）
    And 交通占比 = 30.8%（400/1300）
    And 合計 = 1300（不含 7 月、不含轉帳）

  @P0 @FR-R3
  Scenario: FTS5 中文 bigram 搜尋
    When 搜尋 "超商"
    Then 搜尋 "超商" 命中 1 筆（命中「陽光超商」）
    When 搜尋 "陽光"
    Then 搜尋 "陽光" 命中 1 筆

  @P1 @FR-R3
  Scenario: 複合篩選 AND 語意
    When 篩選 期間=2026/06、分類=餐飲、關鍵字=超商
    Then 命中 1 筆
    When 加上 金額區間 200~400
    Then 命中 0 筆（空結果友善）

  @P1 @FR-R4
  Scenario: CSV 匯出格式
    Given 篩選期間=2026/06
    When 匯出 CSV
    Then 檔案以 UTF-8 BOM 開頭（EF BB BF）
    And 欄位含 日期/類型/金額/幣別/帳戶/分類/商家/備註
    And 金額欄為純數字（6 筆，可 SUM）

  @P0 @NFR-01
  Scenario: 效能_10 萬筆報表
    Given 已匯入 10 萬筆種子交易
    When 執行報表聚合（期間=最近月，計時）
    Then 效能：入庫耗時 1499ms < 1500ms（P95）
