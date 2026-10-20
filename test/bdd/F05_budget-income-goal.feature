@BE @M2 @FR-B @P0
Feature: 預算與收入目標計算（後端自動化）
  對應: acceptance F05、AC-05、AC-13；SDD §5.3 BudgetEvaluator

  Background:
    Given 已重置記憶體資料庫
    And 已建立帳戶「現金」類型 cash 期初 2000
    And 已建立帳戶「示例卡」類型 credit 期初 0
    And 已建立分類「餐飲」
    And 預算「餐飲」金額 8000、起始日 1
    And 預算總額 30000、起始日 1
    And 收入目標 60000
    And 模擬系統時間為 2026/10/18

  @P0 @AC-05 @FR-B4
  Scenario: 80% 閾值觸發 N-1 恰一次
    Given 本期餐飲已支出 6500
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、分類「餐飲」、金額 500、時間 2026/10/18）
    Then 通知 spy 收到 N-1 恰 1 次，內容含 "87.5%"
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、分類「餐飲」、金額 100、時間 2026/10/18）
    Then 通知 spy 收到 N-1 仍恰 1 次（不重複）

  @P0 @FR-B4
  Scenario: 100% 與超支通知分級
    Given 本期餐飲已支出 8000
    Then 通知 spy 收到 N-2 恰 1 次
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、分類「餐飲」、金額 320、時間 2026/10/18）
    Then 通知 spy 收到 N-3 恰 1 次，內容含 "超支 320"

  @P0 @FR-B5
  Scenario: 預算用量含信用卡預扣
    Given 本期餐飲已支出 6500
    When 以「示例卡」記錄支出 1000（餐飲，預扣）
    Then 餐飲預算用量 = 7500（含預扣）
    And 預算明細標記預扣部分 1000

  @P0 @AC-13 @FR-B6
  Scenario: 收入目標達標率
    Given 本月已入帳收入 62000
    Then 收入目標達標率 = 103%（已達成）
    And 本月預計結餘 = 30000（60000 - 30000）

  @P0 @FR-B2
  Scenario: 自訂起始日的週期邊界
    Given 預算「餐飲」金額 8000、起始日 25
    And 模擬系統時間為 2026/06/03
    And 已存在支出 5/20（餐飲 300）與 5/30（餐飲 500）
    Then 目前週期 = 2026/05/25 ~ 2026/06/24
    And 餐飲預算用量 = 500（不含 5/20）
