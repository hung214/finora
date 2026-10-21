import 'package:flutter/material.dart';

import 'data_management_page.dart';
import 'settings_sync_page.dart';

/// 設定 Hub（M7 恢復入口——PM 2026-10-21 決策：含雲端同步）。
///
/// M6 曾因 F07-FE WIP 暫移設定入口（main 可發佈性）；M7 上架需 F09 資料
/// 管理可達（acceptance S9.1 走查：設定→資料管理→清空資料），故恢復為
/// Hub 兩入口。「雲端同步」頁為 F07-FE WIP（S1 卡點暫停中——隨本版暴露，
/// 完整回歸屬 F07-FE 回頭清單 session.md §3.1）。
///
/// 測試 keys：settings-data-management / settings-sync。
/// f07 harness 回頭時須補一步：app-settings → settings-sync → SettingsSyncPage。
class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('同步',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          ListTile(
            key: const Key('settings-sync'),
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('雲端同步'),
            subtitle: const Text('連結 Google Drive、立即同步、衝突檢視'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsSyncPage())),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('資料',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          ListTile(
            key: const Key('settings-data-management'),
            leading: const Icon(Icons.storage_outlined),
            title: const Text('資料管理'),
            subtitle: const Text('清空資料（三重防護）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DataManagementPage())),
          ),
        ],
      ),
    );
  }
}
