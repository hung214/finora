# UI Prototyping Plan（初步 UI 雛型計畫）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.3（初版） |
| 產出者 | 系統分析師工作流 `/system-analysis`（前端 UI prototyping 分支） |
| 輸入 | `SDD.md` §8（UI 資訊架構）、`SPEC.md` §5/§7（功能與流程）、`specs/plan/features/acceptance/` |
| 產出 | 本資料夾 `*.html`：**初步 UI 雛型**（靜態 HTML，瀏覽器直接開啟） |
| 目的 | ①PM 確認畫面流程與資訊架構 ②QA 對照驗收情境的視覺基準 ③Dev 的實作樣式依據 |

---

## 1. 畫面清單與規格對應

| 檔案 | 畫面 | 對應規格 | 關鍵驗收 |
|---|---|---|---|
| `01-dashboard.html` | 總覽（行動） | SDD §8、FR-R1、FR-B6/B7 | AC-13、F01-S1.9 |
| `02-ledger.html` | 明細（行動） | SDD §8、FR-T2、FR-S6 | F02、F03-S3.1 |
| `03-quick-entry.html` | 快速記帳＋每筆確認對話框（行動） | FR-Q1~Q5、SDD §5.1 | AC-01、AC-02 |
| `04-budget.html` | 預算與收入目標（行動） | FR-B2~B7 | AC-05、AC-13 |
| `05-scan-review.html` | 掃描＋確認清單（行動） | FR-S1~S7、SDD §5.4 | AC-03 |
| `06-credit-card.html` | 信用卡與帳單（行動） | FR-C1~C6、SDD §5.2 | AC-04、AC-11 |
| `07-settings-sync.html` | 設定：雲端同步/安全/通知（行動） | FR-Y7/Y11、FR-X1、FR-O1/O2 | AC-08、S7.10~S7.13 |
| `08-desktop-shell.html` | 桌面版三欄殼（Windows/macOS） | SDD §8、FR-Q7 | F01-S1.11、F03-S3.9 |
| `09-category-settings.html` | 分類設定（行動） | FR-B1、FR-Q1 | F01-S1.1 |

## 2. 雛型原則

1. **靜態、自足**：每個 HTML 內嵌 CSS，無外部依賴，雙擊即開；僅呈現單一關鍵狀態（非完整互動）。
2. **規格標註**：畫面旁黃色便利貼 = 規格/驗收連結（FR/AC/情境編號），PM 與 QA 對照用。
3. **資料為劇例**：使用 acceptance 檔之相同測試資料（如 餐飲 87.5%、帳單 5,000、發票 195 元），方便跨文件對照。
4. **此為初步版（low-fi → mid-fi）**：色彩/間距為方向性示意；最終視覺由 M1 Sprint 以 Material 3 token 定稿。App 內建「UI Demo 畫廊」（`flutter run` → 首頁按鈕）為本清單之 Flutter 呈現，支援深色/淺色切換（FR-O1）。
5. 每個雛型定案（PM 簽核）後，作為 F01~F10 驗收之 UI 基準；修改需記錄於本 README §4。
6. **版權聲明**：所有商家／卡片／帳戶名稱皆為虛構（陽光超商、晨光早餐店、示例卡、票證卡等），與任何真實品牌無關；圖示使用 Flutter Material Icons（Apache-2.0）與 Unicode 表情符號，未使用需授權素材。

## 3. 未列入本輪的畫面（後續補）

- 新裝置還原引導（S7.4）、衝突檢視頁（S7.3）、PIN 重設流程（S8.4）、定期交易待確認清單（F06）、報表頁（F10）→ 列 M1~M6 各 Sprint 開工前補齊。
- 深色模式樣本 → M2。

## 4. 變更記錄

| 日期 | 版本 | 變更 | 簽核 |
|---|---|---|---|
| 2026-10-18 | v0.3 | 初版 8 個畫面雛型 | PM 待簽 |
