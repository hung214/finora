import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/sync/sync_fe_state.dart';

/// 衝突檢視頁（AC-07；FR-Y5）：sync_events 唯讀列表——被覆蓋內容快照
/// 供使用者檢視（「後寫入者勝」教育，SDD R5）。
class SyncConflictsPage extends ConsumerWidget {
  const SyncConflictsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(syncEventsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('${events.length} 筆衝突')),
      body: events.isEmpty
          ? const Center(child: Text('目前沒有衝突事件'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (var i = 0; i < events.length; i++)
                  Card(
                    child: ListTile(
                      key: Key('conflict-view-$i'),
                      leading: const Icon(Icons.history),
                      title: Text(conflictOverwrittenSummary(events[i])),
                      subtitle: Text(
                          '${events[i].entity} · 被雲端較新版本覆蓋（唯讀快照）'),
                    ),
                  ),
              ],
            ),
    );
  }
}
