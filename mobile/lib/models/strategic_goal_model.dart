import 'dart:math' as math;

enum GoalIntent {
  buildEmergencyReserve,
  payOffDebt,
  accumulatePurchase,
  deRiskPortfolio,
  boostSavingsRate,
}

enum GoalPriority { high, medium, low }

class StrategicRecommendation {
  final double recommendedMonthlyAllocationZar;
  final String primaryTargetEnvelopeId;
  final String primaryTargetEnvelopeName;
  final String? debtPrioritizationMessage;
  final List<String> reallocationSuggestions;
  final int projectedCompletionMonths;
  final DateTime projectedCompletionDate;
  final List<String> actionSteps;
  final String statusNudge;

  const StrategicRecommendation({
    required this.recommendedMonthlyAllocationZar,
    required this.primaryTargetEnvelopeId,
    required this.primaryTargetEnvelopeName,
    this.debtPrioritizationMessage,
    required this.reallocationSuggestions,
    required this.projectedCompletionMonths,
    required this.projectedCompletionDate,
    required this.actionSteps,
    required this.statusNudge,
  });

  Map<String, dynamic> toJson() => {
        'recommendedMonthlyAllocationZar': recommendedMonthlyAllocationZar,
        'primaryTargetEnvelopeId': primaryTargetEnvelopeId,
        'primaryTargetEnvelopeName': primaryTargetEnvelopeName,
        'debtPrioritizationMessage': debtPrioritizationMessage,
        'reallocationSuggestions': reallocationSuggestions,
        'projectedCompletionMonths': projectedCompletionMonths,
        'projectedCompletionDate': projectedCompletionDate.toIso8601String(),
        'actionSteps': actionSteps,
        'statusNudge': statusNudge,
      };

  factory StrategicRecommendation.fromJson(Map<String, dynamic> json) => StrategicRecommendation(
        recommendedMonthlyAllocationZar: (json['recommendedMonthlyAllocationZar'] as num).toDouble(),
        primaryTargetEnvelopeId: json['primaryTargetEnvelopeId'] as String,
        primaryTargetEnvelopeName: json['primaryTargetEnvelopeName'] as String,
        debtPrioritizationMessage: json['debtPrioritizationMessage'] as String?,
        reallocationSuggestions: (json['reallocationSuggestions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        projectedCompletionMonths: json['projectedCompletionMonths'] as int? ?? 12,
        projectedCompletionDate: DateTime.parse(json['projectedCompletionDate'] as String),
        actionSteps: (json['actionSteps'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
        statusNudge: json['statusNudge'] as String? ?? 'On Track',
      );
}

class StrategicGoalModel {
  final String id;
  final String rawInputPrompt;
  final String title;
  final GoalIntent intent;
  final GoalPriority priority;
  final double targetAmountZar;
  final double currentAmountZar;
  final int targetHorizonMonths;
  final DateTime targetDate;
  final bool isCompleted;
  final StrategicRecommendation recommendation;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StrategicGoalModel({
    required this.id,
    required this.rawInputPrompt,
    required this.title,
    required this.intent,
    required this.priority,
    required this.targetAmountZar,
    required this.currentAmountZar,
    required this.targetHorizonMonths,
    required this.targetDate,
    this.isCompleted = false,
    required this.recommendation,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progressFraction =>
      targetAmountZar > 0 ? (currentAmountZar / targetAmountZar).clamp(0.0, 1.0) : 1.0;

  double get progressPercent => progressFraction * 100.0;

  double get remainingZar => math.max(0, targetAmountZar - currentAmountZar);

  StrategicGoalModel copyWith({
    String? id,
    String? rawInputPrompt,
    String? title,
    GoalIntent? intent,
    GoalPriority? priority,
    double? targetAmountZar,
    double? currentAmountZar,
    int? targetHorizonMonths,
    DateTime? targetDate,
    bool? isCompleted,
    StrategicRecommendation? recommendation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StrategicGoalModel(
      id: id ?? this.id,
      rawInputPrompt: rawInputPrompt ?? this.rawInputPrompt,
      title: title ?? this.title,
      intent: intent ?? this.intent,
      priority: priority ?? this.priority,
      targetAmountZar: targetAmountZar ?? this.targetAmountZar,
      currentAmountZar: currentAmountZar ?? this.currentAmountZar,
      targetHorizonMonths: targetHorizonMonths ?? this.targetHorizonMonths,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      recommendation: recommendation ?? this.recommendation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawInputPrompt': rawInputPrompt,
        'title': title,
        'intent': intent.name,
        'priority': priority.name,
        'targetAmountZar': targetAmountZar,
        'currentAmountZar': currentAmountZar,
        'targetHorizonMonths': targetHorizonMonths,
        'targetDate': targetDate.toIso8601String(),
        'isCompleted': isCompleted,
        'recommendation': recommendation.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StrategicGoalModel.fromJson(Map<String, dynamic> json) => StrategicGoalModel(
        id: json['id'] as String,
        rawInputPrompt: json['rawInputPrompt'] as String? ?? '',
        title: json['title'] as String,
        intent: GoalIntent.values.firstWhere(
          (i) => i.name == json['intent'],
          orElse: () => GoalIntent.buildEmergencyReserve,
        ),
        priority: GoalPriority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => GoalPriority.high,
        ),
        targetAmountZar: (json['targetAmountZar'] as num).toDouble(),
        currentAmountZar: (json['currentAmountZar'] as num).toDouble(),
        targetHorizonMonths: json['targetHorizonMonths'] as int? ?? 12,
        targetDate: DateTime.parse(json['targetDate'] as String),
        isCompleted: json['isCompleted'] as bool? ?? false,
        recommendation: StrategicRecommendation.fromJson(json['recommendation'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  /// Natural Language Goal Parser & Personal CFO Strategy Generator
  static StrategicGoalModel parseFromPrompt({
    required String prompt,
    required double currentEmergencyReserveZar,
    required double monthlyNetSurplusZar,
    required double totalHighInterestDebtZar,
  }) {
    final lower = prompt.toLowerCase();

    GoalIntent intent = GoalIntent.buildEmergencyReserve;
    String title = 'Financial Milestone';
    GoalPriority priority = GoalPriority.medium;
    int horizonMonths = 18;
    double targetAmount = 150000.0;
    String targetEnvId = 'CAT_SINKING_EMERGENCY';
    String targetEnvName = 'Emergency Liquidity Reserve';
    double currentAmount = currentEmergencyReserveZar;

    // 1. Detect Intent
    if (lower.contains('emergency') || lower.contains('buffer') || lower.contains('safety net') || lower.contains('reserve')) {
      intent = GoalIntent.buildEmergencyReserve;
      title = 'Build Executive Liquidity Buffer';
      targetEnvId = 'CAT_SINKING_EMERGENCY';
      targetEnvName = 'Emergency Liquidity Reserve';
      targetAmount = 250000.0;
      currentAmount = currentEmergencyReserveZar;
      priority = GoalPriority.high;
    } else if (lower.contains('debt') || lower.contains('card') || lower.contains('pay off') || lower.contains('wesbank') || lower.contains('settle')) {
      intent = GoalIntent.payOffDebt;
      title = 'Accelerate High-Interest Debt Payoff';
      targetEnvId = 'CAT_DISCRETIONARY_ENTERTAINMENT';
      targetEnvName = 'Debt Liquidation Allocation';
      targetAmount = totalHighInterestDebtZar > 0 ? totalHighInterestDebtZar : 150000.0;
      currentAmount = 25000.0;
      priority = GoalPriority.high;
    } else if (lower.contains('car') || lower.contains('vehicle') || lower.contains('house') || lower.contains('property') || lower.contains('purchase') || lower.contains('buy') || lower.contains('save for')) {
      intent = GoalIntent.accumulatePurchase;
      title = 'Capital Accumulation for Major Asset';
      targetEnvId = 'CAT_SINKING_MAINTENANCE';
      targetEnvName = 'Asset Acquisition Reserve';
      targetAmount = 450000.0;
      currentAmount = 45000.0;
      priority = GoalPriority.medium;
    } else if (lower.contains('risk') || lower.contains('bonds') || lower.contains('treasury') || lower.contains('protect')) {
      intent = GoalIntent.deRiskPortfolio;
      title = 'Portfolio De-Risking & Capital Preservation';
      targetEnvId = 'CAT_ESSENTIAL_SAVINGS';
      targetEnvName = 'Fixed Income & Bond Allocation';
      targetAmount = 500000.0;
      currentAmount = 80000.0;
      priority = GoalPriority.medium;
    } else {
      intent = GoalIntent.boostSavingsRate;
      title = 'Supercharge Net Savings Surplus';
      targetEnvId = 'CAT_SINKING_EMERGENCY';
      targetEnvName = 'Wealth Accumulation Engine';
      targetAmount = 300000.0;
      currentAmount = currentEmergencyReserveZar;
      priority = GoalPriority.medium;
    }

    // 2. Extract Horizon from Text
    final monthMatch = RegExp(r'(\d+)\s*(month|mo|months)').firstMatch(lower);
    final yearMatch = RegExp(r'(\d+)\s*(year|yr|years)').firstMatch(lower);
    if (monthMatch != null) {
      horizonMonths = int.tryParse(monthMatch.group(1) ?? '') ?? horizonMonths;
    } else if (yearMatch != null) {
      horizonMonths = (int.tryParse(yearMatch.group(1) ?? '') ?? 1) * 12;
    }

    // 3. Extract Amount from Text (e.g. 500k, 250000, R500 000, R120,000, 1.5m)
    // Avoid matching 'm' from 'month' or 'months'
    final mAmountMatch = RegExp(r'(r|zar|\$)?\s*(\d+(\.\d+)?)\s*(million|\bm\b)(?!onth)').firstMatch(lower);
    final kAmountMatch = RegExp(r'(r|zar|\$)?\s*(\d+)\s*(k|thousand)\b').firstMatch(lower);
    final rawAmountMatch = RegExp(r'(r|zar|\$)?\s*([\d,]{4,11})').firstMatch(lower);

    if (mAmountMatch != null) {
      final num = double.tryParse(mAmountMatch.group(2) ?? '');
      if (num != null) targetAmount = num * 1000000;
    } else if (kAmountMatch != null) {
      final num = double.tryParse(kAmountMatch.group(2) ?? '');
      if (num != null) targetAmount = num * 1000;
    } else if (rawAmountMatch != null) {
      final clean = rawAmountMatch.group(2)?.replaceAll(',', '') ?? '';
      final num = double.tryParse(clean);
      if (num != null) targetAmount = num;
    }

    // 4. Extract Priority
    if (lower.contains('urgent') || lower.contains('critical') || lower.contains('high priority')) {
      priority = GoalPriority.high;
    } else if (lower.contains('low priority') || lower.contains('someday')) {
      priority = GoalPriority.low;
    }

    // 5. Generate Personal CFO Strategy
    final remaining = math.max(0, targetAmount - currentAmount);
    final double neededMonthly = (horizonMonths > 0 ? (remaining / horizonMonths) : remaining).toDouble();

    final actionSteps = <String>[];
    final reallocations = <String>[];
    String? debtMsg;

    actionSteps.add('Allocate R ${neededMonthly.toStringAsFixed(0)}/mo directly into "$targetEnvName".');

    if (totalHighInterestDebtZar > 0 && intent != GoalIntent.payOffDebt) {
      debtMsg = 'You have R ${totalHighInterestDebtZar.toStringAsFixed(0)} in revolving debt (>15% APR). Maintain minimum debt payoff while funding this goal.';
      actionSteps.add('Maintain scheduled R 5,000/mo paydown on Discovery Card to stop interest erosion.');
    }

    if (neededMonthly > monthlyNetSurplusZar * 0.7) {
      reallocations.add('Reallocate R 6,000/mo from Discretionary Dining & Gear into target envelope.');
      actionSteps.add('Trim discretionary envelopes by ~15% until initial milestone is funded.');
    } else {
      actionSteps.add('Automate payment on the 1st of each calendar month via recurring standing order.');
    }

    final projectedMonths = monthlyNetSurplusZar > 0 ? (remaining / (monthlyNetSurplusZar * 0.4)).ceil().clamp(1, 60) : horizonMonths;
    final projectedDate = DateTime.now().add(Duration(days: projectedMonths * 30));

    String statusNudge = 'On Track';
    if (projectedMonths < horizonMonths) {
      statusNudge = 'Ahead of Pace (${(horizonMonths - projectedMonths)} months earlier than target)';
    } else if (projectedMonths > horizonMonths) {
      statusNudge = 'Action Required: Gap of ~R ${(neededMonthly - monthlyNetSurplusZar * 0.4).toStringAsFixed(0)}/mo to meet deadline';
    }

    final recommendation = StrategicRecommendation(
      recommendedMonthlyAllocationZar: neededMonthly,
      primaryTargetEnvelopeId: targetEnvId,
      primaryTargetEnvelopeName: targetEnvName,
      debtPrioritizationMessage: debtMsg,
      reallocationSuggestions: reallocations,
      projectedCompletionMonths: projectedMonths,
      projectedCompletionDate: projectedDate,
      actionSteps: actionSteps,
      statusNudge: statusNudge,
    );

    return StrategicGoalModel(
      id: 'GOAL_${DateTime.now().millisecondsSinceEpoch}',
      rawInputPrompt: prompt,
      title: title,
      intent: intent,
      priority: priority,
      targetAmountZar: targetAmount,
      currentAmountZar: currentAmount,
      targetHorizonMonths: horizonMonths,
      targetDate: DateTime.now().add(Duration(days: horizonMonths * 30)),
      recommendation: recommendation,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
