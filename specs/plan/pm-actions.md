# PM 行動清單（PM Actions）

| 項目 | 內容 |
|---|---|
| 用途 | 彙整**只有 PM（產品負責人）能處理**的外部服務申請、帳號開通、憑證提供與產品決策——開發端已備妥接線點，取得資訊即可接上 |
| 文件版本 | v0.1（2026-10-22） |
| 關聯文件 | `commercialization.md`（Google 憑證細節／付費模式）、`tasks.md` §4.2（排程）、`debug.md`（技術缺陷）、`session.md`（當前進度） |
| 對象 | PM；技術細節可轉交開發解惑 |

> **一句話總結**：本地端功能已全部完成並通過測試（單位 104 綠、FE 全回歸 10/10）；**唯一阻擋上架的是外部憑證／帳號**（Google OAuth 審核、商店開發者帳號）＋幾項產品決策。以下依優先序排列。

---

## 1. ⚠️ 最高優先：Google OAuth／Drive 憑證（阻擋「雲端同步」上線）

**為什麼卡**：使用者按「連結 Google Drive」時，Google 要確認「是哪個 App 在要權限」——這個 App 身分（OAuth Client ID）必須由您在 Google Cloud Console 建立。**一次性設定，之後不用維護**。

### 1.1 您要做的事（Google Cloud Console，約 40 分鐘＋審核等待）

| # | 動作 | 說明 | 預估 |
|---|---|---|---|
| 1 | 建立 Google Cloud 專案 | 名稱建議「LedgerSync」 | 5 分 |
| 2 | 啟用 **Google Drive API** | API 程式庫 → 搜尋 → 啟用（免費額度足夠，**不需計費**） | 5 分 |
| 3 | 設定 OAuth 同意畫面（consent screen） | User type＝**外部**；App 名稱、**支援 email**、**隱私權政策 URL**；scope 填 `https://www.googleapis.com/auth/drive.appdata` | 15 分 |
| 4 | **送交 Google 審核**（sensitive scope） | 需填用途說明＋（可能）示範影片；**審核數天～數週**。未過審前可先加「測試使用者」（≤100 帳號）內部測試 | ⚠️ 排程關鍵 |
| 5 | 建立 OAuth Client ID **×3** | ①**Android**：套件名＋SHA-1 指紋 ②**iOS**：bundle id ③**Web application**（桌面 loopback 用）：redirect URI | 15 分 |
| 6 | 把憑證交給開發 | Client ID／Secret（**勿入 git**——見 §7） | — |

**您需要的現成識別碼**（開發提供，直接填入 Console）：

| 平台 | 識別碼 |
|---|---|
| Android | 套件名 `com.ledgersync.ledger_sync`（SHA-1 待提供——產生 release keystore 後，見 §2） |
| iOS | bundle id `com.ledgersync.ledgerSync` |
| macOS／Windows（桌面） | 需建立 **Web application** client；redirect URI 由開發提供（loopback，`http://127.0.0.1:<port>`） |
| scope | `https://www.googleapis.com/auth/drive.appdata`（App 專屬隱藏資料夾——**看不到使用者的其他雲端硬碟檔案**） |

### 1.2 開發端現況（讓您知道依賴關係）

| 項目 | 狀態 |
|---|---|
| `GoogleDriveAdapter`（Drive v3＋appDataFolder 路徑映射／覆寫冪等／清單語意） | ✅ 完成＋**9 項單元測試綠** |
| `main()` 生產接線（db／附件目錄／裝置 id／雲端 provider） | ✅ 完成（**憑證未設定時優雅降級——不崩**） |
| 未設定時的 UI 提示（「雲端功能尚未設定（Google 憑證未就緒）」） | ✅ 完成 |
| `DriveApi` 真實實作（`googleapis` REST 呼叫） | ⏳ **等憑證**（介面已定，換實作即可） |
| OAuth 登入（行動 `google_sign_in`／桌面 loopback） | ⏳ **等憑證** |
| 套件追加（`googleapis`／`googleapis_auth`／`google_sign_in`）＋ techstack 版本 | ⏳ **需您簽核**（truth 先行原則） |

### 1.3 您**不需要**做的事（避免多花時間）

- ❌ 不需要「使用者帳號審核認證」——App 是使用者授權**他自己的** Google 帳號。
- ❌ 不需要 GCP 計費帳號（Drive API 免費額度遠超本 App 用量）。
- ❌ 不需要自架伺服器／後端（純 App 直連 Google，無中介伺服器）。

### 1.4 連網權限（開發端已備——供您實機驗證參考）

| 平台 | 設定 | 狀態 |
|---|---|---|
| macOS | 沙箱需 `network.client`（連外）＋`network.server`（桌面 OAuth loopback 本地監聽） | ✅ 已加入 `DebugProfile.entitlements`／`Release.entitlements` |
| Android | **release 版需 `INTERNET` 權限**（Flutter 範本只在 debug/profile 內建） | ✅ 已加入 `AndroidManifest.xml`（main） |
| iOS／Windows | 預設即可連外（HTTPS） | ✅ 無需變更 |

> 若憑證到位後某平台同步失敗，先檢查此表對應項——這是最常見的「程式沒錯但連不出去」原因。

---

## 2. 商店開發者帳號與簽章（上架必需）

| # | 項目 | 費用 | 用途 | 狀態 |
|---|---|---|---|---|
| 1 | **Apple Developer Program** | US$99／年 | iOS 上架＋macOS notarization 憑證（否則使用者開啟會被阻擋） | ☐ 需您申請 |
| 2 | **Google Play Console** | US$25 一次性 | Android 上架 | ☐ 需您申請 |
| 3 | **Android release keystore** | 免費 | Android 簽章（**丟失即無法更新 App**——請妥善備份） | ☐ 可由我產生後交您保管，或您自行產生 |

> 目前 CI 已能自動產出四平台產物，但為**未簽名**版本（ipa／exe／dmg／apk）——正式上架必須簽章。

---

## 3. 商業化（可選；需您決策後才動工）

`commercialization.md` §2 已列四種付費模式。若要變現，需您先決定模式；若選「訂閱制」，還需加開：

| 項目 | 用途 | 備註 |
|---|---|---|
| App Store 內購／Google Play 訂閱 | 兩商店訂閱 | 分開設定 |
| RevenueCat 帳號（可選） | 統一管理跨平台訂閱（最省工） | 月交易額 $2.5k 內免費 |

> 若暫不變現，可先略過——不影響上架。

---

## 4. 待您決策的產品事項

| # | 決策 | 背景 | 影響 |
|---|---|---|---|
| 1 | **首次啟動引導頁（新建/還原/匯入）** | F09 清空完成頁文案承諾「下次啟動回到首次設定（新建/還原/匯入）」，但目前首啟是**自動建立內建分類＋現金帳戶**直接進主畫面 | 是否要做獨立引導頁？（新增 UI 範圍） |
| 2 | **NFR-03 定義** | `research.md` 提到效能抽查含 NFR-03，但找不到其定義 | 效能複測少一項 |
| 3 | **acceptance F03 測資字串修正（76→77 碼）** | 對齊欄位對照表與 T-H6 金測所做的規格修正 | 需您複核後關閉 |
| 4 | **深色模式走查** | UI 統整已以 token 覆蓋（保證無硬編碼色），逐頁視覺需您確認 | 建議在下一版 Release 截圖走查 |
| 5 | 多幣別 900／`notify_enabled=off` 語意 | M2 遺留語意待確認 | 小範圍 |

---

## 5. 驗收走查（需您／QA 簽核）

| 項目 | 說明 |
|---|---|
| acceptance F08（App 鎖）／F09（資料管理）簽核區 | 空白——需實際走查後簽核 |
| F03（發票掃描）走查 | 需先補 **SP-2b 行動相機**（實機相機接線） |
| 四平台實機 | Release 產物已自動建置（GitHub Releases）；gh CLI 未安裝，需網頁下載或補裝 |

---

## 6. 需要您提供的資訊彙總（提供後我能立刻接上）

| # | 資訊 | 用途 | 從哪取得 |
|---|---|---|---|
| 1 | Google OAuth **Client ID ×3**（Android／iOS／Web） | 雲端連結（各平台） | Google Cloud Console §1.1 |
| 2 | Google OAuth **Client Secret**（Web/桌面） | 桌面 loopback 登入 | 同上 |
| 3 | **Android release keystore**（或授權我產生） | 上架簽章 | 您保管／我產生 |
| 4 | **Apple Team ID**＋簽章憑證 | iOS/macOS 簽章 | Apple Developer |
| 5 | **隱私權政策 URL**＋支援 email | OAuth 同意畫面送審必需 | 您提供網頁（我可提供文案草稿） |
| 6 | 商店 listing（App 名稱、圖示、說明） | 上架 | 我可提供草稿，您定稿 |

---

## 7. 憑證注入方式（技術；您只需知道「不要進 git」）

- **本機測試**：
  `flutter run --dart-define=GOOGLE_OAUTH_CLIENT_ID=<id> --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=<secret>`
- **CI（GitHub Actions）**：存為 GitHub Secrets，由 workflow 以 `--dart-define` 注入。
- **絕對不要** commit 到 git（已於本文件標示）；若憑證外洩，請在 Console 撤銷並重新產生。
- 未設定時 App **不會崩**，只會顯示「雲端功能尚未設定」——本地記帳功能完全不受影響。

---

## 8. 建議執行順序（PM 視角）

1. **今天**：啟動 §1.1 步驟 1-4（送審等待最久）＋§3 Google Play 帳號（數天）。
2. **本週**：§2 Apple Developer；產生 release keystore（我可代勞）。
3. **等待期**：§4 決策（尤其 #1 首次啟動引導頁）＋§5 驗收走查。
4. **憑證到位**：交給我 → 我接 DriveApi／OAuth（約 1-2 天）→ 真機端對端驗證 → 上架。
---

## 9. 2026-10-22 分類體系決策記錄（已實作）

| 決策 | 內容 | 狀態 |
|---|---|---|
| **主類別集定稿** | 支出 14：餐飲食品/服飾美容/居家生活/交通運輸/教育學習/休閒娛樂/3C通訊/圖書刊物/汽機車/醫療保健/人情交際/理財投資/其他/費用；收入 2：一般收入/投資收入 | ✅ 已播種＋truth 更新 |
| 轉帳 | 為交易類型（快記已支援支出/轉帳/拆帳模式），不需分類列 | ✅ 無需變更 |
| 主/子分類頁 | 分類管理頁改階層結構：主類別群組（可折疊）＋子分類縮排＋子分類可拖曳 | ✅ 已實作 |
| 常用類別區 | 快記分類選擇器最上方常駐「常用」：最近使用前 10 個（新→舊） | ✅ 已實作 |
| **子分類預設清單** | 全部主類別都要配預設子分類——**待您提供每個主類別的子分類清單**（您已給 餐飲食品→早餐/中餐/晚餐/下午茶/宵夜/水果/食材 範例） | ⏳ 待提供 |
| **既有測試裝置** | 主類別集變更只影響「全新安裝」；已安裝裝置請用 設定→資料管理→清空資料 後重啟（自動以新分類集重播種） | ⚠️ 需您操作一次 |
