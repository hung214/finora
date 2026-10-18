# 📒 LedgerSync — 本地優先跨平台記帳 App

> 一款**資料存在自己裝置、隱私為重**的記帳應用：連續快速記帳、台灣發票掃描、信用卡預扣管理、
> 預算與收入目標，並以 **Google Drive / iCloud 帳號授權**做雲端備份與多裝置同步（無自建伺服器）。
>
> | | |
> |---|---|
> | 支援平台 | iOS 15+ / Android 8+ / macOS 12+ / Windows 10 21H2+ |
> | 技術棧 | Flutter 3.47（單一程式碼庫）— 詳見 `specs/truth/techstack.md` |
> | 規格版本 | v0.3（需求→設計→BDD→驗收→任務全鏈文件） |
> | 當前狀態 | M0 骨架完成；M1 開發中（進度見 `session.md` / `specs/plan/tasks.md` §6） |

---

## 1. 功能說明

### 1.1 快速記帳與連續記帳（FR-Q）
- 大金額鍵盤＋常用分類快捷格，**開啟到儲存 ≤ 3 次點擊**，儲存耗時 < 300ms。
- **智慧預設**：帳戶沿用上一筆、分類依「同商家歷史 > 時段習慣 > 最近使用」推薦；可於設定改為固定預設。
- **連續記帳**：每筆儲存後彈出「繼續記下一筆？」——可繼續（保留帳戶/分類/商家）、復原上一筆、完成離開。
- 完全離線可用；桌面版 `Ctrl+N`（macOS `⌘N`）直接呼喚。

### 1.2 發票掃描記帳（FR-S）
- **台灣電子發票雙 QR 解析**：自動帶入發票號、開立日、賣方、總額（含明細）；紙本收據走本機 OCR。
- 辨識**全在本機**（離線可用、隱私不出裝置），結果一律經「確認清單」人工把關後入帳，原圖存為附件。
- 入口：總覽/明細頁獨立「掃描」按鈕；桌面版工具列＋`Ctrl+Shift+S`。

### 1.3 信用卡預扣與帳單週期（FR-C）
- 刷卡**先記錄（預扣）**：立刻累計「本期應付」，銀行帳戶餘額不動。
- 到結帳日自動彙總**帳單** → 繳款截止前提醒（前 3 天＋當天）→ 點「全額/部分繳款」從連結帳戶扣款。
- **結帳日歸屬每卡可設定**（當天算本期/下期）；支援分期付款、退款衝銷、逾期標示。

### 1.4 支出預算與收入目標（FR-B）
- 總預算＋分類預算（月週期、起始日可自訂），用量**含信用卡預扣**（承諾支出觀點）。
- 進度條＋每日可用額＋月底預測；80%/100%/超支分級通知（每級每期僅一次）。
- **收入目標**：月目標額與達標率，總覽顯示「本月預計結餘 = 收入目標 − 總預算」。

### 1.5 雲端備份與多裝置同步（FR-Y）
- **帳號授權式同步**：登入 Google 帳號（全平台）或 Apple ID（iOS/macOS）即可，**無需任何同步密碼**。
- 本地優先：離線記帳不中斷，上線自動補同步；觸發時機三選一（每筆自動／節能批次預設／僅手動）＋**啟動必同步一次**。
- 端對端保護：雲端僅存於 App 專屬隱藏資料夾；自動備份每日一次、保留 7 份。
- 跨平台遷移：加密備份檔匯出/匯入（可選檔案密碼），四平台互通。

### 1.6 帳戶與多幣別（FR-A/FR-T）
- 帳戶類型：現金／銀行／信用卡／電子支付（悠遊卡等票證）／其他。
- 支出、收入、轉帳（含儲值/提款語意）、信用卡還款、退款；多幣別記錄（原幣＋匯率，整數運算無浮點誤差）。

### 1.7 定期交易（FR-T5）
- 房租、訂閱等固定收支：到期**推播提醒**，進「待確認」清單確認才入帳（金額可先改）；可跳過單期或刪除排程。

### 1.8 報表與統計（FR-R）
- 總覽儀表板、分類占比、支出趨勢（日/週/月/年）、日曆檢視、全文搜尋（中文）、CSV 匯出（Excel 中文相容）。

### 1.9 安全與隱私（FR-X）
- App 鎖（PIN＋Face ID/Touch ID/指紋/Windows Hello）、本地資料庫加密（SQLCipher）、金額一鍵遮蔽。
- PIN 遺忘可經**重新登入雲端帳號**重設（資料保留）；無廣告追蹤器、無雲端不外傳。

---

## 2. 平台與雲端支援

| 能力 | iOS | Android | macOS | Windows |
|---|---|---|---|---|
| 記帳全功能 | ✅ | ✅ | ✅ | ✅ |
| QR 相機掃描 | ✅ | ✅ | 🔬 Spike | 🔬 Spike（fallback：匯入圖片） |
| OCR | ✅ ML Kit | ✅ ML Kit | ✅ Vision | 🔬 Spike |
| Google Drive 同步 | ✅ | ✅ | ✅ | ✅ |
| iCloud 同步 | ✅ | ❌（無官方 API） | ✅ | ❌ |
| 生物辨識 | ✅ | ✅ | ✅ | ✅（Hello） |

> 跨平台遷移不受限：iCloud 裝置可經「加密備份檔」帶到其他平台。

---

## 3. 快速開始

### 3.1 環境需求
- Flutter SDK ≥ 3.47（stable）／Dart ≥ 3.13
- 各平台工具鏈（Android Studio / Xcode / Visual Studio Desktop workload / Xcode+macOS）

### 3.2 安裝與執行
```powershell
flutter pub get
flutter run                      # 選擇裝置
flutter run -d windows           # Windows
flutter run -d macos             # macOS
flutter run -d <android-device>  # Android
flutter run -d <ios-device>      # iOS
```

### 3.3 測試（TDD 紅綠燈的落點）
```powershell
flutter test                     # 後端（@BE：領域/資料/同步邏輯，PR gate）
flutter analyze                  # 靜態分析（零警告 gate）
pwsh tool/sync_features.ps1      # 同步 BDD feature 檔（specs → test 副本，禁止手改副本）
```

> ⚠️ **本機小技巧**：專案路徑含非 ASCII 字元（如本專案所在的「記帳」資料夾）時，`flutter analyze` 可能崩潰（LSP 已知問題）——改用 `dart analyze`（讀同一份 `analysis_options.yaml`，規則相同）。CI 的 checkout 路徑為 ASCII，不受影響。
- feature 檔分佈：後端 `test/bdd/`、前端 `integration_test/features/`（來源：`specs/plan/tests/`）。
- 標籤分級：`@P0` PR 必跑、`@P1` nightly、`@P2` release 前（見 `specs/plan/tests/README.md` §3）。

---

## 4. 操作方式（App 內主要流程）

### 4.1 第一次使用
1. 開啟 App → 隱私說明頁（資料預設只存本機）。
2. 三選一：**開始使用**（新建帳本）／**從雲端還原**／**匯入備份檔**。
3. 基本設定：幣別（預設 TWD）、語系；建議開啟 App 鎖（PIN＋生物辨識）。
4. （可跳過）**連結雲端**：選 Google Drive 或 iCloud → 登入帳號 → 同意授權 → 立即首次備份。

### 4.2 快速記一筆
1. 點中央「＋」大鈕（桌面：`Ctrl+N`）。
2. 帳戶/分類/時間已智慧預填 → 直接**輸入金額**（必要時點分類格/帳戶/時間修改）。
3. 按**儲存** → 彈出「繼續記下一筆？」：**繼續**（Sticky 欄位保留）／**復原上一筆**／**完成**。

### 4.3 掃發票記帳
1. 點總覽或明細頁的「**掃描**」按鈕（桌面：工具列或 `Ctrl+Shift+S`）。
2. 對準電子發票：先掃**左側 QR**（發票資訊）再掃**右側 QR**（明細）；可連續掃多張。
3. 點「完成掃描」→ 確認清單逐筆檢查（低信賴欄位高亮；**總額必經人工確認**）、選分類帳戶 → 儲存 → 自動跳下一筆。

### 4.4 信用卡週期
1. **記錄**：快記時選信用卡 → 輸入金額儲存 →「本期應付」立即累加（銀行餘額不變）。
2. **結帳**：結帳日當天起首次開啟 App 時自動彙總帳單並通知。
3. **繳款**：點通知或信用卡頁 → 全額／部分／自訂金額 → 確認後從連結帳戶產生還款轉帳。
4. 逾期帳單持續標示於卡頁首（v1 不計息）。

### 4.5 預算與收入目標
1. 預算頁 →「＋」新增總預算/分類預算（起始日可自訂）或收入目標。
2. 記帳後進度條即時更新；跨越 80%/100%/超支時收到通知（每級每期一次）。

### 4.6 雲端同步
- **自動**：開啟 App 必同步一次；依設定模式（每筆自動／節能批次／僅手動）持續同步。
- **手動**：設定→雲端與同步→「立即同步」；同步狀態頁可查看各裝置、待同步筆數與衝突檢視。
- **換裝置**：新裝置登入**同一帳號**→「從雲端還原」即可（不需任何密碼）。

### 4.7 定期交易
1. 設定定期交易（房租/訂閱：金額、帳戶、週期）。
2. 到期日推播提醒 → 待確認清單 →「確認入帳」（可先改金額）／「本次跳過」／「刪除排程」。

### 4.8 安全
- 鎖定：設定→安全→App 鎖（PIN＋生物辨識，背景逾時門檻可調）。
- 忘記 PIN：鎖定畫面→「忘記 PIN」→重新登入雲端帳號→設定新 PIN（資料保留）。
- 遮蔽：總覽頁 👁 一鍵遮蔽所有金額。

---

## 5. 專案結構

```
lib/
├── main.dart              # 入口（M0 骨架頁）
├── core/                  # Money、HLC、通用工具（平台無關）
├── domain/
│   ├── entities/          # Account、Tx 等實體（SDD §4）
│   └── services/          # BalanceCalculator、（M3+）BillingCycle…
├── application/           # UseCase 編排（SaveTransaction、SyncCoordinator…）
├── data/
│   ├── drift/             # Drift 表/DAO（schema 對齊 specs/truth/data-spec.dbml）
│   ├── repositories/      # Repository 實作
│   └── sync/              # OpLog、BundleBuilder/Applier（SDD §5.5）
├── platform/              # 平台抽象實作（cloud/drive、cloud/icloud、ocr、secure）
└── presentation/          # 畫面與 Widget（對映 specs/plan/ui/ 雛型）

test/
├── core/  domain/         # 後端單元測試（PR gate）
├── bdd/                   # BDD feature 檔副本（來源 specs/plan/tests/backend/，勿手改）
└── helpers/               # T-H 測試掛鉤（fake clock、in-memory cloud、notification spy）

integration_test/
├── features/              # 前端 BDD feature 檔副本（來源 specs/plan/tests/frontend/）
└── helpers/

specs/
├── plan/                  # 規劃：research、tasks、ui 雛型、tests（FE/BE+dsl）、acceptance、debug
└── truth/                 # 事實來源：techstack、api-spec（P2 草案）、data-spec（schema 唯一依據）
```

**分層依賴方向**：presentation → application → domain；data/platform 實作介面（依賴反轉，SDD §2.1）。

---

## 6. 文件地圖

| 類別 | 檔案 | 說明 |
|---|---|---|
| 需求 | `SPEC.md` | 功能需求（FR-A~O）、非功能（NFR）、流程、通知總表、驗收場景 |
| 設計 | `SDD.md` | 架構、資料模型、帳單引擎、同步協議、安全設計 |
| 行為 | `BDD.md` | Gherkin 情境總集＋AC 追溯矩陣 |
| 驗收 | `specs/plan/features/acceptance/` | PM 驗收標準（10 檔 76 情境＋README） |
| 測試 | `specs/plan/tests/` | 前後端自動化 feature 檔＋步驟 DSL（dsl.md） |
| 研究 | `specs/plan/research.md` | 技術決策 D1~D14、Sprint 計畫、Spike 清單 |
| 任務 | `specs/plan/tasks.md` | 開發任務分解、版控規範、TDD 紅綠藍燈、truth 對齊 |
| 除錯 | `specs/plan/debug.md` | Debug Todolist（DBG-NNN 追蹤） |
| 雛型 | `specs/plan/ui/` | 初步 UI HTML（附規格便利貼） |
| 事實 | `specs/truth/` | techstack（原始碼棧）/ api-spec（P2 草案）/ data-spec（schema 唯一依據） |
| 工作 | `session.md` | 休息交接：目前快照＋下一步＋歷程 |

---

## 7. 開發規範速覽

| 主題 | 規則 | 詳見 |
|---|---|---|
| 分支 | **一個功能一條分支** `feature/F{nn}-{slug}`，`--no-ff` merge 回 main | tasks.md §0.1 |
| Commit | 每個情境紅綠燈循環 ≥1 commit；`type(scope): subject` | tasks.md §0.1 |
| TDD | 🔴 紅燈（先寫失敗測試）→ 🟢 綠燈（最小實作）→ 🔵 藍燈（重構，不得動 truth） | tasks.md §1 |
| 文件同步 | 功能修正必同步 SDD/BDD/TDD/DDD 相關檔案（矩陣檢查，未同步不可合併） | tasks.md §7 |
| truth | schema/API/棧變更**先改 truth 再改碼**；T-H9 自動對齊測試 | tasks.md §5 |
| 除錯 | `specs/plan/debug.md` 建 DBG-NNN 條目；每條目至少一個回歸情境 | tasks.md §4.3 |
| 交接 | 休息前更新 `session.md`；恢復工作依其 SOP | session.md |

---

## 8. 路線圖

| 里程碑 | 內容 | 狀態 |
|---|---|---|
| M0 | 規劃文件集 v0.3＋專案骨架 | ✅ 骨架完成 |
| M1 | 核心本地記帳（帳戶/分類/交易/快記） | 🚧 開發準備 |
| M2 | 預算收入目標＋報表＋桌面適配 | ☐ |
| M3 | 信用卡帳單引擎＋分期 | ☐ |
| M4 | 發票掃描（QR＋OCR） | ☐ |
| M5 | 雲端備份（Drive，帳號授權）＋備份檔遷移 | ☐ |
| M6 | 多裝置同步＋iCloud＋定期交易 | ☐ |
| M7 | 安全打磨＋四平台上架 | ☐ |

---

## 9. 隱私與安全承諾

- 資料**預設只存在裝置**；未連結雲端時 App 不出網（可抓包驗證）。
- QR／OCR 全部本機運算；無廣告、無第三方追蹤器。
- 雲端同步以**你的帳號授權**為準（建議開啟兩步驟驗證）；檔案存於 App 專屬隱藏資料夾，其他 App 不可見。

## 10. 問題回報

- 開發中缺陷：見 `specs/plan/debug.md` 追蹤表。
- 文件與程式碼不一致 → 視為 Blocker（以 `specs/truth/` 為準修復）。
