# 商業化與外部服務憑證說明（付費綁定＋Google 雲端）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.1（初版） |
| 對象 | PM——本文件列出**需要您親自辦理的事項**（⚠️ 標注）與開發側對應 |
| 定位 | 外部服務憑證申請指南＋付費綁定（商業化）選項說明；架構對映見 SDD §6/§7、techstack §4 |
| 原則 | **使用者帳號不需任何「認證/認定」**——App 取得的是使用者授權（存取他自己的雲端硬碟應用資料夾）；多裝置身分邊界＝同一帳號的雲端空間，email 僅供畫面顯示 |

---

## 1. Google 雲端同步——App 憑證申請

### 1.1 為什麼需要（一句話）

使用者按「同意授權」時，Google 會顯示「**LedgerSync** 想要存取你的雲端硬碟應用資料夾」——這個 App 身分需要開發者端的憑證（OAuth client），**一次性設定，之後不用維護**。

### 1.2 ⚠️ PM 動作清單（Google Cloud Console，建議 M5 期間啟動——審核有時程）

| # | 步驟 | 說明 | 估時 |
|---|---|---|---|
| 1 | 建立 Google Cloud 專案 | 專案名建議「LedgerSync」 | 5 分鐘 |
| 2 | 啟用 **Drive API** | API 程式庫 → 搜尋 Google Drive API → 啟用 | 5 分鐘 |
| 3 | 設定 OAuth consent screen | User type=外部；App 名稱＋支援 email；**scope 填 `drive.appdata`** | 15 分鐘 |
| 4 | 準備兩個網頁 URL | 隱私權政策＋服務條款（consent screen 必填——**需先備簡單網頁**，可暫放專案官網/GitHub Pages） | ⚠️ 視網頁準備 |
| 5 | **送交 Google 審核** | `drive.appdata` 屬 sensitive scope——需填寫用途說明＋（可能）錄 demo 影片；**審核數天~數週**。未過審前僅「測試使用者」（100 帳號內）可用——內部測試足夠 | ⚠️ 排程關鍵 |
| 6 | 建立 OAuth client ID ×3 | ①Android（套件名＋SHA-1 憑證指紋——開發提供）②iOS（bundle id——開發提供）③Web Application（桌面 loopback 的 redirect URI——開發提供） | 15 分鐘 |
| 7 | 憑證交付 | client ID／secret 或 google-services 設定檔交給開發（勿入 git——放安全處） | — |

> **可先以「測試模式」運作**：未過審前把測試帳號加進 consent screen 的 test users，開發與內測完全可用——**不阻塞 M5/M6 開發**；正式上架（M7）前過審即可。

### 1.3 開發側對應（不需 PM）

- `GoogleDriveAdapter`（Drive REST v3、appDataFolder）＋ `google_sign_in`（行動）/loopback OAuth（桌面）接線
- 憑證以 `--dart-define`／平台設定檔注入（不入版控）
- 真機端對端驗證（憑證到位後）

### 1.4 ✅ 不需要 PM 做的（常見誤解釋清）

- ❌ 不需要「認證/審核使用者」——使用者授權**他自己的** Google 帳號
- ❌ 不需要拿使用者帳號當 App 內 ID——多裝置身分＝同一帳號的雲端空間（appDataFolder），email 僅畫面顯示
- ❌ 不需要同步密碼——帳號授權式同步（SPEC FR-Y7 定案）

---

## 2. 付費綁定方式（商業化選項）

### 2.1 四種模式比較

| 模式 | 機制 | 抽成/成本 | 適合 | 架構影響 |
|---|---|---|---|---|
| **① 平台內購訂閱**（Play Billing＋App Store IAP） | 各商店購買，App 驗收據解鎖 | 15%（小型開發者）~30% | 行動訂閱 | **跨平台不通**：Play 買的 iOS 認不得 |
| **② RevenueCat**（包裝①） | 統一管理兩商店訂閱，跨平台 entitlement 一致 | 月交易額 $2.5k 內免費 | **跨平台訂閱——最省工** | 需 App User ID（可匿名＋對映 Google 帳號）；需申請 RevenueCat 帳號 ⚠️ |
| **③ 授權碼買斷** | 官網付款→寄授權碼→App 輸入解鎖（離線簽名驗證） | 金流 ~2-3% | 桌面買斷 | **最簡**——無後端（Ed25519 離線驗證） |
| **④ 自建帳號＋金流**（Stripe/藍新/綠界） | Web 訂閱→登入解鎖全平台 | 金流 ~3%＋後端維運 | 需帳號中心 | **需建後端**——與「無帳號、雲端空間即身分」設計張力最大 |

### 2.2 與現有架構的銜接

- 現有設計**無帳號系統**（雲端空間即身分，M5 已落地）
- **②③與現有設計相容**：付費權利（entitlement）可寫入 `vault.json`（M5 已有）→ 同帳號裝置自動共享 Pro 狀態；本地驗證存 OS SecureStorage（SDD §7.1 既有層）
- **④需重新設計身分**——若商業上需要帳號中心再評估

### 2.3 ⚠️ 需要您決策的點（M7 上架前即可，不阻塞現有開發）

| # | 決策 | 選項 |
|---|---|---|
| 1 | **訂閱 vs 買斷** | 訂閱→建議②RevenueCat；買斷→建議③授權碼 |
| 2 | **定價** | 免費/Pro 分界功能（候選：雲端同步本身？多裝置？備份份數？） |
| 3 | 若選② | RevenueCat 帳號申請 ⚠️（10 分鐘）＋兩商店商品設定 ⚠️ |

### 2.4 架構預留（開發側，低承諾）

entitlement 欄位預留於 `vault.json`（一行註記，不改行為）——M7 實作時依決策填入。

---

## 3. 商店帳號（M7 上架用——⚠️ 申請時程長，可提早辦）

| 帳號 | 費用 | 審核 | 備註 |
|---|---|---|---|
| Apple Developer | $99/年 | 1-2 天 | iOS 上架＋notarization 憑證（macOS）必需 |
| Google Play | $25 一次性 | 數天 | Android 上架必需 |
| Microsoft Store | 個人 $19 一次性 | 數天 | Windows（或走官網 exe/zip 直接發佈——現行 release 流程已支援） |

---

## 4. 行動清單總表（誰＋何時）

| # | 事項 | 誰 | 建議時點 | 狀態 |
|---|---|---|---|---|
| 1 | Google Cloud 專案＋Drive API＋consent screen＋**送審** | ⚠️ PM | M5 期間（審核時程） | ☐ |
| 2 | 隱私權政策/服務條款網頁 | ⚠️ PM（內容可由開發起草） | 隨 #1 | ☐ |
| 3 | OAuth client ID ×3（開發提供套件名/SHA-1/bundle id 後建立） | ⚠️ PM（輸入由開發提供） | 隨 #1 | ☐ |
| 4 | GoogleDriveAdapter＋OAuth 接線＋真機驗證 | 開發 | 憑證到位後 | ☐ |
| 5 | 付費模式決策（訂閱/買斷＋定價＋分界功能） | ⚠️ PM 決策 | M7 前 | ☐ |
| 6 | RevenueCat（若選②）或金流（若選③/④）申請 | ⚠️ PM | 隨 #5 | ☐ |
| 7 | Apple Developer／Google Play 帳號申請 | ⚠️ PM | M7 前（可提早） | ☐ |
| 8 | entitlement 預留（vault.json 註記） | 開發 | 隨時（一行） | ☐ |
| 9 | GoogleDriveAdapter 實作（骨架先行） | 開發 | 可與 M5 並行 | ☐ |

---

## 5. 變更記錄

| 日期 | 版本 | 摘要 |
|---|---|---|
| 2026-10-21 | v0.1 | 初版：Google 憑證申請指南（PM 動作 ⚠️ 標注）＋付費綁定四模式＋行動清單 |
