@BE @M3 @FR-C @P0
Feature: 信用卡帳單引擎（後端自動化）
  對應: acceptance F04、AC-04、AC-11；SDD §5.2 BillingCycleService
  ⚠️ 金額/結帳邏輯模組：待雙重 review（research §1.3）

  Background:
    Given 已重置記憶體資料庫
    And 已建立帳戶「薪轉」類型 bank 期初 50000
    And 已建立信用卡「卡A」: 結帳日 5 號、繳款日加 15 天、歸屬 include
    And 已建立信用卡「卡B」: 結帳日 10 號、繳款日加 15 天、歸屬 exclude

  @P0 @FR-C1
  Scenario: 刷卡預扣即時累計且不動銀行餘額
    When 以「卡A」記錄支出 3000（服飾美容）
    Then 交易 settlement_status = pending
    And 帳戶「卡A」重算餘額 = 3000（本期應付）
    And 帳戶「薪轉」重算餘額 = 50000

  @P0 @FR-C3 @AC-04
  Scenario: 過結帳日後補算產生帳單
    Given 已有 3 筆預扣交易於「卡A」共 5000（6/6~7/5）
    And 模擬系統時間為 2026/07/06
    When 執行 BillingCycleService.run（「卡A」）
    Then 產生帳單 2026/06/06~07/05、應繳 5000、繳款日 2026/07/20
    And 交易 settlement_status = billed
    And 通知 spy 收到 N-4 恰 1 次，內容含 "5,000"

  @P0 @FR-C2 @AC-11
  Scenario Outline: 結帳日當天消費歸屬（每卡可設定）
    Given 模擬系統時間為 <卡> 的結帳日當天
    When 以「<卡>」記錄支出 1000
    And 執行 BillingCycleService.run（「<卡>」）
    Then 該筆 1000 歸屬於<歸屬期>

    Examples:
      | 卡 | 歸屬期 |
      | 卡A | 本期 |
      | 卡B | 下期 |

  @P0 @FR-C3
  Scenario: 結帳日 31 號遇小月 clamp
    Given 已建立信用卡「卡C」: 結帳日 31 號、歸屬 include
    And 已有 1 筆預扣交易於「卡C」共 1000（1/1~1/31）
    And 模擬系統時間為 2026/02/01
    When 執行 BillingCycleService.run（「卡C」）
    Then 產生帳單 2026/01/01~01/31、應繳 1000、繳款日 2026/02/15

  @P0 @FR-C4 @AC-04
  Scenario: 全額繳款轉帳與狀態
    Given 帳單 2026/06/06~07/05 應繳 5000 狀態 issued
    When 執行 RepayStatementUseCase（帳單 2026/06/06~07/05、金額 5000）
    Then 帳單狀態 = paid、已繳 5000、剩餘 0
    And 帳戶「薪轉」重算餘額 = 45000
    And 通知 spy 不再收到 N-5（已繳取消提醒）

  @P0 @FR-C4
  Scenario: 部分繳款累加
    Given 帳單 2026/06/06~07/05 應繳 5000 狀態 issued
    When 執行 RepayStatementUseCase（帳單 2026/06/06~07/05、金額 2000）
    Then 帳單狀態 = partial、已繳 2000、剩餘 3000
    When 執行 RepayStatementUseCase（帳單 2026/06/06~07/05、金額 3000）
    Then 帳單狀態 = paid、已繳 5000、剩餘 0

  @P0 @FR-C5
  Scenario: 繳款提醒前 3 天與當天
    Given 帳單 2026/06/06~07/05 應繳 5000 狀態 issued（繳款日 7/20）
    And 模擬系統時間為 2026/07/17
    When 觸發通知檢查
    Then 通知 spy 收到 N-5 恰 1 次
    And 模擬系統時間為 2026/07/18 後觸發通知檢查
    And 通知 spy 收到 N-5 仍恰 1 次
    And 模擬系統時間為 2026/07/20 後觸發通知檢查
    And 通知 spy 收到 N-5 恰 2 次

  @P0 @FR-C6
  Scenario: 逾期判定與 N-6 一次
    Given 帳單 2026/06/06~07/05 應繳 5000 狀態 partial
    And 模擬系統時間為 2026/07/22
    When 觸發通知檢查
    Then 帳單狀態標記逾期
    And 通知 spy 收到 N-6 恰 1 次

  @P1 @FR-C7
  Scenario: 分期排程與刪除連動
    When 以「卡A」建立分期 30000 分 6 期、首期 2026/08/05
    Then 產生 6 筆未來 pending 交易（每筆 5000、installment_seq 1..6）
    And 帳戶「卡A」未來已承諾 = 30000
    When 刪除該分期計畫
    Then 尚未到期的 6 筆分期交易已移除

  @P1 @FR-C8
  Scenario: 退款衝銷已結帳交易
    Given 帳單 2026/06/06~07/05 應繳 5000 狀態 issued，含交易 1000（billed）
    When 針對該筆建立退款 1000
    Then 帳單應繳 = 4000（負項明細 -1000）
    And refund_links 關聯已建立

  @P0 @FR-A3
  Scenario: 修改結帳日僅下期生效
    Given 已有 1 筆預扣交易於「卡A」共 1000（7/6~8/5 期間）
    When 修改「卡A」結帳日為 15 號（effective_from 下一期）
    Then 帳單 2026/07/06~08/05 仍以 5 號規則結算
    And 下一期週期 = 2026/08/06~08/15
