# BDD 步驟 DSL 規範（Given/When/Then 句型登記簿）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.3（初版） |
| 用途 | 前端／後端 `.feature` 檔的**步驟句型唯一登記處**。新步驟必須先登記於本檔再實作綁定；未登記句型視為違規 |
| 綁定 | 前端：自製 Gherkin runner + integration_test（TR-9 過渡；同 T-H7）｜後端：自製 Gherkin runner + flutter_test |

---

## 1. 共同規範

1. **關鍵字英文、敘述繁體中文**（沿 BDD.md 決策）：`Given 已建立帳戶「現金」(餘額 2,000)`。
2. 標籤：`@FE/@BE` + `@P0/@P1` + `@M1~@M7` + `@FR-xx/@AC-xx` + 環境標籤（`@offline/@sync/@desktop`）。
3. 參數型別（正規表示式抽取）：

| 型別 | 模式 | 例 |
|---|---|---|
| 金額 | `-?\d[\d,]*` | `-12,340` |
| 日期時間 | `\d{4}/\d{2}/\d{2}( \d{2}:\d{2})?` 或語意詞（今天/昨天/現在） | `2026/10/18 09:12` |
| 名稱 | `「[^」]+」` | 「現金」 |
| 狀態詞 | pending / billed / settled / paid / partial / issued / 逾期 | — |

4. **商業語意優先於 UI 細節**：步驟描述「使用者做了什麼/系統呈現什麼」，不寫實作（禁：`When 點擊 id=btn_save`）。
5. 資料準備（Given）一律經 **fixture API** 直寫 DB，不經 UI（速度+穩定性）；UI 建立路徑由 When 步驟覆蓋。

---

## 2. 後端 DSL（@BE，綁定純 Dart）

**環境與掛鉤**：記憶體 SQLite DB（每 Scenario 重建；TR-7 過渡 sqlite3 直連）、fake clock、in-memory CloudStorageAdapter、notification spy、StopWatch 效能計測。

### 2.1 Given（前置）

| 句型 | 綁定行為 |
|---|---|
| `Given 已重置記憶體資料庫` | 重建 drift in-memory DB + 清空 spy |
| `Given 已建立帳戶「{name}」類型 {type} 期初 {amount}` | accounts + 期初 |
| `Given 已建立信用卡「{name}」: 結帳日 {day} 號、繳款日加 {n} 天、歸屬 {include/exclude}` | accounts + credit_card_details |
| `Given 已有 {n} 筆預扣交易於「{card}」共 {amount}` | 批次插入 pending 交易 + oplog |
| `Given 帳單 {period} 應繳 {amount} 狀態 {status}` | statements + items |
| `Given 模擬系統時間為 {datetime}` | fake clock 凍結 |
| `Given 模擬雲端為 in-memory adapter 且已連結` | CloudStorageAdapter = fake，vault 就緒 |
| `Given 預算「{cat}」金額 {amount}、起始日 {day}` | budgets |
| `Given 收入目標 {amount}` | income_goals |
| `Given 定期交易「{name}」每月 {day} 日金額 {amount}` | recurring_transactions + next_due |
| `Given 已建立分類{names}` | categories（連續「名稱」緊接，如「餐飲」「交通」；「其他」為內建 is_system） |
| `Given 歷史: {desc}` | 分號分隔段落：①`昨日 HH:MM 帳戶/分類 金額`（單筆支出）②`本週{時段}帳戶/分類 N 筆`（本週前 N 日同時段各 1 筆）→ transactions + oplog |
| `Given 商家「{m}」過去 {n} 筆分類皆為「{c}」` | transactions（merchant=m，過去 n 日各 1 筆，20:00 時段避開上午統計） |
| `Given 目前時段最常用分類為「{c}」` | 依 acceptance 時段表，於過去 3 日同時段各 1 筆該分類 |
| `Given 帳本無任何交易` | 斷言交易為 0 筆（防背景污染） |
| `Given 設定 {key} = {value}` | settings upsert |
| `Given 固定預設 = {account}/{category}` | `quick_entry.fixed_preset`（JSON：account_id/category_id） |
| `Given 已儲存 {n} 筆（{amounts}）` | fixture 直寫 n 筆支出於第一個未封存帳戶（金額清單「、」分隔，依序遞減 1 分鐘） |
| `And 連線已關閉` | in-memory adapter 進入 failing 態（模擬離線） |

### 2.2 When（動作）

| 句型 | 綁定行為 |
|---|---|
| `When 呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）` | UseCase 呼叫（計時） |
| `When 呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）計時 {n} 次` | NFR-01：n 次計時取 P95 |
| `When 呼叫 QuickEntryPresetService 計算預設` | FR-Q4 智慧／固定預設計算（不含商家） |
| `When 呼叫 QuickEntryPresetService 計算預設（商家={m}）` | 同上＋商家歷史分類優先 |
| `When 呼叫 UndoLastTransaction` | 軟刪除+oplog |
| `When 執行 BillingCycleService.run（「{card}」）` | 結帳引擎 |
| `When 執行 RepayStatementUseCase（帳單 {period}、金額 {amt}）` | 繳款 |
| `When 以「{card}」記錄支出 {amt}` | SaveTransactionUseCase（信用卡語意） |
| `When 建立轉帳「{from}」→「{to}」金額 {amt}` | transfer |
| `When 解析左側 QR 字串 "..." 與右側 QR 字串 "..."` | InvoiceQrParser 純函數 |
| `When 對 OCR 文字 fixture 執行欄位抽取` | ReceiptPipeline heuristics |
| `When 執行 SyncCoordinator.pull 與 push` | 同步 |
| `When 套用來自裝置 {d} 的 bundle（seq {n}）` | BundleApplier |
| `When 執行新裝置 Bootstrap（同一帳號）` | replay |
| `When 模擬時間快轉 {n} 天並觸發自動備份` | BackupService |
| `When 觸發定期交易到期檢查` | RecurringService |
| `When 執行清空資料（含雲端）` | WipeService |

### 2.3 Then（斷言）

| 句型 | 綁定行為 |
|---|---|
| `Then 交易 {id} 的 settlement_status = {status}` | DB 讀取 |
| `Then 帳戶「{a}」重算餘額 = {amount}` | BalanceCalculator（衍生值斷言） |
| `Then 產生帳單 {period}、應繳 {amount}、繳款日 {date}` | statements |
| `Then 帳單狀態 = {status}、已繳 {amount}、剩餘 {amount}` | statements |
| `Then oplog 新增 {n} 筆且皆未打包` | oplog |
| `Then 通知 spy 收到 N-{n} 恰 {k} 次，內容含 "{text}"` | notification spy |
| `Then 裝置 {a} 與裝置 {b} 的重算餘額一致` | 跨 fixture 比對 |
| `Then 衝突事件 1 筆，被覆蓋內容為 "{text}"` | sync_events |
| `Then 雲端 backups/ 保留 {n} 份` | fake adapter list |
| `Then 效能：入庫耗時 {ms}ms < 300ms（P95）` | StopWatch P95（F01-BE NFR-01；{ms} 為計畫預記值，以實測 P95 < 300 斷言） |
| `Then 預設帳戶 = 「{name}」` / `Then 預設帳戶 = 第一個未封存帳戶` | QuickEntryPreset 輸出（FR-Q4） |
| `Then 預設分類 = 「{name}」` | QuickEntryPreset 輸出 |
| `Then 預設時間 = {datetime}` | QuickEntryPreset 輸出（= 現在） |
| `Then 交易已入庫且 settlement_status = {status}` | DB 讀取（最後一次 UseCase 儲存） |
| `And oplog 與交易位於同一 DB transaction（中斷模擬不產生孤兒）` | beforeOplog 注入拋錯 → rollback，兩表皆無孤兒（SDD §5.1） |
| `Then 交易 {amount} 為軟刪除（deleted_at 非 null）` | 以金額對映 Given 已儲存之最近一筆 |
| `And oplog 新增 {n} 筆（墓標）` | delta=n 且新 oplog payload=NULL |
| `Then 解析結果：商家="{m}"、總額={amt}、日期={date}` | parser 輸出 |
| `Then 搜尋 "{kw}" 命中 {n} 筆` | FTS5 bigram |

---

## 3. 前端 DSL（@FE，綁定自製 runner + integration_test，TR-9）

**環境與掛鉤**：integration_test 啟動真 App（注入 fake clock/mock cloud/notification spy）；螢幕截圖存檔供報告；桌面 runner 支援快捷鍵注入。

### 3.1 Given（前置）

| 句型 | 綁定行為 |
|---|---|
| `Given App 已完成首次設定` | 啟動至總覽（略過引導） |
| `Given 使用者位於{page}頁` | 導航至該分頁 |
| `Given 已建立帳戶「{name}」(餘額 {amount})` | fixture API（同 BE 語意） |
| `Given 歷史交易: {描述}` | fixture API |
| `Given 模擬系統時間為 {datetime}` | fake clock |
| `Given 裝置處於飛航模式` | 連線模擬關閉 |
| `Given 同步模式設定為「{mode}」` | settings 寫入 |

### 3.2 When（動作）

| 句型 | 綁定行為 |
|---|---|
| `When 開啟快速記帳頁` / `When 按下 Ctrl+N（macOS 為 ⌘N）` | 快記入口 |
| `When 輸入金額 {amount}` | 鍵盤輸入 |
| `When 按下「{label}」` | 點擊可見文字按鈕 |
| `When 點擊時間欄位` | 時間選擇器 |
| `When 掃描標準測資發票（左QR+右QR）` | 影像回放注入掃描器 |
| `When 拍攝紙本收據（fixture {n}）` | OCR 影像回放 |
| `When App 切至背景 {n} 秒後返回` | lifecycle 模擬 |
| `When 關閉並重新啟動 App` | 重啟（驗證啟動同步） |
| `When 從相簿匯入 fixture {n}` | 桌面/無相機路徑 |

### 3.3 Then（斷言）

| 句型 | 綁定行為 |
|---|---|
| `Then {欄位}預填為「{value}」` | widget 斷言 |
| `Then 彈出對話框「{text}」且提供「{a}」「{b}」「{c}」三個動作` | dialog |
| `Then 儲存按鈕為禁用狀態` | enabled=false |
| `Then 明細頁即時顯示該 {n} 筆` | 清單斷言 |
| `Then 顯示「{text}」` / `Then 不顯示「{text}」` | 文字存在性 |
| `Then 進度條為警示色（{color}）` | 樣式斷言 + 截圖 |
| `Then 金額全部顯示為 ●●●●` | 遮蔽 |
| `Then 出現鎖定畫面` | lock screen |
| `Then 交易入庫耗時 < {ms}ms（UI 計時）` | 互動計時 |
| `Then 導向「{target}」` | 路由斷言 |

---

## 4. 兩層寫法對映（同一商業語意）

| 商業語意 | BE（算得對） | FE（看得對） |
|---|---|---|
| 轉帳守恆（AC-10） | `Then 帳戶「現金」重算餘額 = 600` | `Then 明細頁即時顯示該 1 筆`＋餘額卡顯示 600 |
| 預算 80% 警告（AC-05） | `Then 通知 spy 收到 N-1 恰 1 次` | `Then 進度條為警示色（orange）` |
| 信用卡預扣（AC-04） | `Then 交易 {id} 的 settlement_status = pending` | 卡片頁顯示「本期應付 8,000」且薪轉卡顯示 45,000 |
| 衝突 LWW（AC-07） | `Then 衝突事件 1 筆，被覆蓋內容為 "A 版"` | 同步狀態頁可檢視「A 版」內容 |

## 5. 禁例

- 禁止在 feature 檔寫 selector/id/CSS/內部 API。
- 禁止 BE 情境啟動 UI（反之 FE 不自行驗證衍生計算，讀 UI 呈現即可）。
- 禁止未登記句型；新增步驟 → 先改本檔 → 實作綁定 → 才能出現在 feature 檔。
- 同一情境敘述不得同時存在 FE 與 BE（分配見 README §1）。
