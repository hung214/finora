@BE @M5 @FR-Y @P0
Feature: 同步協議與備份（後端自動化）
  對應: acceptance F07、AC-06~08、14；SDD §5.5 SyncCoordinator
  ⚠️ 同步合併模組：待雙重 review（research §1.3）

  Background:
    Given 已重置記憶體資料庫
    And 模擬雲端為 in-memory adapter 且已連結
    And 已建立帳戶「現金」類型 cash 期初 1000

  @P1 @FR-Y4 @AC-06 @offline
  Scenario: 離線補同步_雙裝置一致
    Given 裝置A 離線記錄 3 筆交易（oplog 3 筆未打包）
    When 連線恢復並執行 SyncCoordinator.pull 與 push
    Then 雲端 ops/d-A/00000001.opbundle 存在（3 ops）
    When 裝置B（同一帳號）執行 SyncCoordinator.pull 與 push
    Then 裝置B 收到 3 筆交易
    And 裝置A 與裝置B 的重算餘額一致

  @P1 @FR-Y5 @AC-07
  Scenario: LWW 合併與衝突事件
    Given 裝置A 修改交易 X 備註為「A 版」並同步
    And 裝置B 離線修改交易 X 備註為「B 版」（HLC 較新）
    When 裝置B 執行 SyncCoordinator.pull 與 push
    Then 交易 X 備註 = 「B 版」（兩裝置一致）
    And 衝突事件 1 筆，被覆蓋內容為 "A 版"
    And 通知 spy 收到 N-8 恰 1 次

  @P0 @FR-Y11
  Scenario: 每筆自動同步模式
    Given 同步模式 = 每筆自動同步
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、分類「餐飲食品」、金額 120、時間 2026/10/18）
    Then 雲端 ops/d-A/00000001.opbundle 存在（1 op）
    And oplog 皆已打包（packed_seq 非 null）

  @P1 @FR-Y11
  Scenario: 節能批次模式合併
    Given 同步模式 = 節能批次（預設）
    When 連續記錄 3 筆交易
    And 模擬時間快轉 31 秒並觸發批次同步
    Then 雲端僅 1 個 bundle（3 ops，非 3 個）

  @P0 @FR-Y11
  Scenario: 行動網路附件分流
    Given 附件僅 Wi-Fi 同步 = on 且網路 = 行動
    When 掃描發票入帳（含附件）並觸發同步
    Then 交易已同步且附件暫緩（blobs/ 無新檔）
    When 網路 = Wi-Fi 並觸發同步
    Then 雲端 blobs/{sha256} 存在

  @P0 @FR-Y2 @AC-08
  Scenario: 新裝置 Bootstrap replay
    Given 雲端已有裝置A 的 5 個 bundle 與 1 份快照
    When 執行新裝置 Bootstrap（同一帳號）
    Then 本地收到全部交易/帳戶/分類
    And 裝置C 的 manifest 已建立（lastSeq = 0）
    And 裝置A 與裝置C 的重算餘額一致

  @P0 @FR-Y3
  Scenario: 備份保留份數 GC
    Given 備份保留份數 = 7
    When 模擬時間快轉 8 天並觸發自動備份（每日）
    Then 雲端 backups/ 保留 7 份
    And 最舊一份已被清理

  @P0 @FR-Y6 @AC-14
  Scenario Outline: 備份檔密碼
    When 匯出備份檔<選項>並於另一環境匯入
    Then <匯入結果>

    Examples:
      | 選項                 | 匯入結果 |
      | 不加密(預設)         | 直接還原成功 |
      | 檔案密碼+正確密碼     | 完整還原成功 |
      | 檔案密碼+錯誤密碼     | 拒絕匯入且本地資料不變 |
