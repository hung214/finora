# Session 工作交接（session.md）

| 項目 | 內容 |
|---|---|
| 用途 | **休息／中斷工作前**記錄當前進度，下次開工快速恢復；配套規範見 `specs/plan/tasks.md` §0 |
| 原則 | ①離開前必填「目前快照＋下一步」②狀態同步回 `tasks.md` §6（🔴/🟢/🔵/✅）③工作變更必先 commit（或明確標註 WIP 原因）④**本地部署驗證**：整體軟體所有測試寫完＋全量綠燈後做**一次**（非每個功能做完就部署；PM 2026-10-20 指示），通過才 push ⑤執行每個任務前列出 TASK/TODOLIST 讓 PM 可見（PM 2026-10-19 指示） |

---

## 1. 休息前檢查清單（離開前逐項確認）

- [x] 當前情境的紅/綠燈狀態已記錄（§2 快照表）
- [x] `tasks.md` §6 對應任務狀態已回寫（本次：**M7 完成**——F08 ✅ F09 ✅ 併入 main d8dd684＋tag v0.4.10；FE 回歸 9/10＋部署驗證通過）
- [x] 工作區已 commit（`git status` 乾淨）；分支已 push
- [x] truth 對齊：techstack v0.3.7；data-spec v0.3.2；dsl v1.5；T-H9 對齊測試（95 綠內）持續把關
- [x] 「下一步」精確到：F07-FE 回頭清單、harness 補步、分支名（§3）
- [x] 若有進行中 Debug：`specs/plan/debug.md` 條目狀態已更新（DBG-001~006 均結案）

## 2. 目前快照（每次休息前更新此表）

| 欄位 | 內容 |
|---|---|
| 更新時間 | 2026-10-21（**M7 完成**併入 main——v0.4.10 已 tag；95 unit 綠） |
| 階段 | **M7 完成**（F08 App 鎖 BE 4＋FE 5＋F09 資料管理 BE 3＋FE 2＋效能複測＋UI 統整 全綠——merge d8dd684；**v0.4.10 已 tag** 四平台建置中、部署驗證通過）。**M1~M7 全數完成**。剩：**F07-FE 回頭（M5 收尾）**＋acceptance 走查簽核＋Google OAuth/DriveAdapter 生產接線＋首次啟動引導頁決策 |
| 當前分支 | **main**（d8dd684 已 push；功能分支已清——T-F08 本地刪除、遠端從未 push；遠端已無 T-F07 分支——gh 阻塞項解除） |
| 當前任務 | 下輪：①**F07-FE 回頭**（S1 卡點深查→S3-S6 逐一補驗→**harness 導航補步** app-settings→settings-sync→SettingsSyncPage）②Google OAuth 送審＋GoogleDriveAdapter 骨架（**F07 生產接線**：main() 三 provider 未 override）③acceptance 走查簽核（F08/F09 簽核區＋PM 深色走查）④首次啟動引導頁決策（PM） |
| 紅綠燈狀態 | main 上 `dart analyze` 0＋**unit 95 全綠**；FE：逐檔回歸 9/10 綠（f07-FE 已知暫停紅）；M7 部署驗證 ✅（Release 48.0MB＋Info.plist 0.4.10＋二次啟動 DBG-004 回歸＋RSS 137.5MB＋乾淨退出） |
| 工作區 | 乾淨（文件回寫後 commit） |
| truth 對齊 | techstack v0.3.7；dsl **v1.5**（F09-FE +13 句型——三重防護/加驗身分；v1.4 F09-BE +15）；data-spec v0.3.2；acceptance F03 測資字串修正仍待 PM 複核 |
| 環境筆記 | 延續上輪全部。新增（M7）：①**F07-BE afterSave 接線（c7bd625）使 F01/F02/F03-FE harness 未 override `syncCoordinatorProvider` 即紅**——`ref.read(autoSyncProvider)` 建構即拋（不分 sync.mode，「批次預設 no-op 安全」假設不成立）；**新 harness 一律 override**（附註「啟動同步鉤子防 UnimplementedError」）②**磁碟滿重演**（lipo no space→`flutter clean` 清 8.3GB——第二次發生，平日注意）③**設定入口已恢復**：總覽 AppBar `app-settings`→`SettingsHubPage`（Hub 雙入口 settings-sync／settings-data-management）——**f07 harness 導航需補一步**④WipeService cloud 參數改**可選 named**（未連雲端頁面層無須注入 adapter）⑤ColorScheme token 替換後 F05-FE 色斷言仍相容（token 值＝Colors.red/orange 恆等——決策 A） |
| 阻塞／待決 | ①gh 未安裝（v0.4.10 Release 下載驗證；**F07 遠端分支已不在——原阻塞解除**）②acceptance F03 測資字串修正待 PM 複核③SP-1 SQLCipher④SP-2b mobile_scanner 行動相機（F03 走查前）⑤SP-4 Argon2id（F08 PIN 雜湊現為 FNV 最小實作——TODO 已標）⑥多幣別 900 待 PM⑦notify_enabled=off 語意待 PM⑧**Google OAuth 送審＋DriveAdapter 骨架**（PM 憑證申請並行）⑨**NFR-03 規格未定義**（research.md 提及無出處——效能複測漏項）⑩**首次啟動引導頁（新建/還原/匯入）決策**（F09 完成頁文案承諾但實際首啟自動播種——PM 決策）⑪深色模式 PM 走查（UI 統整決策 C） |

## 3. 下一步（PM 決策：F07-FE 回頭＝M5 收尾；回頭清單見 §3.1）

### 3.1 F07-FE 回頭清單（恢復時照此）
0. **harness 導航補步**（M7 新增）：`_openSettingsSync` 須補一步——`app-settings` → `settings-sync`（SettingsHubPage）→ 斷言 SettingsSyncPage；M7 設定入口已恢復為 Hub 兩層。
1. **卡點**：S1「同意授權」tap 時 oauth-approve 0 widgets——但 DEBUG（tap 前）approve=true/signin=true——**兩行之間按鈕消失**＝frame/rebuild 競爭（_linking 態被翻回 false——疑似 syncAccountProvider/pendingOps 的 provider 重建或 State 重建）。**深查方向**：`tester.allWidgets` dump 比對／暫停 pumpAndSettle／檢查 `SyncAccountNotifier.build` 的 `ref.watch(dbProvider)` 是否因 afterSyncRefresh 的 refresh 鏈重置。
2. **已完成待驗**：S3 修至 lastSyncAt=09:00 正確（Clock 單一來源）——斷言「上次同步 今天 09:00」未重驗；S4/S5/S6 未驗。
3. **已修的環境/缺陷**（已 commit）：macOS **NSAppSleepDisabled**（App Nap 節流——PM 觀察「點視窗才動」根因；測試提速 10 倍）／SyncCoordinator **重入閘**（啟動×手動併發防護）／afterSyncRefresh 改 Clock.now()（T-H2 單一時間來源）／seedTx 勿重複 appendOp。
4. 剩餘：S4 還原/S5 異帳號/S6 衝突檢視 綠燈→FE 全綠→M5 收尾（部署驗證＋merge）。

### 3.2 優先順序（建議，待 PM 指定）
1. **F07-FE 回頭**（M5 收尾）——最大未完項；相依 Google OAuth 送審＋DriveAdapter。
2. **Google OAuth 送審＋GoogleDriveAdapter 骨架**（commercialization.md §4-#9）——F07 生產接線：`main()` 目前未 override `cloudAdapterProvider`／`oauthProvider`／`syncCoordinatorProvider`（雲端功能正式包仍為 seam 狀態，上線前必須接）。
3. **acceptance 走查簽核**：F08/F09 簽核區空白——QA 走查＋PM 複核（含 SP-2b 行動相機 F03 前置）；深色模式 PM 走查。
4. **v0.4.10 Release 確認**：tag 已建立、四平台建置中——產物齊全＋下載驗證。

### 通用 harness/UI 教訓（跨功能累積，持續生效）
- **新 harness 一律 override `syncCoordinatorProvider`**（F07-BE afterSave 接線——`ref.read(autoSyncProvider)` 建構即拋，不分 sync.mode）。
- CreditCardPage 開頁副作用：initState postFrameCallback 觸發結帳檢查（FR-C3 sync 點）——勿在 build 中 ref.read/invalidate。
- 推入路由後主殼 offstage：harness 跨頁斷言前先 `navigator.maybePop()`。
- 金額輸入千分位：parse 須 `replaceAll(',', '')`。
- dsl 變體先於 base 註冊（lazy 前綴碰撞）；同名捕獲群禁用（{n} 出現兩次→後者改 {last}）。
- 測試勿對 UUIDv7 字典序順序斷言（DBG-005）；flaky 排查先落盤再循環重跑。
- 「flutter test integration_test」多檔併跑不可行（macOS 多 app instance 掛 debug connection）——**逐檔跑**。

## 4. 恢復工作 SOP（下次開工照此執行）

1. 讀本檔「目前快照」與「下一步」。
2. `git status` + `git branch --show-current` 確認分支與工作區。
3. 跑 `dart analyze`（注意環境筆記）與 `flutter test` 確認燈號與快照一致。
4. 不一致 → 以測試實際狀態為準並修正本檔，再繼續。
5. 從「下一步」第 1 項繼續；完成一個情境即 commit 一次。

## 5. 歷程記錄（append-only，新在上面）

| 日期 | 摘要 | 分支 | 狀態 |
|---|---|---|---|
| 2026-10-21 | **M7 完成：F08 App 鎖＋F09 資料管理＋效能複測＋UI 統整併入 main＋v0.4.10**：F08-BE 4/4（AppLockController 門檻邊界/生物辨識退場/PIN 重設——無繞過方法）＋F08-FE 5/5（LockGate lifecycle 鎖定閘＋LockScreen／忘記 PIN 重設資料零損失／隱私遮蔽 ●●●●＋pumpBackground）；**F09-BE 3/3**（WipeService 本地全表清空＋附件＋雲端 LedgerSync/ 全刪＋CloudWipedException＋**不復活閘修復**：正式路徑全走 sync()，_ensureVault 先重建 vault 致復活（S9.2 #5 Critical）——device.ever_synced 旗標（pull 成功後武裝；bootstrap 亦武裝）＋vault 缺→sync() 直接拋；首次連結不誤判＋2 回歸測試）＋**F09-FE 2/2**（DataManagementPage 狀態機：警告/PIN/確認文字＋已連雲端加驗身分「帳號不符拒絕」＋「已清空」）；dsl v1.2~v1.5；**UI 統整（PM 簽核三決策）**：`app_theme.dart` AppTokens 定稿（danger=Colors.red／warning=Colors.orange 恆等 F05-FE 斷言＋success/pending/subText/divider/track/cardBg/bg 深淺雙組）＋ad-hoc 10 處清零＋空狀態（overview 尚無帳戶／stats 尚無資料）＋無障礙盤點（6 IconButton 皆 tooltip＝Semantics 合規）＋**設定入口恢復（SettingsHubPage 雙入口——PM 決策含雲端同步）**；**harness 修復**：F01/F02/F03 補 `syncCoordinatorProvider` override（F07-BE afterSave 接線之潛在紅——M5 起未跑未被發現；「批次 no-op 安全」假設不成立）；**效能複測**（儲存 P95 0ms／10 萬筆聚合 378ms／OCR<3s；NFR-03 規格未定義待 PM）；**磁碟滿重演**（flutter clean 8.3GB）；FE 回歸逐檔 9/10 綠（f07 已知暫停）；**部署驗證通過**（Release 48.0MB＋Info.plist 0.4.10＋二次啟動 DBG-004 回歸＋RSS 137.5MB）→merge d8dd684→**tag v0.4.10 自動建立**（四平台建置中）；95 unit 綠＋analyze 0 | main | ✅（M7 完；F07-FE 回頭＋驗收走查待） |
| 2026-10-21 | **M6 完成：F06 定期交易（BE 5＋FE 4）併入 main＋v0.4.9**：dsl v1.0/v1.1（BE +19＋FE +9 句型）；**RecurringService**（到期檢查：日粒度判定＋N-7 千分位＋reminder≥3 暫停；確認 source=recurring 不回寫模板＋monthly next_due clamp 月底＋reminder 歸零；跳過推進；軟刪墓標）＋RecurringRow CRUD＋oplog 契約；**RecurringQueuePage**（全活躍排程：到期項操作/非到期「下期 M/d 提醒」/paused 標示）＋明細 badge 恆顯示＋RecurringDueCountNotifier；**F06-BE 5/5＋FE 4/4 全綠**（修 5：日粒度到期/無尾綴變體/recurringById 排除墓標/前綴碰撞 S5 觸發版/短格式日期 regex）＋NSAppSleepDisabled（App Nap 節流修——PM 觀察）；**設定入口暫移**（F07-FE WIP 隔離——main 可發佈性）；部署驗證通過（Release 47.7MB＋0.4.9＋二次啟動）→merge e4cbd63→**tag v0.4.9**；95 unit 綠 | main | ✅（M6 完；M5-FE 回頭＋M7 待開） |
| 2026-10-21 | **F07-FE WIP 暫停（PM 決策：跳過先做其他）**：dsl v0.9（FE +24 句型）＋harness 24 句型（帳號空間 adapter 異帳號語意＋fake OAuth seam）＋**SettingsSyncPage**（連結兩步授權/立即同步「同步中…→已同步 N 筆」/待同步計數/上次同步/衝突入口/從雲端還原）＋SyncConflictsPage＋cloudAdapter/oauthProvider seam；**S1/S2 綠、S3 修至 lastSyncAt=09:00 正確（afterSyncRefresh 改 Clock.now()——T-H2）**；卡點＝S1 approve tap 時 0 widgets（DEBUG 可見→frame/rebuild 競爭，待深查）；**PM 觀察「點視窗才動」→根因 macOS App Nap 節流——NSAppSleepDisabled 修復（測試提速 10 倍）**；SyncCoordinator 重入閘（啟動×手動併發防護）；90 unit 綠；**commercialization.md v0.1**（Google 憑證申請 PM 動作⚠️＋付費四模式＋行動清單） | feature/T-F07-cloud-sync | 🔵（F07-FE WIP 暫停；BE 已完；90 unit 綠） |
| 2026-10-21 | **M5 開工：T-F07-BE 10 情境全綠＋schema v5 落地**：truth dbml v0.3.2（sync_entity 補 income_goals——F07 護欄先行）＋dsl v0.8（BE +29 句型）；**schema v5**（sync_events 提前隨 F07/M5 衝突事件＋recurring_transactions 表一次到位；T-S5 前段；回歸 3 測＋既有「現行版本」斷言 4→5 維護）；**SyncCoordinator**（vault/devices/ops/blobs 佈局＋pull cursor 套用＋push 打包/manifest/vault 補錄＋附件 Wi-Fi 分流）＋**BundleApplier**（LWW＋衝突 sync_events＋N-8）＋**BackupService**（每日快照 JSON＋AES-GCM 檔案密碼（錯誤密碼拒絕）＋GC 保留份數）＋AutoSyncService（sync.mode 分流接 afterSave）；**綠燈過程修 6 處**（list 相對路徑 vs download 全路徑×2／帳戶 op 基線 packed／衝突事件雙重 insert／spy 斷言全裝置計數／{選項} 中文佔位 runner 不轉（→{option}）／Outline 單數 op 變體）；90 unit 全綠 | feature/T-F07-cloud-sync | 🔵（BE 🟢 10/10；FE 6 情境待開工） |
| 2026-10-21 | **M4 完成：F03 發票掃描 FE 6/6＋併入 main＋v0.4.8**：T-F03-FE 🔴→🟢 逐情境（掃描雙入口 scan-entry＋ScanPage 狀態機（權限閘「請求/拒絕→前往設定開啟權限」不離開 App＋已掃計數＋縮圖列＋完成掃描）＋ReviewPage（總額一律人工檢視 0/空擋下、低信賴高亮「請確認日期」＋已確認、ChoiceChip 分類/帳戶、「n / N」逐張跳、source=scan＋附件落地）＋ImportPage（匯入管線 seam）＋MainShellPage ⌘⇧S 快捷鍵＋TxTile 📷）；**pressShortcut T-H8 落地**（組合鍵注入）；**DBG-006 結案**（f01 殼相依 finder——macOS NSWindow autosave frame 漂移跨實例共享致 Rail 殼，nav 改 byKey 雙殼相容）；**FE 回歸 6/6 全綠**（macOS 逐檔——併跑多 instance 會掛 debug connection，須逐檔）；FE 全綠→bump 0.4.8→**M4 部署驗證通過**（Release 47.6MB＋Info.plist 0.4.8＋二次啟動無崩潰）→`--no-ff` merge（69fd736）→push main→**tag v0.4.8 自動建立**（四平台 Release 建置中）→分支已刪；main analyze 0＋unit 86 全綠 | main | ✅（M4 完；M5 雲端同步待開——truth PR 補 income_goals 先行） |
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
