import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../application/sync/sync_fe_state.dart';
import 'sync_conflicts_page.dart';

/// 雲端與同步設定頁（FR-Y7/Y11；SDD §8 IA「設定同步」——07-prototype）：
/// 連結授權（帳號授權式——**無同步密碼**）／立即同步（同步中…→已同步 N 筆）
/// ／待同步計數／上次同步時間／衝突檢視入口／從雲端還原（新裝置）。
class SettingsSyncPage extends ConsumerStatefulWidget {
  const SettingsSyncPage({super.key});

  @override
  ConsumerState<SettingsSyncPage> createState() => _SettingsSyncPageState();
}

class _SettingsSyncPageState extends ConsumerState<SettingsSyncPage> {
  bool _linking = false; // OAuth 流程中
  bool _linkSuccess = false; // 授權完成（連結成功＋兩步驟驗證建議）
  bool _syncing = false;
  String? _syncResult; // 「已同步 N 筆變更」
  String? _restoreResult; // 「還原完成」/「此帳號沒有可還原的資料」
  String? _error;

  bool get _linked => (ref.watch(syncAccountProvider) ?? '').isNotEmpty;

  /// 連結第一步（FR-Y7）：進入登入畫面（等待「同意授權」——兩步互動）。
  void _beginLink() => setState(() {
        _linking = true;
        _error = null;
      });

  /// 連結第二步（授權）：OAuth seam → 帳號落 settings → 連結成功。
  /// （「同步密碼」UI 一律不存在——帳號授權式，SDD §7.1。）
  Future<void> _approve() async {
    final email = await ref.read(oauthProvider)();
    if (!mounted) return;
    if (email == null) {
      setState(() => _linking = false);
      return;
    }
    ref.read(syncAccountProvider.notifier).link(email);
    setState(() {
      _linking = false;
      _linkSuccess = true;
      _syncResult = null;
    });
  }

  /// 從雲端還原（FR-Y2/AC-08）：登入（同帳號）→ bootstrap → 結果回饋。
  Future<void> _restore() async {
    setState(() {
      _syncing = true;
      _restoreResult = null;
      _error = null;
    });
    final email = await ref.read(oauthProvider)();
    if (!mounted) return;
    if (email == null) {
      setState(() => _syncing = false);
      return;
    }
    ref.read(syncAccountProvider.notifier).link(email);
    await ref.read(syncCoordinatorProvider).bootstrap();
    if (!mounted) return;
    final hasData = ref.read(dbProvider).allAccounts().isNotEmpty;
    setState(() {
      _syncing = false;
      _restoreResult =
          hasData ? '還原完成' : '此帳號沒有可還原的資料';
    });
  }

  /// 立即同步（FR-Y11）：同步中… → 已同步 N 筆變更。
  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _syncResult = null;
      _error = null;
    });
    final pendingBefore = ref.read(pendingOpsProvider);
    await ref.read(syncCoordinatorProvider).sync();
    afterSyncRefresh(container!);
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncResult = '已同步 $pendingBefore 筆變更';
    });
  }

  ProviderContainer? get container =>
      ProviderScope.containerOf(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(syncAccountProvider);
    final pending = ref.watch(pendingOpsProvider);
    final lastSync = ref.watch(lastSyncAtProvider);
    final conflicts = ref.watch(syncEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('雲端與同步')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (!_linked) ...[
            // 未連結（FR-Y7 授權式；無同步密碼 UI）。
            if (_linking) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Center(
                  child: Text('Google 登入', key: Key('google-signin'))),
              Center(
                child: FilledButton(
                  key: const Key('oauth-approve'),
                  onPressed: _approve,
                  child: const Text('同意授權'),
                ),
              ),
            ] else
              Center(
                child: FilledButton.icon(
                  key: const Key('sync-link'),
                  onPressed: _beginLink,
                  icon: const Icon(Icons.link),
                  label: const Text('連結 Google Drive'),
                ),
              ),
          ] else ...[
            // 已連結：帳號＋同步操作。
            if (_linkSuccess) ...[
              Text('連結成功',
                  key: const Key('link-success'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.primary)),
              const Text('建議為此帳號開啟兩步驟驗證'),
              const SizedBox(height: 8),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(account!),
                subtitle: lastSync == null
                    ? null
                    : Text('上次同步 今天 ${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(lastSync))}',
                        key: const Key('last-sync')),
              ),
            ),
            const SizedBox(height: 8),
            if (_syncing)
              const Center(child: Text('同步中…'))
            else
              FilledButton.icon(
                key: const Key('sync-now'),
                onPressed: _syncNow,
                icon: const Icon(Icons.sync),
                label: const Text('立即同步'),
              ),
            if (_syncResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_syncResult!, key: const Key('sync-result')),
              ),
            const SizedBox(height: 8),
            Text('待同步 $pending 筆', key: const Key('pending-count')),
            Card(
              child: ListTile(
                key: const Key('sync-conflicts-entry'),
                leading: Icon(
                  conflicts.isEmpty
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  color: conflicts.isEmpty ? null : Theme.of(context).colorScheme.error,
                ),
                title: Text('${conflicts.length} 筆衝突'),
                subtitle: const Text('被覆蓋內容可檢視（後寫入者勝）'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const SyncConflictsPage()),
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('restore-cloud'),
              onPressed: _syncing ? null : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('從雲端還原'),
            ),
          ],
          if (_linking && _linked) ...[
            // 還原流程之登入步（oauth-approve 於未連結分支外亦可用）。
          ],
          if (_restoreResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_restoreResult!, key: const Key('restore-result')),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
