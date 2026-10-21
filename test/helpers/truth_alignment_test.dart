import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/schema.dart';

/// T-H9 驗收：truth 對齊測試（tasks.md §5 自動化）。
/// 落差即紅燈：①pubspec 依賴 ⊆ techstack.md ②schema v1 表/欄位 ⊆ data-spec.dbml。
void main() {
  test('pubspec 直接依賴皆登記於 specs/truth/techstack.md', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final deps = <String>[];
    var inDeps = false;
    for (final raw in pubspec.split('\n')) {
      final line = raw.replaceFirst('\r', '');
      if (line.startsWith('dependencies:')) {
        inDeps = true;
        continue;
      }
      if (inDeps) {
        if (line.startsWith('dev_dependencies:') || line.trim().isEmpty) break;
        // 僅取兩格縮排的直接依賴（排除巢狀 sdk: 等）
        if (line.startsWith('  ') && !line.startsWith('   ') && !line.trim().startsWith('#')) {
          final name = line.trim().split(':').first.trim();
          if (name.isNotEmpty) deps.add(name);
        }
      }
    }
    final truth = File('specs/truth/techstack.md').readAsStringSync();
    // 環境/工具白名單（SDK 或工具性依賴，不列入 techstack 表）
    const whitelist = {'flutter', 'cupertino_icons', 'flutter_lints'};
    for (final d in deps) {
      if (whitelist.contains(d)) continue;
      expect(truth, contains(d), reason: 'techstack.md 未登記依賴：$d（請回寫 truth）');
    }
  });

  test('schema v1/v2/v3/v4/v5：表與欄位皆存在於 specs/truth/data-spec.dbml', () {
    final dbml = File('specs/truth/data-spec.dbml').readAsStringSync();
    final tableRe = RegExp(r'CREATE TABLE (\w+)');
    final colRe = RegExp(r'^\s*([a-z_]+)\s+(TEXT|INTEGER|REAL)', multiLine: true);

    // v2 新增 FTS5 虛擬表（無型別欄位）——僅驗表名，不進欄位 regex。
    final ftsTableRe = RegExp(r'CREATE VIRTUAL TABLE (\w+)');
    for (final stmt in SchemaV2.ftsStatements) {
      final table = ftsTableRe.firstMatch(stmt)!.group(1)!;
      expect(dbml, contains(table), reason: 'data-spec.dbml 缺少表：$table');
    }

    for (final stmt in [
      ...SchemaV1.statements,
      ...SchemaV2.statements,
      ...SchemaV3.statements,
      ...SchemaV4.statements,
      ...SchemaV5.statements,
    ]) {
      final table = tableRe.firstMatch(stmt)!.group(1)!;
      expect(dbml, contains(table), reason: 'data-spec.dbml 缺少表：$table');
      for (final m in colRe.allMatches(stmt)) {
        final col = m.group(1)!;
        expect(dbml, contains(col),
            reason: 'data-spec.dbml 的 $table 缺少欄位：$col（請回寫 truth）');
      }
    }
    for (final idx in SchemaV1.indexes) {
      final name = RegExp(r'CREATE INDEX (\w+)').firstMatch(idx)!.group(1)!;
      expect(dbml, contains(name), reason: 'data-spec.dbml 缺少索引：$name');
    }
  });
}
