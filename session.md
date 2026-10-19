# Session 工作交接（session.md）

| 項目 | 內容 |
|---|---|
| 用途 | **休息／中斷工作前**記錄當前進度，下次開工快速恢復；配套規範見 `specs/plan/tasks.md` §0 |
| 原則 | ①離開前必填「目前快照＋下一步」②狀態同步回 `tasks.md` §6（🔴/🟢/🔵/✅）③工作變更必先 commit（或明確標註 WIP 原因） |

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
| 更新時間 | 2026-10-19 |
| 階段 | **M1-F01 完成＋四輪部署/缺陷修復＋首次啟動播種落地**（v0.4.4 發佈中）。App 本機與 Release 皆可預覽：總覽/明細/快記全流程可用（現金＋內建分類自動就緒）。下一步：**M1-F02 交易帳戶**（帳戶/分類管理 UI） |
| 當前分支 | main = e20c856（已推送）；v0.4.4 tag/release 管線進行中 |
| 當前任務 | 本輪：①DBG-003 空帳本灰屏修復（preset.account 可空）②DBG-004 檔案 DB 二次啟動崩潰（_migrate 冪等化：user_version 閘＋既有表偵測）③release 流水線重構（單工作流串接＋Release 冪等自癒）④發佈格式定案（版本化檔名＋Inno Setup per-user exe／DMG／未簽名 IPA；MSIX 撤回；軟體內版本 dart-define）⑤首次啟動播種（內建集＋現金，oplog 同交易契約）。**60 測試全綠** |
| 紅綠燈狀態 | `dart analyze` No issues；`flutter test` **60 全綠**；本機 exe 雙重啟動實測通過、DB 播種驗證通過（現金＋支出 4＋薪資） |
| 工作區 | 乾淨（文件回寫後 commit） |
| truth 對齊 | techstack v0.3.6（發佈格式定案；MSIX 撤回）；data-spec v0.3.1；debug.md DBG-003/004 結案；dsl.md BE 9＋FE 7 情境 |
| 環境筆記 | **Release 教訓**：①GITHUB_TOKEN 推標籤不觸發下游工作流→主徑改單工作流串接（Release 冪等自癒）②build job checkout 標籤——**標籤內容必須含打包腳本修復**（v0.4.2 標籤滯後→Inno 舊路徑錯誤；未發佈標籤已重打到 28565fc）③release.yml 後備（手動推標籤）亦未觸發——**main push 為唯一可靠觸發路徑**。**Inno 本機除錯**：`~\tools\innosetup671\ISCC.exe`（同 CI 6.7.1）＋`~\tools\innosetup7`（7.1.0）。FE 測試：`flutter test integration_test/features/f01_quick_entry_test.dart -d windows`（7 情境）。gh 已裝未登入 |
| 阻塞／待決 | ①v0.4.4 release 確認 ②v0.4.0/v0.4.2 壞包待刪（Releases 頁手動；gh auth 後可 CLI）③gh auth login ④SPEC FR-Q4 五段 vs 四段待 PM ⑤SP-1 SQLCipher（DB 明文）⑥F02 落地後檢視播種策略（保留/範例帳本）⑦**設定頁按原計畫屬 F07（M5-M6）**——FR-Q4 固定預設目前僅 BE 覆蓋無 UI，F07 設定頁補 |

## 3. 下一步（M1-F02 交易帳戶；下次開工照此執行）

1. **確認 release**：https://github.com/hung214/finora/actions 的 release 工作流（四平台）與 https://github.com/hung214/finora/releases 的 v0.4.0 產物。
2. **讀規範**：acceptance `F02_transactions-accounts.md`＋`specs/plan/tests/backend/F02_transactions-accounts.feature`（6 情境：金額驗證、轉帳守恆、儲值語意、軟刪除、還款、多幣別）＋truth 對齊項（tx_kind/settlement_status enum——data-spec 已有，確認 schema v1 覆蓋）。
3. **開分支** `feature/F02-transactions-accounts`，照 tasks.md §4.0：BE 情境逐條 🔴→🟢（每情境 ≥1 commit）→ FE（快記/明細擴充轉帳/收入/儲值/還款模式）。
4. gh auth login 後恢復 PR 流程（gh 已裝 2.102.0）。
5. 休息前照 §1 檢查清單更新本檔。

## 4. 恢復工作 SOP（下次開工照此執行）

1. 讀本檔「目前快照」與「下一步」。
2. `git status` + `git branch --show-current` 確認分支與工作區。
3. 跑 `dart analyze`（注意環境筆記）與 `flutter test` 確認燈號與快照一致。
4. 不一致 → 以測試實際狀態為準並修正本檔，再繼續。
5. 從「下一步」第 1 項繼續；完成一個情境即 commit 一次。

## 5. 歷程記錄（append-only，新在上面）

| 日期 | 摘要 | 分支 | 狀態 |
|---|---|---|---|
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
