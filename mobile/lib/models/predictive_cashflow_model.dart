enum AlertSeverity {
  critical,
  warning,
  advisory,
}

class KnownObligation {
  final String id;
  final String title;
  final DateTime dueDate;
  final double amountZar;
  final String targetEnvelopeId;
  final String? accountId;
  final bool isRecurring;

  const KnownObligation({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.amountZar,
    required this.targetEnvelopeId,
    this.accountId,
    this.isRecurring = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dueDate': dueDate.toIso8601String(),
      'amountZar': amountZar,
      'targetEnvelopeId': targetEnvelopeId,
      'accountId': accountId,
      'isRecurring': isRecurring,
    };
  }

  factory KnownObligation.fromJson(Map<String, dynamic> json) {
    return KnownObligation(
      id: json['id'] as String,
      title: json['title'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      amountZar: (json['amountZar'] as num).toDouble(),
      targetEnvelopeId: json['targetEnvelopeId'] as String,
      accountId: json['accountId'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? true,
    );
  }
}

class PredictiveAlert {
  final String id;
  final AlertSeverity severity;
  final String headline;
  final String explanation;
  final String targetName; // e.g. "FNB Operating Account", "Tax Reserve Envelope"
  final DateTime breachDate;
  final double projectedShortfallZar;
  final List<String> suggestedMitigations;

  const PredictiveAlert({
    required this.id,
    required this.severity,
    required this.headline,
    required this.explanation,
    required this.targetName,
    required this.breachDate,
    required this.projectedShortfallZar,
    this.suggestedMitigations = const [],
  });

  int get daysUntilBreach {
    final now = DateTime.now();
    final diff = breachDate.difference(now).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class PredictiveCashFlowProjection {
  final int horizonDays; // 7, 14, 30
  final double currentLiquidZar;
  final double projectedLiquidZar;
  final double dailyBurnRateZar;
  final double upcomingObligationsTotalZar;
  final double expectedInflowsTotalZar;
  final Map<String, double> projectedEnvelopeBalances;
  final List<KnownObligation> upcomingObligations;
  final List<PredictiveAlert> alerts;

  const PredictiveCashFlowProjection({
    required this.horizonDays,
    required this.currentLiquidZar,
    required this.projectedLiquidZar,
    required this.dailyBurnRateZar,
    required this.upcomingObligationsTotalZar,
    required this.expectedInflowsTotalZar,
    this.projectedEnvelopeBalances = const {},
    this.upcomingObligations = const [],
    this.alerts = const [],
  });

  bool get hasCriticalAlerts => alerts.any((a) => a.severity == AlertSeverity.critical);
  bool get hasWarnings => alerts.any((a) => a.severity == AlertSeverity.warning);
}
