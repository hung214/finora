import 'package:flutter_test/flutter_test.dart';

import 'gherkin.dart';

/// T-H7 驗收：自製 Gherkin runner（BE）——解析 .feature 並以 dsl.md 登記之句型執行。
/// 正式情境檔（test/bdd/*.feature）於 M1 起以本 runner 掛接 step definitions。
void main() {
  const sample = '''
@P0 @FR-Q
Feature: 樣本功能
  說明文字（忽略）。

  Background:
    Given 種子資料 {n}

  @AC-01
  Scenario: 情境一
    When 執行動作 {x}
    Then 驗證結果

  Scenario Outline: 大綱情境
    When 大綱動作 <v>
    Then 驗證結果

    Examples:
      | v |
      | 1 |
      | 2 |
''';

  test('解析：Feature/Background/Scenario/Outline/Examples/標籤', () {
    final doc = GherkinParser.parse(sample);
    expect(doc.featureName, '樣本功能');
    expect(doc.featureTags, containsAll(['@P0', '@FR-Q']));
    expect(doc.background, hasLength(1));
    expect(doc.scenarios, hasLength(2));
    expect(doc.scenarios[0].tags, contains('@AC-01'));
    expect(doc.scenarios[1].isOutline, isTrue);
    expect(doc.scenarios[1].examples, hasLength(2));
  });

  test('執行：背景套用於每情境、Outline 逐列展開、參數注入', () async {
    final runner = GherkinRunner()
      ..on('種子資料 {n}', (p) {})
      ..on('執行動作 {x}', (p) {})
      ..on('大綱動作 {v}', (p) {})
      ..on('驗證結果', (p) {});
    final doc = GherkinParser.parse(sample);
    final executed = await runner.run(doc);
    expect(executed, 3); // 情境一 1 次＋Outline 2 列
    expect(runner.log.where((s) => s.contains('種子資料')), hasLength(3)); // 背景×每情境
    expect(
      runner.log.where((s) => s.contains('大綱動作')).toList(),
      ['大綱情境 · When 大綱動作 1', '大綱情境 · When 大綱動作 2'],
    );
  });

  test('標籤過濾：@AC-01 僅執行情境一', () async {
    final runner = GherkinRunner()
      ..on('種子資料 {n}', (p) {})
      ..on('執行動作 {x}', (p) {})
      ..on('大綱動作 {v}', (p) {})
      ..on('驗證結果', (p) {});
    final doc = GherkinParser.parse(sample);
    final executed =
        await runner.run(doc, tagFilter: (tags) => tags.contains('@AC-01'));
    expect(executed, 1);
    expect(runner.log.where((s) => s.contains('大綱動作')), isEmpty);
  });

  test('未匹配步驟 → 明確失敗（提醒登記 dsl.md）', () async {
    final runner = GherkinRunner();
    final doc = GherkinParser.parse(sample);
    await expectLater(runner.run(doc), throwsA(isA<GherkinStepNotBound>()));
  });
}
