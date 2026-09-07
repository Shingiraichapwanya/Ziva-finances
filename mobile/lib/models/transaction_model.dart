import 'dart:convert';

class TransactionModel {
  final String transactionId;
  final String transactionDate;
  final String accountId;
  final String categoryId;
  final String categoryName;
  final String transactionType; // 'EXPENSE', 'INCOME', 'ALLOCATION_TRANSFER'
  final double originalAmount;
  final String originalCurrency; // 'ZAR', 'USD', 'ZiG'
  final double reportingAmountZar;
  final double reportingAmountUsd;
  final String merchantOrPayee;
  final String paymentMethod;
  final bool isTaxDeductible;
  final String notes;
  final List<String> tags;
  final bool isSynced; // Local SQLite tracking flag
  final String? receiptName;
  final String? receiptUrl;
  final String? receiptFileType; // 'pdf' | 'image' | null

  // Multi-Currency & Audit References (Backward-Compatible Aliases)
  String get currencyCode => originalCurrency;
  String? get receiptStorageUrl => receiptUrl;

  TransactionModel({
    required this.transactionId,
    required this.transactionDate,
    required this.accountId,
    required this.categoryId,
    this.categoryName = 'General',
    required this.transactionType,
    required this.originalAmount,
    required this.originalCurrency,
    required this.reportingAmountZar,
    required this.reportingAmountUsd,
    required this.merchantOrPayee,
    this.paymentMethod = 'EFT/Card',
    this.isTaxDeductible = false,
    this.notes = '',
    this.tags = const ['mobile_app'],
    this.isSynced = true,
    this.receiptName,
    this.receiptUrl,
    this.receiptFileType,
  });

  bool get hasReceipt =>
      (receiptName != null && receiptName!.isNotEmpty) ||
      (receiptUrl != null && receiptUrl!.isNotEmpty);

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final rawOrigAmount = json['originalAmount'] ?? json['original_amount'] ?? 0.0;
    final double origAmount = rawOrigAmount is num
        ? rawOrigAmount.toDouble()
        : double.tryParse(rawOrigAmount.toString()) ?? 0.0;

    final rawZarAmount = json['reportingAmountZar'] ?? json['reporting_amount_zar'] ?? 0.0;
    final double zarAmount = rawZarAmount is num
        ? rawZarAmount.toDouble()
        : double.tryParse(rawZarAmount.toString()) ?? 0.0;

    final rawUsdAmount = json['reportingAmountUsd'] ?? json['reporting_amount_usd'] ?? 0.0;
    final double usdAmount = rawUsdAmount is num
        ? rawUsdAmount.toDouble()
        : double.tryParse(rawUsdAmount.toString()) ?? 0.0;

    List<String> parsedTags;
    final rawTags = json['tags'];
    if (rawTags is String) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is Iterable) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        } else {
          parsedTags = ['mobile_app'];
        }
      } catch (_) {
        parsedTags = ['mobile_app'];
      }
    } else if (rawTags is Iterable) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    } else {
      parsedTags = ['mobile_app'];
    }

    final String? rName = (json['receiptName'] ?? json['receipt_name'])?.toString();
    final String? rUrl = (json['receiptUrl'] ?? json['receipt_url'] ?? json['receiptStorageUrl'] ?? json['receipt_storage_url'])?.toString();
    final String? rFileType = (json['receiptFileType'] ?? json['receipt_file_type'])?.toString();
    final String rawCurrency = (json['currency_code'] ?? json['currencyCode'] ?? json['originalCurrency'] ?? json['original_currency'] ?? 'ZAR').toString();
    // Normalize 'ZiG' to 'ZWG'
    final String effectiveCurrency = rawCurrency.toUpperCase() == 'ZIG' ? 'ZWG' : rawCurrency.toUpperCase();

    return TransactionModel(
      transactionId: (json['transactionId'] ?? json['transaction_id'] ?? '').toString(),
      transactionDate: (json['transactionDate'] ?? json['transaction_date'] ?? DateTime.now().toIso8601String().split('T')[0]).toString(),
      accountId: (json['accountId'] ?? json['account_id'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? json['category_id'] ?? 'CAT_GENERAL').toString(),
      categoryName: (json['categoryName'] ?? json['category_name'] ?? 'General').toString(),
      transactionType: (json['transactionType'] ?? json['transaction_type'] ?? 'EXPENSE').toString(),
      originalAmount: origAmount,
      originalCurrency: effectiveCurrency,
      reportingAmountZar: zarAmount,
      reportingAmountUsd: usdAmount,
      merchantOrPayee: (json['merchantOrPayee'] ?? json['merchant_or_payee'] ?? 'Direct Entry').toString(),
      paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'EFT/Card').toString(),
      isTaxDeductible: json['isTaxDeductible'] == 1 || json['isTaxDeductible'] == true || json['is_tax_deductible'] == true,
      notes: (json['notes'] ?? '').toString(),
      tags: parsedTags,
      isSynced: json['is_synced'] == null ? true : (json['is_synced'] == 1 || json['is_synced'] == true),
      receiptName: rName,
      receiptUrl: rUrl,
      receiptFileType: rFileType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'transactionDate': transactionDate,
      'accountId': accountId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'transactionType': transactionType,
      'originalAmount': originalAmount,
      'originalCurrency': originalCurrency,
      'currency_code': originalCurrency,
      'currencyCode': originalCurrency,
      'reportingAmountZar': reportingAmountZar,
      'reportingAmountUsd': reportingAmountUsd,
      'merchantOrPayee': merchantOrPayee,
      'paymentMethod': paymentMethod,
      'isTaxDeductible': isTaxDeductible,
      'notes': notes,
      'tags': tags,
      'receiptName': receiptName,
      'receiptUrl': receiptUrl,
      'receipt_storage_url': receiptUrl,
      'receiptStorageUrl': receiptUrl,
      'receipt_file_type': receiptFileType,
      'receiptFileType': receiptFileType,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'transaction_id': transactionId,
      'transaction_date': transactionDate,
      'account_id': accountId,
      'category_id': categoryId,
      'category_name': categoryName,
      'transaction_type': transactionType,
      'original_amount': originalAmount,
      'original_currency': originalCurrency,
      'currency_code': originalCurrency,
      'reporting_amount_zar': reportingAmountZar,
      'reporting_amount_usd': reportingAmountUsd,
      'merchant_or_payee': merchantOrPayee,
      'payment_method': paymentMethod,
      'is_tax_deductible': isTaxDeductible ? 1 : 0,
      'notes': notes,
      'tags': jsonEncode(tags),
      'is_synced': isSynced ? 1 : 0,
      'receipt_name': receiptName,
      'receipt_url': receiptUrl,
      'receipt_storage_url': receiptUrl,
      'receipt_file_type': receiptFileType,
    };
  }

  TransactionModel copyWith({
    String? transactionId,
    String? transactionDate,
    String? accountId,
    String? categoryId,
    String? categoryName,
    String? transactionType,
    double? originalAmount,
    String? originalCurrency,
    String? currencyCode,
    double? reportingAmountZar,
    double? reportingAmountUsd,
    String? merchantOrPayee,
    String? paymentMethod,
    bool? isTaxDeductible,
    String? notes,
    List<String>? tags,
    bool? isSynced,
    String? receiptName,
    String? receiptUrl,
    String? receiptStorageUrl,
    String? receiptFileType,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      transactionDate: transactionDate ?? this.transactionDate,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      transactionType: transactionType ?? this.transactionType,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: currencyCode ?? originalCurrency ?? this.originalCurrency,
      reportingAmountZar: reportingAmountZar ?? this.reportingAmountZar,
      reportingAmountUsd: reportingAmountUsd ?? this.reportingAmountUsd,
      merchantOrPayee: merchantOrPayee ?? this.merchantOrPayee,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isTaxDeductible: isTaxDeductible ?? this.isTaxDeductible,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      isSynced: isSynced ?? this.isSynced,
      receiptName: receiptName ?? this.receiptName,
      receiptUrl: receiptStorageUrl ?? receiptUrl ?? this.receiptUrl,
      receiptFileType: receiptFileType ?? this.receiptFileType,
    );
  }
}

