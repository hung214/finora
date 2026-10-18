# Session 工作交接（session.md）

| 項目 | 內容 |
|---|---|
| 用途 | **休息／中斷工作前**記錄當前進度，下次開工快速恢復；配套規範見 `specs/plan/tasks.md` §0 |
| 原則 | ①離開前必填「目前快照＋下一步」②狀態同步回 `tasks.md` §6（🔴/🟢/🔵/✅）③工作變更必先 commit（或明確標註 WIP 原因） |

---

## 1. 休息前檢查清單（離開前逐項確認）

- [ ] 當前情境的紅/綠燈狀態已記錄（§2 快照表）
- [ ] `tasks.md` §6 對應任務狀態已回寫
- [ ] 工作區已 commit（`git status` 乾淨）或 §2 已說明 WIP 原因
- [ ] truth 對齊測試（T-H9）最後一次執行為綠燈
- [ ] 「下一步」精確到：打開哪個檔案、做哪個情境、預期燈號
- [ ] 若有進行中 Debug：`specs/plan/debug.md` 條目狀態已更新（🔍/🔧）

## 2. 目前快照（每次休息前更新此表）

| 欄位 | 內容 |
|---|---|
| 更新時間 | 2026-10-18 |
| 階段 | M0 規劃：文件集 v0.3 完成，待 PM 簽核；尚未進入 S0 開發 |
| 當前分支 | （無開發分支；專案尚未 `git init`） |
| 當前任務 | 規劃類全數完成；下一個開發任務 = T-H1（記憶體 DB fixture） |
| 紅綠燈狀態 | 尚無測試（無 🔴/🟢） |
| 工作區 | 無未 commit 變更（所有規劃文件已完成並就緒） |
| truth 對齊 | techstack / api-spec / data-spec 均為 v0.3 初版，與規劃一致 |
| 阻塞／待決 | ①git 尚未 init ②PM 對文件集 v0.3 簽核 ③Google OAuth 送審材料（M5 前才需要） |

## 3. 下一步（精確到檔案與動作）

1. `git init` ＋ 首次 commit（全部規劃文件，`docs: v0.3 規劃文件集`）。
2. 開分支 `feature/T-H-test-helpers`（S0 共用測試模組）。
3. 🔴 T-H1 記憶體 DB fixture：先寫使用範例測試（`test/helpers/db_fixture_test.dart`），確認失敗。
4. 🟢 實作 fixture → 🟢 藍燈重構 → 回寫 `tasks.md` §6。
5. 依序 T-H2 → T-H9（見 `specs/plan/tasks.md` §2 順序）。

## 4. 恢復工作 SOP（下次開工照此執行）

1. 讀本檔「目前快照」與「下一步」。
2. `git status` + `git branch --show-current` 確認分支與工作區。
3. 跑對應 feature 檔的測試（BE：`flutter test test/bdd`；FE：`flutter test integration_test`）確認燈號與快照一致。
4. 不一致 → 以測試實際狀態為準並修正本檔，再繼續。
5. 從「下一步」第 1 項繼續；完成一個情境即 commit 一次。

## 5. 歷程記錄（append-only，新在上面）

| 日期 | 摘要 | 分支 | 狀態 |
|---|---|---|---|
| 2026-10-18 | 規劃文件集 v0.3 完成：SPEC/SDD/BDD、acceptance×11、research、ui×9、tests（FE48/BE62+dsl）、truth×3、tasks、`/system-analysis` 指令 | main（未 init） | 規劃 ✅，待 git init 與 PM 簽核 |
