import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ledger_sync/presentation/screens/ledger/ledger_page.dart';
import 'package:ledger_sync/presentation/theme/app_theme.dart';

import '../helpers/db_fixture.dart';

/// 明細交易列顯示（PM 2026-10-24 回饋：原本缺 分類／帳戶／商家／備註）。
/// - 標題＝商家（無商家→分類名）
/// - 左側＝分類圖示圓（**子類別取主類別圖示**）
/// - 副標＝時間 · 帳戶 · 分類[ · 備註]
void main() {
  testWidgets('明細列：商家／分類（主類別圖示）／帳戶／備註 齊備', (tester) async {
    final db = DbFixture.create();
    const occurredAt = 1760736000000; // 2026/10/18 08:00
    await DbFixture.seedAccount(
        db, id: 'a-1', type: 'cash', name: '現金', opening: 0);
    await DbFixture.seedTx(db,
        id: 't-1',
        kind: 'expense',
        amountMinor: 120,
        accountId: 'a-1',
        category: 'c-food-s0', // 子類別（無自身圖示）
        merchant: '晨光早餐店',
        occurredAt: occurredAt);
    db.setTransactionNote('t-1', '早餐');
    final tx = db.allTransactions().firstWhere((t) => t.id == 't-1');

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: TxTile(
          tx: tx,
          accountName: '現金',
          categoryName: '早餐',
          categoryId: 'c-food-s0',
          categoryIcon: '🍜', // 主類別 emoji（子類別→取主類別）
          note: '早餐',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('晨光早餐店'), findsOneWidget, reason: '商家為標題');
    expect(find.text('🍜'), findsOneWidget,
        reason: '分類圖示圓＝主類別 emoji（子類別無自身圖示）');
    final expected =
        '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(occurredAt))}'
        ' · 現金 · 早餐 · 早餐';
    expect(find.text(expected), findsOneWidget,
        reason: '副標＝時間 · 帳戶 · 分類 · 備註');
    expect(find.text('-120'), findsOneWidget, reason: '支出顯示負號');
    expect(tester.takeException(), isNull);
    db.close();
  });

  testWidgets('明細列：無商家→以分類名為標題', (tester) async {
    final db = DbFixture.create();
    await DbFixture.seedAccount(
        db, id: 'a-1', type: 'cash', name: '現金', opening: 0);
    await DbFixture.seedTx(db,
        id: 't-2',
        kind: 'expense',
        amountMinor: 35,
        accountId: 'a-1',
        category: 'c-transport',
        occurredAt: 1760736000000);
    final tx = db.allTransactions().firstWhere((t) => t.id == 't-2');

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: TxTile(
          tx: tx,
          accountName: '現金',
          categoryName: '交通運輸',
          categoryId: 'c-transport',
          categoryIcon: '🚇',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('交通運輸'), findsWidgets,
        reason: '無商家 → 標題退回分類名（PM 2026-10-24）');
    expect(find.text('🚇'), findsOneWidget);
    expect(find.textContaining('現金'), findsWidgets, reason: '副標含帳戶');
    expect(tester.takeException(), isNull);
    db.close();
  });
}
