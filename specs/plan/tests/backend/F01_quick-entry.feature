@BE @M1 @FR-Q @P0
Feature: 快速記帳領域邏輯（後端自動化）
  驗證智慧預設規則計算、儲存事務完整性、Undo 墓標與效能門檻。
  對應: acceptance F01、AC-01、AC-02；SDD §5.1

  Background:
    Given 已重置記憶體資料庫
    And 已建立帳戶「現金」類型 cash 期初 2000
    And 已建立帳戶「示例卡」類型 credit 期初 0
    And 已建立分類「餐飲食品」「交通運輸」「服飾美容」「其他」
    And 模擬系統時間為 2026/10/18 08:00

  @P0 @AC-01 @FR-Q4
  Scenario: 智慧預設_時段推薦分類與上一筆帳戶
    Given 歷史: 昨日 20:00 示例卡/餐飲食品 120；本週上午現金/交通運輸 5 筆
    When 呼叫 QuickEntryPresetService 計算預設
    Then 預設帳戶 = 「示例卡」
    And 預設分類 = 「交通運輸」
    And 預設時間 = 2026/10/18 08:00

  @P0 @FR-Q4
  Scenario: 智慧預設_同商家歷史分類優先
    Given 商家「陽光」過去 5 筆分類皆為「服飾美容」
    And 目前時段最常用分類為「餐飲食品」
    When 呼叫 QuickEntryPresetService 計算預設（商家=陽光）
    Then 預設分類 = 「服飾美容」

  @P0 @FR-Q4
  Scenario: 智慧預設_無歷史回退「其他」
    Given 帳本無任何交易
    When 呼叫 QuickEntryPresetService 計算預設
    Then 預設分類 = 「其他」
    And 預設帳戶 = 第一個未封存帳戶

  @P0 @FR-Q4
  Scenario: 關閉智慧預設_固定預設生效
    Given 設定 quick_entry.smart_preset = off
    And 固定預設 = 現金/交通運輸
    When 呼叫 QuickEntryPresetService 計算預設（商家=陽光）
    Then 預設帳戶 = 「現金」
    And 預設分類 = 「交通運輸」

  @P0 @AC-02 @FR-Q5
  Scenario: 儲存事務_交易與 oplog 同步寫入
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、分類「餐飲食品」、金額 120、時間 2026/10/18 08:00）
    Then 交易已入庫且 settlement_status = none
    And oplog 新增 1 筆且皆未打包
    And oplog 與交易位於同一 DB transaction（中斷模擬不產生孤兒）

  @P0 @FR-Q3
  Scenario: Undo_墓標與 oplog
    Given 已儲存 2 筆（120、80）
    When 呼叫 UndoLastTransaction
    Then 交易 80 為軟刪除（deleted_at 非 null）
    And 帳戶「現金」重算餘額 = 1880
    And oplog 新增 1 筆（墓標）

  @P0 @FR-Q6 @offline
  Scenario: 離線記帳寫入 oplog 待上傳
    Given 模擬雲端為 in-memory adapter 且已連結
    And 連線已關閉
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、分類「餐飲食品」、金額 120、時間 2026/10/18 08:00）
    Then 交易已入庫且 settlement_status = none
    And oplog 新增 1 筆且皆未打包

  @P0 @NFR-01
  Scenario: 效能_儲存 < 300ms
    When 呼叫 SaveTransactionUseCase（帳戶「現金」、分類「餐飲食品」、金額 120、時間 2026/10/18 08:00）計時 100 次
    Then 效能：入庫耗時 299ms < 300ms（P95）

  @P0 @FR-Q4
  Scenario: 智慧預設_空帳本不崩潰
    Given 帳本為全新空本（無帳戶/分類/交易）
    When 呼叫 QuickEntryPresetService 計算預設
    Then 預設帳戶為空（待帳戶建立）
    And 預設分類為空（內建集隨首次設定落地）
