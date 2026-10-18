# Session 工作交接（session.md）

| 項目 | 內容 |
|---|---|
| 用途 | **休息／中斷工作前**記錄當前進度，下次開工快速恢復；配套規範見 `specs/plan/tasks.md` §0 |
| 原則 | ①離開前必填「目前快照＋下一步」②狀態同步回 `tasks.md` §6（🔴/🟢/🔵/✅）③工作變更必先 commit（或明確標註 WIP 原因） |

---

## 1. 休息前檢查清單（離開前逐項確認）

- [x] 當前情境的紅/綠燈狀態已記錄（§2 快照表）
- [x] `tasks.md` §6 對應任務狀態已回寫（本次：骨架類工作，非 T-H/Fxx 情境）
- [x] 工作區已 commit（`git status` 乾淨）
- [x] truth 對齊：techstack v0.3.1 已回寫實鎖版本；T-H9 自動化測試尚未實作（S0 後續任務）
- [x] 「下一步」精確到：打開哪個檔案、做哪個情境、預期燈號
- [x] 若有進行中 Debug：`specs/plan/debug.md` 條目狀態已更新（無進行中條目）

## 2. 目前快照（每次休息前更新此表）

| 欄位 | 內容 |
|---|---|
| 更新時間 | 2026-10-18 |
| 階段 | **本地測試部署版完成**（Windows x64 Release，啟動冒煙 ✅，zip 11.7MB 於 `dist/`）；S0 ✅、M0 ✅；下一步 M1-F01 |
| 當前分支 | main（`f8db9a5` fix/TR-8 已合併推送）；tag：v0.1.0、v0.2.0（release 工作流） |
| 當前任務 | 完成：本地部署建置實測 → 發現並結案 **DBG-002**（①路徑非 ASCII → ASCII clone 建置 ②flutter_secure_storage 需 ATL 元件 → TR-8 移至 M2）；tool/package_windows.ps1 打包腳本 |
| 紅綠燈狀態 | `flutter test` = **56 全綠**；`dart analyze` = No issues found!；**Windows Release 建置成功＋啟動冒煙通過**（行程存活 8s、127.7MB） |
| 工作區 | 乾淨（session.md 本次更新後 commit＋push） |
| truth 對齊 | techstack **v0.3.3**（TR-8：secure_storage/local_auth 移至 M2 回歸）；T-H9 對齊測試持續把關 |
| 環境筆記 | ⚠️ **路徑非 ASCII 是硬傷**：原生建置必須在 ASCII 路徑（clone 副本 `C:\Users\hung2\AppData\Local\Temp\opencode\finora-build`；**建議長期把 repo 移至 `E:\opencode\finora`**）。⚠️ TR-6 SQLCipher EOL、TR-7 drift 暫緩。**執行注意：M0 為記憶體 DB，資料不持久化（重啟清空）——M1 接檔案 DB** |
| 阻塞／待決 | ①**建議：repo 遷移至 ASCII 路徑**（根治建置問題，待使用者決定）②v0.2.0 GitHub release 四平台結果確認 ③SP-1 SQLCipher EOL（M1 前）④PM 簽核 UI Demo／文件集 |

## 3. 下一步（精確到檔案與動作）

1. 開分支 `feature/T-H-test-helpers`（S0 共用測試模組）。
2. 🔴 T-H1 記憶體 DB fixture：寫 `test/helpers/db_fixture_test.dart`（含 drift v1 schema 基礎：accounts/categories/transactions/oplog/settings/templates，對齊 `specs/truth/data-spec.dbml`）→ 確認紅燈。
3. 🟢 實作 fixture（`test/helpers/db_fixture.dart`）→ 🟢；同輪做 T-H2 fake clock（可先抽 `lib/core/clock.dart`）。
4. 依 `specs/plan/tasks.md` §2 順序推進 T-H3~H9（T-H9 truth 對齊測試上 CI）。
5. S0 出口：Helper 全綠 → 開 `feature/F01-quick-entry` 進 M1（tasks.md §4.0 SOP）。

## 4. 恢復工作 SOP（下次開工照此執行）

1. 讀本檔「目前快照」與「下一步」。
2. `git status` + `git branch --show-current` 確認分支與工作區。
3. 跑 `dart analyze`（注意環境筆記）與 `flutter test` 確認燈號與快照一致。
4. 不一致 → 以測試實際狀態為準並修正本檔，再繼續。
5. 從「下一步」第 1 項繼續；完成一個情境即 commit 一次。

## 5. 歷程記錄（append-only，新在上面）

| 日期 | 摘要 | 分支 | 狀態 |
|---|---|---|---|
| 2026-10-18 | **本地測試部署版**：Windows Release 建置實測 → DBG-002（①路徑非 ASCII 使 MSBuild 失敗 → ASCII clone `finora-build` 建置 ②secure_storage 需 ATL → TR-8 移至 M2）→ 建置成功（17.7s）＋**啟動冒煙通過**（行程存活 8s/127.7MB）→ 打包 `dist/LedgerSync-v0.2.0-windows-x64-local-test.zip`（11.7MB）＋tool/package_windows.ps1；techstack v0.3.3 | fix/TR-8-windows-build → main | ✅（5db6c26 / merge f8db9a5） |
| 2026-10-18 | **S0 完成**：T-H3 雲端 adapter（雙裝置拓撲：每裝置各自本地 SQLite＋雲端檔案交換 OpBundle 契約）、T-H4 通知 spy、T-H5 標準資料集、T-H6 發票測資＋deflate/Base32 編碼器、T-H7 Gherkin runner（解析/背景/Outline/標籤過濾）、T-H8 FE 掛鉤（M1 啟用）、T-H9 truth 對齊測試上 CI；版本 bump 0.2.0+1 → **tag-on-main 自動建立 v0.2.0 並觸發 release** | feature/T-H-helpers-2 → main | ✅（39be197 紅 / f803eb2 綠 / e669783 bump / merge 6509a4a / tag v0.2.0） |
| 2026-10-18 | **遠端上線＋S0 開跑**：接 origin（hung214/finora）push main；T-H1 記憶體 DB fixture（sqlite3 2.9.4 直連 schema v1 對齊 data-spec.dbml）＋T-H2 Clock（單一時間來源）→ **33 測試綠**；新增需求落地：tag-on-main 自動 v 標籤＋release 四平台工作流（Android/Windows/macOS/iOS→GitHub Release）；TR-7（drift 工具鏈不相容，過渡 sqlite3）＋DBG-001 結案；techstack v0.3.2；**tag v0.1.0 已推送觸發 release** | feature/T-H-test-helpers → main | ✅（9622009 紅 / b557029 綠 / 1d7a463 ci / merge b658329 / tag v0.1.0） |
| 2026-10-18 | **UI Demo 畫廊**：7 畫面（總覽/明細/快記＋每筆確認/預算/信用卡/分類設定/設定同步）＋深淺色切換（DemoThemeScope）；新增 09 分類設定 HTML 雛型；品牌名虛構化 27 檔（全家→陽光、富邦卡→示例卡、悠遊卡→票證卡等，版權考量）；README 授權聲明；analyze 零問題、21 測試綠 | feature/ui-demo-gallery → main | ✅（89571c9 / 01a295c / merge bcd4ee5） |
| 2026-10-18 | S0 骨架：flutter create 四平台（116 檔）、pubspec 對齊 techstack、Money/HLC/Balance + 21 測試全綠、dart analyze 零問題、BDD feature 同步（tool/sync_features.ps1）、CI workflow、README；truth v0.3.1 實鎖版本回寫（SQLCipher EOL → TR-6） | main | 骨架 ✅（commit 96bca5f / 8430b03） |
| 2026-10-18 | 規劃文件集 v0.3 完成：SPEC/SDD/BDD、acceptance×11、research、ui×9、tests（FE48/BE62+dsl）、truth×3、tasks、`/system-analysis` 指令 | main | 規劃 ✅（commit 4a6eebd） |
