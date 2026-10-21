import '../cloud/cloud_storage_adapter.dart';

/// Google OAuth 登入 seam（FR-Y7；SDD §7.1）。
///
/// 回傳已授權帳號的 email；`null`＝未設定或使用者取消。
/// - 行動：`google_sign_in`（原生帳號選擇器）
/// - 桌面：loopback OAuth（系統瀏覽器）
/// 兩者皆需 **Google Cloud 憑證**——就緒後接線（見 `specs/plan/pm-actions.md`）。
///
/// 現況：憑證未就緒時（[cloud] 未設定）直接回 `null`——UI 顯示
/// 「雲端功能尚未設定」提示（[SettingsSyncPage]），不會崩、不會假裝成功。
Future<String?> Function() googleOAuthSignIn(CloudStorageAdapter cloud) {
  return () async {
    if (!await cloud.isConfigured()) return null; // 憑證未就緒
    // TODO(憑證就緒): 依平台取得 email——
    //   行動：GoogleSignIn().signIn()（scope: drive.appdata）→ account.email
    //   桌面：loopback flow（googleapis_auth）→ userinfo.email
    return null;
  };
}
