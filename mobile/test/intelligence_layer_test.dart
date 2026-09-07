import 'package:flutter_test/flutter_test.dart';
import 'package:ziva_finance/models/scenario_model.dart';
import 'package:ziva_finance/models/tax_automation_model.dart';
import 'package:ziva_finance/models/strategic_goal_model.dart';
import 'package:ziva_finance/services/sqlite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scenario Planner Sandbox Unit Tests', () {
    test('runSimulation computes accurate baseline trajectory without stress test', () {
      final scenario = ScenarioModel(
        id: 'test_car_scenario',
        title: 'Buy Executive SUV',
        description: 'BMW X5 purchase with monthly installment',
        horizonMonths: 12,
        startDate: DateTime(2026, 9, 1),
        oneTimeExpenses: [
          ScenarioExpense(
            id: 'exp_1',
            title: 'Deposit & Admin Fees',
            amountZar: 150000.0,
            category: 'Vehicle',
            targetDate: DateTime(2026, 9, 1),
          ),
        ],
        recurringChanges: [
          const ScenarioRecurringChange(
            id: 'rec_1',
            title: 'Vehicle Installment & Insurance',
            monthlyDeltaZar: -18500.0,
            isIncome: false,
          ),
        ],
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      final result = scenario.runSimulation(
        initialNetWorthZar: 2000000.0,
        baseMonthlyInflowZar: 100000.0,
        baseMonthlyOutflowZar: 50000.0,
        initialEmergencyBufferZar: 300000.0,
      );

      // Trajectory length: Month 0 + 12 months sampled at 2-month steps = 7 points
      expect(result.trajectory.length, equals(7));
      // Month 0 has immediate deduction of one-time expense (R 150,000)
      expect(result.trajectory.first.scenarioNetWorthZar, equals(1850000.0));
      // Monthly cash flow delta should be -18500
      expect(result.monthlyCashFlowDeltaZar, equals(-18500.0));
      // Resiliency score is positive since base surplus (50k) covers 18.5k installment
      expect(result.resiliencyScorePercent, greaterThan(0));
    });

    test('runSimulation stress test factors adjust surplus and trigger warnings on shortfall', () {
      final scenario = ScenarioModel(
        id: 'test_stress_scenario',
        title: 'Aggressive Expansion',
        description: 'Commercial studio expansion with heavy rent',
        horizonMonths: 6,
        startDate: DateTime(2026, 9, 1),
        oneTimeExpenses: [
          ScenarioExpense(
            id: 'exp_heavy',
            title: 'Office Lease Deposit',
            amountZar: 200000.0,
            category: 'Commercial',
            targetDate: DateTime(2026, 9, 1),
          ),
        ],
        recurringChanges: [
          const ScenarioRecurringChange(
            id: 'rec_rent',
            title: 'New Rent & Staff',
            monthlyDeltaZar: -45000.0,
            isIncome: false,
          ),
        ],
        stressTest: const StressTestParameters(
          interestRateDeltaPercent: 2.0,
          incomeReliabilityFactor: 0.70, // 30% drop in revenue
          expenseSpikeFactor: 1.20, // 20% spike in living costs
        ),
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      final result = scenario.runSimulation(
        initialNetWorthZar: 500000.0,
        baseMonthlyInflowZar: 60000.0,
        baseMonthlyOutflowZar: 40000.0,
        initialEmergencyBufferZar: 100000.0,
      );

      // Under stress: Inflow is 42,000, Outflow is 48,000 (Base deficit: -6,000)
      // With recurring -45,000, total monthly scenario cash flow is severely negative
      expect(result.monthlyCashFlowDeltaZar, equals(-45000.0));
      expect(result.strategicWarnings.isNotEmpty, isTrue);
      // Warning for negative cash flow or buffer depletion must be present
      expect(
        result.strategicWarnings.any((w) => w.contains('negative') || w.contains('runway') || w.contains('Interest')),
        isTrue,
      );
    });

    test('Scenario remains in-memory and does not modify live balance until committed', () async {
      final initialEnvelopes = await SqliteService.instance.getEnvelopes();
      final initialRent = initialEnvelopes.firstWhere((e) => e.categoryId == 'CAT_HOUSING_RENT');
      final initialPlanned = initialRent.plannedAmountZar;

      // Create and save a sandbox scenario
      final sandboxScenario = ScenarioModel(
        id: 'test_sandbox_iso',
        title: 'Isolated Purchase',
        description: 'Testing sandbox isolation',
        horizonMonths: 12,
        startDate: DateTime(2026, 9, 1),
        oneTimeExpenses: [
          ScenarioExpense(
            id: 'exp_iso',
            title: 'Lease Renewal Fee',
            amountZar: 5000.0,
            category: 'Housing',
            sourceEnvelopeId: 'CAT_HOUSING_RENT',
            targetDate: DateTime(2026, 9, 1),
          ),
        ],
        recurringChanges: [
          const ScenarioRecurringChange(
            id: 'rec_iso',
            title: 'Rent Escalation',
            monthlyDeltaZar: -2000.0,
            isIncome: false,
            targetEnvelopeId: 'CAT_HOUSING_RENT',
          ),
        ],
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );

      await SqliteService.instance.saveScenario(sandboxScenario);

      // Live envelope plannedAmount must remain identical before apply
      final envelopesAfterSave = await SqliteService.instance.getEnvelopes();
      final rentAfterSave = envelopesAfterSave.firstWhere((e) => e.categoryId == 'CAT_HOUSING_RENT');
      expect(rentAfterSave.plannedAmountZar, equals(initialPlanned));

      // Explicitly commit scenario to live
      await SqliteService.instance.applyScenarioToLive(sandboxScenario);

      // Now the envelope should reflect the recurring change planned budget adjustment
      final envelopesAfterCommit = await SqliteService.instance.getEnvelopes();
      final rentAfterCommit = envelopesAfterCommit.firstWhere((e) => e.categoryId == 'CAT_HOUSING_RENT');
      expect(rentAfterCommit.plannedAmountZar, equals(initialPlanned + 2000.0));

      // Scenario status should now be committed
      final scenarios = SqliteService.instance.getScenarios();
      final updatedScenario = scenarios.firstWhere((s) => s.id == 'test_sandbox_iso');
      expect(updatedScenario.status, equals(ScenarioStatus.committed));
    });
  });

  group('Tax Reserve Automation Unit Tests', () {
    test('TaxAutomationConfig computes accurate skim amounts across rule types', () {
      const allIncomeConfig = TaxAutomationConfig(
        enabled: true,
        defaultTaxRatePercent: 27.0,
        targetEnvelopeId: 'CAT_ESSENTIAL_TAX',
        ruleType: TaxRuleType.allIncome,
        minimumThresholdZar: 0.0,
      );

      // Should skim 27% of 10,000 = 2,700
      expect(
        allIncomeConfig.calculateSkimAmount(
          grossAmountZar: 10000.0,
          description: 'Client Payment',
          category: 'Income',
        ),
        equals(2700.0),
      );

      const thresholdConfig = TaxAutomationConfig(
        enabled: true,
        defaultTaxRatePercent: 25.0,
        targetEnvelopeId: 'CAT_ESSENTIAL_TAX',
        ruleType: TaxRuleType.aboveThreshold,
        minimumThresholdZar: 5000.0,
      );

      // Under threshold: 0
      expect(
        thresholdConfig.calculateSkimAmount(
          grossAmountZar: 4000.0,
          description: 'Small gig',
          category: 'Income',
        ),
        equals(0.0),
      );
      // Above threshold (10,000): 25% of (10,000 - 5,000) = 1,250
      expect(
        thresholdConfig.calculateSkimAmount(
          grossAmountZar: 10000.0,
          description: 'Large contract',
          category: 'Income',
        ),
        equals(1250.0),
      );

      const specificSourcesConfig = TaxAutomationConfig(
        enabled: true,
        defaultTaxRatePercent: 30.0,
        targetEnvelopeId: 'CAT_ESSENTIAL_TAX',
        ruleType: TaxRuleType.specificSources,
        qualifyingSources: ['Consulting', 'Dividend', 'Freelance'],
        minimumThresholdZar: 0.0,
      );

      // Matches keyword: 30% of 20,000 = 6,000
      expect(
        specificSourcesConfig.calculateSkimAmount(
          grossAmountZar: 20000.0,
          description: 'Acme Consulting retainer',
          category: 'Income',
        ),
        equals(6000.0),
      );
      // Does not match: 0
      expect(
        specificSourcesConfig.calculateSkimAmount(
          grossAmountZar: 20000.0,
          description: 'Salary from Employer',
          category: 'Employment',
        ),
        equals(0.0),
      );
    });

    test('calculateTaxReserveStatus produces telemetry and determines adequacy', () {
      final status = SqliteService.instance.calculateTaxReserveStatus();
      expect(status.currentTaxReserveZar, greaterThanOrEqualTo(0));
      expect(status.currentQuarterEstimatedLiabilityZar, greaterThanOrEqualTo(0));
      expect(status.adequacyRatioPercent, greaterThanOrEqualTo(0));
      expect(status.netQuarterSurplusZar, isNotNull);
    });
  });

  group('Strategic Insights & Personal CFO Unit Tests', () {
    test('parseFromPrompt parses natural language emergency fund goal', () {
      final goal = StrategicGoalModel.parseFromPrompt(
        prompt: 'Save R120,000 for emergency fund in 12 months',
        currentEmergencyReserveZar: 45000.0,
        monthlyNetSurplusZar: 25000.0,
        totalHighInterestDebtZar: 0.0,
      );

      expect(goal.intent, equals(GoalIntent.buildEmergencyReserve));
      expect(goal.targetAmountZar, equals(120000.0));
      expect(goal.targetHorizonMonths, equals(12));
      expect(goal.recommendation.recommendedMonthlyAllocationZar, equals(6250.0));
      expect(goal.recommendation.actionSteps.isNotEmpty, isTrue);
    });

    test('parseFromPrompt parses debt paydown goal with correct intent', () {
      final goal = StrategicGoalModel.parseFromPrompt(
        prompt: 'Pay off credit card balance of R45,000 in 6 months',
        currentEmergencyReserveZar: 45000.0,
        monthlyNetSurplusZar: 25000.0,
        totalHighInterestDebtZar: 45000.0,
      );

      expect(goal.intent, equals(GoalIntent.payOffDebt));
      expect(goal.targetAmountZar, equals(45000.0));
      expect(goal.targetHorizonMonths, equals(6));
      expect(goal.recommendation.recommendedMonthlyAllocationZar, closeTo(3333.33, 0.1));
    });

    test('getPersonalCfoNextBestMove returns actionable tactical suggestion', () {
      final nextMove = SqliteService.instance.getPersonalCfoNextBestMove();
      expect(nextMove.statusNudge.isNotEmpty, isTrue);
      expect(nextMove.actionSteps.isNotEmpty, isTrue);
      expect(nextMove.recommendedMonthlyAllocationZar, greaterThan(0));
    });
  });
}
