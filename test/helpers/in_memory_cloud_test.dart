import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/data/sqlite/app_database.dart';
import 'package:ledger_sync/domain/services/balance_calculator.dart';
import 'package:ledger_sync/platform/cloud/cloud_storage_adapter.dart';

import 'db_fixture.dart';
import 'in_memory_cloud_adapter.dart';

/// T-H3 驗收：in-memory 雲端 adapter（SDD §6 抽象的 fake 實作）。
/// 架構核心（使用者確認）：**每個裝置本地各有一個 SQLite 資料庫**，
/// 裝置間僅透過雲端「檔案」交換 OpBundle——本檔以契約模擬驗證此拓撲；
/// 完整合併邏輯由 SyncCoordinator 於 M5/M6（F07）實作。
void main() {
  late InMemoryCloudAdapter cloud;

  setUp(() {
    cloud = InMemoryCloudAdapter();
  });

  test('upload → list → download → delete（檔案語意四操作）', () async {
    const path = 'ops/d-A1B2/00000001.opbundle';
    final bytes = utf8.encode('{"seq":1}');

    await cloud.upload(path, Uint8List.fromList(bytes));
    expect(await cloud.download(path), bytes);
    expect(await cloud.list('ops/d-A1B2'), contains('00000001.opbundle'));
    await cloud.delete(path);
    expect(await cloud.download(path), isNull);
  });

  test('download 不存在的檔案回 null（附件懶下載語意）', () async {
    expect(await cloud.download('blobs/unknown.bin'), isNull);
  });

  test('同路徑重複上傳為冪等覆蓋（同步冪等性）', () async {
    const path = 'devices/d-A.json';
    await cloud.upload(path, Uint8List.fromList(utf8.encode('{"last_seq":1}')));
    await cloud.upload(path, Uint8List.fromList(utf8.encode('{"last_seq":2}')));
    expect(utf8.decode((await cloud.download(path))!), contains('"last_seq":2'));
    expect(cloud.uploadCount, 2);
  });

  test('list 依資料夾過濾（vault/devices/ops/backups 佈局，SDD §5.5.1）', () async {
    await cloud.upload('vault.json', Uint8List(0));
    await cloud.upload('devices/d-A.json', Uint8List(0));
    await cloud.upload('ops/d-A/00000001.opbundle', Uint8List(0));
    expect(await cloud.list(''), containsAll(['vault.json', 'devices/d-A.json']));
    expect(await cloud.list('devices'), ['d-A.json']);
    expect(await cloud.list('ops/d-A'), ['00000001.opbundle']);
  });

  test('故障注入：failing 時上傳/下載拋例外（網路失敗重試測試用）', () async {
    cloud.failing = true;
    await expectLater(
      cloud.upload('ops/x', Uint8List(0)),
      throwsA(isA<CloudUnavailableException>()),
    );
    cloud.failing = false;
    await cloud.upload('ops/x', Uint8List(0)); // 恢復後可用
  });

  test(
      '雙裝置拓撲：每個裝置各自一個本地 SQLite，僅經雲端檔案交換 OpBundle（契約模擬）',
      () async {
    // 裝置 A / 裝置 B：兩個完全獨立的本地 SQLite 資料庫。
    final deviceA = DbFixture.create();
    final deviceB = DbFixture.create();

    // 各自寫入本地交易（oplog 留在各自 DB，未打包）。
    await DbFixture.seedAccount(deviceA, id: 'cash', type: 'cash', name: '現金', opening: 1000);
    await DbFixture.seedTx(
      deviceA,
      id: 't-A1',
      kind: 'expense',
      amountMinor: 195,
      accountId: 'cash',
      occurredAt: 1760760000000,
    );
    await DbFixture.seedAccount(deviceB, id: 'bank', type: 'bank', name: '銀行', opening: 10000);

    // 兩庫互不可見（本地事實來源各自獨立）。
    expect(deviceA.tableNames(), deviceB.tableNames()); // schema 相同
    expect(deviceB.allAccounts().map((a) => a.id), isNot(contains('cash')));

    // 裝置 A 打包自己的變更為 OpBundle 並上傳雲端（Push）。
    final bundleOps = deviceA.allOps().map((o) => {
          'entity': o.entity,
          'entity_id': o.entityId,
          'hlc': o.hlc,
        });
    final bundle = utf8.encode(jsonEncode({
      'device_id': 'd-A1B2',
      'seq': 1,
      'ops': bundleOps.toList(),
    }));
    await cloud.upload('ops/d-A1B2/00000001.opbundle', Uint8List.fromList(bundle));

    // 裝置 B 從雲端拉取並讀得 A 的變更（Pull 的前置；合併於 F07 實作）。
    final pulled = await cloud.download('ops/d-A1B2/00000001.opbundle');
    final decoded = jsonDecode(utf8.decode(pulled!)) as Map<String, dynamic>;
    expect(decoded['device_id'], 'd-A1B2');
    expect((decoded['ops'] as List).first['entity_id'], 't-A1');

    // 各自餘額由「各自的本地交易」重算（衍生餘額原則，SDD §4.3）。
    const calc = BalanceCalculator();
    expect(
      calc.assetBalance(
          account: deviceA.allAccounts().first, txs: deviceA.transactionsByAccount('cash')),
      805, // 1000 − 195
    );
    expect(
      calc.assetBalance(
          account: deviceB.allAccounts().first, txs: deviceB.transactionsByAccount('bank')),
      10000,
    );

    deviceA.close();
    deviceB.close();
  });
}
