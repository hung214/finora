# LedgerSync 安裝說明（直接下載版）

> 適用版本：**v0.4.16**（含完整本機記帳功能；雲端同步保留介面，未設定時不影響任何本機功能）
> 下載頁：**[Releases](https://github.com/hung214/ledger_sync/releases/latest)** → Assets 選對應平台檔案

| 平台 | 檔案 | 安裝方式 |
|---|---|---|
| **Android** | `LedgerSync-android-0.4.16.apk` | 下載後點開 → 允許「安裝未知來源應用」→ 安裝 |
| **macOS** | `LedgerSync-macos-0.4.16.dmg` | 下載後雙擊 → 拖曳 App 到「應用程式」→ **第一次開啟請在圖示上按右鍵→「打開」**（未公證簽章的一次性步驟） |
| **Windows** | `LedgerSync-setup-0.4.16.exe`（安裝版）／`LedgerSync-windows-x64-0.4.16.zip`（免安裝可攜） | exe：雙擊安裝（per-user，不需管理員）；zip：解壓後直接執行 `ledger_sync.exe` |
| **iOS** | `LedgerSync-ios-0.4.16.ipa`（未簽名） | ⚠️ 需側載工具（AltStore／Sideloadly＋自己的 Apple ID，每 7 天重簽）——**建議先用 Android/macOS/Windows** |

## 各平台注意事項

### Android（推薦）
- 安裝時 Play Protect 可能顯示「未知開發者」警告 → 點「**仍要安裝**」（未上架 Google Play 的正常現象）
- 資料存在本機（app 私有目錄），解除安裝會一併刪除——重要資料請用「設定→資料管理」或雲端備份

### macOS（推薦）
- Gatekeeper 提示「無法驗證開發者」→ 右鍵→打開→再點「打開」（只要一次）
- 資料位置：沙箱 `~/Library/Containers/…/Documents/`（App 內可直接匯出）

### Windows
- SmartScreen 可能攔截 → 「**更多資訊**」→「仍要執行」
- 免安裝 zip 版資料放在 exe 同目錄，適合隨身碟

### iOS
- 未簽名 IPA **無法直接安裝**（Apple 限制），需電腦＋側載工具＋個人 Apple ID（免費帳號 7 天需重簽；付費開發者帳號一年）
- 這是暫不申請開發者/商店帳號的已知取捨——要長期使用 iOS 版，之後再談正式管道

## 首次啟動

1. 開 App → 自動建立「現金」帳戶＋內建分類集（支出 14 主類別×子分類 61 項＋收入 2）
2. 快記一筆：輸金額→選分類→儲存
3. 設定→外觀：明亮／暗色／跟隨系統
4. （可選）設定→帳戶管理：加銀行/電子支付帳戶；「不計入合併統計」開關適用於緊急金等

## 雲端同步（目前狀態）

- 介面完整保留（設定→雲端同步），**未設定憑證前會顯示「雲端功能尚未設定」**
- 不設定**完全不影響**本機記帳、統計、預算、分類等功能
- 未來開通後即可雙向同步（屆時不需重新安裝）

---

**版本**：v0.4.16（2026-10-22）｜ 更新內容見 [Releases](https://github.com/hung214/ledger_sync/releases)
