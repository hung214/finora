import 'package:ledger_sync/application/notifications/notification_service.dart';

export 'package:ledger_sync/application/notifications/notification_service.dart'
    show NotificationCall;

/// T-H4：notification spy（攔截本機通知；斷言 N-1~N-10 之編號/內容/次數）。
class NotificationSpy implements NotificationService {
  final List<NotificationCall> records = [];

  /// id 對應 SPEC §8 通知總表 N-x。
  int timesWithId(int id) => records.where((r) => r.id == id).length;

  List<NotificationCall> withId(int id) => records.where((r) => r.id == id).toList();

  void clear() => records.clear();

  @override
  Future<void> notify(NotificationCall call) async {
    records.add(call);
  }

  @override
  Future<void> cancel(int id) async {
    records.removeWhere((r) => r.id == id);
  }
}
