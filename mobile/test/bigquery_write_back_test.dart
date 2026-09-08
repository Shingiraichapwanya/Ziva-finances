import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ziva_finance/models/debt_model.dart';
import 'package:ziva_finance/models/transaction_model.dart';
import 'package:ziva_finance/services/api_service.dart';
import 'package:ziva_finance/services/sqlite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime.parse('2026-09-08T00:00:00Z');

  group('BigQuery Multi-Currency Schema Mapping Tests', () {
    test('TransactionModel correctly serializes multi-currency fields for BigQuery fct_transactions', () {
      final tx = TransactionModel(
        transactionId: 'TX_TEST_001',
        transactionDate: '2026-09-08',
        accountId: 'ACC_ZW_ECOCASH_USD',
        categoryId: 'CAT_TECH_CLOUD',
        categoryName: 'Cloud SaaS & Productivity Tools',
        transactionType: 'EXPENSE',
        originalAmount: -150.00,
        originalCurrency: 'USD',
        reportingAmountZar: -2737.50,
        reportingAmountUsd: -150.00,
        merchantOrPayee: 'Google Cloud Platform',
        paymentMethod: 'Credit Card',
        isTaxDeductible: true,
        receiptUrl: 'https://storage.googleapis.com/budget-tracker-507418-receipts/rec_001.pdf',
        receiptFileType: 'application/pdf',
        notes: 'BigQuery & Dataplex infrastructure',
        tags: const ['cloud', 'tax_deductible'],
      );

      final json = tx.toJson();

      // BigQuery fct_transactions column mappings
      expect(json['transaction_id'], equals('TX_TEST_001'));
      expect(json['original_currency'], equals('USD'));
      expect(json['currency_code'], equals('USD'));
      expect(json['original_amount'], equals(-150.00));
      expect(json['reporting_amount_usd'], equals(-150.00));
      expect(json['reporting_amount_zar'], equals(-2737.50));
      expect(json['is_tax_deductible'], equals(true));
      expect(json['receipt_storage_url'], equals('https://storage.googleapis.com/budget-tracker-507418-receipts/rec_001.pdf'));
      expect(json['receipt_file_type'], equals('application/pdf'));
    });

    test('TransactionModel correctly handles ZWG (ZiG) multi-currency serialization', () {
      final tx = TransactionModel(
        transactionId: 'TX_TEST_ZWG',
        transactionDate: '2026-09-08',
        accountId: 'ACC_ZW_ECOCASH_ZIG',
        categoryId: 'CAT_GROCERIES',
        categoryName: 'Groceries',
        transactionType: 'EXPENSE',
        originalAmount: -2650.00,
        originalCurrency: 'ZWG',
        reportingAmountZar: -1825.00,
        reportingAmountUsd: -100.00,
        merchantOrPayee: 'OK Supermarket Harare',
        paymentMethod: 'EcoCash',
      );

      final json = tx.toJson();
      expect(json['original_currency'], equals('ZWG'));
      expect(json['currency_code'], equals('ZWG'));
      expect(json['original_amount'], equals(-2650.00));
    });

    test('DebtModel serializes and deserializes accurately for BigQuery debt_credit_ledger schema', () {
      final debt = DebtModel(
        id: 'DEBT_TEST_001',
        counterparty: 'Tinashe Makoni',
        direction: DebtDirection.owedToMe,
        debtType: DebtType.personalLoan,
        currency: 'USD',
        originalPrincipalZar: 1000.00,
        currentOutstandingBalanceZar: 1000.00,
        notes: 'Venture advance',
        createdAt: testDate,
        updatedAt: testDate,
      );

      final json = debt.toJson();

      // Verify schema mappings for BigQuery debt_credit_ledger
      expect(json['id'], equals('DEBT_TEST_001'));
      expect(json['person_name'], equals('Tinashe Makoni'));
      expect(json['direction'], equals('owed_to_me'));
      expect(json['amount'], equals(1000.00));
      expect(json['status'], equals('Pending'));
      expect(json['currency'], equals('USD'));

      // Verify deserialization from BigQuery query result
      final reconstructed = DebtModel.fromJson({
        'id': 'DEBT_TEST_001',
        'person_name': 'Tinashe Makoni',
        'direction': 'OWED_TO_ME',
        'amount': 1000.00,
        'status': 'PENDING',
        'currency': 'USD',
        'notes': 'Venture advance',
        'date': '2026-09-08T00:00:00Z',
      });

      expect(reconstructed.id, equals('DEBT_TEST_001'));
      expect(reconstructed.counterparty, equals('Tinashe Makoni'));
      expect(reconstructed.direction, equals(DebtDirection.owedToMe));
      expect(reconstructed.originalPrincipalZar, equals(1000.00));
      expect(reconstructed.currency, equals('USD'));
    });
  });

  group('Strict Confirmation Loop & Write-Back Tests', () {
    test('saveTransaction succeeds and confirms record when BigQuery returns HTTP 200/201', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/transactions') && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['original_currency'], equals('USD'));
          expect(body['original_amount'], equals(-250.0));

          return http.Response(
            jsonEncode({
              'success': true,
              'transactionId': 'TX_BQ_CONFIRMED_001',
              'persistedToBigQuery': true,
              'record': {
                'transaction_id': 'TX_BQ_CONFIRMED_001',
                'transaction_date': '2026-09-08',
                'account_id': 'ACC_ZW_ECOCASH_USD',
                'category_id': 'CAT_TECH_CLOUD',
                'category_name': 'Cloud SaaS',
                'transaction_type': 'EXPENSE',
                'original_amount': -250.0,
                'original_currency': 'USD',
                'currency_code': 'USD',
                'reporting_amount_usd': -250.0,
                'reporting_amount_zar': -4562.50,
                'merchant_or_payee': 'AWS Cloud Services',
                'payment_method': 'Credit Card',
                'is_tax_deductible': true,
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      SqliteService.instance.setApiForTesting(testApi);

      final txToSave = TransactionModel(
        transactionId: 'TX_BQ_CONFIRMED_001',
        transactionDate: '2026-09-08',
        accountId: 'ACC_ZW_ECOCASH_USD',
        categoryId: 'CAT_TECH_CLOUD',
        categoryName: 'Cloud SaaS',
        transactionType: 'EXPENSE',
        originalAmount: -250.0,
        originalCurrency: 'USD',
        reportingAmountZar: -4562.50,
        reportingAmountUsd: -250.0,
        merchantOrPayee: 'AWS Cloud Services',
      );

      final result = await SqliteService.instance.saveTransaction(txToSave);

      expect(result.transactionId, equals('TX_BQ_CONFIRMED_001'));
      expect(result.originalCurrency, equals('USD'));
      expect(result.originalAmount, equals(-250.0));
      expect(result.isSynced, isTrue);
    });

    test('saveTransaction fails closed and throws Exception when BigQuery write-back is rejected', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'BigQuery IAM permission denied on budget-tracker-507418.personal_finance.fct_transactions'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      SqliteService.instance.setApiForTesting(testApi);

      final txToSave = TransactionModel(
        transactionId: 'TX_FAIL_001',
        transactionDate: '2026-09-08',
        accountId: 'ACC_CHECKING',
        categoryId: 'CAT_MISC',
        transactionType: 'EXPENSE',
        originalAmount: -99.0,
        originalCurrency: 'ZAR',
        reportingAmountZar: -99.0,
        reportingAmountUsd: -5.42,
        merchantOrPayee: 'Unknown Merchant',
      );

      // Verify that the call fails closed without optimistic update
      expect(
        () async => await SqliteService.instance.saveTransaction(txToSave),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteTransaction calls BigQuery DELETE and succeeds on 200 OK', () async {
      bool deleteCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/transactions/TX_TO_DELETE') && request.method == 'DELETE') {
          deleteCalled = true;
          return http.Response(
            jsonEncode({'success': true, 'transactionId': 'TX_TO_DELETE'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      SqliteService.instance.setApiForTesting(testApi);

      await SqliteService.instance.deleteTransaction('TX_TO_DELETE');
      expect(deleteCalled, isTrue);
    });

    test('deleteTransaction throws Exception and fails closed when BigQuery delete fails', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      SqliteService.instance.setApiForTesting(testApi);

      expect(
        () async => await SqliteService.instance.deleteTransaction('TX_FAIL_DEL'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Debt Write-Back & Settlement Tests', () {
    test('saveDebt writes to BigQuery debt_credit_ledger and returns verified record', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/debts') && request.method == 'POST') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['person_name'], equals('Apex Solutions'));
          expect(payload['amount'], equals(5000.0));
          expect(payload['currency'], equals('USD'));

          return http.Response(
            jsonEncode({
              'success': true,
              'id': 'DEBT_APEX_001',
              'persistedToBigQuery': true,
              'record': {
                'id': 'DEBT_APEX_001',
                'person_name': 'Apex Solutions',
                'direction': 'OWED_BY_ME',
                'amount': 5000.0,
                'status': 'PENDING',
                'currency': 'USD',
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      SqliteService.instance.setApiForTesting(testApi);

      final debt = DebtModel(
        id: 'DEBT_APEX_001',
        counterparty: 'Apex Solutions',
        direction: DebtDirection.owedByMe,
        currency: 'USD',
        originalPrincipalZar: 5000.0,
        currentOutstandingBalanceZar: 5000.0,
        createdAt: testDate,
        updatedAt: testDate,
      );

      final saved = await SqliteService.instance.saveDebt(debt);
      expect(saved.id, equals('DEBT_APEX_001'));
      expect(saved.counterparty, equals('Apex Solutions'));
      expect(saved.currency, equals('USD'));
    });

    test('settleDebt executes PATCH against BigQuery debt_credit_ledger and marks status as Settled', () async {
      bool settleCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/debts/DEBT_APEX_001/settle') && request.method == 'PATCH') {
          settleCalled = true;
          return http.Response(
            jsonEncode({
              'success': true,
              'debtId': 'DEBT_APEX_001',
              'status': 'Settled',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      SqliteService.instance.setApiForTesting(testApi);

      await SqliteService.instance.settleDebt('DEBT_APEX_001');
      expect(settleCalled, isTrue);
    });

    test('deleteDebt executes DELETE against BigQuery debt_credit_ledger', () async {
      bool deleteCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/debts/DEBT_APEX_001') && request.method == 'DELETE') {
          deleteCalled = true;
          return http.Response(
            jsonEncode({'success': true, 'debtId': 'DEBT_APEX_001'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      SqliteService.instance.setApiForTesting(testApi);

      await SqliteService.instance.deleteDebt('DEBT_APEX_001');
      expect(deleteCalled, isTrue);
    });
  });

  group('BigQuery Connection Health Check Tests', () {
    test('checkHealth returns ONLINE status and telemetry details', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/health')) {
          return http.Response(
            jsonEncode({
              'status': 'ONLINE',
              'bigquery': {
                'projectId': 'budget-tracker-507418',
                'datasetId': 'personal_finance',
                'location': 'africa-south1',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Error', 500);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      final health = await testApi.checkHealth();

      expect(health['status'], equals('ONLINE'));
      expect(health['bigquery']['projectId'], equals('budget-tracker-507418'));
      expect(health['bigquery']['datasetId'], equals('personal_finance'));
    });

    test('checkHealth throws on backend connection refusal or non-JSON 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Connection refused', 503);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      expect(() async => await testApi.checkHealth(), throwsA(isA<Exception>()));
    });

    test('checkHealth decodes and returns structured diagnostic payload when backend reports offline', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'OFFLINE',
            'connected': false,
            'project': 'budget-tracker-507418',
            'error': {
              'code': 403,
              'message': 'Access Denied: Dataset personal_finance',
              'troubleshooting': 'Grant roles/bigquery.dataEditor to service account.'
            }
          }),
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      final health = await testApi.checkHealth();

      expect(health['status'], equals('OFFLINE'));
      expect(health['connected'], equals(false));
      expect(health['error']['code'], equals(403));
      expect(health['error']['troubleshooting'], contains('Grant roles/bigquery.dataEditor'));
    });

    test('testConnection executes live connection probe and returns telemetry', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/connection-test')) {
          return http.Response(
            jsonEncode({
              'status': 'ONLINE',
              'connected': true,
              'project': 'budget-tracker-507418',
              'dataset': 'personal_finance',
              'latencyMs': 142,
              'datasetDetails': {'totalRecords': 45}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      final result = await testApi.testConnection();

      expect(result['connected'], isTrue);
      expect(result['latencyMs'], equals(142));
      expect(result['datasetDetails']['totalRecords'], equals(45));
    });

    test('postTransaction automatically retries on transient connection failure and succeeds', () async {
      int attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts < 2) {
          // Simulate transient 503 socket error
          return http.Response('Backend unavailable (transient)', 503);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'transactionId': 'TX_RETRY_001',
            'persistedToBigQuery': true,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final testApi = ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
      final result = await testApi.postTransaction({'transaction_id': 'TX_RETRY_001', 'amount': 100});

      expect(attempts, equals(2));
      expect(result['success'], isTrue);
      expect(result['transactionId'], equals('TX_RETRY_001'));
    });
  });
}
