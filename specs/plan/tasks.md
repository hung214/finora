# 開發任務分解（Tasks — 分割擊破）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.3（初版） |
| 定位 | 把 SPEC/SDD/BDD/acceptance/tests/truth 轉成**可執行的開發任務清單**：每個任務小到一個人一次紅綠燈循環可完成 |
| 輸入 | `research.md` §2（Sprint 計畫）、`specs/plan/tests/`（FE/BE feature 檔 + dsl.md）、`specs/truth/*` |
| 任務狀態標記 | ☐ 未開始 → 🔴 紅燈（測試已寫、失敗中）→ 🟢 綠燈（測試通過）→ 🔵 藍燈（重構中）→ ✅ 完成（對齊 truth 已驗證） |

---

## 0. 版控 / 檔名 / 格式規範

### 0.1 版本控制（Git）
| 規範 | 內容 |
|---|---|
| 分支 | trunk-based：`main` 永遠可發佈；**每個功能一條分支**：`feature/F{nn}-{slug}`（例：`feature/F04-credit-card-billing`，自 main 切出，完成後 merge 回 main）；S0 Helper 用 `feature/T-H-test-helpers`；修復分支 `fix/{issue}-{簡述}` |
| Commit | `type(scope): subject`，type ∈ feat/fix/test/refactor/docs/chore；scope 用 FR 或模組（例：`feat(FR-C2): billing boundary rule include/exclude`）。**粒度：每個情境紅綠燈循環至少一個 commit**（🔴 `test(dsl): F04-BE 結帳歸屬紅燈` → 🟢 `feat(FR-C2): …` → 🔵 `refactor: …`）；每個功能合併前至少含 T-Fxx-BE 與 T-Fxx-FE 各一個功能級 commit |
| PR | 標題必帶 FR/AC/情境 ID（追溯鍵）；描述需附：紅燈證據（失敗輸出）→ 綠燈證據（通過輸出）→ truth 對齊檢查清單（§5） |
| 合併 | P0 測試全綠才可合併；功能分支以 `--no-ff` merge 回 main（merge commit 帶 FR/AC，例：`Merge feature/F04-credit-card-billing (FR-C, AC-04/11)`），合併後刪除功能分支；truth 檔（specs/truth/*）變更須另外一個 PR 且由架構簽核（research §1.3 護欄） |
| Tag | **工作完整併至 main 時自動建立版本標籤並發佈**：tag-on-main workflow 讀 pubspec `version`（去 +build）→ `v{major.minor.patch}` 標籤（已存在則略過）→ 檢查 Release 是否已發佈（冪等）→ 缺則**同一工作流**建置 Android/Windows/macOS/iOS 並發佈 GitHub Release（⚠ 2026-10-19 修正：GITHUB_TOKEN 推標籤不觸發下游工作流——原鏈式設計從未生效，v0.1.0~v0.4.0 皆無 Release；`release.yml` 保留為手動推標籤之後備）。P0 把關由同 push 之 CI（analyze＋test）負責 |
| Session | 休息／中斷前：更新根目錄 `session.md`（快照＋下一步＋歷程）、回寫 `tasks.md` §6 狀態、確認已 commit；恢復工作依 `session.md` §4 SOP |
| 禁止 | force push main；跳過測試（--no-verify）合併；truth 與程式碼同 PR（先 truth 後碼） |

### 0.2 檔名格式
| 對象 | 規範 | 例 |
|---|---|---|
| Dart 原始碼/測試 | snake_case | `billing_cycle_service.dart`、`op_bundle_applier_test.dart` |
| Feature 檔 | `F{nn}_{slug}.feature`，與 `specs/plan/tests/{frontend,backend}/` **同名同步** | `F04_credit-card-billing.feature` |
| UI 雛型 | `NN-{名稱}.html` | `05-scan-review.html` |
| truth 檔 | **固定名稱不得改名**：`techstack.md` / `api-spec.yaml` / `data-spec.dbml` | — |
| 文件 | SPEC.md / SDD.md / BDD.md 為根目錄固定檔；規劃類放 `specs/plan/` | — |

### 0.3 內容格式
- Feature 檔：Gherkin 英文關鍵字＋繁中敘述、2 空格縮進（dsl.md §1）。
- Dart：`dart format` 為 CI gate；分析零警告（research §2.4）。
- 文件改動必帶版本號與修訂記錄（文件集以 v0.3 對應）。

---

## 1. 測試驅動開發：紅燈 → 綠燈 → 藍燈

每個情境（Scenario）都走一次三燈循環；**任務的最小單位 = 一個情境的一次循環**。

| 燈 | 動作 | 完成條件 | 禁止 |
|---|---|---|---|
| 🔴 **紅燈** | 從 `tests/{backend\|frontend}/Fxx.feature` 選一個情境 → 依 dsl.md 實作 step definitions → 執行**確認失敗**（因功能未實作） | 失敗原因 = 「功能不存在」，不是語法錯誤 | 先寫實作再補測試；跳過紅燈直接寫碼 |
| 🟢 **綠燈** | **最小實作**讓該情境通過（只求正確，不求優雅） | 該情境綠燈；同檔其他情境未被破壞 | 過度設計；為了綠燈改測試斷言 |
| 🔵 **藍燈** | 測試全綠後**重構**：命名、抽共用 helper、消除重複 | 綠燈保持；程式碼更簡潔 | 改變 truth（schema/API/stack）——若重構發現需要動 schema/API：**停止**，走 §3 truth 變更流程後回到紅燈 |

**循環外的紅燈（truth 驅動）**：若 schema/套件/API 變更需求先出現（例如 F04 需要新表），順序為：改 `data-spec.dbml`（PR）→ 寫 migration 與 schema 回歸測試（紅燈：舊 DB 無新表）→ migration 綠燈 → 才開始 feature 情境循環。

**對齊驗證**：每個 🔵 結束跑 `truth 對齊測試`（T-H9），確保碼與 truth 無落差（落差 = Blocker）。

---

## 2. 共用測試模組 HELPER（T-H，先於所有 Feature 開發）

> 位置：`test/helpers/`（BE）與 `integration_test/helpers/`（FE）；每個 Helper 自身也走紅綠燈（先寫使用範例測試）。

| 任務 ID | Helper | 內容 | 對應 dsl.md 掛鉤 | 狀態 |
|---|---|---|---|---|
| T-H1 | 記憶體 DB fixture | drift in-memory（測試關 SQLCipher）、每 Scenario 重建、seed API | BE Given「已重置記憶體資料庫」 | ☐ |
| T-H2 | Fake clock | 凍結/快轉時間（結帳日、預算週期、逾期、30 天還原） | 「模擬系統時間為 {dt}」 | ☐ |
| T-H3 | In-memory CloudStorageAdapter | list/upload/download/delete 假實作，可控成功/失敗/延遲/斷線 | BE「模擬雲端…」、FE @sync | ☐ |
| T-H4 | Notification spy | 攔截通知、斷言編號/內容/次數（N-1~N-10） | 「通知 spy 收到 N-{n} 恰 {k} 次」 | ☐ |
| T-H5 | 測試資料集 Builder | acceptance 前置條件一鍵建立（帳戶/分類/交易/預算/卡/定期） | 所有 Given 資料步驟 | ☐ |
| T-H6 | 發票測資 fixtures | 77 碼左 QR 字串、右 QR deflate+Base32 產生器、OCR 文字/圖片 fixtures | F03 BE/FE | ☐ |
| T-H7 | Gherkin Runner | BE：自製 runner 掛 flutter_test；FE：flutter_gherkin 設定（tag 過濾） | — | ☐ |
| T-H8 | FE 掛鉤 | lifecycle 模擬（背景秒數）、鍵盤/快捷鍵注入、截圖報告 | FE「App 切至背景」「Ctrl+N」 | ☐ |
| T-H9 | **truth 對齊測試** | ①schema snapshot ↔ `data-spec.dbml` 解析比對 ②pubspec 依賴版本 ↔ `techstack.md` §2；落差即紅燈 | §5 對齊清單的自動化 | ☐ |

---

## 3. 資料庫版本控制（Drift Migration）

### 3.1 規則
1. **單一事實來源**：schema = `specs/truth/data-spec.dbml`；drift schema 版本號 = dbml 變更序號。
2. 變更流程：改 dbml（獨立 PR）→ 產生 migration step → **schema 回歸測試**（紅燈：舊版 DB 升級後缺新表/資料遺失）→ 綠燈 → 更新 SDD §4.2 摘要。
3. 禁止：直接改 drift 表而不改 dbml；刪欄/改型不寫遷移；跳版本升級。
4. 每版必附「降級防護」：升級前自動保護備份（FR-Y10 語意）。

### 3.2 Schema 版本歷程（綁里程碑）

| 版本 | 里程碑 | 新增表 | 對應任務 |
|---|---|---|---|
| v1 | M1 | accounts、categories、transactions、oplog、settings、templates | T-S1 |
| v2 | M2 | budgets、income_goals、transactions_fts（FTS5 bigram 影子表，SP-1） | T-S2 |
| v3 | M3 | credit_card_details、statements、statement_items、refund_links、installment_plans | T-S3 |
| v4 | M4 | attachments（+ blobs 目錄約定） | T-S4 |
| v5 | M6 | recurring_transactions、sync_events | T-S5 |

> 註：credit_card_details 的 boundary_rule、statements 的 overdue_notified 等欄位隨 v3 一次到位（避免中途改欄）。

| 任務 ID | 環節 | 內容 | 狀態 |
|---|---|---|---|
| T-S1 | M1 migration | v1 建表 + schema 回歸測試（v0 空 DB → v1）＋ truth 對齊（T-H9 基線） | ☐ |
| T-S2 | M2 migration | v2 預算/FTS5 + bigram 寫入觸發器/服務邏輯 + 回歸測試（v1→v2 資料保留） | ☐ |
| T-S3 | M3 migration | v3 信用卡/帳單 + 回歸測試（既有交易 settlement_status 預設 none） | ☐ |
| T-S4 | M4 migration | v4 attachments + 回歸測試 | ☐ |
| T-S5 | M6 migration | v5 定期交易/同步事件 + 回歸測試 | ☐ |

---

## 4. Feature 依序開發（每個 feature 檔：BE → FE → 對齊）

### 4.0 標準作業順序（每個 Fxx 相同）
0. **開分支**：自 main 切出 `feature/F{nn}-{slug}`（一個功能一條分支，見 §0.1）。
1. **讀**：`acceptance/Fxx` ＋ `tests/frontend|backend/Fxx.feature` ＋ truth 相關段落（data-spec 對應表、techstack 套件）。
2. **BE 紅綠燈**：後端情境逐條 🔴→🟢→🔵（P0 先於 P1），每情境 ≥1 commit。
3. **FE 紅綠燈**：前端情境逐條（以 BE 為掛鉤，不重驗計算），每情境 ≥1 commit。
4. **對齊**：跑 T-H9 truth 對齊測試 + CI 全綠。
5. **PR／合併**：標題帶 FR/AC；附紅/綠證據；`--no-ff` merge 回 main；acceptance 手動情境（無法自動化部分）留給 QA 走查簽核。
6. **收尾**：`tasks.md` §6 該功能狀態改 ✅；休息或中斷前更新 `session.md`。

### 4.1 任務總表

| Feature | BE 任務（情境數） | FE 任務（情境數） | truth 對齊項 | 里程碑 | 狀態 |
|---|---|---|---|---|---|
| F01 快記 | T-F01-BE（8：智慧預設規則×4、儲存事務、Undo、離線、效能） | T-F01-FE（7：預填呈現、對話框、Sticky、完成、時間選擇器、復原、桌面快捷鍵） | settings key 命名（settings 表） | M1 | ☐ |
| F02 交易帳戶 | T-F02-BE（6：金額驗證、轉帳守恆、儲值語意、軟刪除、還款、多幣別）——**6/6 ✅**（多幣別照數學修：餘額 −2,200；fxRate 換算入 BalanceCalculator） | T-F02-FE（6：禁用態、轉帳樣式、儲值文案、最近刪除、拆分＋**S2.9 計算機鍵盤**）——**6/6 ✅**（executeSplit 總額守恆＋TxTile 拆分樣式） | tx_kind/settlement_status enum（✅ schema v1 覆蓋）；fx_rate（✅ TxRow/Tx/BalanceCalculator 換算） | M1/M2 | ✅ |
| F03 掃描 | T-F03-BE（7：QR 解析、明細合併、回退、OCR 信賴度、附件定址、離線、效能） | T-F03-FE（6：入口、權限、確認清單、高亮、連拍、桌面匯入） | attachments.sha256（blobs 約定）；測資 fixture=T-H6 | M4 | ☐ |
| F04 信用卡 | T-F04-BE（10：預扣、補算、歸屬 outline、clamp、繳款×2、提醒、逾期、分期、退款、生效日）——**🟢 12 情境執行全綠**（5 服務：BillingCycle/RepayStatement/NotificationCheck/Installment/Refund＋生效日） | T-F04-FE（5：帳單呈現、繳款流程、部分繳、設定顯示、逾期標示）——**🟢 macOS 全綠**（CreditCardPage＋CardSettingsPage＋總覽入口） | **schema v3**（T-S3 ✅）；boundary_rule enum | M3 | ✅（**M3 完成併入 main c1b52b0；v0.4.7 已 tag**：FE 回歸 4/4＋部署驗證通過（Release 47.4MB＋二次啟動）） |
| F05 預算 | T-F05-BE（5：閾值×2、含預扣、達標率、起始日）——**5/5 ✅**（BudgetAlertService 冪等 sync 點＋notif_state 去重） | T-F05-FE（5：警示色、超支、預扣標籤、達成、通知開關）——**5/5 ✅**（預算分頁＋總覽卡；FE 基線自洽修正 S1 7000/S2 8320） | **schema v2**（T-S2 ✅）；budgets/income_goals | M2 | ✅ |
| F06 定期交易 | T-F06-BE（5：到期提醒、確認不回寫、跳過、刪除、逾期暫停） | T-F06-FE（4：badge、清單、確認 UI、暫停標示） | **schema v5**（T-S5 先行） | M6 | ☐ |
| F07 雲端同步 | T-F07-BE（8：補同步、LWW、每筆模式、批次、附件分流、bootstrap、GC、備份密碼） | T-F07-FE（6：連結、立即同步、啟動同步、還原、異帳號、衝突檢視） | api-spec.yaml（P2 僅對照，不改）；oplog packed_seq | M5/M6 | ☐ |
| F08 App 鎖 | T-F08-BE（4：門檻邊界、退場狀態機、重設路徑×2） | T-F08-FE（5：鎖定畫面、10 秒、退 PIN、忘記 PIN、遮蔽） | lock.timeout key（settings） | M7 | ☐ |
| F09 資料管理 | T-F09-BE（3：本地清空、雲端清空、不復活） | T-F09-FE（2：三重防護、加驗身分） | 清空=雲端資料夾刪除契約 | M7 | ☐ |
| F10 報表 | T-F10-BE（5：占比、bigram 搜尋、AND 篩選、CSV、效能）——**5/5 ✅**（TextIndex bigram＋SearchService FTS 優先 LIKE 降級＋ReportService 0.1%＋CsvExporter BOM＋NFR-01 10 萬筆 387ms） | T-F10-FE（3：圖表呈現、複合篩選、匯出提示）——**3/3 ✅**（統計分頁＋明細篩選列 chips＋匯出提示；呈現以數值文字斷言，甜甜圈視覺屬打磨） | transactions_fts（v2 ✅）；CSV 欄位契約 | M2 | ✅ |

### 4.2 依序開發的排程（對應 research §2.2 Sprint）

```
S0  ：T-H1~H9（Helper 全數紅綠燈完畢）→ T-S1 基線 migration → truth 對齊測試上 CI
S1-2：T-S1 → T-F01(BE→FE) → T-F02(BE→FE)
S3-4：T-S2 → T-F05(BE→FE) → T-F10(BE→FE) → 桌面適配（F01-S1.11/F03-S3.9）
S5  ：T-S3 → T-F04(BE→FE)
S6-7：T-S4 → T-F03(BE→FE)
S8  ：F07 之 BE（備份/還原/GC）→ FE（連結/還原/狀態頁）→ Google OAuth 送審
S9-10：T-S5 → T-F07 其餘（同步/LWW）→ T-F06(BE→FE)
S11-12：T-F08 → T-F09 → 效能複測（NFR-01~03）→ 上架
  補充（PM 2026-10-20）：UI 統整留到 M7 上架前一次做——Material 3 tokens 定稿＋各頁視覺套用＋深色模式逐頁檢查＋無障礙/空狀態文案；不在各 milestone 中途做（現況各頁樣式 ad-hoc 已知）
```

**依序原則**：同一 feature 永遠 BE 先於 FE（FE 以 BE 為地基）；schema migration 先於依賴它的 feature；truth 變更先於一切。

### 4.3 修正流程（既有功能的 fix，區別於新開發）
0. 自 main 切 `fix/{issue}-{簡述}` 分支（§0.1）。
1. 在 `specs/plan/debug.md` 建立 **DBG-NNN 條目**（含最小重現步驟與嚴重度）。
2. 把重現做成**回歸情境**：加入 `tests/{frontend|backend}/Fxx.feature`（新句型先登記 `dsl.md`）→ 🔴 紅燈。
3. 最小修復 → 🟢 綠燈 → 🔵 重構。
4. **依 §7.1 同步矩陣**更新 SDD／BDD／TDD／DDD 相關檔案（truth 先行，research §6）。
5. PR（`fix(DBG-NNN): …`）→ merge → `debug.md` 結案（記錄根因）→ 更新 `tasks.md` §6 與 `session.md`。

---

## 5. truth 對齊檢查清單（每個 PR 必過；T-H9 自動化＋人工勾選）

| # | 檢查 | 自動化 | 落差處置 |
|---|---|---|---|
| 1 | drift schema（表/欄/enum/index）≡ `data-spec.dbml` | ✅ T-H9 snapshot 比對 | 🔴 補 migration 或改 dbml（走 §3 流程） |
| 2 | pubspec 依賴與版本 ⊆ `techstack.md` §2 | ✅ CI 比對腳本 | 升版需 techstack PR（架構簽核） |
| 3 | `api-spec.yaml` 僅在 P2 工作分支變更 | ✅ CI 路徑規則 | 還原；v1 不得實作其端點 |
| 4 | 新步驟句型已登記 `dsl.md` | 🔍 PR review | 補登記後才可合併 |
| 5 | FR/AC/情境 ID 出現於 PR 標題與測試標籤 | 🔍 PR review | 補標籤（追溯鍵不可斷） |
| 6 | acceptance 檔未被改動；若改動 → PM 重新簽核 | 🔍 CI 路徑規則 | 依 acceptance README §5 流程 |
| 7 | 金額/加密/同步模組變更 → PR 標註「待雙重 review」 | 🔍 review | 兩位 reviewer 核准才可合併 |

---

## 6. 任務狀態總覽（活文件）

| 區塊 | 任務 | 狀態 |
|---|---|---|
| 前置 | 專案骨架（flutter create 四平台＋Money/HLC/Balance＋CI＋README＋BDD feature 同步） | ✅（96bca5f） |
| 前置 | UI Demo 畫廊（7 畫面＋深淺色切換＋分類設定頁＋品牌虛構化 27 檔） | ✅（89571c9/01a295c） |
| Helper | T-H1 記憶體 DB fixture（sqlite3 直連 schema v1）＋T-H2 Clock | ✅（9622009 紅/b557029 綠） |
| Helper | T-H3 雲端 adapter（雙裝置拓撲模擬）＋T-H4 通知 spy＋T-H5 標準資料集＋T-H6 發票測資＋編碼器 | ✅（39be197 紅/f803eb2 綠） |
| Helper | T-H7 Gherkin runner（BE）＋T-H8 FE 掛鉤（驗證延至 M1 FE 首跑）＋T-H9 truth 對齊測試 | ✅（f803eb2） |
| Migration | T-S1 schema v1（建表＋建表回歸＋truth 對齊基線，隨 T-H1 完成） | ✅ |
| Migration | T-S2~T-S5（v2~v5，M2~M6 隨各 feature）——T-S2 ✅（81 綠）｜T-S3 ✅（信用卡/帳單/退款/分期；81 綠）｜T-S4 ✅（attachments＋遷移鏈 v3→v4＋T-H9 擴充；85 綠；merge 6501051）｜T-S5 ☐ |
| Feature | T-F01-BE（8 情境：智慧預設×4／儲存事務／Undo／離線／效能——🔴→🟢 完成，每情境一 commit） | ✅（合併 ffadf09） |
| Feature | T-F01-FE（@P0 6 情境：預填／對話框／Sticky／完成／時間選擇器／復原——🔴→🟢 Windows 實跑全綠；App 主殼+快記頁+明細+總覽落地）＋production 接線（path_provider，techstack v0.3.5 PM 定案） | ✅（S1.11 @P1 @desktop 屬 M2；acceptance 手動情境留 QA 走查） |
| Feature | T-F02-BE（@BE @P0 5 情境 🔴→🟢：金額驗證／轉帳守恆＋MonthlyStatsService／儲值 transfer 語意／軟刪除＋TombstonePurgeService 30 天／還款＋creditUnpaidTotal；多幣別 @P1 @M2 deferred PM 確認） | ✅（7ef56da） |
| Feature | T-F02-FE（@FE @P0 5 情境 🔴→🟢 macOS 實跑全綠：金額驗證禁用態／快記轉帳模式＋明細樣式／儲值文案／最近刪除 30 天還原 UI（RestoreTransactionUseCase 補口＋unit test）／**S2.9 金額計算機鍵盤**（PM 增補：常駐四則運算、＝ 四捨五入整數元、macOS 視窗 800×760）；feature 檔 rootBundle 資產載入（桌面 CWD 修復，F01 同修）；69 unit＋F01-FE 回歸全綠；M1 部署驗證通過（Release 46.9MB＋檔案 DB 二次啟動） | ✅（c46df19；拆分 @P1 @M2） |
| Feature | T-F05-BE（@BE @P0 5 情境 🔴→🟢：閾值 N-1 冪等／N-2/N-3 分級＋預算用量含 pending 預扣分量／收入達標率不封頂／自訂起始日跨月週期——BudgetPeriodService＋BudgetEvaluator＋BudgetAlertService 冪等 sync 點（settings notif_state per period）＋SaveTransactionUseCase settlementStatus＋afterSave 鉤子；S5.3 規格補漏 Given 6500） | ✅（3181aab） |
| Feature | T-F05-FE（@FE @P0 5 情境 🔴→🟢 macOS 實跑全綠：進度條警示色 orange/red／超支不封鎖記帳／預扣標籤／收入目標已達成卡／通知開關閘 budget.notify_enabled——預算分頁（M2 IA 第三分頁）＋總覽收入目標卡＋共用 BudgetProgressBar；FE 情境基線自洽修正 S1 7000/S2 8320 對齊 acceptance 敘述） | ✅（b23aca1） |
| Feature | T-F02~F10（BE+FE） | ☐ |
| Feature | 首次啟動播種（內建分類集＋預設現金帳戶；M1 過渡——帳戶/分類管理 UI 屬 F02；oplog 同交易契約） | ✅（8545bc5） |
| 對齊 | §5 清單自動化（pubspec/schema ✓ 已上 CI）；PR review 項人工 | 🟢 |
| 發佈 | v0.1.0、v0.2.0（自動標籤；**Release 產物從未成功**——流水線鏈式缺陷）；**v0.4.3（DBG-004）／v0.4.4（首次啟動播種＋發佈格式定案：版本化檔名＋Inno Setup per-user exe／DMG／未簽名 IPA／軟體內版本）** | ✅（v0.4.0~0.4.2 為修復迭代，v0.4.2/v0.4.0 壞包待刪） |

- 狀態更新規則：🔴/🟢 由 CI 與 PR 自動可推導；🔵 與 ✅ 由開發者於 PR 描述更新；每 Sprint 結束回寫本表（對應 research §2.2 出口條件）。

---

## 7. 功能修正的文件同步（SDD／BDD／TDD／DDD）

> **規則**：任何功能修正（缺陷修復或需求調整）合併前，必須依下表同步對應文件；**未同步 = PR 不可合併**（CI＋review 雙重檢查）。條目追蹤使用 `specs/plan/debug.md`。

### 7.1 四類文件定位

| 類別 | 檔案 |
|---|---|
| **SDD（設計）** | `SDD.md`；truth（`techstack.md`／`api-spec.yaml`／`data-spec.dbml`） |
| **BDD（行為）** | `BDD.md`；`specs/plan/features/acceptance/*` |
| **TDD（測試驅動檔）** | `specs/plan/tests/{frontend,backend}/*.feature`；`dsl.md`；`test/`、`integration_test/` 同步副本 |
| **DDD（領域）** | `lib/domain/**`（實體/服務）＋對映文件：SDD §4 資料模型、SDD §5 服務、`data-spec.dbml` |

### 7.2 同步矩陣（依變更類型）

| 變更類型 | SPEC | SDD | BDD | TDD | DDD | truth | 其他 |
|---|---|---|---|---|---|---|---|
| 需求／行為變更 | ✔ FR 條文 | ✔ §5 模組 | ✔ 情境 | ✔ FE/BE feature | ✔ 領域服務文件 | 視影響 | acceptance 重簽 |
| schema 變更 | — | ✔ §4 摘要 | ✔ 若影響情境 | ✔ 測試 fixture | ✔ lib/domain 實體 | ✔ **data-spec.dbml 先行** | migration（§3） |
| API／P2 變更 | — | ✔ §5.5/§12 | — | — | — | ✔ api-spec.yaml | — |
| 套件／stack 變更 | — | ✔ §3 | — | — | — | ✔ techstack.md 先行 | pubspec |
| UI 變更 | — | ✔ §8 | — | ✔ FE feature | — | ✔ specs/plan/ui/ 雛型 | acceptance 走查 |
| 新步驟句型 | — | — | — | ✔ **dsl.md 先行** | — | — | — |
| 缺陷修復（fix） | ✔ 若行為定義變 | ✔ 若設計變 | ✔ 新增回歸情境 | ✔ 回歸情境 | ✔ 若領域規則變 | 視影響 | debug.md 結案 |

### 7.3 Debug 流程（詳見 `specs/plan/debug.md`）
1. `debug.md` 建條目 DBG-NNN → 2. 最小重現做成回歸情境（🔴）→ 3. 定位與實驗（記錄於條目）→ 4. 最小修復（🟢/🔵）→ 5. 依 §7.2 同步 → 6. commit `fix(DBG-NNN): …` → 7. 結案（記根因）。
- 分支：`fix/{issue}-{簡述}`；每條目**至少一個回歸情境**（防止復發）；Blocker/Critical 結案需 reviewer 核准。
