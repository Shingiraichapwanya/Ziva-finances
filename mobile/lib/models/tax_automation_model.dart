enum TaxRuleType {
  allIncome,
  specificSources,
  aboveThreshold,
}

class TaxSkimRecord {
  final String id;
  final String sourceTransactionId;
  final String sourceDescription;
  final double grossIncomeZar;
  final double taxRateAppliedPercent;
  final double skimmedTaxAmountZar;
  final String targetEnvelopeId;
  final String targetEnvelopeName;
  final DateTime timestamp;

  const TaxSkimRecord({
    required this.id,
    required this.sourceTransactionId,
    required this.sourceDescription,
    required this.grossIncomeZar,
    required this.taxRateAppliedPercent,
    required this.skimmedTaxAmountZar,
    required this.targetEnvelopeId,
    required this.targetEnvelopeName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceTransactionId': sourceTransactionId,
        'sourceDescription': sourceDescription,
        'grossIncomeZar': grossIncomeZar,
        'taxRateAppliedPercent': taxRateAppliedPercent,
        'skimmedTaxAmountZar': skimmedTaxAmountZar,
        'targetEnvelopeId': targetEnvelopeId,
        'targetEnvelopeName': targetEnvelopeName,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TaxSkimRecord.fromJson(Map<String, dynamic> json) => TaxSkimRecord(
        id: json['id'] as String,
        sourceTransactionId: json['sourceTransactionId'] as String,
        sourceDescription: json['sourceDescription'] as String,
        grossIncomeZar: (json['grossIncomeZar'] as num).toDouble(),
        taxRateAppliedPercent: (json['taxRateAppliedPercent'] as num).toDouble(),
        skimmedTaxAmountZar: (json['skimmedTaxAmountZar'] as num).toDouble(),
        targetEnvelopeId: json['targetEnvelopeId'] as String,
        targetEnvelopeName: json['targetEnvelopeName'] as String? ?? 'Tax Reserve',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class TaxAutomationConfig {
  final bool enabled;
  final double defaultTaxRatePercent; // e.g. 27.5%
  final String targetEnvelopeId;
  final String targetEnvelopeName;
  final TaxRuleType ruleType;
  final List<String> qualifyingSources; // Keywords like 'Consulting', 'Invoice', 'Retainer', 'Trading'
  final double minimumThresholdZar; // e.g. 5000.0
  final String jurisdictionContext; // 'South Africa (SARS)' / 'Zimbabwe (ZIMRA)' / 'Custom'
  final bool autoSkimOnIncome;

  const TaxAutomationConfig({
    this.enabled = true,
    this.defaultTaxRatePercent = 27.5,
    this.targetEnvelopeId = 'CAT_ESSENTIAL_TAX',
    this.targetEnvelopeName = 'Income Tax & SARS Reserve',
    this.ruleType = TaxRuleType.allIncome,
    this.qualifyingSources = const [
      'Executive Consulting',
      'Advisory Retainer',
      'Capital Inflow',
      'Client Invoice',
      'Dividend Distribution',
    ],
    this.minimumThresholdZar = 5000.0,
    this.jurisdictionContext = 'South Africa (SARS)',
    this.autoSkimOnIncome = true,
  });

  TaxAutomationConfig copyWith({
    bool? enabled,
    double? defaultTaxRatePercent,
    String? targetEnvelopeId,
    String? targetEnvelopeName,
    TaxRuleType? ruleType,
    List<String>? qualifyingSources,
    double? minimumThresholdZar,
    String? jurisdictionContext,
    bool? autoSkimOnIncome,
  }) {
    return TaxAutomationConfig(
      enabled: enabled ?? this.enabled,
      defaultTaxRatePercent: defaultTaxRatePercent ?? this.defaultTaxRatePercent,
      targetEnvelopeId: targetEnvelopeId ?? this.targetEnvelopeId,
      targetEnvelopeName: targetEnvelopeName ?? this.targetEnvelopeName,
      ruleType: ruleType ?? this.ruleType,
      qualifyingSources: qualifyingSources ?? this.qualifyingSources,
      minimumThresholdZar: minimumThresholdZar ?? this.minimumThresholdZar,
      jurisdictionContext: jurisdictionContext ?? this.jurisdictionContext,
      autoSkimOnIncome: autoSkimOnIncome ?? this.autoSkimOnIncome,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'defaultTaxRatePercent': defaultTaxRatePercent,
        'targetEnvelopeId': targetEnvelopeId,
        'targetEnvelopeName': targetEnvelopeName,
        'ruleType': ruleType.name,
        'qualifyingSources': qualifyingSources,
        'minimumThresholdZar': minimumThresholdZar,
        'jurisdictionContext': jurisdictionContext,
        'autoSkimOnIncome': autoSkimOnIncome,
      };

  factory TaxAutomationConfig.fromJson(Map<String, dynamic> json) => TaxAutomationConfig(
        enabled: json['enabled'] as bool? ?? true,
        defaultTaxRatePercent: (json['defaultTaxRatePercent'] as num?)?.toDouble() ?? 27.5,
        targetEnvelopeId: json['targetEnvelopeId'] as String? ?? 'CAT_ESSENTIAL_TAX',
        targetEnvelopeName: json['targetEnvelopeName'] as String? ?? 'Income Tax & SARS Reserve',
        ruleType: TaxRuleType.values.firstWhere(
          (r) => r.name == json['ruleType'],
          orElse: () => TaxRuleType.allIncome,
        ),
        qualifyingSources: (json['qualifyingSources'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        minimumThresholdZar: (json['minimumThresholdZar'] as num?)?.toDouble() ?? 5000.0,
        jurisdictionContext: json['jurisdictionContext'] as String? ?? 'South Africa (SARS)',
        autoSkimOnIncome: json['autoSkimOnIncome'] as bool? ?? true,
      );

  /// Evaluates whether an inflow qualifies for tax skimming and calculates amount
  double calculateSkimAmount({
    required double grossAmountZar,
    required String description,
    required String category,
  }) {
    if (!enabled || !autoSkimOnIncome || grossAmountZar <= 0) return 0.0;

    if (grossAmountZar < minimumThresholdZar) return 0.0;

    switch (ruleType) {
      case TaxRuleType.allIncome:
        return grossAmountZar * (defaultTaxRatePercent / 100.0);

      case TaxRuleType.aboveThreshold:
        final taxableSlice = grossAmountZar - minimumThresholdZar;
        return taxableSlice > 0 ? taxableSlice * (defaultTaxRatePercent / 100.0) : 0.0;

      case TaxRuleType.specificSources:
        final matchDesc = qualifyingSources.any(
            (s) => description.toLowerCase().contains(s.toLowerCase()) || category.toLowerCase().contains(s.toLowerCase()));
        if (matchDesc) {
          return grossAmountZar * (defaultTaxRatePercent / 100.0);
        }
        return 0.0;
    }
  }
}

class TaxReserveStatus {
  final double currentTaxReserveZar;
  final double ytdTaxReservedZar;
  final double estimatedAnnualTaxObligationZar;
  final double currentQuarterEstimatedLiabilityZar;
  final double currentQuarterReservesZar;

  const TaxReserveStatus({
    required this.currentTaxReserveZar,
    required this.ytdTaxReservedZar,
    required this.estimatedAnnualTaxObligationZar,
    required this.currentQuarterEstimatedLiabilityZar,
    required this.currentQuarterReservesZar,
  });

  double get netQuarterSurplusZar => currentQuarterReservesZar - currentQuarterEstimatedLiabilityZar;
  bool get isQuarterAdequate => netQuarterSurplusZar >= 0;
  double get adequacyRatioPercent => currentQuarterEstimatedLiabilityZar > 0
      ? (currentQuarterReservesZar / currentQuarterEstimatedLiabilityZar) * 100.0
      : 100.0;
}
