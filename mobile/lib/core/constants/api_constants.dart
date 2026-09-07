import 'package:flutter/foundation.dart';

class ApiConstants {
  // Default to localhost for Web, iOS Simulator, or Desktop; 10.0.2.2 for Android Emulator.
  // Can also be overridden at build time via --dart-define=ZIVA_API_URL=https://...
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('ZIVA_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1' || Uri.base.host.isEmpty) {
        return 'http://localhost:3001';
      }
      return '';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    } else {
      return 'http://localhost:3001';
    }
  }

  // Endpoints
  static const String healthEndpoint = '/api/health';
  static const String ratesEndpoint = '/api/rates';
  static const String accountsEndpoint = '/api/accounts';
  static const String transactionsEndpoint = '/api/transactions';
  static const String debtsEndpoint = '/api/debts';
  static const String budgetsEndpoint = '/api/budgets';
  static const String burnRateEndpoint = '/api/burn-rate';
  static const String taxScheduleEndpoint = '/api/tax-schedule';
  static const String analyticsSummaryEndpoint = '/api/analytics/summary';
  static const String copilotChatEndpoint = '/api/copilot/chat';
  static const String testQueryEndpoint = '/api/test-query';
}
