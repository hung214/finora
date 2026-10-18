@BE @M7 @FR-X @P0
Feature: App 鎖判定邏輯（後端自動化）
  對應: acceptance F08、AC-09；SDD §7.2 AppLockController

  Background:
    Given 已重置記憶體資料庫
    And App 鎖設定: PIN=1234、生物辨識 enabled、門檻 30 秒
    And 模擬雲端為 in-memory adapter 且已連結

  @P0 @AC-09 @FR-X1
  Scenario: 門檻邊界判定
    Given App 於 12:00:00 切至背景
    When 背景時長 = 29 秒 返回
    Then 鎖定需求 = false
    When 背景時長 = 30 秒 返回
    Then 鎖定需求 = true
    When 背景時長 = 31 秒 返回
    Then 鎖定需求 = true

  @P0 @FR-X1
  Scenario: 生物辨識失敗計數退場
    Given 生物辨識失敗計數 = 0
    When 失敗 1 次
    Then 仍允許生物辨識重試
    When 累計失敗 3 次
    Then 鎖定策略 = 僅 PIN（停用生物辨識本次解鎖）

  @P0 @FR-X5
  Scenario: PIN 重設授權路徑（已連雲端）
    Given 已連結雲端
    When 重新登入同一雲端帳號（token 驗證通過）
    Then 允許設定新 PIN
    And 本地資料未清空（交易筆數不變）

  @P0 @FR-X5
  Scenario: PIN 重設拒絕路徑（未連雲端）
    Given 未連結雲端
    When 嘗試「忘記 PIN」
    Then 僅提供「重置 App」
    And 不存在繞過 PIN 且保留資料的路徑（斷言無此分支）
