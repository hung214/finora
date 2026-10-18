import 'package:flutter_test/flutter_test.dart';

import 'notification_spy.dart';

/// T-H4 驗收：notification spy（攔截本機通知，斷言 N-1~N-10 之編號/內容/次數）。
void main() {
  late NotificationSpy spy;

  setUp(() {
    spy = NotificationSpy();
  });

  test('記錄通知：id/title/body/payload', () async {
    await spy.notify(const NotificationCall(
      id: 1,
      title: '預算警告',
      body: '餐飲預算已用 87%（7,000/8,000）',
      payload: {'kind': 'N-1'},
    ));
    expect(spy.records, hasLength(1));
    expect(spy.records.single.id, 1);
    expect(spy.records.single.body, contains('87%'));
    expect(spy.records.single.payload?['kind'], 'N-1');
  });

  test('timesWithId：同 id 通知次數統計（80% 每期僅一次的斷言基礎）', () async {
    await spy.notify(const NotificationCall(id: 1, title: 'a', body: 'b'));
    await spy.notify(const NotificationCall(id: 1, title: 'a2', body: 'b2'));
    await spy.notify(const NotificationCall(id: 2, title: 'c', body: 'd'));
    expect(spy.timesWithId(1), 2);
    expect(spy.timesWithId(2), 1);
    expect(spy.timesWithId(3), 0);
  });

  test('cancel 移除已發通知記錄（繳款後取消提醒的斷言基礎）', () async {
    await spy.notify(const NotificationCall(id: 5, title: '繳款提醒', body: 'x'));
    await spy.cancel(5);
    expect(spy.timesWithId(5), 0);
  });

  test('clear 重置（每情境獨立）', () async {
    await spy.notify(const NotificationCall(id: 1, title: 'a', body: 'b'));
    spy.clear();
    expect(spy.records, isEmpty);
  });
}
