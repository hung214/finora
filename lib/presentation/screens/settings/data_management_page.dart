import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../application/sync/backup_service.dart';
import '../../../application/wipe/wipe_service.dart';
import '../../../application/scan/scan_state.dart';
import '../../../application/sync/sync_fe_state.dart';
import '../../../application/lock/lock_fe_state.dart';
import '../../theme/app_theme.dart';

/// 資料管理頁（FR-O3；驗收 S9.1/S9.2）：清空資料三重防護——
/// ①警告（未連雲端「無雲端可還原」＋可先匯出備份檔入口）②PIN ③確認文字；
/// 已連雲端加驗身分（重新登入雲端帳號——錯誤帳號拒絕，S9.2 #2）。
///
/// 清空執行交 [WipeService]（BE F09 已驗：本地全表＋附件＋含雲端 LedgerSync/
/// 全刪；不復活閘由 SyncCoordinator 偵測——其他裝置同步顯示「雲端資料已不存在」）。
/// 設定入口接線屬 F07-FE 回頭項（M5 暫停——_openSettings 同批恢復）。
///
/// 測試 keys：wipe-start / wipe-backup-entry / wipe-warning-continue /
/// wipe-pin-input / wipe-pin-submit / wipe-confirm-input / wipe-confirm-submit /
/// wipe-oauth-button / wipe-done-home。
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

enum _WipeStep { idle, warning, pin, confirm, oauth, done }

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  _WipeStep _step = _WipeStep.idle;
  bool _busy = false;
  bool _pinError = false;
  bool _confirmError = false;
  bool _oauthError = false;

  /// 確認文字（驗收 S9.1 #3：「我要清除所有資料」）。
  static const _confirmPhrase = '我要清除所有資料';

  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  bool get _linked =>
      (ref.read(dbProvider).getSetting('sync.account') ?? '').isNotEmpty;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// 執行清空（WipeService——BE F09 三情境已驗契約）。
  Future<void> _executeWipe() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(dbProvider);
      final linked = _linked;
      Directory? blobs;
      try {
        blobs = ref.read(blobsDirProvider);
      } catch (_) {
        blobs = null; // 生產未接線（main() override 前）防護——測試必注入
      }
      await WipeService(db,
              cloud: linked ? ref.read(cloudAdapterProvider) : null,
              blobsDir: blobs)
          .wipe(includeCloud: linked);
      if (mounted) {
        setState(() {
          _step = _WipeStep.done;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('清空失敗：$e')));
      }
    }
  }

  /// 加驗身分（S9.2）：重新登入雲端帳號——帳號不符拒絕執行。
  Future<void> _verifyOauth() async {
    setState(() => _busy = true);
    final email = await ref.read(oauthProvider)();
    if (!mounted) return;
    final linked = ref.read(dbProvider).getSetting('sync.account') ?? '';
    if (email == null || (linked.isNotEmpty && email != linked)) {
      setState(() {
        _oauthError = true;
        _busy = false;
      });
      return;
    }
    await _executeWipe();
  }

  /// 防呆入口（驗收 S9.2 邊界：清空前提示可先匯出備份檔）。
  /// 雲端備份接線屬 F07-FE（main() 尚未注入 cloud/sync provider——try 防護）。
  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_linked) {
      messenger.showSnackBar(const SnackBar(
          content: Text('未連結雲端——連結後可備份至雲端（設定→雲端同步）')));
      return;
    }
    try {
      final db = ref.read(dbProvider);
      final cloud = ref.read(cloudAdapterProvider);
      final deviceId = ref.read(syncCoordinatorProvider).deviceId;
      final path = await BackupService(db, cloud, deviceId: deviceId).export();
      messenger.showSnackBar(SnackBar(content: Text('備份已匯出：$path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    }
  }

  void _onConfirmSubmit() {
    final ok = _confirmController.text.trim() == _confirmPhrase;
    setState(() {
      _confirmError = !ok;
      if (ok && _linked) _step = _WipeStep.oauth;
    });
    if (ok && !_linked) _executeWipe(); // 未連雲端：三重防護後直接執行
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('資料管理')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : switch (_step) {
              _WipeStep.idle => _buildIdle(context),
              _WipeStep.warning => _buildWarning(context),
              _WipeStep.pin => _buildPin(context),
              _WipeStep.confirm => _buildConfirm(context),
              _WipeStep.oauth => _buildOauth(context),
              _WipeStep.done => _buildDone(context),
            },
    );
  }

  Widget _buildIdle(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('清空資料', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('刪除本機所有交易、帳戶、分類與附件。此操作無法復原。'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  key: const Key('wipe-start'),
                  onPressed: () => setState(() => _step = _WipeStep.warning),
                  child: const Text('清空資料'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarning(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 40),
          const SizedBox(height: 12),
          Text(
            _linked
                ? '將刪除所有資料（含雲端 LedgerSync/ 同步與備份）'
                : '將刪除所有資料且無雲端可還原',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('wipe-backup-entry'),
            onPressed: _exportBackup,
            child: const Text('可先匯出備份檔'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('wipe-warning-continue'),
            onPressed: () => setState(() => _step = _WipeStep.pin),
            child: const Text('下一步'),
          ),
        ],
      ),
    );
  }

  Widget _buildPin(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('輸入 PIN 以繼續'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('wipe-pin-input'),
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          if (_pinError)
            Text('PIN 不正確',
                style: TextStyle(color: AppTokens.of(context).danger)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('wipe-pin-submit'),
            onPressed: () {
              final ok = ref
                  .read(appLockControllerProvider)
                  .verifyPin(_pinController.text);
              setState(() {
                _pinError = !ok;
                if (ok) _step = _WipeStep.confirm;
              });
            },
            child: const Text('驗證'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('輸入確認文字：$_confirmPhrase'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('wipe-confirm-input'),
            controller: _confirmController,
          ),
          if (_confirmError)
            Text('確認文字不符',
                style: TextStyle(color: AppTokens.of(context).danger)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('wipe-confirm-submit'),
            onPressed: _onConfirmSubmit,
            child: const Text('繼續'),
          ),
        ],
      ),
    );
  }

  Widget _buildOauth(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('重新登入雲端帳號',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('清空將連雲端 LedgerSync/ 一併刪除——須重新驗證身分。'),
          if (_oauthError)
            Text('帳號不符，已取消',
                style: TextStyle(color: AppTokens.of(context).danger)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('wipe-oauth-button'),
            onPressed: _verifyOauth,
            child: const Text('以雲端帳號驗證'),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 48),
          const SizedBox(height: 12),
          const Text('已清空', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          const Text('資料已全部清除。\n下次啟動將回到首次設定（新建/還原/匯入）。'),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('wipe-done-home'),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('回到總覽'),
          ),
        ],
      ),
    );
  }
}
