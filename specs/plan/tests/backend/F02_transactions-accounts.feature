@BE @M1 @FR-T @FR-A @P0
Feature: 交易與帳戶領域邏輯（後端自動化）
  對應: acceptance F02、AC-10；SDD §4.3 BalanceCalculator

  Background:
    Given 已重置記憶體資料庫
    And 已建立帳戶「現金」類型 cash 期初 1000
    And 已建立帳戶「銀行」類型 bank 期初 10000
    And 已建立帳戶「票證卡」類型 ewallet 期初 0
    And 已建立帳戶「示例卡」類型 credit 期初 0
    And 已建立分類「交通」「購物」「餐飲」「薪資」

  @P0 @FR-T7
  Scenario: 金額驗證規則
    When 呼叫 SaveTransactionUseCase（金額 0）
    Then 顯示「驗證失敗：金額必須大於 0」且不入庫
    And oplog 新增 0 筆且皆未打包

  @P0 @AC-10 @FR-T1
  Scenario: 轉帳守恆與統計隔離
    Given 本月已支出 500、收入 10000
    When 建立轉帳「現金」→「銀行」金額 400
    Then 帳戶「現金」重算餘額 = 600
    And 帳戶「銀行」重算餘額 = 10400
    And 本月支出統計 = 500（不含轉帳）
    And 本月收入統計 = 10000

  @P0 @FR-A5
  Scenario: 儲值為 transfer 語意
    When 建立轉帳「銀行」→「票證卡」金額 500（儲值）
    Then 交易 kind = transfer
    And 帳戶「票證卡」重算餘額 = 500
    And 本月支出統計 = 0

  @P0 @FR-T3
  Scenario: 軟刪除與 30 天還原
    Given 已存在一筆支出 120 元
    When 刪除該筆交易
    Then 帳戶「現金」重算餘額 = 1000
    And 交易 120 為軟刪除（deleted_at 非 null）
    When 模擬時間快轉 31 天並執行清除工作
    Then 該筆墓標已物理清除（無法還原）

  @P0 @FR-T7
  Scenario: 信用卡還款語意
    When 建立還款交易 來源=銀行 目標=示例卡 金額 5000
    Then 交易 kind = repayment 且無分類
    And 帳戶「銀行」重算餘額 = 5000
    And 帳戶「示例卡」未繳合計 = 0（含還款抵扣）
    And 本月支出統計 = 0

  @P1 @M2 @FR-T4
  Scenario: 多幣別整數換算
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、金額 100 USD、匯率 32.0）
    Then 交易保存原幣 100 與 fx_rate 32.0
    And 帳戶「現金」重算餘額 = 900（以 3200 TWD 計）
    And 金額運算無浮點誤差（Money VO 斷言）
