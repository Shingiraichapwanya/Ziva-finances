/// EnvelopeModel - Zero-Based Budget Envelope Representation
class EnvelopeModel {
  final String categoryId;
  final String categoryName;
  final String categoryGroup; // 'ESSENTIALS', 'DISCRETIONARY', 'SINKING_FUNDS', 'DEBT_OBLIGATIONS', 'LIVING_EXPENSES'
  final String cashFlowTier;   // 'DAILY_SPENDING', 'MONTHLY_ALLOCATION', 'LONG_TERM_VAULT'
  final String targetCurrency; // 'ZAR', 'USD', 'ZiG'
  final double plannedAmountZar;
  final double actualSpentZar;
  final bool isFixedObligation;
  final bool isActive;
  final String notes;

  const EnvelopeModel({
    required this.categoryId,
    required this.categoryName,
    required this.categoryGroup,
    this.cashFlowTier = 'MONTHLY_ALLOCATION',
    this.targetCurrency = 'ZAR',
    required this.plannedAmountZar,
    this.actualSpentZar = 0.0,
    this.isFixedObligation = false,
    this.isActive = true,
    this.notes = '',
  });

  /// Current available balance in envelope (Planned - Spent)
  double get currentBalanceZar => plannedAmountZar - actualSpentZar;

  /// Remaining amount available to spend (clamped to 0 minimum for allocation display)
  double get remainingAmountZar => currentBalanceZar > 0 ? currentBalanceZar : 0.0;

  /// Percentage of planned budget consumed
  double get pctConsumed => plannedAmountZar > 0 ? (actualSpentZar / plannedAmountZar) * 100.0 : 0.0;

  /// Budget status indicator
  String get budgetStatus {
    if (actualSpentZar > plannedAmountZar) return 'OVER_BUDGET';
    if (pctConsumed >= 90.0) return 'NEAR_LIMIT';
    return 'ON_TRACK';
  }

  EnvelopeModel copyWith({
    String? categoryId,
    String? categoryName,
    String? categoryGroup,
    String? cashFlowTier,
    String? targetCurrency,
    double? plannedAmountZar,
    double? actualSpentZar,
    bool? isFixedObligation,
    bool? isActive,
    String? notes,
  }) {
    return EnvelopeModel(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryGroup: categoryGroup ?? this.categoryGroup,
      cashFlowTier: cashFlowTier ?? this.cashFlowTier,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      plannedAmountZar: plannedAmountZar ?? this.plannedAmountZar,
      actualSpentZar: actualSpentZar ?? this.actualSpentZar,
      isFixedObligation: isFixedObligation ?? this.isFixedObligation,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryGroup': categoryGroup,
      'cashFlowTier': cashFlowTier,
      'targetCurrency': targetCurrency,
      'plannedAmountZar': plannedAmountZar,
      'actualSpentZar': actualSpentZar,
      'isFixedObligation': isFixedObligation,
      'isActive': isActive,
      'notes': notes,
    };
  }

  factory EnvelopeModel.fromJson(Map<String, dynamic> json) {
    return EnvelopeModel(
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      categoryGroup: json['categoryGroup']?.toString() ?? 'ESSENTIALS',
      cashFlowTier: json['cashFlowTier']?.toString() ?? 'MONTHLY_ALLOCATION',
      targetCurrency: json['targetCurrency']?.toString() ?? 'ZAR',
      plannedAmountZar: (json['plannedAmountZar'] as num?)?.toDouble() ??
          (json['plannedAmount'] as num?)?.toDouble() ??
          0.0,
      actualSpentZar: (json['actualSpentZar'] as num?)?.toDouble() ?? 0.0,
      isFixedObligation: json['isFixedObligation'] == true || json['isFixedObligation'] == 1,
      isActive: json['isActive'] != false && json['isActive'] != 0,
      notes: json['notes']?.toString() ?? '',
    );
  }

  @override
  String toString() =>
      'EnvelopeModel(id: $categoryId, name: $categoryName, planned: $plannedAmountZar, spent: $actualSpentZar, balance: $currentBalanceZar)';
}
