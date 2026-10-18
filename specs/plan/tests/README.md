# 自動化測試計畫（前端／後端 BDD Feature 檔索引）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.3（初版） |
| 來源 | PM 驗收標準 `specs/plan/features/acceptance/`（F01~F10）→ 依層級拆分為可自動化的 `.feature` 檔 |
| 步驟 DSL | 見同層 `dsl.md`（所有 Given/When/Then 句型必須登記於該檔） |
| 位置規範 | 本資料夾為**計畫源**；實作時前端複製至 `integration_test/features/`、後端複製至 `test/bdd/`（以腳本同步，禁止手改副本） |

---

## 1. 拆分原則

| 情境性質 | 歸層 | 工具 |
|---|---|---|
| 需要看見 UI（按鈕/對話框/顏色/快捷鍵/權限） | **前端 FE** | flutter_gherkin + integration_test（真機/模擬器） |
| 領域邏輯、資料計算、同步協議、解析器、效能 | **後端 BE** | flutter_test 純 Dart（記憶體 Drift DB + in-memory cloud + fake clock + notification spy） |
| E2E 跨層情境（記帳→同步→另一裝置可見） | FE 主導，BE 掛鉤驗證資料 | 兩者協作（FE 步驟內斷言經 repository 讀取） |

- 同一 AC 可同時出現在 FE 與 BE（不同切入點），但**同一情境敘述不重複**：BE 驗「算得對」，FE 驗「看得對、點得對」。

## 2. 檔案清單與層級分配

| Feature | 前端檔 | 後端檔 | 涵蓋 AC |
|---|---|---|---|
| F01 快速記帳 | `frontend/F01_quick-entry.feature`（7） | `backend/F01_quick-entry.feature`（8） | AC-01、02 |
| F02 交易與帳戶 | `frontend/F02_transactions-accounts.feature`（5） | `backend/F02_transactions-accounts.feature`（6） | AC-10 |
| F03 發票掃描 | `frontend/F03_receipt-scan.feature`（6） | `backend/F03_receipt-scan.feature`（7） | AC-03 |
| F04 信用卡帳單 | `frontend/F04_credit-card-billing.feature`（5） | `backend/F04_credit-card-billing.feature`（10） | AC-04、11 |
| F05 預算收入目標 | `frontend/F05_budget-income-goal.feature`（5） | `backend/F05_budget-income-goal.feature`（5） | AC-05、13 |
| F06 定期交易 | `frontend/F06_recurring-transactions.feature`（4） | `backend/F06_recurring-transactions.feature`（5） | AC-12 |
| F07 雲端同步 | `frontend/F07_cloud-sync-backup.feature`（6） | `backend/F07_cloud-sync-backup.feature`（8） | AC-06~08、14 |
| F08 App 鎖 | `frontend/F08_app-lock-security.feature`（5） | `backend/F08_app-lock-security.feature`（4） | AC-09 |
| F09 資料管理 | `frontend/F09_data-management.feature`（2） | `backend/F09_data-management.feature`（3） | — |
| F10 報表搜尋 | `frontend/F10_reports-search.feature`（3） | `backend/F10_reports-search.feature`（4） | — |

（括號內為情境數；合計 FE 48、BE 60）

## 3. 標籤與 CI 分級

| 標籤 | 意義 | CI |
|---|---|---|
| `@FE` / `@BE` | 層級 | — |
| `@P0` / `@P1` | 優先級 | P0：PR gate；P1：nightly |
| `@M1`~`@M7` | 里程碑（對應 SPEC §11） | 對應 Sprint 出口 |
| `@FR-xx` / `@AC-xx` | 追溯鍵 | 報表彙總用 |
| `@offline` / `@sync` / `@desktop` | 環境條件 | 對應 runner 設定 |

## 4. 執行方式

- **BE**：`flutter test test/bdd --tags "@BE and @P0"`（純 Dart，PR 每次必跑，<5 分鐘）。
- **FE**：`flutter test integration_test --tags "@FE and @P0" -d <device>`（夜間 + release 前；四平台矩陣見 acceptance README §3）。
- 出口條件：對應 Sprint 的 P0 情境全綠（同 acceptance README §5 簽核流程）。
