# Session 工作交接（session.md）

| 項目 | 內容 |
|---|---|
| 用途 | **休息／中斷工作前**記錄當前進度，下次開工快速恢復；配套規範見 `specs/plan/tasks.md` §0 |
| 原則 | ①離開前必填「目前快照＋下一步」②狀態同步回 `tasks.md` §6（🔴/🟢/🔵/✅）③工作變更必先 commit（或明確標註 WIP 原因）④**本地部署驗證**：整體軟體所有測試寫完＋全量綠燈後做**一次**（非每個功能做完就部署；PM 2026-10-20 指示），通過才 push ⑤執行每個任務前列出 TASK/TODOLIST 讓 PM 可見（PM 2026-10-19 指示） |

---

## 1. 休息前檢查清單（離開前逐項確認）

- [x] 當前情境的紅/綠燈狀態已記錄（§2 快照表）
- [x] `tasks.md` §6 對應任務狀態已回寫（本次：**F04 ✅ M3 完成**——merge main c1b52b0＋tag v0.4.7；FE 回歸 4/4＋部署驗證通過）
- [x] 工作區已 commit（`git status` 乾淨）；分支已 push
- [x] truth 對齊：techstack v0.3.6；data-spec v0.3.1；T-H9 對齊測試（60 綠內）持續把關
- [x] 「下一步」精確到：F02 規範檔案、情境清單、分支名（§3）
- [x] 若有進行中 Debug：`specs/plan/debug.md` 條目狀態已更新（DBG-003/004 均 ✅ 結案）

## 2. 目前快照（每次休息前更新此表）

| 欄位 | 內容 |
|---|---|
| 更新時間 | 2026-10-21（M4 進行中：T-S4 ✅＋T-F03-BE 🟢 7/7，交接快照） |
| 階段 | **M4 掃描進行中**：T-S4 schema v4 ✅（attachments 表＋遷移鏈 v3→v4＋T-H9 擴充，merge main `6501051`，85 綠）；**T-F03-BE 🟢 7/7 全綠**（分支 `feature/F03-receipt-scan` 進行中：QR 77 碼切片解析／右 QR 明細合併 codec／回退 TransactionDraft.blank／OCR heuristics 0.7 門檻／AttachmentStore 壓縮+sha256 定址／離線／NFR-02；86 unit 綠）；**T-F03-FE 6 情境待開工**（紅燈未起） |
| 當前分支 | **feature/F03-receipt-scan**（自主測快照：10 commits——truth/依賴/紅燈/S1~S7 綠/藍燈/DBG-005 結案/tasks 回寫；**未 push**） |
| 當前任務 | 本輪：①T-S4 schema v4 ✅ ②techstack v0.3.7（image 4.12.0＋crypto 3.0.7，PM 簽核 2026-10-21）③T-F03-BE 7 情境 🔴→🟢 ④DBG-005 結案（save_split 順序依賴；斷言改順序無關；10 連綠驗證）⑤規格修正：acceptance/feature 測資字串 76→77 碼（總計段補 0——**acceptance 變更待 PM 複核**）＋S7 效能句型「入庫耗時」→「OCR 欄位抽取耗得」 |
| 紅綠燈狀態 | 分支上 `dart analyze` 0＋**unit 86 全綠**（85＋F03-BE 1 檔）；main 85 綠 |
| 工作區 | 乾淨（已 commit 至 e7689cf；未 push——FE 完成後隨 M4 一起評估） |
| truth 對齊 | **techstack v0.3.7**（image＋crypto 新增）；**dsl v0.6**（BE §2 +19 句型：Given 1/When 5/Then 13）；data-spec v0.3.1 不變（attachments v0.3 已預定義）；T-H9 對齊綠（pubspec ⊆ techstack） |
| 環境筆記 | 延續上輪全部。新增（F03-BE）：①**測試勿對 UUIDv7 字典序順序斷言**——allTransactions() ORDER BY id 在同 occurredAt 時由 UUID 字典序決定，時鐘微回退（NTP slew）使順序翻轉（DBG-005 根因）②**手寫 77 碼長字串極易錯**——規格測資字串以 T-H6 fixture 拼接為準，發現 76 碼 typo 用 python 腳本替換勿手改 ③image 套件 4.12：decodeImage 要求 Uint8List（List<int> 須 Uint8List.fromList）；`Image(width:, height:)` 建空圖＋encodePng 動態 fixture 可行 ④flutter test 併行下 flaky 排查：先落盤再循環重跑（`for i; flutter test > log`），勿只 tail——本輪靠 dbg005_loop_7.log 抓到 Expected 600 Actual 400 |
| 阻塞／待決 | ①**acceptance F03 測資字串修正待 PM 複核**（76→77 碼 typo，欄位對照語意不變）②gh 未安裝 ③dbml sync_entity 缺 income_goals（F07 前 truth PR）④SP-1 SQLCipher ⑤多幣別 900 矛盾待 PM ⑥notify_enabled=off 語意待 PM ⑦UI 統整＝M7 一次做 |

## 3. 下一步（T-F03-FE 6 情境；下次開工照此執行）

1. **push 分支**（feature/F03-receipt-scan 未 push——BE 完成狀態先保住）。
2. **dsl.md §3 FE 句型登記**（~20 個，dsl 先行）：`Given 相機權限未授權`／`Given 掃描頁已掃 {n} 張標準測資發票`／`Given OCR 對日期欄位的信賴度為 0.5（低於 0.7 門檻）`／`Given 使用者位於 Windows 版（無相機裝置）`／`When 開啟總覽頁並按下「掃描」`（或複合既有）／`When 拒絕權限`／`When 進入確認卡`／`When 按下「確認儲存」而未處理`／`When 按下 Ctrl+Shift+S`／`And 再掃描 {n} 張`／`Then 顯示「掃描」按鈕（獨立於快記大鈕）`／`Then 顯示「權限請求」`／`Then 顯示「前往設定開啟權限」且不離開 App`／`Then 顯示「確認清單（{n} 張）」`／`When 確認第 {n} 張（分類={cat}、帳戶={a}）並按下「確認儲存」`／`Then 顯示「{n} / {total}」`／`And 明細頁即時顯示該 1 筆（帶 📷 附件標記）`／`Then 顯示「請確認日期」（高亮樣式）`／`Then 顯示「請先確認高亮欄位」且不建立交易`／`Then 顯示「已掃 {n} 張」`／`And 顯示 {n} 個縮圖`／`Then 導向「相簿/檔案匯入」`——既有可覆用：`按下「{label}」`、`從相簿匯入 fixture {n}`、`掃描標準測資發票（左QR+右QR）`（影像回放注入——FE harness 須建 fake scanner）。
3. **UI 構件**（M4 FE 主體）：①掃描入口按鈕（總覽＋明細頁；key `scan-entry`）②ScanPage（狀態機：權限閘→掃描中（已掃計數＋縮圖列）→完成掃描→確認清單）③權限流程（fake permission harness：未授權→權限請求→拒絕→「前往設定開啟權限」不離開 App）④ReviewPage 確認清單（逐張卡：商家/總額/日期＋needsReview 高亮警示色＋分類/帳戶選擇＋「n / N」＋確認儲存跳下一張——掛 SaveTransactionUseCase source=scan＋AttachmentStore）⑤低信賴擋儲存（未處理高亮→「請先確認高亮欄位」）⑥桌面 ⌘⇧S/Ctrl+Shift+S→無相機導向匯入→檔案匯入 OCR 回放（fixture 1）→確認清單。
4. **測試環境**：FE harness 照 F02/F05 模式（integration_test＋rootBundle feature 檔＋fake clock）；macOS 實跑（相機權限與掃描器皆 fake——無真裝置依賴；桌面情境在 macOS 上以 ⌘⇧S 注入測）。
5. FE 全綠後：M4 收尾——全量綠燈→**本地部署驗證一次**（Release 47MB 級＋啟動冒煙）→bump 0.4.8→merge main→tag v0.4.8→M5（F07 同步）。
6. 休息前照 §1 檢查清單更新本檔。

### 通用 harness/UI 教訓（跨功能累積，持續生效）
- CreditCardPage 開頁副作用：initState postFrameCallback 觸發結帳檢查（FR-C3 sync 點）——勿在 build 中 ref.read/invalidate。
- 推入路由後主殼 offstage：harness 跨頁斷言前先 `navigator.maybePop()`。
- 金額輸入千分位：parse 須 `replaceAll(',', '')`。
- dsl 變體先於 base 註冊（lazy 前綴碰撞）；同名捕獲群禁用（{n} 出現兩次→後者改 {last}）。

## 4. 恢復工作 SOP（下次開工照此執行）

1. 讀本檔「目前快照」與「下一步」。
2. `git status` + `git branch --show-current` 確認分支與工作區。
3. 跑 `dart analyze`（注意環境筆記）與 `flutter test` 確認燈號與快照一致。
4. 不一致 → 以測試實際狀態為準並修正本檔，再繼續。
5. 從「下一步」第 1 項繼續；完成一個情境即 commit 一次。

## 5. 歷程記錄（append-only，新在上面）

| 日期 | 摘要 | 分支 | 狀態 |
|---|---|---|---|
| 2026-10-21 | **M4 開工：T-S4 完成＋T-F03-BE 7/7 全綠＋DBG-005 結案**：T-S4 schema v4（attachments 表＋遷移鏈 v3→v4＋T-H9 擴充＋既有遷移測試「現行版本」斷言 3→4 維護——merge main `6501051`，85 綠）；techstack v0.3.7（image 4.12.0＋crypto 3.0.7 附件壓縮定案，PM 簽核——純 Dart 跨平台位元組一致保內容定址去重）；dsl v0.6（BE +19 句型）；**T-F03-BE 🔴→🟢 逐情境 7 commits**（InvoiceQrParser 77 碼切片/應稅驗證/民國轉西元→parse 雙 QR 合併/回退 null→ReceiptFieldExtractor heuristics 0.7 門檻→AttachmentStore image 縮 1600+JPEG q70+sha256→blobs）；**規格修正**：acceptance＋feature 測資字串 76→77 碼（總計段補 0，對齊欄位對照表與 T-H6；**待 PM 複核**）＋S7 效能句型「入庫耗時」→「OCR 欄位抽取耗時」（F10 先例）；**DBG-005 結案**（save_split 3/50 間歇失敗——根因：測試對 UUIDv7 字典序的順序依賴，NTP slew 時鐘微回退觸發翻轉，Expected 600 Actual 400 證據落盤；斷言改順序無關，10 連跑驗證）；86 unit 全綠 | feature/F03-receipt-scan（未 push） | 🔵（BE 🟢 7/7；FE 6 情境待開工） |
| 2026-10-20 | **M3 完成：F04 併入 main＋v0.4.7**：FE 回歸 4/4 全綠（F01 6＋F02 5＋F05 5＋F10 3，macOS）→M3 部署驗證通過（Release 47.4MB＋兩次啟動冒煙＋二次啟動無崩潰（DBG-004 回歸）＋Info.plist 0.4.7）→bump 0.4.7＋`--no-ff` merge（c1b52b0）→push main→**tag v0.4.7 自動建立**（四平台 release 建置中）→功能分支已刪；main analyze 0＋unit 82 全綠 | main | ✅（M3 完；M4 掃描待開） |
| 2026-10-20 | **F04 信用卡帳單引擎 BE＋FE 完成（12+5 情境全綠）**：BE（5 服務：BillingCycleService 結帳/clamp/歸屬冪等、RepayStatementUseCase paid/partial＋N-5 取消、NotificationCheckService N-5 前三+當天分級＋N-6 一次、InstallmentService 排程+刪除連動、RefundService refund_links＋帳單負項； TxRow.installmentSeq、AppDatabase v3 CRUD/runInTransaction/生效日）；FE（CreditCardPage 徽章/帳單卡/繳款對話框、CardSettingsPage、總覽入口、repayStatementProvider）；**修復**：build 期間 invalidate（postFrameCallback）／推入路由主殼 offstage（maybePop）／金額千分位 parse／Rail-Bar finder；**磁碟滿危機**（lipo no space→當機主因，flutter clean 9.1GB）；dsl +22 句型（BE 11＋FE 11）；unit 82 全綠 | feature/F04-credit-card-billing | 🔵（F04 全綠；待 FE 回歸+部署驗證+merge 0.4.7） |
| 2026-10-20 | **App 畫廊新增「10 新增資料」＋UI 統整決策**：畫廊新增可互動 demo 頁（真實 AmountKeypad：計算機/模式切換/儲存啟用態）；**UI 統整＝M7 上架前一次做**（tokens＋深色模式＋無障礙；PM 決策——中途不做視覺 pass）記入 tasks.md §4.2；session.md 快照同步（main 28bdc85） | main | ✅（28bdc85 已 push） |
| 2026-10-20 | **F10-FE 完成＋桌面殼落地＋UI demo**：統計分頁（M2 IA 第四分頁：月份選擇器＋占比 0.1%＋合計千分位＋月趨勢）；明細頁複合篩選（期間/分類/關鍵字 AND＋chips 可移除＋清除＋無符合結果）＋匯出 CSV 提示；**AC-02 回歸修復**（LedgerPage 搜尋重寫遺漏 ledgerProvider 訂閱——F01/F02 紅燈抓到）；**桌面殼 RWD**（≥900px NavigationRail 側欄＋nav keys 雙殼相容＋⌘N/Ctrl+N 快記 F01-S1.11＋視窗 1180×740 對齊 08 雛型）；UI demo `10-quick-entry-calc.html`（新增資料頁：金額輸入＋計算機＋轉帳模式，README v0.4）；**F10-FE 3 情境全綠於 Rail 殼** | feature/F10-reports-search | 🔵（M2 核心齊：F05＋F10；待全套回歸→部署驗證→merge） |
| 2026-10-20 | **F10-BE 報表聚合與搜尋完成（5 情境全綠）**：TextIndex（CJK bigram＋MATCH 查詢）＋AppDatabase FTS 維護（save 鉤子重索引＋ftsSearch/transactionsByRowids/setTransactionNote；環境缺模組降級 LIKE）＋SearchService（AND 複合：期間/分類/帳戶/金額區間＋關鍵字標準化）＋ReportService（占比 0.1%＋總計，轉帳/收入不計）＋CsvExporter（UTF-8 BOM＋10 欄位＋金額純數字）＋insertTransactionsBulk 效能測資；**NFR-01 實測 10 萬筆聚合 387ms<1500ms**；規格修正三處（CSV 5 筆／金額區間 400~800 證明空結果／效能句型「入庫耗時」→報表聚合）；**75 unit 全綠** | feature/F10-reports-search | 🔵（BE 🟢 5/5、FE 待） |
| 2026-10-20 | **T-F05 預算 BE→FE 完成（5+5 情境全綠）**：BE 🔴→🟢（BudgetRow/IncomeGoalRow oplog 契約／BudgetPeriodService 跨月週期／BudgetEvaluator 用量含 pending 預扣分量＋達標率不封頂＋預計結餘／BudgetAlertService 冪等 sync 點——N-1/N-2/N-3 分級補發 settings notif_state per period＋afterSave 鉤子＋notificationProvider no-op；S5.3 規格補漏 Given 6500 對齊 acceptance 前置表）；FE 🔴→🟢（預算分頁 M2 IA 第三分頁＋進度條警示色 orange/red＋超支不封鎖＋預扣標籤＋總覽收入目標卡＋通知開關閘 budget.notify_enabled；情境基線自洽修正 S1 7000/S2 8320 對齊 acceptance 敘述）；**74 unit＋F01/F02-FE 回歸全綠** | feature/F05-budget-income-goal | 🔵（5+5 全綠、待 push 與 PR） |
| 2026-10-20 | **T-S2 schema v2 完成＋M1 發佈**：F02 bump 0.4.5＋merge main→**tag v0.4.5 自動建立**（四平台建置中）；T-S2 🔴→🟢（budgets/income_goals/fts——dbml v0.3 早已預定義，code schema 對齊落地；fts 環境缺模組容錯降級；_migrate 多版本鏈 v1→v2 每版本 transaction＋既有表偵測補標；T-H9 對齊擴充 v1/v2；回歸 4 測試：全新直達 v2／FTS 容錯／v1 舊檔升級資料完整／file 冪等）；T-F05 設計筆記寫入（冪等 sync 點通知語意——由 S5.1 內容 87.5%＋S5.2 N-2 時序反推）；**73 測試全綠**；T-S2 已 merge main（v0.4.5 冪等未重複觸發） | feature/T-S2-schema-v2 → main | ✅（e23b795→bc82a6f→merge ea23a92） |
| 2026-10-20 | **F02-FE 完成＋S2.9 計算機（M1 全綠）**：F02-FE @P0 5 情境 🔴→🟢 macOS 實跑全綠（S1 金額 0/空值禁用／S2 快記轉帳模式＋明細 swap 樣式＋總覽千分位／S3 儲值文案／S4 最近刪除 30 曆日窗口＋還原 UI〔RestoreTransactionUseCase＋unit test〕）；**S2.9 金額計算機鍵盤**（PM 增補：常駐四則運算、＝ 左至右四捨五入整數元、÷0 no-op、連按運算子取代；macOS 視窗 800×760）；**harness 修復**：feature 檔 rootBundle 資產載入（桌面行程 CWD=/，File 相對路徑失效——F01 同修）；規範修正：本地部署驗證＝整體軟體全綠後**一次**、任務前必列 TODOLIST；analyze 0＋unit 69 綠＋F01-FE 回歸全綠；M1 部署驗證通過（Release 46.9MB＋檔案 DB 二次啟動） | feature/F02-transactions-accounts | 🔵（M1 全綠、已部署驗證、已 push、待 PR 合併） |
| 2026-10-19 | **跨電腦接手（macOS）＋F02-BE 完成**：Flutter 3.27.1→**3.47.7 換裝**（truth 對齊；淺層 clone tag，回收 3.6G）；v0.4.4 release 確認（五產物齊全）；**F02-BE @BE @P0 5 情境 🔴→🟢**（6 commits：金額驗證 TransactionValidationException／轉帳守恆 UseCase kind/toAccountId＋MonthlyStatsService／儲值 transfer 語意／軟刪除 DeleteTransactionUseCase＋TombstonePurgeService 30 天／還款 creditUnpaidTotal 下限 0）；dsl v0.4（+18 句型，多幣別 3 條 @M2 deferred PM 確認）；**harness 教訓**：句型 lazy match 前綴碰撞（變體先於 base 登記）＋feature 層 @P0 繼承（過濾須 !@M2）；**61 測試全綠**；macOS Release 建置＋啟動冒煙＋播種驗證（push 前本地部署規範首次執行，PM 指示） | feature/F02-transactions-accounts | 🔵（BE 🟢 5/6、FE 待；已部署驗證已 push） |
| 2026-10-19 | **部署實測回饋修復×3＋播種＋發佈格式定案**：DBG-003 空帳本灰屏（preset 可空＋FE 顯示選擇帳戶/儲存禁用）；DBG-004 檔案 DB 二次啟動崩潰（_migrate 冪等化：user_version 閘＋既有表偵測）；Release 流水線重構（單工作流串接＋冪等自癒——GITHUB_TOKEN 鏈式觸發失效為根因）；發佈格式（PM）：版本化檔名＋Inno Setup per-user exe（MSIX 撤回）＋DMG＋未簽名 IPA＋軟體內版本 dart-define；首次啟動播種（內建集＋現金，oplog 契約，PM 定案）；設定頁按原計畫屬 F07（PM）。60 測試全綠；v0.4.3/v0.4.4 發佈；本機 exe 預覽可用 | main | ✅（多 commit，v0.4.4 發佈中） |
| 2026-10-19 | **T-F01-FE 完成（@P0 6 情境 🔴→🟢）＋分支整理**：C8 紅（c8c8515：dsl §3 登記 8 句型＋App 骨架＋FE harness；feature 背景順序修正）→ C9-C14 綠：S1 預填（1115b52）、S2 對話框（46990a5）、S3 Sticky＋S4 返回（a47ae1d）、S5 時間選擇器（ee57ae0）、S6 復原（593df0f）；**Windows 實跑 6 情境全綠（12s）**；harness 三教訓（KeyedSubtree 隔離/^ 錨點/@P1 過濾）；非 F01 之 2 commits 拆分至 main（62bd646 opencode、6912b8e TR-9） | feature/F01-quick-entry | 🔵（情境全綠、待 PR 合併） |
| 2026-10-18 | **T-F01-BE 完成（8 情境 🔴→🟢）**：C1 紅（2618b13：dsl 登記＋BDD harness＋stubs；Undo 期望修正 1880 對齊 acceptance S1.8；dbml v0.3.1 settings key）→ C2-C7 綠：S1 時段/上一筆（6ec94af）、S2 商家（58ad00b）、S3 回退（dce4e9a）、S4 固定預設（24255eb）、S5 儲存事務（d045e12；S7 離線/S8 效能同）、S6 Undo 墓標（51a34cd）；57 測試全綠；opencode.json 修復（0d98087） | feature/F01-quick-entry | 🔵（BE 綠、FE 待、未合併） |
| 2026-10-18 | **遷移完成＋DBG-002-① 根治驗證**：repo 移至 `E:\opencode\finora`；還原誤刪 `opencode.json`；刪舊 junction；`flutter clean` 清舊 CMakeCache（含舊路徑絕對路徑）後 `dart analyze`／56 測試／Windows Release 建置（81.9s）全數直接通過；README §3.2、debug.md 回寫「已遷移／根治」 | main | ✅ |
| 2026-10-18 | **休息交接**：使用者將遷移資料夾至英文路徑（根治 DBG-002-①）；§3 已寫入遷移後驗證與 M1 接續步驟 | main | 休息前 ✅（工作區乾淨、56 綠燈） |
| 2026-10-18 | **本地測試部署版**：Windows Release 建置實測 → DBG-002（①路徑非 ASCII 使 MSBuild 失敗 → ASCII clone `finora-build` 建置 ②secure_storage 需 ATL → TR-8 移至 M2）→ 建置成功（17.7s）＋**啟動冒煙通過**（行程存活 8s/127.7MB）→ 打包 `dist/LedgerSync-v0.2.0-windows-x64-local-test.zip`（11.7MB）＋tool/package_windows.ps1；techstack v0.3.3 | fix/TR-8-windows-build → main | ✅（5db6c26 / merge f8db9a5） |
| 2026-10-18 | **S0 完成**：T-H3 雲端 adapter（雙裝置拓撲：每裝置各自本地 SQLite＋雲端檔案交換 OpBundle 契約）、T-H4 通知 spy、T-H5 標準資料集、T-H6 發票測資＋deflate/Base32 編碼器、T-H7 Gherkin runner（解析/背景/Outline/標籤過濾）、T-H8 FE 掛鉤（M1 啟用）、T-H9 truth 對齊測試上 CI；版本 bump 0.2.0+1 → **tag-on-main 自動建立 v0.2.0 並觸發 release** | feature/T-H-helpers-2 → main | ✅（39be197 紅 / f803eb2 綠 / e669783 bump / merge 6509a4a / tag v0.2.0） |
| 2026-10-18 | **遠端上線＋S0 開跑**：接 origin（hung214/finora）push main；T-H1 記憶體 DB fixture（sqlite3 2.9.4 直連 schema v1 對齊 data-spec.dbml）＋T-H2 Clock（單一時間來源）→ **33 測試綠**；新增需求落地：tag-on-main 自動 v 標籤＋release 四平台工作流（Android/Windows/macOS/iOS→GitHub Release）；TR-7（drift 工具鏈不相容，過渡 sqlite3）＋DBG-001 結案；techstack v0.3.2；**tag v0.1.0 已推送觸發 release** | feature/T-H-test-helpers → main | ✅（9622009 紅 / b557029 綠 / 1d7a463 ci / merge b658329 / tag v0.1.0） |
| 2026-10-18 | **UI Demo 畫廊**：7 畫面（總覽/明細/快記＋每筆確認/預算/信用卡/分類設定/設定同步）＋深淺色切換（DemoThemeScope）；新增 09 分類設定 HTML 雛型；品牌名虛構化 27 檔（全家→陽光、富邦卡→示例卡、悠遊卡→票證卡等，版權考量）；README 授權聲明；analyze 零問題、21 測試綠 | feature/ui-demo-gallery → main | ✅（89571c9 / 01a295c / merge bcd4ee5） |
| 2026-10-18 | S0 骨架：flutter create 四平台（116 檔）、pubspec 對齊 techstack、Money/HLC/Balance + 21 測試全綠、dart analyze 零問題、BDD feature 同步（tool/sync_features.ps1）、CI workflow、README；truth v0.3.1 實鎖版本回寫（SQLCipher EOL → TR-6） | main | 骨架 ✅（commit 96bca5f / 8430b03） |
| 2026-10-18 | 規劃文件集 v0.3 完成：SPEC/SDD/BDD、acceptance×11、research、ui×9、tests（FE48/BE62+dsl）、truth×3、tasks、`/system-analysis` 指令 | main | 規劃 ✅（commit 4a6eebd） |
