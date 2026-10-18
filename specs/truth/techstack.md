# Tech Stack — 原始碼單一事實來源（Source of Truth）

| 項目 | 內容 |
|---|---|
| 文件版本 | v0.3.1（S0 實鎖版本回寫） |
| 日期 | 2026-10-18 |
| 性質 | **原始碼技術棧的唯一事實來源**。SDD §3 為設計說明；本檔記錄「將寫進程式碼」的定案（含版本）。兩者不一致時以本檔為準並回修 SDD |
| 變更規則 | 僅能經 PR 變更；新增/升級依賴需通過授權審查（research.md D14）+ 全測試綠燈；每次變更記錄於 §8 變更記錄 |
| 來源 | 定案依據見 `specs/plan/research.md` §3（D1~D14）；未定案項（🔬）以「暫定」標示，Spike 後回填 |

---

## 1. 架構定位：前端與「後端」

```
┌─ 前端（App）＝ Flutter 單一程式碼庫 ─────────────────────┐
│  presentation / application / domain / data（SDD §2）     │
│  本地事實來源：SQLite（SQLCipher）＋ FTS5                  │
└──────────────┬───────────────────────────────────────────┘
               │ OAuth / 平台 SDK / Platform Channel
┌─ 「後端」＝ 無自建伺服器，由外部服務承擔 ─────────────────┐
│  Google Drive API v3（drive.appdata 檔案儲存，全平台）      │
│  CloudKit private DB（iCloud，僅 iOS/macOS）               │
│  OS 服務：Keychain/Keystore/DPAPI、通知、生物辨識、相機     │
└──────────────────────────────────────────────────────────┘
預留（P2，屆時更新本檔）：Supabase / Firebase（即時同步、家庭共享）
```

> 註：本專案為**本地優先**架構，「後端」指外部雲端/平台服務；若 P2 引入自建後端，於本檔新增 §「後端服務」並升版。

---

## 2. 核心棧（版本鎖定）

### 2.1 語言與框架

| 層 | 技術 | 版本 | 備註 |
|---|---|---|---|
| 語言 | Dart | 3.13.5 stable（CI 鎖定） | null-safety 強制 |
| 框架 | Flutter | 3.47.7 stable（環境實測） | 四平台（research D1） |

### 2.2 App 分層依賴（前端）

| 層 | 套件 | 版本 | 用途 | 對應 |
|---|---|---|---|---|
| presentation | flutter_riverpod / riverpod_annotation | 2.6.1 | 狀態管理（D3） | SDD §3 |
| presentation | go_router | 14.8.1 | 路由（桌面分欄/深連結） | SDD §3 |
| presentation | fl_chart | 0.69+ | 圖表（D10） | SDD §3 |
| application | flutter_local_notifications | 17.x | 本機通知 N-1~N-10（D9） | SDD §5.2/5.3 |
| application | workmanager | 0.5.x | 僅 Android 背景加值（可選，不依賴） | SDD §5.2 |
| domain | freezed / json_serializable | 2.5.8 | 實體/OpBundle 模型 | SDD §4 |
| domain | intl | 0.20.3 | 多語系/幣別格式 | FR-O1 |
| domain | uuid | 4.6.0 | UUIDv7（交易/實體 ID） | SDD §4.2 |
| data | drift / drift_dev | 2.28.2 | SQLite ORM + Reactive Streams + migration（D2） | SDD §4.2 |
| data | sqlite3_flutter_libs | 0.5.42 | 四平台 SQLite 原生庫 | — |
| data | sqlcipher_flutter_libs | 0.7.0+eol（⚠ 套件已標 EOL → SP-1 強化評估） | DB 加密（FR-X2，D2） | SDD §7 |
| data | cryptography | 2.9.0 | AES-256-GCM（D8；Argon2id 僅備份檔密碼用，效能見 research TR-4） | SDD §7 |
| core | flutter_secure_storage | 9.2.4 | DB 金鑰/OAuth token（Keychain/Keystore/DPAPI） | SDD §7.1 |
| core | local_auth | 2.3.0 | 生物辨識 App 鎖（FR-X1） | SDD §7.2 |

### 2.3 功能套件

| 能力 | 套件/技術 | 平台 | 版本/狀態 | 對應 |
|---|---|---|---|---|
| QR 掃描 | mobile_scanner | iOS/Android | 5.x ✅ | SDD §5.4 |
| QR 掃描（桌面） | 相機取幀 channel + ZXing（暫定 zxing FFI 綁定） | Windows/macOS | 🔬 SP-2b；fallback＝相簿匯入 | FR-S6 |
| OCR | google_mlkit_text_recognition（中文模型） | iOS/Android | 最新 stable ✅ | SDD §5.4 |
| OCR | Apple Vision（VNRecognizeTextRequest，platform channel） | macOS | 自寫 channel ✅ | SDD §5.4 |
| OCR | Windows.Media.OCR（platform channel） | Windows | 自寫 channel 🔬 SP-3 | SDD §5.4 |
| 雲端 | googleapis（Drive v3）+ google_sign_in | 行動 | 最新 stable ✅ | SDD §6 |
| 雲端 | googleapis + oauth2（loopback flow） | Windows/macOS | 🔬 SP-4 | SDD §6 |
| 雲端 | flutter_cloud_kit（或自寫 channel） | iOS/macOS | 🔬 SP-5 評估後定 | SDD §6 |
| 搜尋 | SQLite FTS5 + 中文 bigram 影子欄位 | 全平台 | 🔬 SP-1 | FR-R3 |
| 打包 | MSIX（Windows）／DMG+notarization（macOS） | 桌面 | 🔬 SP-7 | SDD §11 風險 |

### 2.4 開發與測試工具

| 用途 | 工具 | 版本 |
|---|---|---|
| 測試 | flutter_test、mocktail、integration_test | mocktail 1.0.5（lock） |
| BDD | flutter_gherkin（步驟定義掛接 BDD.md） | 3.x |
| Codegen | build_runner（drift_dev/freezed/json_serializable） | build_runner 2.5.4（lock） |
| CI | GitHub Actions（analyze/unit/integration-P0/四平台 build） | — |
| 發佈 | Codemagic 或 Fastlane（iOS 簽名/上架） | 🔬 SP-7 |

---

## 3. 平台功能矩陣（實作定案對映）

| 能力 | iOS | Android | macOS | Windows | 對應 |
|---|---|---|---|---|---|
| 本地 DB（SQLCipher+FTS5） | ✅ | ✅ | ✅ | ✅ | FR-X2/R3 |
| QR 相機掃描 | ✅ mobile_scanner | ✅ mobile_scanner | 🔬 SP-2b | 🔬 SP-2b | FR-S1/S2 |
| 相簿/檔案匯入辨識 | ✅ | ✅ | ✅ | ✅ | FR-S8/S6 |
| OCR | ✅ ML Kit | ✅ ML Kit | ✅ Vision | 🔬 SP-3 | FR-S3 |
| Google Drive 同步 | ✅ | ✅ | ✅ | ✅（SP-4） | FR-Y1 |
| iCloud 同步 | ✅ | ❌（UI 明示） | ✅ | ❌（UI 明示） | FR-Y1/SPEC §4 |
| 生物辨識鎖 | ✅ Face/Touch | ✅ 指紋/臉 | ✅ Touch ID | ✅ Hello | FR-X1 |
| 本機通知 | ✅ | ✅ | ✅ | ✅ | §8 通知總表 |
| 安裝包 | IPA (App Store) | AAB (Play) | DMG（notarized） | MSIX | SP-7 |

---

## 4. 外部服務與帳號清單

| 服務 | 用途 | 關鍵設定 | 風險/排程 |
|---|---|---|---|
| Google Drive API v3 | 檔案式同步/備份 | scope=`drive.appdata`；OAuth consent 需驗證（sensitive） | S8 前送審；備選 `drive.file`（research TR-3） |
| CloudKit | iCloud 同步 | private database、CKAsset；Apple Developer 帳號 | 速率配額；附件去重已內建 |
| 財政部電子發票 QR 規格 | 解析依據（非 API） | 依官方規格文件實作 parser，樣本測試集維護 | 規格變動 → parser 版本化（SDD R6） |
| 商店帳號 | 上架 | App Store / Google Play / Microsoft Store / macOS notarization 憑證 | 待申請（S8 起辦理） |

---

## 5. 編碼規範要點（與 tech stack 綁定）

1. 金額一律 `int` minor units（自訂 Money VO），禁用 double 運算金額。
2. 業務表必含 `created_at/updated_at/hlc/deleted_at`（SDD §4.2 通用欄位）；刪除一律軟刪除。
3. 寫入業務表必同步追加 oplog（同一 DB transaction，SDD §5.1）。
4. 平台能力一律經抽象介面（CloudStorageAdapter/ReceiptRecognizer/BiometricLock），禁止在 presentation 直接呼叫 platform channel。
5. 桌面視窗與快捷鍵行為遵守 SDD §8 IA（`Ctrl+N`/`⌘N`、`Ctrl+Shift+S`/`⌘⇧S`）。

---

## 6. 未定案項（Spike 後回填）

| # | 項目 | Spike | 回填位置 |
|---|---|---|---|
| 1 | 桌面 QR：ZXing FFI vs 僅匯入 | SP-2b | §2.3 |
| 2 | Windows OCR channel 細節 | SP-3 | §2.3 |
| 3 | iCloud：flutter_cloud_kit vs 自寫 channel | SP-5 | §2.3 |
| 4 | 發佈鏈：Codemagic vs Fastlane | SP-7 | §2.4 |
| 5 | FTS5 中文 bigram 細節 | SP-1 | §2.3 |
| 6 | Argon2：cryptography 純 Dart vs FFI libargon2 | SP-4 附測 | §2.2 |
| 7 | SQLCipher 四平台整合（sqlcipher_flutter_libs 0.7.0+eol 已標 EOL） | SP-1（強化） | §2.3 |

## 7. 版本升級流程
1. 於分支升級依賴 → 全測試 + 四平台 build → acceptance 抽測 P0 情境。
2. PR 更新本檔版本表 + §8 變更記錄（日期/版本/變更/PR 連結）。
3. 同步回修 SDD §3（若技術選型描述受影響）。

## 8. 變更記錄

| 日期 | 版本 | 變更 | PR |
|---|---|---|---|
| 2026-10-18 | v0.3 | 初版：依 research.md D1~D14 定案寫入；未定案項標 🔬 | — |
| 2026-10-18 | v0.3.1 | S0 `flutter pub get` 實鎖版本回寫（drift 2.28.2／sqlcipher_flutter_libs 0.7.0+eol ⚠EOL／intl 0.20.3 等）；新增 §6-7 SQLCipher EOL 風險 | — |
