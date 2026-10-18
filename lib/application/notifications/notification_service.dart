/// 本機通知服務抽象（N-1~N-10，SPEC §8 通知總表）。
///
/// 正式實作（M2/M3）：flutter_local_notifications 平台橋接；
/// 測試：NotificationSpy（T-H4）攔截並斷言。
class NotificationCall {
  const NotificationCall({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });

  /// 通知編號 = 通知總表 N-x 的 x（1~10）。
  final int id;
  final String title;
  final String body;
  final Map<String, String>? payload;
}

abstract interface class NotificationService {
  Future<void> notify(NotificationCall call);

  /// 移除已排程/已顯示通知（例：繳清後取消 N-5）。
  Future<void> cancel(int id);
}
