class ConfidenceEngineConfig {
  final double highConfidenceThresholdPercent; // Default 95.0%
  final double mediumConfidenceThresholdPercent; // Default 70.0%
  final bool autoAddEnabled; // If true, items >= highConfidenceThresholdPercent are auto-added
  final Map<String, double> sourceWeights; // Adjust confidence by data source reliability

  const ConfidenceEngineConfig({
    this.highConfidenceThresholdPercent = 95.0,
    this.mediumConfidenceThresholdPercent = 70.0,
    this.autoAddEnabled = true,
    this.sourceWeights = const {
      'officialBankStatement': 1.05,
      'bankNotificationEmail': 1.0,
      'onlineMerchantReceipt': 0.95,
      'handwrittenDepositSlip': 0.90,
      'casualEmailSnippet': 0.75,
    },
  });

  ConfidenceEngineConfig copyWith({
    double? highConfidenceThresholdPercent,
    double? mediumConfidenceThresholdPercent,
    bool? autoAddEnabled,
    Map<String, double>? sourceWeights,
  }) {
    return ConfidenceEngineConfig(
      highConfidenceThresholdPercent: highConfidenceThresholdPercent ?? this.highConfidenceThresholdPercent,
      mediumConfidenceThresholdPercent: mediumConfidenceThresholdPercent ?? this.mediumConfidenceThresholdPercent,
      autoAddEnabled: autoAddEnabled ?? this.autoAddEnabled,
      sourceWeights: sourceWeights ?? this.sourceWeights,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'highConfidenceThresholdPercent': highConfidenceThresholdPercent,
      'mediumConfidenceThresholdPercent': mediumConfidenceThresholdPercent,
      'autoAddEnabled': autoAddEnabled,
      'sourceWeights': sourceWeights,
    };
  }

  factory ConfidenceEngineConfig.fromJson(Map<String, dynamic> json) {
    return ConfidenceEngineConfig(
      highConfidenceThresholdPercent: (json['highConfidenceThresholdPercent'] as num?)?.toDouble() ?? 95.0,
      mediumConfidenceThresholdPercent: (json['mediumConfidenceThresholdPercent'] as num?)?.toDouble() ?? 70.0,
      autoAddEnabled: json['autoAddEnabled'] as bool? ?? true,
      sourceWeights: (json['sourceWeights'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {
            'officialBankStatement': 1.05,
            'bankNotificationEmail': 1.0,
            'onlineMerchantReceipt': 0.95,
            'handwrittenDepositSlip': 0.90,
            'casualEmailSnippet': 0.75,
          },
    );
  }
}

class AutoAddAuditRecord {
  final String id;
  final DateTime timestamp;
  final String sourceType; // 'Email / Google Workspace', 'Handwritten Slip OCR', 'Banking API Feed'
  final String createdTransactionId;
  final String counterparty;
  final double amountZar;
  final String currency;
  final double confidenceScore;
  final String decisionReason;
  final String rawSnippet;

  const AutoAddAuditRecord({
    required this.id,
    required this.timestamp,
    required this.sourceType,
    required this.createdTransactionId,
    required this.counterparty,
    required this.amountZar,
    this.currency = 'ZAR',
    required this.confidenceScore,
    required this.decisionReason,
    required this.rawSnippet,
  });

  String get formattedConfidence => '${(confidenceScore * 100).toStringAsFixed(0)}%';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'sourceType': sourceType,
      'createdTransactionId': createdTransactionId,
      'counterparty': counterparty,
      'amountZar': amountZar,
      'currency': currency,
      'confidenceScore': confidenceScore,
      'decisionReason': decisionReason,
      'rawSnippet': rawSnippet,
    };
  }

  factory AutoAddAuditRecord.fromJson(Map<String, dynamic> json) {
    return AutoAddAuditRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sourceType: json['sourceType'] as String,
      createdTransactionId: json['createdTransactionId'] as String,
      counterparty: json['counterparty'] as String,
      amountZar: (json['amountZar'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'ZAR',
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      decisionReason: json['decisionReason'] as String,
      rawSnippet: json['rawSnippet'] as String,
    );
  }
}
