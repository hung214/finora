import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';

/// 卡片設定頁（FR-A3/C2 呈現面；M3）。
///
/// - 歸屬規則呈現：include → 「當天算本期」；exclude → 「當天不算本期」。
/// - 修改提示：「修改將於下一期生效」（FR-A3 effective_from 語意）。
class CardSettingsPage extends ConsumerWidget {
  const CardSettingsPage({super.key, required this.cardAccountId});

  final String cardAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final detail = db.creditCardDetail(cardAccountId);
    final card = db.allAccounts().firstWhere((a) => a.id == cardAccountId);
    final ruleText = detail?.boundaryRule == 'exclude' ? '當天不算本期' : '當天算本期';

    return Scaffold(
      appBar: AppBar(title: Text('${card.name} 設定')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: Text('歸屬：$ruleText',
                  key: const Key('card-settings-rule')),
              subtitle: const Text('結帳日當天消費的歸屬規則'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: Text('結帳日：${detail?.statementDay ?? '-'} 號'),
              subtitle: const Text('修改將於下一期生效',
                  key: Key('card-settings-effective-note')),
            ),
          ),
        ],
      ),
    );
  }
}
