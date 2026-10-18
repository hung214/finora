# 技術決策研究報告（System Analyst Research & Development Plan）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.3（初版，與文件集 v0.3 對應） |
| 日期 | 2026-10-18 |
| 角色 | 系統分析師（System Analyst）工作流產出 |
| 輸入 | `SPEC.md` v0.3（需求）、`SDD.md` v0.3（架構草案）、`BDD.md` v0.3（驗收） |
| 輸出 | ①開發計畫（§2）②技術決策研究（§3）→ 定案寫入 `specs/truth/techstack.md`（原始碼單一事實來源） |
| 決策狀態標記 | ✅ 已定案（寫入 truth）／🔬 待 Spike 驗證（M0 執行，附成功條件）／⏸ 延後（P2） |

---

## 1. 系統分析師工作流與 AI 協助規劃

### 1.1 工作流全景

```
需求（SPEC.md）
   │  PM 確認商業決策（訪談 → FR/AC）
   ▼
技術決策研究（本文件 research.md）
   │  系統分析師：候選方案比較、風險、Spike 清單
   ▼
Spike 技術驗證（M0，時限盒） ──失敗──► 回退研究，換候選方案
   │  成功
   ▼
架構定案（SDD.md）＋ 原始碼事實（specs/truth/techstack.md）
   │
   ▼
開發（Sprint 計畫 §2）──產出──► 驗收（BDD.md + specs/plan/features/acceptance/）
```

- 原則：**research 提案 → SDD 設計 → truth 定案**。research.md 是討論與比較的場所；truth/techstack.md 只記錄「已定案且將寫進原始碼」的事實。
- 不一致時：原始碼以 **truth** 為準，並回修 SDD/research（見 §6 變更控制）。

### 1.2 AI 協助規劃（人機分工）

| 階段 | AI（opencode agent）承擔 | 人類把關 |
|---|---|---|
| 需求 | 訪談整理、起草 SPEC/流程步驟/驗收場景、文件交叉一致性檢查 | PM 確認商業決策（同步模式、安全邊界、優先級） |
| 技術研究 | 產生候選方案比較表、風險登記、Spike 清單與成功條件 | 架構師/開發者簽核定案（寫入 truth） |
| 開發 | 生成 repository/DAO 樣板、step definitions、單元測試、遷移腳本、code review 清單 | PR review（金額/加密/同步模組**雙重 review**） |
| 驗收 | 由 BDD 生成 QA 檢核與 acceptance 檔維護 | QA 執行、PM 複核（acceptance 簽核區） |
| 文件同步 | 以 FR/AC ID 為鍵，同步更新 SPEC/SDD/BDD/truth | 版本升級簽核 |

### 1.3 AI 護欄
1. `truth/techstack.md` 僅能經 PR 變更，AI 產出僅為提案（research.md §3），不得直接改 truth。
2. 關鍵模組（金額運算、加密、同步合併）AI 生成碼必須附單元測試，領域層覆蓋率門檻 ≥80%（NFR-10）。
3. 商業決策（定價、上架範圍）AI 只列選項，不做決策。

---

## 2. 開發計畫（Development Plan）

### 2.1 週期與人力假設
- 節奏：2 週／衝刺，共 12 衝刺（約 6 個月）至四平台上架。
- 建議配置：1× Flutter 全端工程 + 0.5× QA + PM 兼任；AI 代理作為「虛擬隊友」承擔文件、測試樣板與研究比較。
- 每衝刺出口條件：對應 acceptance 檔的 P0 情境全 Pass + CI 綠燈。

### 2.2 衝刺計畫（對應 SPEC §11 里程碑）

| Sprint | 里程碑 | 目標與交付物 | 驗收檔 | Spike（並行） |
|---|---|---|---|---|
| S0 | M0 | 文件定稿；技術驗證 | — | SP-1~SP-7 全數啟動 |
| S1–S2 | M1 | 核心本地記帳：帳戶/分類/交易/明細/快記（智慧預設+每筆確認） | F01、F02（P0） | SP-1 收斂 |
| S3–S4 | M2 | 支出預算+收入目標、報表 v1、桌面版 UI 適配 | F05、F10 | SP-6 |
| S5 | M3 | 信用卡帳單引擎（每卡歸屬）+分期 | F04 | — |
| S6–S7 | M4 | 發票掃描：獨立入口、雙 QR、OCR、確認清單 | F03 | SP-2/SP-3 收斂 |
| S8 | M5 | 雲端備份（Drive，帳號授權）+備份檔遷移 | F07（S7.1、S7.4~S7.9） | SP-4；Google OAuth 送審 |
| S9–S10 | M6 | 多裝置同步（OpLog）、iCloud、定期交易 | F07（其餘）、F06 | SP-5 |
| S11–S12 | M7 | App 鎖/資料管理、效能打磨、四平台上架 | F08、F09 | SP-7 |

### 2.3 Spike 清單（時限各 2–3 天，M0 執行）

| # | Spike | 成功條件 | 失敗回退 |
|---|---|---|---|
| SP-1 | Drift + SQLCipher 於 4 平台：開庫、migration、FTS5（含中文 bigram 影子欄位） | 四平台單元測試全綠；FTS5 中文查詢命中 | 改 raw sqlite3 FFI + 自管 schema |
| SP-2 | mobile_scanner 同幀雙 QR 連讀（500ms 合併） | 實機 10/10 次合併成功 | 改原生 API（AVFoundation/CameraX）封裝 |
| SP-2b | Windows/macOS 相機取幀 → ZXing 解碼通道 | 桌面可掃標準發票測資 | 桌面僅提供相簿匯入（FR-S6 fallback，可接受） |
| SP-3 | Windows.Media.OCR platform channel + 中文收據抽取 | 20 張樣本：日期/總額抽取 ≥70% | 引導使用者拍照品質/手動輸入（欄位抽取為輔助） |
| SP-4 | 桌面 OAuth loopback（Drive `drive.appdata`）讀寫 | Win/macOS 完成 upload/download/delete | 先只出行动端 Drive，桌面走備份檔 |
| SP-5 | CloudKit private DB + CKAsset 寫讀（iOS/macOS） | 檔案語意四操作（list/upload/download/delete）通通 | 僅 iOS 用 iCloud，macOS 走 Drive |
| SP-6 | fl_chart 於 10 萬筆聚合資料渲染 | 月報表 < 1.5s（NFR-01） | 預聚合（SQL 摘要表）再渲染 |
| SP-7 | MSIX 打包 + DMG notarization 全鏈 | 兩平台安裝/啟動/自動更新驗證 | 改便攜 zip + 手動安裝說明 |

### 2.4 品質門檻（每 Sprint 出口）
- 領域層覆蓋率 ≥80%；P0 acceptance 情境全綠；`flutter analyze` 零警告；效能抽查（NFR-01/02/03）記錄實測值。
- 預期 Tech Stack 摘要：見 §3 決策總表；**原始碼定案版本一律以 `specs/truth/techstack.md` 為準**。

---

## 3. 技術決策研究（ADR 式逐項）

> 格式：背景 → 候選 → 評估 → 決策 → 風險與回退。決策編號 D1~D14。

### D1 跨平台框架 — ✅ Flutter
- **背景**：SPEC §4 要求 iOS/Android/macOS/Windows 四平台、單人團隊、UI 一致（FR-O1 深色模式、桌面快捷鍵 FR-Q7）。
- **候選**：Flutter 3.x ｜ React Native（+RN-Windows/RN-macOS）｜ Kotlin Multiplatform + Compose Multiplatform ｜ .NET MAUI。
- **評估**：

| 維度 | Flutter | React Native | KMP | MAUI |
|---|---|---|---|---|
| 四平台單碼庫 | ✅ 成熟 | ⚠️ Win/macOS 支援薄弱 | ⚠️ 桌面較新 | ⚠️ 行動體驗普通 |
| 生態（DB/OCR/QR/雲端） | ✅ 完整 | ⚠️ | ⚠️ | ⚠️ |
| UI 一致性/自繪 | ✅ | ⚠️ 平台差異 | ✅ | ⚠️ |
| 單人團隊效率 | ✅ | ✅ | ⚠️ | ⚠️ |

- **決策**：Flutter（SDD §3 已定）。研究佐證：drift/sqlcipher、mobile_scanner、googleapis 等關鍵依賴皆有活躍維護。
- **風險**：桌面相機與平台通道品質 → SP-2b 驗證；輸入法/視窗行為差異 → M2 桌面適配衝刺處理。

### D2 本地資料庫與加密 — ✅ Drift + SQLCipher
- **候選**：drift + sqlcipher_flutter_libs ｜ Isar ｜ Realm ｜ sqflite + 手寫 SQL。
- **評估**：需要型別安全 ORM、**Reactive Streams**（餘額/清單即時刷新，SDD §4.3）、FTS5 全文搜尋（FR-R3）、SQLCipher（FR-X2）、四平台。
- **結論**：Isar 無 SQL/FTS 與成熟加密；Realm 授權與桌面支援疑慮；drift 全符合且支援 schema 遷移工具。
- **風險/回退**：SQLCipher 版本對齊 → SP-1；FTS5 中文分詞（unicode61 對 CJK 不切詞）→ **bigram 影子欄位**方案（寫入時對 merchant/note 做兩字切分入 FTS5，查詢同樣切分），併入 SP-1 驗證。

### D3 狀態管理 — ✅ Riverpod 2
- 對比 Bloc（樣板多）、MobX（code gen 重）、GetX（隱式依賴、測試性弱）。Riverpod：編譯期安全、provider 可替換（測試注入 fake clock/mock cloud 必備）。

### D4 QR 掃描 — 🔬 行動已定、桌面待驗證
- **候選**：mobile_scanner（MobileScanner API）｜ qr_code_scanner（維護趨緩）｜ 純原生 API ｜ ZXing FFI。
- **決策**：行動 = mobile_scanner（支援同幀多碼，滿足雙 QR 連讀）；桌面 = 相機取幀 channel + ZXing 解碼（SP-2b），**fallback：相簿/檔案匯入**（FR-S6 已定案無相機路徑，因此桌面掃描失敗不阻塞）。
- **風險**：雙 QR 合併時序 → SDD §5.4 的 500ms 暫存設計 + SP-2 實測。

### D5 OCR 引擎 — ✅ 四平台各用原生最佳引擎（不引入雲端 OCR）
- **候選**：ML Kit Text Recognition v2（Android/iOS）｜ Apple Vision（macOS）｜ Windows.Media.OCR ｜ Tesseract ｜ Google Cloud Vision（雲端）。
- **評估**：FR-S3 要求離線、FR-X4 要求本機處理 → 雲端 OCR 直接排除（隱私+離線+成本）。Tesseract 中文品質與包體不佳。
- **決策**：平台各用原生引擎，統一 `ReceiptRecognizer` 抽象（輸出 `(value, confidence)`，SDD §5.4）；明細抽取用 heuristics；金測 100 張真實收據（準確率 ≥98%，總額欄位 100%）。
- **風險**：Windows OCR 中文品質 → SP-3；引擎間信賴度尺度不一致 → 抽象層統一定義（0~1，平台各自校準）。

### D6 同步架構 — ✅ 檔案式 OpLog（自研，無後端）
- **候選**：①雲端檔案 + OpLog 合併（SDD §5.5）②Firebase/Supabase 即時同步 ③現成 CRDT 套件（如 crdt）。
- **評估**：FR-Y 決策「無自建後端、帳號授權式同步」直接排除②；③之 LWW-RN 與 Drift 整合、墓標語意、schema 版本控制需大幅改造，且未來接後端時平移成本高。
- **決策**：①。整列快照 + per-device bundle 序號 + HLC（SDD §5.5.4）——「衍生餘額」原則讓 LWW 造成的衝突永不破壞帳務守恆。
- **風險**：自研協議正確性 → 雙/三裝置整合測試（BDD F7）為 Sprint S9 出口條件。

### D7 雲端儲存 — ✅ Google Drive `drive.appdata`（全平台）＋ CloudKit private DB（iOS/macOS）
- **Drive**：scope `drive.appdata`（sensitive → OAuth 驗證流程於 S8 Sprint 前送審，回退 `drive.file`+使用者自選資料夾）；桌面 loopback OAuth（SP-4）。
- **iCloud**：CloudKit record+CKAsset 對映檔案語意（SP-5）；Android/Windows 無 SDK（SPEC §4 平台限制，UI 明示）。
- **風險**：CloudKit 速率/配額 → 附件去重（內容定址）+ 懶下載已內建於協議。

### D8 加密與金鑰 — ✅ AES-256-GCM（cryptography 套件）＋ OS 安全儲存
- **評估**：本地 DB 金鑰走 flutter_secure_storage（Keychain/Keystore/DPAPI）；雲端內容加密為 P2（FR-Y7 決策：預設帳號授權保護）；備份檔檔案密碼（FR-Y6，P1）需要 KDF。
- **注意**：純 Dart Argon2 效能慢——僅用於低頻操作（匯出/匯入備份檔），可接受；若實測 >3 秒，改 FFI libargon2（列入 SP-4 附帶量測）。

### D9 通知與背景 — ✅ flutter_local_notifications ＋ 開啟 App 補算
- 背景排程不可靠（iOS BGTaskScheduler、Android Doze）→ 帳單結算/逾期判定一律「開啟 App 補算」（SPEC §10.6、SDD §5.2）；workmanager 僅作 Android 加值（可選）。

### D10 圖表 — ✅ fl_chart（MIT）
- 對比 Syncfusion（社群授權有營收條款）、graphic（較新）。fl_chart 滿足甜甜圈/趨勢且 MIT 無風險；大資料以 SQL 預聚合再渲染（SP-6 驗證）。

### D11 CI/CD 與發佈 — 🔬 框架已定、上架鏈待驗證
- CI：GitHub Actions（analyze/unit/integration-P0/四平台 build）；iOS 簽名與上架以 Codemagic 或 Fastlane（SP-7 一併驗證）。
- 產物：AAB ｜ IPA ｜ **MSIX**（Windows）｜ **DMG + notarization**（macOS）。

### D12 測試工具 — ✅ flutter_test + flutter_gherkin + mocktail + golden
- BDD.md §4 之 step definitions 以 flutter_gherkin 掛接；三測試掛鉤（fake clock / in-memory cloud / notification spy）為標配。

### D13 全文搜尋（中文）— 🔬 併入 SP-1
- FTS5 預設 tokenizer 不切中文 → 採 **bigram 影子欄位**：寫入時將 merchant/note 切成兩字詞（空格分隔）存入 FTS5 欄位，查詢同樣切分。驗證：查「超商」命中「陽光超商」。

### D14 套件治理 — ✅
- 授權白名單（MIT/BSD/Apache-2.0，排除 copyleft）；pubspec.lock 鎖版；每月人工審查相依更新（不自動升級）；供應鏈風險：關鍵套件（加密/DB）鎖 commit tag。

---

## 4. 決策總表

| 編號 | 決策 | 狀態 | Spike | 寫入 truth |
|---|---|---|---|---|
| D1 | Flutter 3.x | ✅ | — | ✔ |
| D2 | Drift + SQLCipher + FTS5 | ✅ | SP-1 | ✔ |
| D3 | Riverpod 2 | ✅ | — | ✔ |
| D4 | mobile_scanner（行動）／桌面相機+ZXing | 🔬 | SP-2/SP-2b | 行動 ✔；桌面暫定 |
| D5 | 原生 OCR 四引擎 + 統一抽象 | ✅ | SP-3 | ✔ |
| D6 | 檔案式 OpLog 同步 | ✅ | — | ✔ |
| D7 | Drive appDataFolder + CloudKit | ✅ | SP-4/SP-5 | ✔ |
| D8 | AES-256-GCM；Argon2id（檔案密碼） | ✅ | SP-4 附測 | ✔ |
| D9 | flutter_local_notifications + 補算 | ✅ | — | ✔ |
| D10 | fl_chart | ✅ | SP-6 | ✔ |
| D11 | GitHub Actions + Codemagic/Fastlane；MSIX/DMG | 🔬 | SP-7 | 待定 |
| D12 | flutter_gherkin 測試鏈 | ✅ | — | ✔ |
| D13 | FTS5 中文 bigram | 🔬 | SP-1 | 待定 |
| D14 | 套件治理規則 | ✅ | — | ✔（規則節） |

## 5. 風險登記（技術補充，與 SDD §11 併閱）

| # | 風險 | Spike/對策 |
|---|---|---|
| TR-1 | SP-2b 桌面相機不可行 | 回退相簿匯入（FR-S6 已內建，非阻塞） |
| TR-2 | SP-3 Windows OCR 中文差 | 欄位抽取定位為輔助；確認頁人工把關（FR-S4/S5） |
| TR-3 | Google OAuth 審核延誤 | S8 前送審；備選 `drive.file`（R2） |
| TR-4 | 純 Dart Argon2 過慢 | FFI libargon2（僅影響備份檔加解密，低頻） |
| TR-5 | 自研同步協議缺陷 | 雙/三裝置整合測試為 S9 出口條件；GC 保守保留 20 個 bundle |
| TR-6 | sqlcipher_flutter_libs 0.7.0+eol（套件已標記 EOL，S0 pub get 發現） | D2 加密整合 | SP-1 強化評估：改自帶 SQLCipher native（sqlite3 FFI + cipher 編譯）或替代加密層；M1 前定案（techstack §6-7） |
| TR-7 | drift/build_runner codegen 與 Dart 3.13.5 工具鏈不相容（analyzer 7.x 無法序列化 SDK dot-shorthand；dart_style 3.1.13+ 需 Dart 3.14 fe types；build_runner 2.16.x pub cache 提取損壞） | D2/T-S1 | **過渡**：T-S1 以 sqlite3 2.9.4 直連（lib/data/sqlite/，schema 仍以 data-spec.dbml 為準）；M1 前於 CI（Linux）重試 drift 回歸，屆時 DB 層 API 不變僅換底層（DBG-001 結案記錄） |

## 6. 變更控制（research → truth 流程）

1. 新需求/新技術疑問 → 於本文件 §3 新增決策項（狀態 🔬）。
2. Spike 完成 → 更新狀態為 ✅/回退方案 → 經架構簽核。
3. 同步更新：SDD 對應段落 → **PR 變更 `truth/techstack.md`**（版本+日期+理由）→ 若影響需求，以 FR/AC ID 回溯 SPEC/BDD/acceptance。
4. truth 與原始碼不一致時：視為缺陷（Blocker），以 truth 為準修碼或修 truth（擇一，禁止長期分叉）。
