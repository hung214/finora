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
| 階段 | M0 骨架完成（四平台可建置、21 測試綠燈）；S0 Helper 尚未開始 |
| 當前分支 | main（`8430b03`）；最近：`96bca5f` feat(scaffold)、`4a6eebd` docs 規劃文件集 |
| 當前任務 | 已完成：專案骨架、核心模組（Money/HLC/BalanceCalculator）、BDD feature 同步（10+10）、CI、README、techstack v0.3.1 |
| 紅綠燈狀態 | `flutter test` = **21 全綠**（Money 7／HLC 8／Balance 6）；`dart analyze` 零問題 |
| 工作區 | 乾淨（session.md 本次更新後將 commit） |
| truth 對齊 | techstack v0.3.1（實鎖版本回寫）；api-spec/data-spec 未動；T-H9 自動對齊測試待建 |
| 環境筆記 | ⚠️ 專案路徑含非 ASCII（記帳）：`flutter analyze` 會崩潰 → **改用 `dart analyze`**，或透過 junction `C:\Users\hung2\AppData\Local\Temp\opencode\ledger_app` 執行 flutter 命令；`flutter test` 不受影響。⚠️ sqlcipher_flutter_libs 0.7.0+eol 已 EOL（research TR-6） |
| 阻塞／待決 | ①PM 對文件集 v0.3 簽核 ②SP-1 SQLCipher EOL 替代方案定案（M1 前）③Google OAuth 送審材料（M5 前） |

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
| 2026-10-18 | S0 骨架：flutter create 四平台（116 檔）、pubspec 對齊 techstack、Money/HLC/Balance + 21 測試全綠、dart analyze 零問題、BDD feature 同步（tool/sync_features.ps1）、CI workflow、README；truth v0.3.1 實鎖版本回寫（SQLCipher EOL → TR-6） | main | 骨架 ✅（commit 96bca5f / 8430b03） |
| 2026-10-18 | 規劃文件集 v0.3 完成：SPEC/SDD/BDD、acceptance×11、research、ui×9、tests（FE48/BE62+dsl）、truth×3、tasks、`/system-analysis` 指令 | main | 規劃 ✅（commit 4a6eebd） |
