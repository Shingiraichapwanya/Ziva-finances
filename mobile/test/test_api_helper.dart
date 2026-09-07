import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ziva_finance/services/api_service.dart';

ApiService createMockApiService() {
  final List<Map<String, dynamic>> mockTxs = [];
  final List<Map<String, dynamic>> mockDebts = [];

  final mockClient = MockClient((request) async {
    final path = request.url.path;

    if (path.contains('/api/health')) {
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

    if (path.contains('/api/transactions')) {
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final txId = body['transactionId'] ?? body['transaction_id'] ?? 'TX_MOCK_1';
        final record = {
          'transaction_id': txId,
          'transaction_date': body['transactionDate'] ?? body['transaction_date'] ?? '2026-09-08',
          'account_id': body['accountId'] ?? body['account_id'] ?? 'ACC_CHECKING',
          'category_id': body['categoryId'] ?? body['category_id'] ?? 'CAT_GENERAL',
          'transaction_type': body['transactionType'] ?? body['transaction_type'] ?? 'EXPENSE',
          'original_amount': body['originalAmount'] ?? body['original_amount'] ?? 0.0,
          'original_currency': body['originalCurrency'] ?? body['original_currency'] ?? 'ZAR',
          'currency_code': body['originalCurrency'] ?? body['original_currency'] ?? 'ZAR',
          'reporting_amount_zar': body['reportingAmountZar'] ?? body['reporting_amount_zar'] ?? 0.0,
          'reporting_amount_usd': body['reportingAmountUsd'] ?? body['reporting_amount_usd'] ?? 0.0,
          'merchant_or_payee': body['merchantOrPayee'] ?? body['merchant_or_payee'] ?? 'Merchant',
        };
        mockTxs.removeWhere((t) => t['transaction_id'] == txId);
        mockTxs.insert(0, record);
        return http.Response(
          jsonEncode({
            'success': true,
            'transactionId': txId,
            'persistedToBigQuery': true,
            'record': record,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'DELETE') {
        final segments = request.url.pathSegments;
        if (segments.isNotEmpty) {
          final id = segments.last;
          mockTxs.removeWhere((t) => t['transaction_id'] == id);
        }
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(mockTxs),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/debts')) {
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final id = body['id'] ?? 'DEBT_MOCK_1';
        mockDebts.removeWhere((d) => d['id'] == id);
        mockDebts.insert(0, body);
        return http.Response(
          jsonEncode({
            'success': true,
            'id': id,
            'record': body,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'DELETE') {
        final segments = request.url.pathSegments;
        if (segments.isNotEmpty) {
          final id = segments.last;
          mockDebts.removeWhere((d) => d['id'] == id);
        }
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(mockDebts),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/accounts')) {
      return http.Response(
        jsonEncode([]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/budgets')) {
      return http.Response(
        jsonEncode([]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.Response(
      jsonEncode({'success': true}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  return ApiService(customBaseUrl: 'http://localhost:3001', client: mockClient);
}
