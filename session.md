# Session 工作交接（session.md）

| 項目 | 內容 |
|---|---|
| 用途 | **休息／中斷工作前**記錄當前進度，下次開工快速恢復；配套規範見 `specs/plan/tasks.md` §0 |
| 原則 | ①離開前必填「目前快照＋下一步」②狀態同步回 `tasks.md` §6（🔴/🟢/🔵/✅）③工作變更必先 commit（或明確標註 WIP 原因）④**本地部署驗證**：整體軟體所有測試寫完＋全量綠燈後做**一次**（非每個功能做完就部署；PM 2026-10-20 指示），通過才 push ⑤執行每個任務前列出 TASK/TODOLIST 讓 PM 可見（PM 2026-10-19 指示） |

---

## 1. 休息前檢查清單（離開前逐項確認）

- [x] 當前情境的紅/綠燈狀態已記錄（§2 快照表）
- [x] `tasks.md` §6 對應任務狀態已回寫（本次：首次啟動播種 ✅、發佈格式定案 v0.3.6、DBG-003/004 結案、設定頁按原計畫屬 F07）
- [x] 工作區已 commit（`git status` 乾淨）；交接快照已推 `session/handoff` 分支（跨電腦接手）
- [x] truth 對齊：techstack v0.3.6；data-spec v0.3.1；T-H9 對齊測試（60 綠內）持續把關
- [x] 「下一步」精確到：F02 規範檔案、情境清單、分支名（§3）
- [x] 若有進行中 Debug：`specs/plan/debug.md` 條目狀態已更新（DBG-003/004 均 ✅ 結案）

## 2. 目前快照（每次休息前更新此表）

| 欄位 | 內容 |
|---|---|
| 更新時間 | 2026-10-20（macOS 跨電腦接手） |
| 階段 | **M1 完成並發佈中**（v0.4.5 tag 已自動建立，四平台建置中）＋**T-S2 schema v2 完成**（73 測試全綠，已合併 main）。下一步：**T-F05 預算 BE→FE**（新分支 `feature/F05-budget-income-goal` 自 main 切；設計筆記見阻塞⑤⑥）→ T-F10 報表 |
| 當前分支 | main = ea23a92（F02＋T-S2 均已合併；v0.4.5 冪等未重複觸發） |
| 當前任務 | 本輪：①F02 bump 0.4.5＋merge main（tag v0.4.5 自動建立）②T-S2 schema v2 🔴→🟢（budgets/income_goals/fts 容錯降級＋_migrate 多版本鏈 v1→v2＋T-H9 對齊 v1/v2＋回歸 4 測試：e23b795→bc82a6f） |
| 紅綠燈狀態 | `dart analyze` No issues；unit **73 全綠**（69＋schema v2 回歸 4）；F02-FE 5 情境＋F01-FE 回歸 7 情境全綠（macOS 實跑） |
| 工作區 | 乾淨（文件回寫後 commit） |
| truth 對齊 | data-spec.dbml v0.3 **不變**（budgets/income_goals/fts 早已預定義——T-S2 為 code schema 對齊落地）；dsl v0.5；techstack v0.3.6 |
| 環境筆記 | 延續上輪（rootBundle 資產／句型前綴碰撞／tag 過濾／macOS 800×760／TextInputType.none）。新增：①gh **未安裝**於本 Mac——PR/壞包刪除須 PM 手動或安裝 gh ②FTS5 容錯：winsqlite3.dll 可能缺模組——v2 遷移 try-catch 跳過，F10 依表存在性分流（LIKE）③「T-S1 schemaVersion=1」斷言已隨 T-S2 更新為 2（db_fixture_test.dart）④CI 測試在 ubuntu（FTS5 齊全）；release 環境用 bundled sqlite3（齊全） |
| 阻塞／待決 | ①gh 安裝＋登入（PR 與壞包 v0.4.0/0.4.2 刪除）②SPEC FR-Q4 待 PM ③SP-1 SQLCipher（DB 明文）④多幣別「餘額 900」矛盾待 PM 釋義（M2 尾）⑤**T-F05 設計決策（已推導，待實作）**：通知為「冪等 sync 點」——BudgetAlertService.sync(db) 於 SaveTransactionUseCase 記帳後＋通知斷言 Then 前置呼叫。依據：S5.1 要 N-1 內容=87.5%（⇒ 6500 seed 期不得評估，N-1 於 7000 首發）；S5.2 要 N-2 於 8000 期已發（⇒ sync 補發分級 N-1/N-2/N-3 各一次）。去重狀態存 settings `budget.notif_state`（JSON per period——週期切換自然重置）；預算用量＝本期分類 expense **含 pending 預扣**；SaveTransactionUseCase 需加 settlementStatus 參數（S5.3 示例卡預扣）⑥週期邊界：period_start_day → 本期起訖（S5.6：起始日 25 → 5/25~6/24，跨月計算） |

## 3. 下一步（T-F05 預算 BE→FE；下次開工照此執行）

1. **開分支** `feature/F05-budget-income-goal`（自 main ea23a92）。
2. **讀規範**：acceptance F05（S5.1~S5.7）＋backend/frontend F05 feature＋上表⑤⑥設計筆記＋T-H4 notification spy（test/helpers/notification_spy.dart）＋NotificationService（lib/application/notifications/notification_service.dart）。
3. **dsl §2 登記新句型**（先登記再綁定）：`Given 頄算總額 {amt}、起始日 {day}`、`Given 本期{cat}已支出 {amt}`、`Given 本月已入帳收入 {amt}`、`When 以「{card}」記錄支出 {amt}（{cat}，預扣）`（variant）、`Then 通知 spy 收到 N-{n} 仍恰 {k} 次（不重複）`、`Then {cat}頄算用量 = {amt}（含預扣）`、`And 頄算明細標記預扣部分 {amt}`、`Then 收入目標達標率 = {pct}%（已達成）`、`And 本月預計結餘 = {amt}（{expr}）`、`Then 目前週期 = {start} ~ {end}`。
4. **BE 紅綠燈逐條**（5 情境，每情境 ≥1 commit）：BudgetPeriodService（週期計算）→ BudgetEvaluator（用量／達標率／預計結餘）→ BudgetAlertService.sync（N-1/N-2/N-3 冪等）→ SaveTransactionUseCase 加 settlementStatus＋記帳後 sync 鉤子。
5. **FE 紅綠燈**（5 情境：警示色、超支、預扣標籤、達成、通知開關）——預算頁＋總覽卡。
6. 完成後照規範：全綠＋部署驗證一次→ push→ PR（gh 裝好後）。
7. 休息前照 §1 檢查清單更新本檔。

## 4. 恢復工作 SOP（下次開工照此執行）

1. 讀本檔「目前快照」與「下一步」。
2. `git status` + `git branch --show-current` 確認分支與工作區。
3. 跑 `dart analyze`（注意環境筆記）與 `flutter test` 確認燈號與快照一致。
4. 不一致 → 以測試實際狀態為準並修正本檔，再繼續。
5. 從「下一步」第 1 項繼續；完成一個情境即 commit 一次。

## 5. 歷程記錄（append-only，新在上面）

| 日期 | 摘要 | 分支 | 狀態 |
|---|---|---|---|
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
