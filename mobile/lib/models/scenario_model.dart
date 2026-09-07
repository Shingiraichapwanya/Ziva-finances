import 'dart:math' as math;

enum ScenarioStatus { draft, active, archived, committed }

enum Frequency { monthly, quarterly, annual }

class ScenarioExpense {
  final String id;
  final String title;
  final double amountZar;
  final String? category;
  final String? sourceEnvelopeId;
  final DateTime targetDate;

  const ScenarioExpense({
    required this.id,
    required this.title,
    required this.amountZar,
    this.category,
    this.sourceEnvelopeId,
    required this.targetDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amountZar': amountZar,
        'category': category,
        'sourceEnvelopeId': sourceEnvelopeId,
        'targetDate': targetDate.toIso8601String(),
      };

  factory ScenarioExpense.fromJson(Map<String, dynamic> json) => ScenarioExpense(
        id: json['id'] as String,
        title: json['title'] as String,
        amountZar: (json['amountZar'] as num).toDouble(),
        category: json['category'] as String?,
        sourceEnvelopeId: json['sourceEnvelopeId'] as String?,
        targetDate: DateTime.parse(json['targetDate'] as String),
      );
}

class ScenarioRecurringChange {
  final String id;
  final String title;
  final double monthlyDeltaZar; // Positive for income or expense reduction, negative for new recurring expense
  final bool isIncome;
  final String? targetEnvelopeId;

  const ScenarioRecurringChange({
    required this.id,
    required this.title,
    required this.monthlyDeltaZar,
    required this.isIncome,
    this.targetEnvelopeId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'monthlyDeltaZar': monthlyDeltaZar,
        'isIncome': isIncome,
        'targetEnvelopeId': targetEnvelopeId,
      };

  factory ScenarioRecurringChange.fromJson(Map<String, dynamic> json) => ScenarioRecurringChange(
        id: json['id'] as String,
        title: json['title'] as String,
        monthlyDeltaZar: (json['monthlyDeltaZar'] as num).toDouble(),
        isIncome: json['isIncome'] as bool? ?? false,
        targetEnvelopeId: json['targetEnvelopeId'] as String?,
      );
}

class StressTestParameters {
  final double interestRateDeltaPercent; // e.g. +2.5%
  final double incomeReliabilityFactor; // e.g. 0.85 = 15% reduction in inflows
  final double expenseSpikeFactor; // e.g. 1.20 = 20% increase in operational outflows

  const StressTestParameters({
    this.interestRateDeltaPercent = 0.0,
    this.incomeReliabilityFactor = 1.0,
    this.expenseSpikeFactor = 1.0,
  });

  StressTestParameters copyWith({
    double? interestRateDeltaPercent,
    double? incomeReliabilityFactor,
    double? expenseSpikeFactor,
  }) {
    return StressTestParameters(
      interestRateDeltaPercent: interestRateDeltaPercent ?? this.interestRateDeltaPercent,
      incomeReliabilityFactor: incomeReliabilityFactor ?? this.incomeReliabilityFactor,
      expenseSpikeFactor: expenseSpikeFactor ?? this.expenseSpikeFactor,
    );
  }

  Map<String, dynamic> toJson() => {
        'interestRateDeltaPercent': interestRateDeltaPercent,
        'incomeReliabilityFactor': incomeReliabilityFactor,
        'expenseSpikeFactor': expenseSpikeFactor,
      };

  factory StressTestParameters.fromJson(Map<String, dynamic> json) => StressTestParameters(
        interestRateDeltaPercent: (json['interestRateDeltaPercent'] as num?)?.toDouble() ?? 0.0,
        incomeReliabilityFactor: (json['incomeReliabilityFactor'] as num?)?.toDouble() ?? 1.0,
        expenseSpikeFactor: (json['expenseSpikeFactor'] as num?)?.toDouble() ?? 1.0,
      );
}

class SimulationPoint {
  final int monthIndex;
  final String label;
  final double currentNetWorthZar;
  final double scenarioNetWorthZar;
  final double currentCashFlowZar;
  final double scenarioCashFlowZar;
  final double emergencyBufferZar;

  const SimulationPoint({
    required this.monthIndex,
    required this.label,
    required this.currentNetWorthZar,
    required this.scenarioNetWorthZar,
    required this.currentCashFlowZar,
    required this.scenarioCashFlowZar,
    required this.emergencyBufferZar,
  });
}

class ScenarioSimulationResult {
  final List<SimulationPoint> trajectory;
  final double projectedNetWorthDeltaZar;
  final double monthlyCashFlowDeltaZar;
  final double bufferRunwayMonths;
  final double resiliencyScorePercent; // 0 to 100%
  final List<String> strategicWarnings;
  final List<String> recommendedSafeguards;

  const ScenarioSimulationResult({
    required this.trajectory,
    required this.projectedNetWorthDeltaZar,
    required this.monthlyCashFlowDeltaZar,
    required this.bufferRunwayMonths,
    required this.resiliencyScorePercent,
    required this.strategicWarnings,
    required this.recommendedSafeguards,
  });
}

class ScenarioModel {
  final String id;
  final String title;
  final String description;
  final int horizonMonths; // e.g. 6, 12, 24, 36
  final DateTime startDate;
  final ScenarioStatus status;
  final List<ScenarioExpense> oneTimeExpenses;
  final List<ScenarioRecurringChange> recurringChanges;
  final List<String> fundingSourcePriorityIds; // envelope IDs in drawdown priority
  final StressTestParameters stressTest;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScenarioModel({
    required this.id,
    required this.title,
    required this.description,
    this.horizonMonths = 12,
    required this.startDate,
    this.status = ScenarioStatus.active,
    this.oneTimeExpenses = const [],
    this.recurringChanges = const [],
    this.fundingSourcePriorityIds = const [],
    this.stressTest = const StressTestParameters(),
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalOneTimeCapitalOutflowZar =>
      oneTimeExpenses.fold<double>(0.0, (sum, e) => sum + e.amountZar);

  double get netMonthlyRecurringDeltaZar =>
      recurringChanges.fold<double>(0.0, (sum, r) => sum + r.monthlyDeltaZar);

  ScenarioModel copyWith({
    String? id,
    String? title,
    String? description,
    int? horizonMonths,
    DateTime? startDate,
    ScenarioStatus? status,
    List<ScenarioExpense>? oneTimeExpenses,
    List<ScenarioRecurringChange>? recurringChanges,
    List<String>? fundingSourcePriorityIds,
    StressTestParameters? stressTest,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScenarioModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      horizonMonths: horizonMonths ?? this.horizonMonths,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      oneTimeExpenses: oneTimeExpenses ?? this.oneTimeExpenses,
      recurringChanges: recurringChanges ?? this.recurringChanges,
      fundingSourcePriorityIds: fundingSourcePriorityIds ?? this.fundingSourcePriorityIds,
      stressTest: stressTest ?? this.stressTest,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'horizonMonths': horizonMonths,
        'startDate': startDate.toIso8601String(),
        'status': status.name,
        'oneTimeExpenses': oneTimeExpenses.map((e) => e.toJson()).toList(),
        'recurringChanges': recurringChanges.map((r) => r.toJson()).toList(),
        'fundingSourcePriorityIds': fundingSourcePriorityIds,
        'stressTest': stressTest.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScenarioModel.fromJson(Map<String, dynamic> json) => ScenarioModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        horizonMonths: json['horizonMonths'] as int? ?? 12,
        startDate: DateTime.parse(json['startDate'] as String),
        status: ScenarioStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ScenarioStatus.active,
        ),
        oneTimeExpenses: (json['oneTimeExpenses'] as List<dynamic>?)
                ?.map((e) => ScenarioExpense.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        recurringChanges: (json['recurringChanges'] as List<dynamic>?)
                ?.map((r) => ScenarioRecurringChange.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
        fundingSourcePriorityIds: (json['fundingSourcePriorityIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        stressTest: json['stressTest'] != null
            ? StressTestParameters.fromJson(json['stressTest'] as Map<String, dynamic>)
            : const StressTestParameters(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  /// Executes sandbox simulation over the horizon without touching live balances
  ScenarioSimulationResult runSimulation({
    double initialNetWorthZar = 1845000.0,
    double baseMonthlyInflowZar = 195400.0,
    double baseMonthlyOutflowZar = 88200.0,
    double initialEmergencyBufferZar = 145000.0,
  }) {
    final points = <SimulationPoint>[];
    final baseMonthlySurplus = baseMonthlyInflowZar - baseMonthlyOutflowZar;

    // Apply stress test modifiers
    final stressedInflow = baseMonthlyInflowZar * stressTest.incomeReliabilityFactor;
    final stressedOutflow = baseMonthlyOutflowZar * stressTest.expenseSpikeFactor;
    final stressedBaseSurplus = stressedInflow - stressedOutflow;

    double currNetWorth = initialNetWorthZar;
    double scenNetWorth = initialNetWorthZar - totalOneTimeCapitalOutflowZar;
    double emergencyBuffer = initialEmergencyBufferZar - math.min(initialEmergencyBufferZar * 0.4, totalOneTimeCapitalOutflowZar);

    final scenarioMonthlyCashFlow = stressedBaseSurplus + netMonthlyRecurringDeltaZar;

    points.add(SimulationPoint(
      monthIndex: 0,
      label: 'Month 0',
      currentNetWorthZar: currNetWorth,
      scenarioNetWorthZar: scenNetWorth,
      currentCashFlowZar: baseMonthlySurplus,
      scenarioCashFlowZar: scenarioMonthlyCashFlow,
      emergencyBufferZar: emergencyBuffer,
    ));

    final steps = horizonMonths.clamp(1, 60);
    final monthStep = (steps / 6).ceil().clamp(1, 12);

    for (int m = 1; m <= steps; m++) {
      currNetWorth += baseMonthlySurplus;
      scenNetWorth += scenarioMonthlyCashFlow;

      if (scenarioMonthlyCashFlow >= 0) {
        emergencyBuffer += scenarioMonthlyCashFlow * 0.2; // allocate 20% to buffer
      } else {
        emergencyBuffer += scenarioMonthlyCashFlow; // buffer drawn down
      }

      if (m % monthStep == 0 || m == steps) {
        points.add(SimulationPoint(
          monthIndex: m,
          label: 'M$m',
          currentNetWorthZar: currNetWorth,
          scenarioNetWorthZar: scenNetWorth,
          currentCashFlowZar: baseMonthlySurplus,
          scenarioCashFlowZar: scenarioMonthlyCashFlow,
          emergencyBufferZar: math.max(0, emergencyBuffer),
        ));
      }
    }

    final netWorthDelta = scenNetWorth - currNetWorth;
    final monthlyBurn = scenarioMonthlyCashFlow < 0 ? scenarioMonthlyCashFlow.abs() : 0.0;
    final runwayMonths = monthlyBurn > 0 ? (emergencyBuffer / monthlyBurn) : 99.0;

    final warnings = <String>[];
    final safeguards = <String>[];

    if (scenarioMonthlyCashFlow < 0) {
      warnings.add('Scenario creates negative operational cash flow (-R ${scenarioMonthlyCashFlow.abs().toStringAsFixed(0)}/mo).');
    }
    if (runwayMonths < 6) {
      warnings.add('Emergency runway drops below 6 months ($runwayMonths months estimated).');
    }
    if (stressTest.interestRateDeltaPercent > 0) {
      warnings.add('Interest rate shock of +${stressTest.interestRateDeltaPercent}% applied to variable debt obligations.');
    }

    if (totalOneTimeCapitalOutflowZar > initialNetWorthZar * 0.15) {
      safeguards.add('Cap upfront capital expenditure to avoid liquidity depletion.');
    }
    safeguards.add('Maintain a strict 3-month operational buffer in liquid cash before commitment.');

    double resiliency = 85.0;
    if (scenarioMonthlyCashFlow < 0) resiliency -= 25.0;
    if (runwayMonths < 6) resiliency -= 20.0;
    if (stressTest.incomeReliabilityFactor < 0.9) resiliency -= 15.0;
    if (stressTest.expenseSpikeFactor > 1.1) resiliency -= 10.0;
    resiliency = resiliency.clamp(10.0, 99.0);

    return ScenarioSimulationResult(
      trajectory: points,
      projectedNetWorthDeltaZar: netWorthDelta,
      monthlyCashFlowDeltaZar: netMonthlyRecurringDeltaZar,
      bufferRunwayMonths: runwayMonths,
      resiliencyScorePercent: resiliency,
      strategicWarnings: warnings,
      recommendedSafeguards: safeguards,
    );
  }
}
