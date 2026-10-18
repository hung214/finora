@BE @M6 @FR-T5 @P1
Feature: 定期交易排程（後端自動化）
  對應: acceptance F06、AC-12；提醒確認制（未確認不入帳）

  Background:
    Given 已重置記憶體資料庫
    And 已建立帳戶「銀行」類型 bank 期初 50000
    And 已建立分類「居住」
    And 已建立定期交易「房租」每月 1 日金額 15000
    And 模擬系統時間為 2026/06/01

  @P1 @AC-12
  Scenario: 到期產生提醒但未入帳
    When 觸發定期交易到期檢查
    Then 通知 spy 收到 N-7 恰 1 次，內容含 "15,000"
    And 交易資料表無新增（未確認不入帳）
    And 待確認佇列含「房租 6/1」

  @P1 @AC-12
  Scenario: 確認入帳且不回寫模板
    Given 待確認佇列含「房租 6/1」
    When 確認入帳（金額改為 16500、日期 2026/06/01）
    Then 交易已入庫且 source = recurring
    And 交易金額 = 16500（模板仍為 15000）
    And next_due_date = 2026/07/01
    And reminder_count 歸零

  @P1 @AC-12
  Scenario: 本次跳過產生下期
    Given 待確認佇列含「房租 6/1」
    When 按下「本次跳過」
    Then 交易資料表無新增
    And next_due_date = 2026/07/01

  @P1 @AC-12
  Scenario: 刪除排程不再提醒
    Given 待確認佇列含「房租 6/1」
    When 刪除排程
    Then recurring_transactions 該列為墓標
    And next_due_date 不再產生提醒

  @P1 @FR-T5
  Scenario: 同期逾期 3 次暫停推播
    Given 模擬系統時間為 2026/06/01 並觸發到期檢查（第 1 次）
    And 模擬系統時間為 2026/06/02 並觸發到期檢查（第 2 次）
    And 模擬系統時間為 2026/06/03 並觸發到期檢查（第 3 次）
    When 模擬系統時間為 2026/06/04 並觸發到期檢查
    Then 通知 spy 收到 N-7 恰 3 次（第 4 次不發）
    And reminder_count = 3 且 paused = true
    And 待確認佇列仍保留「房租 6/1」
