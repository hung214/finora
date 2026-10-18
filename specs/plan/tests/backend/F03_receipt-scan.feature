@BE @M4 @FR-S @P0
Feature: 發票掃描解析與附件（後端自動化）
  對應: acceptance F03、AC-03；SDD §5.4 InvoiceQrParser / ReceiptPipeline

  Background:
    Given 已重置記憶體資料庫
    And 已建立帳戶「現金」類型 cash 期初 1000

  @P0 @FR-S1 @AC-03
  Scenario: 電子發票左 QR 77 碼解析
    When 解析左側 QR 字串 "AB12345678115101812341234567800000001861000000000900000001950000000000000000"
    Then 解析結果：商家統編="12345678"、總額=195、日期=2026/10/18
    And 校驗：銷售額 186 + 稅額 9 = 總額 195 通過

  @P0 @FR-S2 @AC-03
  Scenario: 右 QR 明細合併（deflate+Base32）
    When 解析左側 QR 字串 "AB12345678115101812341234567800000001861000000000900000001950000000000000000" 與右側 QR 字串 "<明細測資: 測試超商; 咖啡 2x95; 茶葉蛋 5>"
    Then 解析結果：商家="測試超商"
    And 明細含 咖啡 2×95=190 與 茶葉蛋 5

  @P0 @FR-S2
  Scenario: 不支援格式回退
    When 解析左側 QR 字串 "https://example.com/not-an-invoice"
    Then 顯示「無法辨識此發票格式」且不建立草稿
    And 建立空白確認卡（日期=今天）供手動輸入

  @P0 @FR-S5
  Scenario: OCR 欄位抽取與信賴度
    When 對 OCR 文字 fixture 1 執行欄位抽取
    Then 解析結果：總額=195、日期=2026/10/18（信賴度 0.5）
    And 信賴度 < 0.7 的欄位標記為「需人工確認」
    And 無法判定的欄位為留空（非猜測值）

  @P0 @FR-S4
  Scenario: 附件壓縮與內容定址
    Given 一張 4000x3000 原圖 fixture
    When 執行附件儲存流程
    Then 附件縮至最長邊 1600px、JPEG q70
    And 檔名 = blobs/{sha256}（內容定址）
    And attachments 資料列建立且關聯交易

  @P0 @FR-S3 @offline
  Scenario: 解析全程本機（無網路依賴）
    Given 連線已關閉
    When 解析左側 QR 字串 "AB12345678115101812341234567800000001861000000000900000001950000000000000000"
    Then 解析結果：總額=195（無網路呼叫斷言）

  @P0 @NFR-02
  Scenario: 效能_單張 OCR < 3 秒
    When 對 OCR 文字 fixture 1 執行欄位抽取（計時）
    Then 效能：入庫耗時 2999ms < 3000ms
