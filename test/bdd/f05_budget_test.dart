import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/core/clock.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';

import '../helpers/db_fixture.dart';
import '../helpers/gherkin/gherkin.dart';
import '../helpers/notification_spy.dart';

/// F05-BE 情境執行器（@BE @M2 @FR-B @P0，5 情境）。
///
/// 來源：specs/plan/tests/backend/F05_budget-income-goal.feature（sync_features.ps1
/// 同步副本，禁止手改副本）。句型登記簿：specs/plan/tests/dsl.md §2。
/// 警示語意：BudgetAlertService.sync 為**冪等 sync 點**（記帳鉤子＋斷言前呼叫）。
void main() {
  final source = File('test/bdd/F05_budget-income-goal.feature').readAsStringSync();
  final doc = GherkinParser.parse(source);

  test('F05-BE：預算與收入目標計算（5 情境：閾值×2／預扣口徑／達標率／週期邊界）', () async {
    final w = _World();
    final runner = GherkinRunner();
    _bind(runner, w);

    try {
      final executed =
          await runner.run(doc, tagFilter: (tags) => tags.contains('@BE') && tags.contains('@P0'));
      expect(executed, 5, reason: 'F05-BE 應執行 5 個情境（@BE @P0）');
      // ignore: avoid_print
      print(runner.log.join('\n'));
    } finally {
      Clock.unfreeze();
      for (final db in w.dbs) {
        db.close();
      }
    }
  });
}

/// 情境共享狀態（每 Scenario 由 Background 重置）。
class _World {
  final List<AppDatabase> dbs = [];
  late AppDatabase db;
  final NotificationSpy spy = NotificationSpy();

  /// 名稱 → id 對映（Background 建立時登記）。
  final accounts = <String, String>{};
  final categories = <String, String>{};
}

void _bind(GherkinRunner runner, _World w) {
  // ── Given：環境 ─────────────────────────────────────────
  runner.on(r'已重置記憶體資料庫$', (p) {
    final db = DbFixture.create();
    w.dbs.add(db);
    w.db = db;
    w.accounts.clear();
    w.categories.clear();
    w.spy.clear();
  });

  runner.on(r'已建立帳戶「{name}」類型 {type} 期初 {amount}$', (p) {
    final id = 'a-${w.accounts.length}';
    DbFixture.seedAccount(
      w.db,
      id: id,
      type: p['type']!,
      name: p['name']!,
      opening: _amount(p['amount']!),
    );
    w.accounts[p['name']!] = id;
  });

  runner.on(r'已建立分類{names}$', (p) {
    final names =
        RegExp('「([^」]+)」').allMatches(p['names']!).map((m) => m.group(1)!).toList();
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final id = 'c-${w.categories.length}';
      DbFixture.seedCategory(
        w.db,
        id: id,
        kind: name == '薪資' ? 'income' : 'expense',
        name: name,
      );
      w.categories[name] = id;
    }
  });

  runner.on(r'模擬系統時間為 {dt}$', (p) => Clock.freeze(_dateTime(p['dt']!)));
}

int _amount(String s) => int.parse(s.trim().replaceAll(',', ''));

DateTime _dateTime(String s) {
  final m = RegExp(r'^(\d{4})/(\d{2})/(\d{2})(?: (\d{1,2}):(\d{2}))?$').firstMatch(s.trim());
  if (m == null) throw FormatException('日期時間格式未支援：$s（dsl.md §1-3）');
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    m.group(4) == null ? 0 : int.parse(m.group(4)!),
    m.group(5) == null ? 0 : int.parse(m.group(5)!),
  );
}
