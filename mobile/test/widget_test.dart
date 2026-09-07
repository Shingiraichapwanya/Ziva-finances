import 'package:flutter_test/flutter_test.dart';
import 'package:ziva_finance/core/theme/ziva_theme.dart';
import 'package:ziva_finance/services/sqlite_service.dart';
import 'package:ziva_finance/models/transaction_model.dart';
import 'test_api_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SqliteService.instance.setApiForTesting(createMockApiService());
  });

  test('ZivaTheme configuration smoke test', () {
    final theme = ZivaTheme.darkTheme;
    expect(theme.useMaterial3, true);
    expect(theme.cardTheme.color, ZivaTheme.bgCard);
    expect(theme.scaffoldBackgroundColor, ZivaTheme.bgCore);
  });

  test('SqliteService initializes and handles offline queue/caching safely', () async {
    final sqlite = SqliteService.instance;
    final count = await sqlite.getPendingQueueCount();
    expect(count >= 0, true);

    final tx = TransactionModel(
      transactionId: 'test-tx-1',
      transactionDate: '2026-09-05',
      accountId: 'ACC_CHECKING',
      categoryId: 'CAT_TEST',
      categoryName: 'Test Category',
      transactionType: 'EXPENSE',
      originalAmount: 100.0,
      originalCurrency: 'ZAR',
      reportingAmountZar: 100.0,
      reportingAmountUsd: 5.5,
      merchantOrPayee: 'Test Merchant',
    );

    await sqlite.saveTransaction(tx);
    final txs = await sqlite.getTransactions(limit: 10);
    expect(txs.any((t) => t.transactionId == 'test-tx-1'), true);

    final queueItem = await sqlite.enqueueMutation(
      transactionId: 'test-tx-1',
      payloadJson: '{"test": true}',
    );
    expect(queueItem.transactionId, 'test-tx-1');

    final pending = await sqlite.getPendingQueue();
    expect(pending.any((q) => q.transactionId == 'test-tx-1'), true);
  });

  test('SqliteService deletes transaction and prunes local stores', () async {
    final sqlite = SqliteService.instance;
    final tx = TransactionModel(
      transactionId: 'test-delete-tx',
      transactionDate: '2026-09-05',
      accountId: 'ACC_CHECKING',
      categoryId: 'CAT_TEST',
      categoryName: 'Test Category',
      transactionType: 'EXPENSE',
      originalAmount: -500.0,
      originalCurrency: 'ZAR',
      reportingAmountZar: -500.0,
      reportingAmountUsd: -27.0,
      merchantOrPayee: 'Store to Delete',
    );

    await sqlite.saveTransaction(tx);
    final beforeTxs = await sqlite.getTransactions(limit: 50);
    expect(beforeTxs.any((t) => t.transactionId == 'test-delete-tx'), true);

    final success = await sqlite.deleteTransaction('test-delete-tx');
    expect(success, true);

    final afterTxs = await sqlite.getTransactions(limit: 50);
    expect(afterTxs.any((t) => t.transactionId == 'test-delete-tx'), false);
  });
}
