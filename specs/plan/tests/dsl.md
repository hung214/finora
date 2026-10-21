# BDD 步驟 DSL 規範（Given/When/Then 句型登記簿）

| 項目 | 內容 |
|---|---|
| 文件版本 | v1.3（F08-FE：§3 Given 3＋When 8＋Then 8 句型登記——鎖定畫面/Face ID seam/PIN 重設/隱私遮蔽；v1.2 F08-BE：§2 Given 6＋When 6＋Then 8 句型登記——AppLockController 門檻邊界/生物辨識退場/PIN 重設授權與拒絕路徑；v1.1 F06-FE：§3 Given 2＋When 3＋Then 4 句型登記——待確認 badge/清單/下期提醒/暫停標示；v1.0 F06-BE：Given 3＋When 4＋Then 12 句型登記——RecurringService 提醒確認制；v0.9 F07-FE：§3 Given 6＋When 6＋Then 12 句型登記；「同步中…」回饋斷言法（tap 後 pump 未 settle）；v0.8 F07-BE：§2.1 Given 8＋§2.2 When 7＋§2.3 Then 14 句型登記——SyncCoordinator/BundleApplier/BackupService；Outline 匯入結果分列綁定） |
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
| `Given 已建立信用卡「{name}」: 結帳日 {day} 號、歸屬 {include/exclude}` | 同上（繳款日加預設 15 天；F04 clamp 情境） |
| `Given 已有 {n} 筆預扣交易於「{card}」共 {amount}（{start}~{end}）` | 批次 pending 交易＋oplog（期間變體，F04 S10-補算/逾期/生效日） |
| `Given 帳單 {period} 應繳 {amount} 狀態 {status}，含交易 {txAmount}（billed）` | statements＋statement_items＋billed 交易（退款情境，F04） |
| `Given 帳單 {period} 應繳 {amount} 狀態 {status}（繳款日 {date}）` | 同上＋due_date 指定（提醒情境，F04） |
| `Given 已有 {n} 筆預扣交易於「{card}」共 {amount}（{start}~{end} 期間）` | 週期語意（生效日情境，F04 修改結帳日） |
| `Given 帳單 {period} 應繳 {amount} 狀態 {status}，含交易 {txAmount}（billed）` | statements＋billed 交易＋statement_items（退款情境，F04） |
| `When 針對該筆建立退款 {amount}` | RefundService（refund 交易＋refund_links＋帳單負項，FR-C8） |
| `Then 帳單應繳 = {amount}（負項明細 -{refund}）` | 帳單 total 沖減（FR-C8） |
| `And refund_links 關聯已建立` | refund_links 查詢（FR-C8） |
| `Given 已有 {n} 筆預扣交易於「{card}」共 {amount}` | 批次插入 pending 交易 + oplog |
| `Given 帳單 {period} 應繳 {amount} 狀態 {status}` | statements + items |
| `Given 模擬系統時間為 {datetime}` | fake clock 凍結 |
| `Given 模擬雲端為 in-memory adapter 且已連結` | CloudStorageAdapter = fake，vault 就緒 |
| `Given 預算「{cat}」金額 {amount}、起始日 {day}` | budgets |
| `Given 預算總額 {amount}、起始日 {day}` | budgets（category_id NULL＝總預算，FR-B2） |
| `Given 收入目標 {amount}` | income_goals（FR-B6） |
| `Given 本期{cat}已支出 {amount}` | fixture 直寫本期 expense（**不觸發警示評估**——警示於記帳鉤子／斷言前 sync 冪等補發，F05 S5.1/S5.2 語意反推） |
| `Given 本月已入帳收入 {amount}` | fixture 直寫本月 income |
| `And 已存在支出 {d1}（{cat1} {a1}）與 {d2}（{cat2} {a2}）` | fixture 直寫兩筆（M/D 日期，年取自凍結時間；F05 S5.6） |
| `Given 收入目標 {amount}` | income_goals |
| `Given 定期交易「{name}」每月 {day} 日金額 {amount}` | recurring_transactions + next_due |
| `Given 已建立分類{names}` | categories（連續「名稱」緊接，如「餐飲」「交通」；「其他」為內建 is_system） |
| `Given 歷史: {desc}` | 分號分隔段落：①`昨日 HH:MM 帳戶/分類 金額`（單筆支出）②`本週{時段}帳戶/分類 N 筆`（本週前 N 日同時段各 1 筆）→ transactions + oplog |
| `Given 商家「{m}」過去 {n} 筆分類皆為「{c}」` | transactions（merchant=m，過去 n 日各 1 筆，20:00 時段避開上午統計） |
| `Given 目前時段最常用分類為「{c}」` | 依 acceptance 時段表，於過去 3 日同時段各 1 筆該分類 |
| `Given 帳本無任何交易` | 斷言交易為 0 筆（防背景污染） |
| `Given 帳本為全新空本（無帳戶/分類/交易）` | 以全新 in-memory DB 替換（fixture 層；DBG-003 回歸用） |
| `Given 設定 {key} = {value}` | settings upsert |
| `Given 固定預設 = {account}/{category}` | `quick_entry.fixed_preset`（JSON：account_id/category_id） |
| `Given 已儲存 {n} 筆（{amounts}）` | fixture 直寫 n 筆支出於第一個未封存帳戶（金額清單「、」分隔，依序遞減 1 分鐘） |
| `Given 本月已支出 {expense}、收入 {income}` | fixture 直寫本月支出/收入各 1 筆於票證卡（本月統計基準線；不得落於該情境有餘額斷言之帳戶，F02 S2.3） |
| `Given 已存在一筆支出 {amount} 元` | fixture 直寫 1 筆支出於第一個未封存帳戶並登記 id（刪除情境目標，F02 S2.5） |
| `Given 已存在 {month} 月支出: {desc}（經 fixture）` | fixture 直寫（段落「分類 N 筆共 TOTAL」以總額/N 各一筆；年取 Clock.now；FTS 隨 save 維護，F10） |
| `And 其中 {n} 筆 {month} 月{cat}備註含「{kw}」` | setTransactionNote（UPDATE＋FTS 重索引；正式編輯功能屬後續） |
| `Given 已匯入 {n} 萬筆種子交易` | 批次直寫當月（略 oplog——聚合僅讀 transactions；NFR-01 效能測資） |
| `And 連線已關閉` | in-memory adapter 進入 failing 態（模擬離線） |
| `Given 一張 4000x3000 原圖 fixture` | T-H6 動態生成原圖 bytes（image 套件 encodePng；F03 S5 附件壓縮輸入） |
| `Given 模擬雲端為 in-memory adapter 且已連結` | T-H3 adapter 建置＋vault/devices 佈局初始化（SDD §5.5.1；F07 Background——多裝置拓撲：每裝置各自本地 DB，僅經雲端檔案交換） |
| `Given 裝置{d} 離線記錄 {n} 筆交易（oplog {n} 筆未打包）` | 該裝置 DB fixture 直寫＋oplog（packed_seq=null；未觸發同步） |
| `Given 同步模式 = {mode}` | settings sync.mode（每筆自動同步/節能批次（預設）/僅手動——FR-Y11） |
| `Given 附件僅 Wi-Fi 同步 = {state} 且網路 = {network}` | settings backup.attachments_wifi_only＋網路型態 seam（wifi/mobile——FR-Y11 附件分流） |
| `Given 雲端已有裝置{d} 的 {n} 個 bundle 與 {m} 份快照` | 預置雲端狀態（bundle 產生＋backups 快照；bootstrap 前置） |
| `Given 備份保留份數 = {n}` | settings backup.keep（FR-Y3 GC） |
| `Given 裝置{d} 修改交易 {id} 備註為「{note}」並同步` | setTransactionNote＋oplog 整列快照＋push（LWW 前置；F07 S2） |
| `And 裝置{d} 離線修改交易 {id} 備註為「{note}」（HLC 較新）` | 該裝置修改但未同步（HLC 較新→LWW 勝出方；F07 S2） |
| `Given 已建立定期交易「{name}」每月 {day} 日金額 {amt}` | recurring_transactions 種資（frequency=monthly、anchor/next_due=當月 day 日；F06 Background） |
| `Given 待確認佇列含「{name} {date}」` | 觸發到期檢查後之佇列（next_due ≤ today 動態推導；F06 S2~S4 前置） |
| `Given 模擬系統時間為 {date} 並觸發到期檢查（第 {n} 次）` | Clock 凍結＋RecurringService.runCheck（逾期計數前置；F06 S5） |
| `Given App 鎖設定: PIN={pin}、生物辨識 {state}、門檻 {n} 秒` | settings lock.* 寫入＋AppLockController 建構（PIN 雜湊存儲；F08 Background） |
| `Given App 於 {time} 切至背景` | Clock 凍結＋onBackground（背景時刻記錄；F08 S1） |
| `Given 生物辨識失敗計數 = {n}` | AppLockController 失敗計數預置（F08 S2） |
| `Given 已連結雲端` | settings sync.account 有值（PIN 重設授權前提；F08 S3） |
| `Given 未連結雲端` | settings sync.account 空（F08 S4） |

### 2.2 When（動作）

| 句型 | 綁定行為 |
|---|---|
| `When 呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）` | UseCase 呼叫（計時） |
| `When 呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）計時 {n} 次` | NFR-01：n 次計時取 P95 |
| `When 呼叫 QuickEntryPresetService 計算預設` | FR-Q4 智慧／固定預設計算（不含商家） |
| `When 呼叫 QuickEntryPresetService 計算預設（商家={m}）` | 同上＋商家歷史分類優先 |
| `When 呼叫 UndoLastTransaction` | 軟刪除+oplog |
| `When 執行 BillingCycleService.run（「{card}」）` | 結帳引擎 |
| `Given 模擬系統時間為 {card} 的結帳日當天` | Clock 凍結至該卡當月結帳日（statement_day；Outline 歸屬情境） |
| `Then 該筆 {amount} 歸屬於{period}$` | 本期：statement_items 含該筆；下期：不含（FR-C2） |
| `When 觸發通知檢查` | NotificationCheckService（提醒 N-5/逾期 N-6，FR-C5/C6） |
| `And 模擬系統時間為 {dt} 後觸發通知檢查` | Clock 快轉＋通知檢查 |
| `When 以「{card}」建立分期 {total} 分 {n} 期、首期 {date}` | InstallmentService（FR-C7） |
| `When 刪除該分期計畫` | 刪除 plan＋未到期分期交易移除（FR-C7） |
| `When 針對該筆建立退款 {amount}` | RefundService（refund_links＋帳單負項，FR-C8） |
| `When 修改「{card}」結帳日為 {day} 號（effective_from 下一期）` | credit_card_details 更新（FR-A3） |
| `When 執行 RepayStatementUseCase（帳單 {period}、金額 {amt}）` | 繳款 |
| `When 以「{card}」記錄支出 {amt}` | SaveTransactionUseCase（信用卡語意） |
| `When 以「{card}」記錄支出 {amt}（{cat}，預扣）` | 同上＋settlement=pending（F05 S5.3 預扣口徑） |
| `When 以「{card}」記錄支出 {amt}（{cat}）` | SaveTransactionUseCase（信用卡帳戶＋分類 → settlement=pending，FR-C1；分類隱式建立） |
| `Then 交易 settlement_status = {status}$` | 最近記錄交易之狀態（F04 預扣/結帳） |
| `And 帳戶「{card}」重算餘額 = {amount}（本期應付）` | creditOpenBalance（pending 口徑，FR-C1） |
| `When 建立轉帳「{from}」→「{to}」金額 {amt}` | transfer |
| `When 建立轉帳「{from}」→「{to}」金額 {amt}（儲值）` | 同上（儲值語意註記；kind=transfer，FR-A5） |
| `When 建立還款交易 來源={from} 目標={to} 金額 {amt}` | repayment（無分類；FR-T7） |
| `When 呼叫 SaveTransactionUseCase（金額 {amt}）` | 最小參數驗證（F02 S2.1：金額規則） |
| `When 刪除該筆交易` | DeleteTransactionUseCase（軟刪除+oplog 墓標，FR-T3） |
| `When 執行報表聚合（期間={period}）` | ReportService.aggregate（YYYY/MM；僅 expense，轉帳/收入不計——FR-R2） |
| `When 執行報表聚合（期間=最近月，計時）` | 同上＋Stopwatch（NFR-01：10 萬筆 < 1500ms） |
| `When 搜尋 "{kw}"` | SearchService（FTS5 bigram；環境缺模組降級 LIKE） |
| `When 篩選 期間={period}、分類={cat}、關鍵字={kw}` | AND 複合（FR-R3） |
| `When 加上 金額區間 {min}~{max}` | 前次篩選條件＋金額區間（AND） |
| `When 匯出 CSV` | CsvExporter（篩選後結果；UTF-8 BOM，FR-R4） |
| `When 模擬時間快轉 {days} 天並執行清除工作` | Clock 快轉＋TombstonePurgeService（30 天保留期，FR-T3） |
| `When 呼叫 SaveTransactionUseCase（帳戶「{a}」、金額 {amount} {currency}、匯率 {rate}）` | **M2**（F02 S2.8 多幣別 @P1；M1 不綁定） |
| `When 解析左側 QR 字串 "..." 與右側 QR 字串 "..."` | InvoiceQrParser 純函數（右側為 `<明細測資: ...>` 哨兵 → T-H6 rightQr 產生器；F03 S2） |
| `When 解析左側 QR 字串 "..."` | 同上單 QR 變體——僅左側（F03 S1/S3/S6） |
| `When 對 OCR 文字 fixture {n} 執行欄位抽取` | ReceiptPipeline heuristics（T-H6 文字 fixture {n}；欄位輸出 (value, confidence)，F03 S4） |
| `When 對 OCR 文字 fixture {n} 執行欄位抽取（計時）` | 同上＋Stopwatch（NFR-02 單張 < 3 秒；F03 S7） |
| `When 執行附件儲存流程` | AttachmentStore（縮圖最長邊 1600px→JPEG q70→sha256→blobs/{sha256}→attachments 列；FR-S4，F03 S5） |
| `When 執行 SyncCoordinator.pull 與 push` | 同步 |
| `When 套用來自裝置 {d} 的 bundle（seq {n}）` | BundleApplier |
| `When 執行新裝置 Bootstrap（同一帳號）` | replay |
| `When 模擬時間快轉 {n} 天並觸發自動備份` | BackupService |
| `When 觸發定期交易到期檢查` | RecurringService.runCheck（next_due ≤ today → N-7 提醒＋reminder_count+1；≥3 暫停推播） |
| `When 確認入帳（金額改為 {amt}、日期 {date}）` | RecurringService.confirm——入帳（source=recurring）＋next_due 推進＋reminder 歸零；**不回寫模板金額**（FR-T5） |
| `When 按下「本次跳過」` | RecurringService.skip——不入帳＋next_due 推進（FR-T5） |
| `When 刪除排程` | RecurringService.delete——墓標（deleted_at＋oplog 墓標；不再提醒） |
| `When 模擬系統時間為 {date} 並觸發到期檢查` | Clock 凍結＋runCheck（逾期序列驅動；F06 S5） |
| `When 背景時長 = {n} 秒 返回` | Clock 快轉＋shouldLockOnResume（門檻邊界判定；F08 S1） |
| `When 失敗 {n} 次` | AppLockController.onBiometricFail ×n（F08 S2） |
| `When 累計失敗 {n} 次` | 同上（累計語意） |
| `When 重新登入同一雲端帳號（token 驗證通過）` | PIN 重設授權 seam（token 驗證→canResetPin；FR-X5） |
| `When 嘗試「忘記 PIN」` | canResetPin 查詢（未連雲端→false；F08 S4） |
| `When 執行清空資料（含雲端）` | WipeService |
| `When 裝置{d}（同一帳號）執行 SyncCoordinator.pull 與 push` | 切換當前裝置＋SyncCoordinator（pull 套用 peers＋push 未打包；F07 S1/S2） |
| `When 連續記錄 {n} 筆交易` | 該裝置連寫 n 筆（oplog 未打包；批次合併測資） |
| `And 模擬時間快轉 {n} 秒並觸發批次同步` | Clock 快轉秒＋SyncCoordinator（節能批次 30s 觸發點；FR-Y11） |
| `When 掃描發票入帳（含附件）並觸發同步` | ScannedItem 儲存（source=scan＋附件落 blobs/）＋SyncCoordinator（附件分流前置） |
| `When 網路 = {network} 並觸發同步` | 網路型態 seam 設定＋SyncCoordinator（附件分流第二段） |
| `When 模擬時間快轉 {n} 天並觸發自動備份（每日）` | Clock 快轉＋BackupService（>24h 產新備份＋GC；FR-Y3） |
| `When 匯出備份檔{option}並於另一環境匯入` | BackupService 匯出（無加密/檔案密碼）→ 新 DB 匯入（Outline；FR-Y6/AC-14） |

### 2.3 Then（斷言）

| 句型 | 綁定行為 |
|---|---|
| `Then 交易 {id} 的 settlement_status = {status}` | DB 讀取 |
| `Then 帳戶「{a}」重算餘額 = {amount}` | BalanceCalculator（衍生值斷言） |
| `Then 帳戶「{card}」未繳合計 = {amount}（含還款抵扣）` | BalanceCalculator.creditUnpaidTotal（預扣−退款−還款抵扣，下限 0；M3 帳單引擎前骨架版） |
| `Then 本月支出統計 = {amount}（不含轉帳）` | MonthlyStatsService（僅 kind=expense；AC-10 統計隔離） |
| `Then 本月支出統計 = {amount}` | 同上（純值變體，S2.4/S2.6 用；匹配順序須後於「（不含轉帳）」變體） |
| `Then 本月收入統計 = {amount}` | MonthlyStatsService（僅 kind=income） |
| `Then 交易 kind = {kind}` | DB 讀取（最後一次 UseCase 建立之交易） |
| `Then 交易 kind = {kind} 且無分類` | 同上＋category_id IS NULL（FR-T7 還款） |
| `Then 顯示「{message}」且不入庫` | UseCase 驗證例外訊息＋交易/oplog 零新增（F02 S2.1） |
| `Then 該筆墓標已物理清除（無法還原）` | transactionById 為 null（FR-T3 保留期屆滿；oplog 墓標保留，GC 屬 F07） |
| `Then 交易保存原幣 {amount} 與 fx_rate {rate}` | **M2**（F02 S2.8；amount_minor 存原幣 minor units＋fx_rate REAL） |
| `And 金額運算無浮點誤差（Money VO 斷言）` | **M2**（F02 S2.8；Money 整數 minor units 換算斷言） |
| `Then 產生帳單 {period}、應繳 {amount}、繳款日 {date}` | statements |
| `Then 帳單狀態 = {status}、已繳 {amount}、剩餘 {amount}` | statements |
| `Then 交易 settlement_status = {status}$` | 最近記錄交易之狀態（F04 預扣/結帳） |
| `And 帳戶「{card}」重算餘額 = {amount}（本期應付）` | creditOpenBalance（pending 口徑，F04 S10-預扣） |
| `And 通知 spy 不再收到 N-{n}（已繳取消提醒）` | spy.withId(n) 於取消後不增加 |
| `Then 帳單狀態標記逾期` | statements.overdue（FR-C6） |
| `Then 產生 {n} 筆未來 pending 交易（每筆 {amount}、installment_seq 1..{last}）` | installment 排程（FR-C7；{last}={n}——同名捕獲群禁用） |
| `And 帳戶「{card}」未來已承諾 = {amount}` | Σ 未到期分期 pending（FR-C7） |
| `Then 尚未到期的 {n} 筆分期交易已移除` | 刪除連動（FR-C7） |
| `Then 帳單應繳 = {amount}（負項明細 -{refund}）` | 退款負項（FR-C8） |
| `And refund_links 關聯已建立` | refund_links 表（FR-C8） |
| `Then 帳單 {period} 仍以 {day} 號規則結算` | effective_from 語意（FR-A3） |
| `And 下一期週期 = {period}` | 新結帳日之下一期（FR-A3） |
| `Then oplog 新增 {n} 筆且皆未打包` | oplog |
| `Then 通知 spy 收到 N-{n} 恰 {k} 次，內容含 "{text}"` | notification spy |
| `Then 通知 spy 收到 N-{n} 恰 {k} 次` | 同上（無內容限定） |
| `Then 通知 spy 收到 N-{n} 仍恰 {k} 次（不重複）` | 同上（冪等驗證；斷言前均先 BudgetAlertService.sync 冪等補發） |
| `Then {cat}預算用量 = {amount}（{note}）` | BudgetEvaluator（本期 expense **含 pending 預扣**；{note} 為語意註記，F05 S5.3/S5.6） |
| `Then {cat}預算用量 = {amount}` | 同上（base，後於註記 variant） |
| `And 預算明細標記預扣部分 {amount}` | BudgetEvaluator.pendingPortion（settlement=pending 分量） |
| `Then 收入目標達標率 = {pct}%（已達成）` | BudgetEvaluator（收入/目標 四捨五入；≥100% 已達成） |
| `And 本月預計結餘 = {amount}（{expr}）` | BudgetEvaluator（收入目標 − 總預算；{expr} 為算式註記） |
| `Then 目前週期 = {start} ~ {end}` | BudgetPeriodService（period_start_day → 起訖；end 為含端顯示） |
| `Then 裝置 {a} 與裝置 {b} 的重算餘額一致` | 跨 fixture 比對 |
| `Then 衝突事件 1 筆，被覆蓋內容為 "{text}"` | sync_events |
| `Then 雲端 backups/ 保留 {n} 份` | fake adapter list |
| `Then 雲端 ops/{d}/{file} 存在（{n} ops）` | adapter list/download（OpBundle ops 數；SDD §5.5.2；F07 S1/S3） |
| `Then 裝置{d} 收到 {n} 筆交易` | 該裝置 DB 交易計數（pull 套用結果） |
| `Then 交易 {id} 備註 = 「{note}」（兩裝置一致）` | 兩裝置 DB 比對（LWW 收斂；F07 S2） |
| `And oplog 皆已打包（packed_seq 非 null）` | oplog 全列 packed_seq 非 null（每筆模式即時打包） |
| `Then 雲端僅 {n} 個 bundle（{m} ops，非 {k} 個）` | adapter ops/ 清單計數（批次合併；F07 S4） |
| `Then 交易已同步且附件暫緩（blobs/ 無新檔）` | 交易 op 已上雲＋adapter blobs/ 空（行動網路分流；FR-Y11） |
| `Then 雲端 blobs/{name} 存在` | adapter blobs/ 內容定址檔（Wi-Fi 第二段同步；{name} 為字面佔位——實斷言 blobs/ 非空） |
| `Then 本地收到全部交易/帳戶/分類` | bootstrap 後與來源裝置 DB 比對（FR-Y2） |
| `And 裝置{d} 的 manifest 已建立（lastSeq = {n}）` | devices/{d}.json 存在＋last_seq 欄位（bootstrap 收尾） |
| `And 最舊一份已被清理` | backups 清單不含最舊時間戳（GC 連動） |
| `Then 直接還原成功` | Outline：不加密備份→新 DB 匯入 ok（FR-Y6） |
| `Then 完整還原成功` | Outline：密碼加密備份＋正確密碼→匯入 ok（cryptography AES-GCM） |
| `Then 拒絕匯入且本地資料不變` | Outline：錯誤密碼→拋例外＋新 DB 資料零變動（AC-14） |
| `And 交易資料表無新增（未確認不入帳）` | transactions 計數不變（提醒確認制核心——FR-T5） |
| `And 待確認佇列含「{name} {date}」` | 到期未確認排程查詢（name＋next_due 月/日顯示） |
| `And 待確認佇列仍保留「{name} {date}」` | 同上（暫停後佇列保留——僅停推播不停確認；F06 S5） |
| `Then 交易已入庫且 source = recurring` | DB 讀取（source 欄位；確認入帳） |
| `And 交易金額 = {amt}（模板仍為 {amt2}）` | 交易 amount_minor＋recurring_templates 模板不變（不回寫——FR-T5） |
| `And next_due_date = {date}` | 排程下期推進（monthly→次月同日） |
| `And reminder_count 歸零` | 確認/處理後計數重置 |
| `Then recurring_transactions 該列為墓標` | deleted_at 非 null＋oplog 墓標（payload=null） |
| `And next_due_date 不再產生提醒` | 再 runCheck→N-7 不增（刪除後） |
| `And reminder_count = {n} 且 paused = true` | 同期逾期計數與暫停旗標（FR-T5：≥3 停止推播） |
| `Then 通知 spy 收到 N-{n} 恰 {k} 次（第 {m} 次不發）` | 既有 spy 斷言之語意註記變體（逾期暫停） |
| `Then 鎖定需求 = {bool}` | shouldLockOnResume 判定（≥門檻鎖定；AC-09 邊界） |
| `Then 仍允許生物辨識重試` | biometricFailures < 3（F08 S2） |
| `Then 鎖定策略 = 僅 PIN（停用生物辨識本次解鎖）` | biometricFailures ≥ 3 → biometricAllowed=false（FR-X1 退場） |
| `Then 允許設定新 PIN` | canResetPin=true（雲端 token 驗證通過；FR-X5） |
| `And 本地資料未清空（交易筆數不變）` | 重設前後交易計數一致（資料零損失） |
| `Then 僅提供「重置 App」` | canResetPin=false＋唯一路徑為重置（無繞過分支——FR-X5） |
| `And 不存在繞過 PIN 且保留資料的路徑（斷言無此分支）` | controller 介面無 unlock-without-credential 方法（介面枚舉斷言——安全設計檢驗） |
| `Then 效能：入庫耗時 {ms}ms < 300ms（P95）` | StopWatch P95（F01-BE NFR-01；{ms} 為計畫預記值，以實測 P95 < 300 斷言） |
| `Then 預設帳戶 = 「{name}」` / `Then 預設帳戶 = 第一個未封存帳戶` | QuickEntryPreset 輸出（FR-Q4） |
| `Then 預設帳戶為空（待帳戶建立）` | preset.account == null（DBG-003：空帳本不崩潰） |
| `Then 預設分類為空（內建集隨首次設定落地）` | preset.category == null（內建集 seeding 屬 F02） |
| `Then 預設分類 = 「{name}」` | QuickEntryPreset 輸出 |
| `Then 預設時間 = {datetime}` | QuickEntryPreset 輸出（= 現在） |
| `Then 交易已入庫且 settlement_status = {status}` | DB 讀取（最後一次 UseCase 儲存） |
| `And oplog 與交易位於同一 DB transaction（中斷模擬不產生孤兒）` | beforeOplog 注入拋錯 → rollback，兩表皆無孤兒（SDD §5.1） |
| `Then 交易 {amount} 為軟刪除（deleted_at 非 null）` | 以金額對映 Given 已儲存之最近一筆 |
| `And oplog 新增 {n} 筆（墓標）` | delta=n 且新 oplog payload=NULL |
| `Then 解析結果：商家="{m}"、總額={amt}、日期={date}` | parser 輸出 |
| `Then 解析結果：商家統編="{id}"、總額={amt}、日期={date}` | InvoiceQrParser 左 QR 輸出（77 碼欄位對照 acceptance F03；F03 S1） |
| `And 校驗：銷售額 {s} + 稅額 {t} = 總額 {total} 通過` | 解析器內部驗證（銷售額＋稅額＝總計；SDD §5.4；F03 S1） |
| `Then 解析結果：商家="{m}"` | 雙 QR 合併輸出（右 QR 賣方名稱；商家單欄變體，F03 S2） |
| `And 明細含 {items}（與分隔）` | ReceiptDraft.lineItems 逐項斷言（格式「品名 數量×單價=金額」；F03 S2） |
| `Then 顯示「無法辨識此發票格式」且不建立草稿` | 解析失敗回退（FR-S2；固定訊息；不產生發票草稿） |
| `And 建立空白確認卡（日期=今天）供手動輸入` | 回退草稿（日期=Clock.now、總額/商家留空；FR-S2，F03 S3） |
| `Then 解析結果：總額={amt}、日期={date}（信賴度 {conf}）` | OCR 欄位抽取輸出（{conf} 屬**日期欄**——acceptance S3.5：日期欄信賴 0.5；F03 S4） |
| `And 信賴度 < 0.7 的欄位標記為「需人工確認」` | needsReview 旗標（FR-S5 門檻 0.7；F03 S4） |
| `And 無法判定的欄位為留空（非猜測值）` | 無候選 → value 為 null（FR-S5 不猜測；F03 S4） |
| `Then 附件縮至最長邊 1600px、JPEG q70` | 壓縮輸出：最長邊 ≤1600＋JPEG 位元組（FR-S4；F03 S5） |
| `And 檔名 = blobs/{sha256}（內容定址）` | blob 檔名 == 壓縮後 bytes 之 sha256（SDD §5.4；{sha256} 由 harness 計算；F03 S5） |
| `And attachments 資料列建立且關聯交易` | attachments.transaction_id 關聯＋sha256/byte_size 落地（FR-S4；F03 S5） |
| `Then 解析結果：總額={amt}（無網路呼叫斷言）` | 純本機解析（FR-S3；連線關閉態可達；F03 S6） |
| `Then 效能：OCR 欄位抽取耗時 {ms}ms < {limit}ms` | Stopwatch 實測（NFR-02 單張 OCR < 3000ms；{ms} 為計畫預記值；F03 S7——**2026-10-21 規格修正**：原句「入庫耗時」語意不符（OCR 抽取不入庫），照 F10 效能句型修正先例） |
| `Then 通知 spy 收到 N-{n} 恰 {k} 次（分級累計）` | 通知檢查多時點累計（F04 提醒：前 3 天＋當天各一次） |
| `Then 搜尋 "{kw}" 命中 {n} 筆` | FTS5 bigram |
| `Then 搜尋 "{kw}" 命中 {n} 筆（命中「{hit}」）` | 同上＋命中備註/商家含 {hit} |
| `Then 命中 {n} 筆（{note}）` / `Then 命中 {n} 筆` | 複合篩選結果數（AND；空結果友善提示為 UI 面） |
| `Then 檔案以 UTF-8 BOM 開頭（EF BB BF）` | CsvExporter 輸出 utf8 前三 bytes（FR-R4） |
| `And 欄位含 {fields}` | CSV header 欄位檢查 |
| `And 金額欄為純數字（{n} 筆，可 SUM）` | 資料列金額皆為整數＋列數檢查 |
| `Then 效能：報表聚合耗時 < {limit}ms（P95）` | Stopwatch 實測（NFR-01；10 萬筆 < 1500ms） |
| `Then {cat}占比 = {pct}%（{expr}）` | ReportAggregate（分類金額/總計，四捨五入至 0.1%；FR-R2） |
| `And 合計 = {amount}（{note}）` | 期間 expense 總計（不含 7 月/轉帳——FR-R2） |

---

## 3. 前端 DSL（@FE，綁定自製 runner + integration_test，TR-9）

**環境與掛鉤**：integration_test 啟動真 App（注入 fake clock/mock cloud/notification spy）；螢幕截圖存檔供報告；桌面 runner 支援快捷鍵注入。

### 3.1 Given（前置）

| 句型 | 綁定行為 |
|---|---|
| `Given App 已完成首次設定` | 啟動至總覽（略過引導） |
| `Given 使用者位於{page}頁` | 導航至該分頁（NavigationBar 點選；同句型之 Then 用法見 §3.3） |
| `Given 已建立帳戶「{name}」(餘額 {amount})` | fixture API（同 BE 語意；未標類型 → 內建集名稱對映：票證卡=ewallet、銀行=bank、其餘 cash——F02 儲值語意需類型） |
| `Given 已建立分類{names}` | categories（連續「名稱」緊接；「其他」為內建 is_system；同 BE 語意） |
| `Given 歷史交易: {描述}` | fixture API。段型：①`昨日 HH:MM 帳戶/分類/商家 金額 元`（單筆支出）②`本週{時段}帳戶/分類 N 筆`（前 N 日同時段各 1 筆）——**須在「模擬系統時間」之後**（相對日以凍結時間為基準） |
| `Given 模擬系統時間為 {datetime}` | fake clock 凍結 |
| `Given 快記頁已輸入金額 {amount}、帳戶={account}、分類={category}` | 開啟快記＋controller 狀態設定（金額/帳戶/分類） |
| `Given 已儲存 {n} 筆（{account}/{category}/{merchant}）並於對話框按「繼續」` | 逐筆：設定→儲存→按「繼續」（Sticky 觸發；金額未標 → 120） |
| `Given 已於本 session 儲存 {n} 筆` | 前 n-1 筆儲存後按「繼續」，第 n 筆儲存後**留於對話框**（復原入口） |
| `Given 帳本為全新空本（無帳戶/分類/交易）` | 以全新 in-memory DB 替換（fixture 層；DBG-003 回歸用——App 未 pump 前生效） |
| `Given 已存在一筆支出 {amount} 元` | fixture 直寫 1 筆支出（第一個未封存帳戶）並凍結基準日 2026/10/19 12:00（對齊情境日期算術：2026/11/18 = +30 日；F02-FE S4） |
| `Given 裝置處於飛航模式` | 連線模擬關閉 |
| `Given 同步模式設定為「{mode}」` | settings 寫入 |
| `Given 相機權限未授權` | fake 權限閘（T-H8 掛鉤；權限對話框回放；F03-FE S2） |
| `Given 掃描頁已掃 {n} 張標準測資發票` | fake scanner 回放注入 n 張 T-H6 標準發票（不經真相機；F03-FE S3） |
| `Given OCR 對日期欄位的信賴度為 {conf}（低於 {threshold} 門檻）` | OCR 影像回放注入低信賴 fixture（acceptance S3.5；F03-FE S4） |
| `Given 使用者位於 Windows 版（無相機裝置）` | 桌面無相機模擬（F03-FE S6 @desktop） |
| `Given 模擬雲端為 in-memory adapter 且已連結（Google 帳號 {email}）` | FE Background：adapter＋OAuth seam 預連結（settings sync.account；F07-FE） |
| `Given 未連結雲端` | settings sync.account 清空（F07-FE S1） |
| `Given 已有 {n} 筆未同步變更` | fixture 直寫 n 筆（oplog packed_seq=null；F07-FE S2/S3） |
| `Given 模擬雲端已有帳本資料` | 預置 bundle＋backups（還原流程前置；F07-FE S4） |
| `Given 模擬雲端已有帳本資料（帳號 {email}）` | 同上——異帳號空間（F07-FE S5） |
| `Given 同步狀態頁有 {n} 筆衝突事件（被覆蓋內容「{text}」）` | db 直寫 sync_events（AC-07 呈現前置；F07-FE S6） |
| `Given 已建立定期交易「{name}」每月 {day} 日金額 {amt}（提醒確認制）` | FE fixture 直寫 recurring（同 BE 語意；F06-FE Background） |
| `Given 房租連續 3 次開啟 App 皆未處理（{dates}）` | 逐日凍結＋重啟（啟動檢查觸發 reminder 累計；F06-FE S4） |
| `Given App 鎖已啟用（PIN {pin} + Face ID、門檻 {n} 秒）` | FE Background：AppLockController 接線（鎖定覆蓋層啟用；F08-FE） |
| `Given App 已連結雲端帳號` | settings sync.account（還原/重設前提；F08-FE） |
| `Given 於鎖定畫面` | 鎖定覆蓋層呈現中（F08-FE S4） |

### 3.2 When（動作）

| 句型 | 綁定行為 |
|---|---|
| `When 開啟快速記帳頁` / `When 按下 Ctrl+N（macOS 為 ⌘N）` | 快記入口 |
| `When 開啟快速記帳頁並連續記錄 {n} 筆後按下「完成」` | 開快記→連存 n 筆（每筆按繼續，末筆按完成）→返回原分頁（S1.9） |
| `When 輸入金額 {amount}` | 鍵盤輸入 |
| `When 開啟支出記錄` | 開啟快記（預設支出模式；F02-FE S1 同「開啟快速記帳頁」） |
| `When 以計算機鍵盤計算 {expr}` | 逐鈕點按（數字逐位＋運算子＋＝；`+ - * /` 映射鍵面 ＋－×÷）；＝求值寫入金額欄（左至右、TWD 四捨五入至整數元；F02-FE S2.9） |
| `When 於計算機鍵盤按 {key}` | 單鈕點按（C 清空／⌫ 退位；F02-FE S2.9） |
| `When 建立轉帳「{from}」→「{to}」金額 {amt}` | 快記轉帳模式：開快記→切轉帳→選來源/目標→輸入→儲存→完成（F02-FE S2） |
| `When 建立「儲值」交易 {to} 金額 {amt} 來源={from}` | 同轉帳（目標=票證卡；F02-FE S3） |
| `When 刪除該筆交易` | 明細列 → 刪除動作（bottom sheet「刪除」；軟刪除，F02-FE S4） |
| `When 按下「{label}」` | 點擊可見文字按鈕 |
| `When 點擊時間欄位` | 時間選擇器 |
| `When 掃描標準測資發票（左QR+右QR）` | 影像回放注入掃描器 |
| `When 拍攝紙本收據（fixture {n}）` | OCR 影像回放 |
| `When App 切至背景 {n} 秒後返回` | lifecycle 模擬 |
| `When 關閉並重新啟動 App` | 重啟（驗證啟動同步） |
| `When 從相簿匯入 fixture {n}` | 桌面/無相機路徑 |
| `When 開啟總覽頁並按下「掃描」` | 導航至總覽＋點擊掃描入口（key scan-entry；F03-FE S2） |
| `When 拒絕權限` | fake 權限對話框按「拒絕」（F03-FE S2） |
| `When 進入確認卡` | 確認清單首張卡聚焦（F03-FE S4） |
| `When 確認第 {n} 張（分類={cat}、帳戶={a}）並按下「確認儲存」` | 卡內分類/帳戶選擇→儲存→自動跳下一張（source=scan＋附件關聯；F03-FE S3） |
| `When 按下「{label}」而未處理` | 點擊但高亮欄位未確認（F03-FE S4；匹配順序須後於通用 `按下「{label}」`） |
| `When 按下 Ctrl+Shift+S（macOS 為 ⌘⇧S）` | 桌面掃描快捷鍵注入（F03-FE S6；同 Ctrl+N 鍵注入模式） |
| `And 再掃描 {n} 張` | fake scanner 追加回放（F03-FE S5） |
| `When 設定→雲端與同步→按下「連結 Google Drive」` | 導航設定同步頁＋點擊連結（key sync-link；F07-FE S1） |
| `When 完成登入並同意授權` | fake OAuth 完成回呼（email 回傳；F07-FE S1） |
| `When 按下「立即同步」` | 點擊同步鈕（key sync-now；SyncSettingsPage；F07-FE S2） |
| `When 關閉並重新啟動 App 並選擇「從雲端還原」` | 重啟＋還原流程入口（key restore-cloud；F07-FE S4） |
| `And 登入同一帳號` | fake OAuth 同 email（F07-FE S4） |
| `When 選擇「從雲端還原」並登入帳號 {email}` | 還原＋異帳號 OAuth（F07-FE S5） |
| `When 開啟同步狀態頁` | 導航衝突檢視（key sync-conflicts-entry；F07-FE S6） |
| `When 按下 badge` | 點擊待確認 badge（key recurring-badge；F06-FE S1） |
| `When 將金額改為 {amt} 並按下「確認入帳」` | 待確認清單金額欄＋確認鈕（key recurring-amount/confirm-recurring；F06-FE S2） |
| `When 開啟待確認清單` | 導航 RecurringQueuePage（F06-FE S4） |
| `When App 切至背景 {n} 秒後返回` | lifecycle 模擬＋AppLockController 門檻判定（T-H8 pumpBackground 落地；F08-FE S1/S2） |
| `When 使用 Face ID 成功解鎖` | fake biometric seam 成功回呼（F08-FE S1） |
| `When Face ID 連續失敗 {n} 次` | fake biometric 失敗×n（退場機制；F08-FE S3） |
| `When 輸入 PIN {pin}` | PIN 鍵盤輸入（key pin-input；F08-FE S3） |
| `When 按下「忘記 PIN」` | 鎖定畫面入口（key forgot-pin；F08-FE S4） |
| `When 設定新 PIN {pin}` | 新 PIN 設定（key new-pin-input＋確認；F08-FE S4） |
| `When 按下 👁 遮蔽開關` | 隱私遮蔽切換（key privacy-toggle；FR-X3；F08-FE S5） |
| `When 按下檢視` | 衝突事件詳情（F07-FE S6） |

### 3.3 Then（斷言）

| 句型 | 綁定行為 |
|---|---|
| `Then {field}預填為「{value}」` | widget 斷言（field=帳戶/分類/商家：find.text 於快記頁內；field=時間：value="現在" → 格式化 Clock.now()，否則解析 {value} 比對） |
| `Then 金額欄為空且鍵盤已聚焦` | 金額 TextField text 為空＋EditableText focusNode.hasFocus |
| `Then 金額欄為空` | 金額 TextField text 為空 |
| `Then 使用者位於{page}頁` | 分頁斷言（與 §3.1 同句型：綁定以該頁是否已作用中區分——未作用中=導航（Given），已作用中=斷言（Then）） |
| `Then 彈出對話框「{text}」且提供「{a}」「{b}」「{c}」三個動作` | dialog |
| `Then 儲存按鈕為禁用狀態` | enabled=false |
| `Then 明細頁即時顯示該 {n} 筆` | 清單斷言 |
| `Then 顯示「{text}」` / `Then 不顯示「{text}」` | 文字存在性（「日期時間選擇器」綁定 find.byType(QuickDateTimePicker)） |
| `Then 顯示「{text}」且為可點擊` | 文字存在＋對應按鈕 enabled（F02-FE S1 儲存鈕啟用） |
| `Then 顯示「{text}」標籤` | 文字存在（標籤語意；F05-FE S5.3 預扣標籤） |
| `Then 顯示「掃描」按鈕（獨立於快記大鈕）` | find.byKey(scan-entry)（FR-S6 兩入口；F03-FE S1） |
| `Then 顯示「前往設定開啟權限」且不離開 App` | 引導文案＋仍在 App 內（F03-FE S2） |
| `Then 顯示「確認清單（{n} 張）」` | 確認清單標題（F03-FE S3/S6） |
| `Then 顯示「{n} / {total}」` | 逐張確認進度（F03-FE S3） |
| `And 明細頁即時顯示該 1 筆（帶 📷 附件標記）` | 明細列＋附件圖示（F03-FE S3；**先於通用 `明細頁即時顯示該 {n} 筆` 註冊**） |
| `Then 顯示「請確認日期」（高亮樣式）` | needsReview 欄位警示高亮（FR-S5 0.7 門檻；F03-FE S4） |
| `Then 顯示「請先確認高亮欄位」且不建立交易` | 未處理擋下＋交易零新增（FR-S5；F03-FE S4） |
| `Then 顯示「已掃 {n} 張」` | 掃描計數文字（FR-S7；F03-FE S5） |
| `And 顯示 {n} 個縮圖` | 掃描縮圖列計數（F03-FE S5） |
| `Then 導向「相簿/檔案匯入」` | 無相機匯入頁呈現（F03-FE S6 @desktop） |
| `Then 顯示「Google 登入」（模擬）` | OAuth seam 登入畫面（F07-FE S1） |
| `Then 顯示「連結成功」` | 授權完成回饋（FR-Y7；F07-FE S1） |
| `And 顯示「建議為此帳號開啟兩步驟驗證」` | 帳號安全教育文案（SDD §7.1；F07-FE S1） |
| `And 不顯示「同步密碼」` | 帳號授權式同步——無同步密碼 UI（FR-Y7 反斷言；F07-FE S1/S4） |
| `Then 顯示「同步中…」` | 同步進行中回饋（按鈕態；tap 後 pump 未 settle 斷言；F07-FE S2） |
| `Then 顯示「已同步 {n} 筆變更」` | 同步完成回饋（Snackbar；F07-FE S2） |
| `And 顯示「待同步 {n} 筆」` | unpackedOps 計數（F07-FE S2/S3） |
| `Then 顯示「上次同步 今天 {time}」` | settings sync.last_at 格式化（啟動同步觸發證明；F07-FE S3） |
| `Then 顯示「還原完成」（帳戶/交易/分類/預算）` | bootstrap 結果回饋（AC-08；F07-FE S4） |
| `Then 顯示「此帳號沒有可還原的資料」` | 異帳號空備份（FR-Y2；F07-FE S5） |
| `Then 顯示「{n} 筆衝突」` | sync_events 計數（AC-07；F07-FE S6） |
| `Then 顯示「鎖定畫面」` | 鎖定覆蓋層（key lock-screen；不可透視——遮蔽底層內容；AC-09） |
| `Then 顯示「離開前的畫面」且資料完整` | 解鎖後恢復原路由（lock overlay 移除） |
| `Then 顯示「PIN 輸入鍵盤」` | 退場後 PIN 輸入 UI（key pin-input；FR-X1 退場） |
| `Then 顯示「設定新 PIN」` | 重設流程（key new-pin；FR-X5） |
| `Then 顯示「資料完整保留」（{n} 筆交易）` | 還原/重設後交易計數（資料零損失；FR-X5） |
| `Then 金額全部顯示為 ●●●●` | 隱私遮蔽態（金額 widget 全遮蔽；FR-X3） |
| `Then 顯示「{amount}」（原金額）` | 遮蔽關閉還原（F08-FE S5） |
| `Then 顯示「{text}」（唯讀）` | 被覆蓋內容唯讀檢視（F07-FE S6） |
| `Then 顯示「待確認 {n}」badge` | find.byKey(recurring-badge) 文字（FR-T5 到期未確認數；F06-FE S1） |
| `Then 顯示「待確認清單」含「{name} {amt}」` | RecurringQueuePage 標題＋項目（F06-FE S1） |
| `Given 待確認清單含「{name} {amt}」` | 同上（前置語意——啟動檢查已產生佇列；F06-FE S2/S3 前置） |
| `And 顯示「下期 {date} 提醒」` | next_due 月/日顯示（確認/跳過後推進呈現；F06-FE S2/S3） |
| `Then 顯示「已暫停提醒」` | paused 項標示（逾期 3 次；F06-FE S4） |
| `Given 本期{cat}已支出 {amount}` | fixture 直寫本期 expense（F05-FE） |
| `Given 本期{cat}含信用卡預扣 {amount}` | fixture 直寫本期 pending expense（F05-FE S5.3） |
| `Given 收入目標 {goal} 且本月已入帳 {achieved}` | income_goals＋fixture 直寫本月 income（F05-FE S5.4） |
| `Given 設定→通知→「預算警示」= {state}` | settings `budget.notify_enabled`（on/off；off 僅關推播，in-App 視覺不受影響——FR-O2/S5.7） |
| `When 開啟預算頁` | 導航至預算分頁（M2 主殼第三分頁，SDD §8 IA） |
| `When 開啟統計頁並選擇 {month} 月` | 導航至統計分頁＋月份選擇器（M2 主殼第四分頁；F10-FE S1） |
| `Then 月趨勢圖 {m1} 月 = {v1}、{m2} 月 = {v2}` | 月趨勢值文字（千分位；有資料月份，F10-FE S1） |
| `When 篩選 期間={period}、分類={cat}` | 明細頁篩選列：期間/分類選擇器（F10-FE S2） |
| `When 關鍵字輸入「{kw}」` | 篩選關鍵字欄輸入（FTS 即時套用） |
| `Then 僅顯示 {n} 筆（三條件交集）` | TxTile 計數（AND 交集） |
| `And 顯示篩選 chips 可逐一移除` | InputChip 存在（≥1，可逐一移除） |
| `When 清除全部篩選` | 「清除篩選」按鈕（還原完整清單） |
| `Then 顯示全部 {n} 筆` | TxTile 計數（全部月份） |
| `Given 篩選生效（期間={period}）` | 明細頁期間篩選設定（F10-FE S3） |
| `And 已建立帳戶「{name}」(餘額 {amount})（結帳日 {day} 號、歸屬={rule}）` | seedCreditCard（rule：當天算本期=include；F04-FE） |
| `Given 已有 {n} 筆預扣交易於「{card}」共 {amount}（上一期）` | fixture 直寫上一期 pending（相對凍結時間之已關閉週期；F04-FE） |
| `And 執行 BillingCycleService.run（「{card}」）（經 fixture 觸發）` | BE 服務直接呼叫（結帳觸發點前置，F04-FE） |
| `When 開啟信用卡頁` | 總覽信用卡卡點擊 → CreditCardPage（F04-FE） |
| `When 開啟信用卡頁並按下「{label}」` | 開頁＋繳款對話框開啟（F04-FE） |
| `When 按下「繳款」→「自訂金額」輸入 {amount} 並確認` | 自訂金額繳款流程（F04-FE S3） |
| `When 開啟卡片設定頁` | CardSettingsPage（歸屬規則呈現，F04-FE S4） |
| `Then 顯示「{text}」徽章` | 狀態徽章（key badge-{text}；F04-FE） |
| `And 顯示「{text}」徽章（頁首）` | 頁首徽章（逾期標示，F04-FE S5） |
| `When 建立拆分交易 總額 {total}（{cat1} {a1} + {cat2} {a2}）` | 快記拆分模式：雙子項（分類＋金額）→ executeSplit（總額守恆；F02-FE S2.7 @M2） |
| `And 顯示「{label}」樣式（同一群組）` | 拆分樣式：兩列同群組＋call_split 圖示（F02-FE S2.7） |
| `When 開啟總覽頁` | 導航至總覽分頁（NavigationBar；F05-FE S5.4/S5.5） |
| `Then 金額欄下方顯示常駐計算機鍵盤` | find.byKey(amount-keypad)；金額欄 readOnly 不彈系統鍵盤（F02-FE S2.9） |
| `Then 金額欄顯示 {value}` | 金額欄 text == value（＝ 求值結果；TWD 四捨五入整數元） |
| `Then 顯示「{label}」樣式（非支出圖示）` | 明細列樣式：textContaining({label})＋轉帳圖示 swap_horiz（F02-FE S2） |
| `Then 顯示「{text}」（不顯示「{other}」）` | 組合斷言：儲值文案出現且支出字樣不出現（F02-FE S3） |
| `Then 帳戶「{name}」餘額顯示為 {amount}` | 總覽餘額卡（千分位格式；導航至總覽分頁後 find.text，F02-FE S2） |
| `Then 明細頁即時顯示該 {n} 筆（已移除）` | 該 session 金額文字自明細消失（軟刪除即時反映，F02-FE S4） |
| `Then 設定→「最近刪除」顯示 {n} 筆（剩餘 {days} 天）` | RecentDeletionsPage：墓標列數＋「剩餘 N 天」文字（M1 入口＝明細 AppBar；設定頁整體屬 F07；剩餘天數以**曆日**計，F02-FE S4） |
| `Then 設定→「最近刪除」顯示 {n} 筆` | 同上（無剩餘天數限定；0 筆＝空狀態） |
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
