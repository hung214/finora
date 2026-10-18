@BE @M7 @FR-O3 @P1
Feature: 資料清除執行（後端自動化）
  對應: acceptance F09；SDD §7.3

  Background:
    Given 已重置記憶體資料庫
    And 帳本含 20 筆交易與 1 張附件
    And 模擬雲端為 in-memory adapter 且已連結

  @P1 @FR-O3
  Scenario: 未連雲端的本地清空
    Given 未連結雲端
    When 執行清空資料（含雲端=false）
    Then 交易/帳戶/分類/附件全部清空
    And 附件檔案已刪除
    And 回到首次啟動狀態

  @P1 @FR-O3
  Scenario: 已連雲端的完整清空
    Given 已連結雲端（雲端含 vault/ops/backups）
    When 執行清空資料（含雲端=true，身分驗證通過）
    Then 本地資料全部清空
    And 雲端 LedgerSync/ 整個資料夾已刪除（vault/devices/ops/backups 皆無）

  @P1 @FR-O3
  Scenario: 清空後其他裝置不復活
    Given 已連結雲端且裝置B 存在
    And 雲端資料已清除
    When 裝置B 執行 SyncCoordinator.pull 與 push
    Then 顯示「雲端資料已不存在」
    And 裝置B 不會把舊資料同步回來
