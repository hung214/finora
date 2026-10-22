import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sqlite/app_database.dart';
import '../providers.dart';

/// 外觀主題（FR-O1；SPEC P0）：跟隨系統／淺色／深色。
///
/// 持久化於 settings `app.theme_mode`（system|light|dark）——重啟後
/// [build] 重讀即還原；[set] 立即更新 state（MaterialApp.themeMode 即時套用）。
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final db = ref.watch(dbProvider);
    final mode = db.getSetting('app.theme_mode') ?? 'system';
    return switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// 設定→外觀：寫 settings＋立即套用。
  void set(ThemeMode mode) {
    ref
        .read(dbProvider)
        .setSetting('app.theme_mode', switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          _ => 'system',
        });
    state = mode;
  }
}

/// 外觀設定頁面用：目前模式之顯示名。
String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => '淺色',
      ThemeMode.dark => '深色',
      _ => '跟隨系統',
    };

/// 供測試／UI：由 settings 字串解析（AppDatabase.getSetting 包裝）。
ThemeMode themeModeFromSetting(AppDatabase db) {
  final mode = db.getSetting('app.theme_mode') ?? 'system';
  return switch (mode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
