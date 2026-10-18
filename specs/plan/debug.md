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
| DBG-002 | 2026-10-18 | Major | 本地部署建置（flutter build windows） | ①專案路徑含非 ASCII（記帳）→ MSBuild 讀不到 app.dill，原生建置失敗 ②flutter_secure_storage_windows 需 atlstr.h（VS C++ ATL 元件缺） | fix/TR-8-windows-build | Windows release 建置＋啟動冒煙（本輪通過） | ✅ 結案 | ①路徑非 ASCII：以 ASCII clone（finora-build）建置；**建議長期將 repo 移至 ASCII 路徑** ②ATL 元件缺：TR-8（secure_storage/local_auth 移至 M2，安裝元件後回歸） |
| DBG-001 | 2026-10-18 | Major | T-H1 紅綠燈（drift codegen） | build_runner/drift 與 Dart 3.13.5 工具鏈不相容：analyzer 7.x 序列化 SDK dot-shorthand 崩潰；dart_style 3.1.13+ 需 Dart 3.14 fe types（LabelReference 等）；build_runner 2.16.x pub cache 提取損壞、2.17.1 與 json_serializable 衝突 | feature/T-H-test-helpers | tests 依新 DB 邊界改寫（33 情境綠） | ✅ 結案 | 環境工具鏈問題（非程式缺陷）；過渡方案 sqlite3 直連（research TR-7、techstack v0.3.2），M1 前於 CI 重試 drift 回歸 |
| DBG-000（格式範例） | 2026-10-18 | Major | F04-BE 結帳歸屬 | （範例）卡B 當天消費誤入本期 | fix/dbg-000-example | F04-BE 新增回歸情境 | ✅ 結案 | （範例）boundary_rule 未傳入 period 計算 |

> DBG-000 僅示範欄位格式，非真實缺陷；第一筆真實條目由 DBG-001 起。

## 5. 結案規則

- 必附**回歸情境**且併入 CI（對應標籤分級：P0 缺陷的回歸＝PR gate）。
- 行為定義有變 → SPEC/SDD/BDD 同步（`tasks.md` §7.2），acceptance 變更需 PM 重簽。
- Blocker／Critical 結案需另一位 reviewer 核准；結案後條目**不刪除**（留作根因資料庫）。
