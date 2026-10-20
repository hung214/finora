# Debug Todolist（除錯追蹤活文件）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.3（初版） |
| 定位 | 開發／測試／QA 發現缺陷時的**追蹤清單**；流程規範見 `specs/plan/tasks.md` §4.3／§7 |
| 嚴重度 | Blocker / Critical / Major / Minor（定義見 `specs/plan/features/acceptance/README.md` §4） |
| 分支 | 每條目一條 `fix/{issue}-{簡述}`；commit 格式 `fix(DBG-NNN): …` |

---

## 1. 何時開條目

- 情境測試 🔴 失敗且 **30 分鐘內無法定位**（避免盲改；能立即修的小錯不必開條目）。
- QA 驗收（acceptance 走查）回報的缺陷。
- 真機與 CI 行為不一致、truth 對齊測試（T-H9）紅燈且非預期。

## 2. Debug 標準流程（每條目七步）

1. **建條目**：複製 §3 模板，取得編號 DBG-NNN。
2. **最小重現**：把重現寫成**回歸情境**加入 `specs/plan/tests/{backend|frontend}/Fxx.feature`（新句型先登記 `dsl.md`）→ 🔴。
3. **定位**：列嫌疑模組／最近相關 commit（必要時 bisect），每次實驗記錄結果於條目。
4. **假設→修復**：最小修復，不做順手改。
5. **回歸綠燈**：新回歸情境 🟢＋既有測試不被破壞。
6. **文件同步**：依 `tasks.md` §7.2 矩陣更新 SDD／BDD／TDD／DDD 相關檔案（truth 先行）。
7. **結案**：commit `fix(DBG-NNN): …` → merge → 本表標 ✅ 並記錄**根因**。

## 3. 條目模板（複製使用）

```
### DBG-NNN｜{一句話摘要}
- 日期／回報者：
- 嚴重度：Blocker|Critical|Major|Minor
- 來源：Fxx-BE/FE 情境 | AC-xx | QA 走查 | T-H9 truth 對齊
- 重現：{最小步驟}
- 回歸情境：tests/{backend|frontend}/Fxx.feature → Scenario {名稱}
- 定位：{嫌疑模組/commit → 實驗 1：結果 → 實驗 2：結果}
- 根因：
- 修復：{檔案與改動要點}
- 同步（§7.2）：SDD[ ] BDD[ ] TDD[ ] DDD[ ] truth[ ]
- 狀態：🔴 重現中 / 🔍 定位中 / 🔧 修復中 / ✅ 結案
```

## 4. 追蹤表（活文件，新條目加在上面）

| ID | 日期 | 嚴重度 | 來源 | 摘要 | 分支 | 回歸情境 | 狀態 | 根因 |
|---|---|---|---|---|---|---|---|---|
| DBG-005 | 2026-10-20 | Minor | T-S4 全量測試（併行） | `save_split_transaction_test` 第 1 情境於全量跑中三度間歇失敗（~3/50），錯誤均為 `Expected: <600> Actual: <400>`（rows[0].amountMinor）。**根因**：斷言隱式依賴 `allTransactions()` 之 `ORDER BY occurred_at, id`——兩筆拆分子交易同 occurredAt，陳列順序由 UUIDv7 id 字典序（＝時間戳序）決定；系統時鐘微回退（NTP slew，並行負載下較易）使後生成者 id 較小 → 順序翻轉 rows[0]=第二筆（400）。屬**測試順序依賴缺陷**（拆分子交易陳列順序非契約），非產品 bug | —（測試基建，未開 fix 分支） | 修復即回歸：斷言改**順序無關**（金額/分類集合 {600,400}/{c-food,c-shop}，語意不變——兩筆金額皆在＋同群組＋oplog 兩筆）；證據 log `dbg005_loop_7.log`（+24 -1, line 27） | ✅ 結案 | 測試對非契約細節（UUID 字典序）斷言；環境層時鐘微回退為觸發器。2026-10-21 修復＋驗證 10 連跑 |
| DBG-004 | 2026-10-19 | Critical | 本地部署實測（第二次啟動） | 檔案 DB **第二次開啟即崩潰**：`_migrate()` 無條件重跑 `CREATE TABLE`（無 IF NOT EXISTS、無 schema 版本閘）→ "table accounts already exists" → main() 啟動即拋錯。in-memory 測試每案例皆全新 DB，未覆蓋「重開既有檔案 DB」 | fix/dbg-004-db-reopen | db_fixture_test 新增「DBG-004：既有檔案 DB 重新開啟不崩潰且資料延續」（紅：SqliteException → 綠） | ✅ 結案 | 遷移無冪等/版本控制；修復：`_migrate()` 加 `PRAGMA user_version` 閘＋既有表偵測（交易式 DDL 全有全無，偵測可靠），使用者既有 DB 開啟即自動補標版本；DDL 字串不動（T-H9 truth regex 相容）；多版本遷移器隨 T-S2 落地 |
| DBG-003 | 2026-10-19 | Critical | 本地部署實測（v0.4.0 Windows Release） | 空帳本（全新安裝、零帳戶）首頁正常，點快記 → 整頁灰屏：`QuickEntryPresetService._firstActiveAccount()` 對空帳戶清單取 `.first` → StateError → 頁面建構拋例外（Release 呈現灰屏） | fix/dbg-003-empty-ledger | BE 情境「智慧預設_空帳本不崩潰」（紅：Bad state: No element→綠）＋FE 情境「空帳本開啟快記不崩潰」（灰屏→顯示選擇帳戶＋儲存禁用） | ✅ 結案 | FE 情境 Background 一律先種帳戶，零帳戶邊界未覆蓋；修復：`QuickEntryPreset.account` 改可空、`_firstActiveAccount()` 空清單回退 null（UI 顯示「選擇帳戶」、儲存禁用）——帳戶建立 UI 屬 F02 |
| DBG-002 | 2026-10-18 | Major | 本地部署建置（flutter build windows） | ①專案路徑含非 ASCII（記帳）→ MSBuild 讀不到 app.dill，原生建置失敗 ②flutter_secure_storage_windows 需 atlstr.h（VS C++ ATL 元件缺） | fix/TR-8-windows-build | Windows release 建置＋啟動冒煙（本輪通過） | ✅ 結案 | ①路徑非 ASCII：曾以 ASCII clone（finora-build）建置；**已根治：2026-10-18 repo 遷移至 ASCII 路徑 `E:\opencode\finora`，`dart analyze`／56 測試／Windows Release 建置（81.9s）全數直接通過（遷移後需 `flutter clean` 清含舊路徑的 CMakeCache）** ②ATL 元件缺：TR-8（secure_storage/local_auth 移至 M2，安裝元件後回歸） |
| DBG-001 | 2026-10-18 | Major | T-H1 紅綠燈（drift codegen） | build_runner/drift 與 Dart 3.13.5 工具鏈不相容：analyzer 7.x 序列化 SDK dot-shorthand 崩潰；dart_style 3.1.13+ 需 Dart 3.14 fe types（LabelReference 等）；build_runner 2.16.x pub cache 提取損壞、2.17.1 與 json_serializable 衝突 | feature/T-H-test-helpers | tests 依新 DB 邊界改寫（33 情境綠） | ✅ 結案 | 環境工具鏈問題（非程式缺陷）；過渡方案 sqlite3 直連（research TR-7、techstack v0.3.2），M1 前於 CI 重試 drift 回歸 |
| DBG-000（格式範例） | 2026-10-18 | Major | F04-BE 結帳歸屬 | （範例）卡B 當天消費誤入本期 | fix/dbg-000-example | F04-BE 新增回歸情境 | ✅ 結案 | （範例）boundary_rule 未傳入 period 計算 |

> DBG-000 僅示範欄位格式，非真實缺陷；第一筆真實條目由 DBG-001 起。

## 5. 結案規則

- 必附**回歸情境**且併入 CI（對應標籤分級：P0 缺陷的回歸＝PR gate）。
- 行為定義有變 → SPEC/SDD/BDD 同步（`tasks.md` §7.2），acceptance 變更需 PM 重簽。
- Blocker／Critical 結案需另一位 reviewer 核准；結案後條目**不刪除**（留作根因資料庫）。
