# BDD 步驟 DSL 規範（Given/When/Then 句型登記簿）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.5（F02 全期：§2 BE 18 句型＋§3 FE 16 句型（含 S2.9 計算機 4 句型）；多幣別 3 句型 @M2 暫緩綁定） |
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
| `Given 已有 {n} 筆預扣交易於「{card}」共 {amount}（{start}~{end}）` | 批次 pending 交易＋oplog（期間變體，F04 S10-補算/逾期/生效日） |
| `Given 帳單 {period} 應繳 {amount} 狀態 {status}，含交易 {txAmount}（billed）` | statements＋statement_items＋billed 交易（退款情境，F04） |
| `Given 帳單 {period} 應繳 {amount} 狀態 {status}（繳款日 {date}）` | 同上＋due_date 指定（提醒情境，F04） |
| `Given 已有 {n} 筆預扣交易於「{card}」共 {amount}（{start}~{end} 期間）` | 週期語意（生效日情境，F04 修改結帳日） |
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

### 2.2 When（動作）

| 句型 | 綁定行為 |
|---|---|
| `When 呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）` | UseCase 呼叫（計時） |
| `When 呼叫 SaveTransactionUseCase（帳戶「{a}」、分類「{c}」、金額 {amt}、時間 {t}）計時 {n} 次` | NFR-01：n 次計時取 P95 |
| `When 呼叫 QuickEntryPresetService 計算預設` | FR-Q4 智慧／固定預設計算（不含商家） |
| `When 呼叫 QuickEntryPresetService 計算預設（商家={m}）` | 同上＋商家歷史分類優先 |
| `When 呼叫 UndoLastTransaction` | 軟刪除+oplog |
| `When 執行 BillingCycleService.run（「{card}」）` | 結帳引擎 |
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
| `Then 產生 {n} 筆未來 pending 交易（每筆 {amount}、installment_seq 1..{n}）` | installment 排程（FR-C7） |
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
