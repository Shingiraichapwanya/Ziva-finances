import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ziva_finance/core/currency/currency_conversion.dart';
import 'package:ziva_finance/core/currency/currency_display_state.dart';
import 'package:ziva_finance/core/currency/currency_types.dart';
import 'package:ziva_finance/models/transaction_model.dart';
import 'package:ziva_finance/services/auth_session.dart';
import 'package:ziva_finance/services/auth_storage.dart';
import 'package:ziva_finance/services/exchange_rate_service.dart';
import 'package:ziva_finance/services/receipt_storage_service.dart';
import 'package:ziva_finance/services/tax_report_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Multi-Currency Architecture & Backward Compatibility Tests', () {
    test('Supported currencies list strictly contains USD, ZWG, ZAR', () {
      expect(supportedCurrencies, equals(['USD', 'ZWG', 'ZAR']));
    });

    test('getEffectiveCurrencyCode resolves null or empty to ZAR legacy baseline', () {
      expect(getEffectiveCurrencyCode(null), equals('ZAR'));
      expect(getEffectiveCurrencyCode(''), equals('ZAR'));
      expect(getEffectiveCurrencyCode('   '), equals('ZAR'));
    });

    test('getEffectiveCurrencyCode maps legacy ZiG to official ISO 4217 ZWG', () {
      expect(getEffectiveCurrencyCode('ZiG'), equals('ZWG'));
      expect(getEffectiveCurrencyCode('zig'), equals('ZWG'));
      expect(getEffectiveCurrencyCode('ZIG'), equals('ZWG'));
      expect(getEffectiveCurrencyCode('ZWG'), equals('ZWG'));
    });

    test('getEffectiveCurrencyCode parses map structures with snake_case and camelCase keys', () {
      expect(getEffectiveCurrencyCode({'currency_code': 'USD'}), equals('USD'));
      expect(getEffectiveCurrencyCode({'currencyCode': 'ZWG'}), equals('ZWG'));
      expect(getEffectiveCurrencyCode({'original_currency': 'ZiG'}), equals('ZWG'));
      expect(getEffectiveCurrencyCode({'originalCurrency': 'ZAR'}), equals('ZAR'));
    });

    test('TransactionModel backward compatibility preserves currencyCode and receiptStorageUrl aliases', () {
      final tx = TransactionModel.fromJson({
        'transaction_id': 'TX_TEST_001',
        'original_amount': 250.0,
        'original_currency': 'ZiG',
        'receipt_url': 'https://storage.googleapis.com/test_bucket/test.pdf',
        'is_tax_deductible': true,
      });

      expect(tx.originalCurrency, equals('ZWG'));
      expect(tx.currencyCode, equals('ZWG'));
      expect(tx.receiptStorageUrl, equals('https://storage.googleapis.com/test_bucket/test.pdf'));
      expect(tx.isTaxDeductible, isTrue);

      final json = tx.toJson();
      expect(json['currency_code'], equals('ZWG'));
      expect(json['receipt_storage_url'], equals('https://storage.googleapis.com/test_bucket/test.pdf'));

      final sqliteMap = tx.toSqliteMap();
      expect(sqliteMap['currency_code'], equals('ZWG'));
      expect(sqliteMap['receipt_storage_url'], equals('https://storage.googleapis.com/test_bucket/test.pdf'));
    });
  });

  group('Currency Display State & ExchangeRate-API Conversion Tests', () {
    test('CurrencyDisplayState defaults to ZAR and updates cleanly', () async {
      final state = CurrencyDisplayState.instance;
      expect(state.currentDisplayCurrency, isNotEmpty);

      await state.setDisplayCurrency('USD');
      expect(state.currentDisplayCurrency, equals('USD'));

      await state.setDisplayCurrency('ZWG');
      expect(state.currentDisplayCurrency, equals('ZWG'));

      // Restore to ZAR
      await state.setDisplayCurrency('ZAR');
      expect(state.currentDisplayCurrency, equals('ZAR'));
    });

    test('convertAmount converts identically when from == to', () {
      expect(convertAmount(amount: 500.0, fromCurrency: 'USD', toCurrency: 'USD'), equals(500.0));
      expect(convertAmount(amount: 500.0, fromCurrency: 'ZAR', toCurrency: 'ZAR'), equals(500.0));
      expect(convertAmount(amount: 500.0, fromCurrency: 'ZWG', toCurrency: 'ZWG'), equals(500.0));
    });

    test('convertAmount accurately converts across USD, ZAR, and ZWG', () {
      // USD to ZAR (1 USD = 18.25 ZAR)
      final zarVal = convertAmount(amount: 100.0, fromCurrency: 'USD', toCurrency: 'ZAR');
      expect(zarVal, closeTo(1825.0, 1.0));

      // USD to ZWG (1 USD = 26.50 ZWG)
      final zwgVal = convertAmount(amount: 100.0, fromCurrency: 'USD', toCurrency: 'ZWG');
      expect(zwgVal, closeTo(2650.0, 1.0));

      // ZAR to ZWG (18.25 ZAR = 26.50 ZWG => 100 ZAR ~ 145.2 ZWG)
      final zarToZwg = convertAmount(amount: 100.0, fromCurrency: 'ZAR', toCurrency: 'ZWG');
      expect(zarToZwg, closeTo(145.2, 1.0));
    });

    test('ExchangeRateService generates historical rates for 30d and 90d', () {
      final points30 = ExchangeRateService.instance.getHistoricalRates('USD/ZAR', days: 30);
      expect(points30.length, equals(30));
      expect(points30.first.rate, greaterThan(15.0));
      expect(points30.last.rate, closeTo(18.25, 0.01));

      final points90 = ExchangeRateService.instance.getHistoricalRates('USD/ZWG', days: 90);
      expect(points90.length, equals(90));
      expect(points90.last.rate, closeTo(26.50, 0.01));
    });
  });

  group('Session Persistence & Authentication Tests', () {
    test('createPersistentSession creates unexpired session and saves token in storage', () async {
      final session = await AuthSession.instance.createPersistentSession(userId: 'shingirai');
      expect(session, isNotNull);
      expect(session!.token, startsWith('ziva_sec_'));
      expect(session.userId, equals('shingirai'));
      expect(session.isExpired, isFalse);

      final restored = await AuthSession.instance.restoreSessionIfPossible();
      expect(restored, isTrue);
      expect(AuthSession.instance.isAuthenticated, isTrue);
    });

    test('clearPersistentSession clears stored session and causes restore to fail closed', () async {
      await AuthSession.instance.createPersistentSession(userId: 'test_exec');
      expect(await AuthSession.instance.restoreSessionIfPossible(), isTrue);

      await AuthSession.instance.clearPersistentSession();
      expect(await AuthSession.instance.restoreSessionIfPossible(), isFalse);
      expect(AuthSession.instance.isAuthenticated, isFalse);
    });

    test('AuthStorage fails closed on expired session token', () async {
      final expiredSession = StoredSessionData(
        token: 'ziva_sec_expired_token',
        userId: 'expired_user',
        issuedAt: DateTime.now().subtract(const Duration(days: 10)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      await AuthStorage.instance.saveSession(expiredSession);
      final retrieved = await AuthStorage.instance.getSession();
      expect(retrieved, isNull);
    });
  });

  group('Audit-Ready Ledger & Tax Report Generator Tests', () {
    test('ReceiptStorageService detects PDF and Image file types correctly', () {
      final service = ReceiptStorageService.instance;
      expect(service.detectFileType('invoice.pdf'), equals('pdf'));
      expect(service.detectFileType('receipt.png'), equals('image'));
      expect(service.detectFileType('scan.jpeg'), equals('image'));
      expect(service.detectFileType('document.pdf', 'application/pdf'), equals('pdf'));
      expect(service.detectFileType('photo.jpg', 'image/jpeg'), equals('image'));
    });

    test('ReceiptStorageService generates standardized GCS audit reference', () {
      final url = ReceiptStorageService.instance.generateStorageUrl(
        transactionId: 'TX_123',
        filename: 'Receipt Slip #001.pdf',
      );
      expect(url, contains('TX_123_Receipt_Slip__001.pdf'));
      expect(url, startsWith('https://storage.googleapis.com/budget-tracker-507418-receipts/tax_2026/'));
    });

    test('TaxReportGenerator builds valid PDF with magic bytes %PDF-', () async {
      final txs = [
        TransactionModel(
          transactionId: 'TX_DEDUCT_USD_01',
          transactionDate: '2026-03-15',
          accountId: 'ACC_ZW_ECOCASH_USD',
          categoryId: 'CAT_TECH_CLOUD',
          categoryName: 'Cloud SaaS & Infrastructure',
          transactionType: 'EXPENSE',
          originalAmount: -150.0,
          originalCurrency: 'USD',
          reportingAmountZar: -2737.50,
          reportingAmountUsd: -150.0,
          merchantOrPayee: 'Google Cloud Platform',
          isTaxDeductible: true,
          receiptName: 'gcp_invoice_march.pdf',
          receiptUrl: 'https://storage.googleapis.com/receipts/gcp_invoice.pdf',
        ),
        TransactionModel(
          transactionId: 'TX_DEDUCT_ZWG_01',
          transactionDate: '2026-03-20',
          accountId: 'ACC_ZW_ECOCASH_ZIG',
          categoryId: 'CAT_CONNECTIVITY',
          categoryName: 'Fibre Internet',
          transactionType: 'EXPENSE',
          originalAmount: -800.0,
          originalCurrency: 'ZWG',
          reportingAmountZar: -550.94,
          reportingAmountUsd: -30.18,
          merchantOrPayee: 'Liquid Intelligent Tech',
          isTaxDeductible: true,
          receiptName: 'liquid_fibre_receipt.png',
          receiptUrl: 'https://storage.googleapis.com/receipts/liquid_fibre.png',
        ),
      ];

      final pdfBytes = await TaxReportGenerator.instance.buildReportPdf(
        transactions: txs,
        displayCurrency: 'USD',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      // Verify PDF Header Magic Bytes %PDF-
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
      expect(pdfBytes[4], equals(0x2D)); // -
    });
  });
}
