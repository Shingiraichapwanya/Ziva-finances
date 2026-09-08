import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/account_model.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';

/// Authoritative API client communicating with the BigQuery backend layer.
/// Strictly executes real HTTP calls against Google BigQuery tables:
/// - fct_transactions
/// - debt_credit_ledger
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? customBaseUrl, http.Client? client})
      : baseUrl = (customBaseUrl != null && customBaseUrl.isNotEmpty)
            ? customBaseUrl
            : (ApiConstants.defaultBaseUrl.isNotEmpty ? ApiConstants.defaultBaseUrl : 'http://localhost:3001'),
        _client = client ?? http.Client();

  /// Execute an asynchronous operation with retry logic and exponential backoff
  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await action();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isRetryable = errStr.contains('socket') ||
            errStr.contains('timeout') ||
            errStr.contains('connection') ||
            errStr.contains('clientexception') ||
            errStr.contains('502') ||
            errStr.contains('503') ||
            errStr.contains('429');

        if (attempt >= maxAttempts || !isRetryable) {
          rethrow;
        }
        await Future<void>.delayed(initialDelay * attempt);
      }
    }
  }

  /// Probe BigQuery backend health and verify connection status
  Future<Map<String, dynamic>> checkHealth({bool force = false}) async {
    final query = force ? '?force=true' : '';
    final uri = Uri.parse('$baseUrl${ApiConstants.healthEndpoint}$query');
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    if (res.body.trim().startsWith('{')) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }

    throw Exception('Backend health check returned ${res.statusCode}: ${res.body}');
  }

  /// Explicit connection test probe - forces live query execution on BigQuery
  Future<Map<String, dynamic>> testConnection() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.connectionTestEndpoint}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));

    if (res.body.trim().startsWith('{')) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Connection test failed with status ${res.statusCode}: ${res.body}');
  }

  /// Fetch accounts with live cumulative BigQuery balances
  Future<List<AccountModel>> fetchAccounts() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.accountsEndpoint}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
      return list.map((item) => AccountModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch accounts: ${res.statusCode}');
  }

  /// Fetch primary ledger transactions from BigQuery (fct_transactions)
  Future<List<TransactionModel>> fetchTransactions({int limit = 100}) async {
    final uri = Uri.parse('$baseUrl${ApiConstants.transactionsEndpoint}?limit=$limit');
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
      return list.map((item) => TransactionModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch transactions from BigQuery: ${res.statusCode}');
  }

  /// Ingest transaction mutation directly into BigQuery (fct_transactions) with retry
  Future<Map<String, dynamic>> postTransaction(Map<String, dynamic> payload) async {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl${ApiConstants.transactionsEndpoint}');
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to ingest transaction to BigQuery: ${res.statusCode} ${res.body}');
    });
  }

  /// Delete a transaction record from BigQuery warehouse (fct_transactions) with retry
  Future<bool> deleteTransaction(String transactionId) async {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl${ApiConstants.transactionsEndpoint}/$transactionId');
      final res = await _client.delete(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return true;
      }
      throw Exception('Failed to delete transaction from BigQuery: ${res.statusCode} ${res.body}');
    });
  }

  /// Fetch all debt/credit records from BigQuery (debt_credit_ledger)
  Future<List<DebtModel>> fetchDebts({String? status}) async {
    final queryParam = status != null ? '?status=$status' : '';
    final uri = Uri.parse('$baseUrl${ApiConstants.debtsEndpoint}$queryParam');
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body) as List<dynamic>;
      return list.map((item) => DebtModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch debts from BigQuery: ${res.statusCode}');
  }

  /// Post a new debt/credit record directly to BigQuery (debt_credit_ledger) with retry
  Future<Map<String, dynamic>> postDebt(Map<String, dynamic> payload) async {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl${ApiConstants.debtsEndpoint}');
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to create debt record in BigQuery: ${res.statusCode} ${res.body}');
    });
  }

  /// Mark a debt/credit record as Settled in BigQuery (debt_credit_ledger) with retry
  Future<Map<String, dynamic>> settleDebt(String id) async {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl${ApiConstants.debtsEndpoint}/$id/settle');
      final res = await _client.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to settle debt in BigQuery: ${res.statusCode} ${res.body}');
    });
  }

  /// Delete a debt/credit record from BigQuery (debt_credit_ledger) with retry
  Future<bool> deleteDebt(String id) async {
    return _withRetry(() async {
      final uri = Uri.parse('$baseUrl${ApiConstants.debtsEndpoint}/$id');
      final res = await _client.delete(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return true;
      }
      throw Exception('Failed to delete debt from BigQuery: ${res.statusCode} ${res.body}');
    });
  }

  /// Fetch performance and analytics summary
  Future<Map<String, dynamic>> fetchAnalyticsSummary() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.analyticsSummaryEndpoint}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch analytics summary: ${res.statusCode}');
  }

  /// Run a live test query directly against the BigQuery dataset
  Future<Map<String, dynamic>> runBigQueryTestQuery() async {
    final uri = Uri.parse('$baseUrl${ApiConstants.testQueryEndpoint}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to execute BigQuery test query: ${res.statusCode} ${res.body}');
  }
}
