import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../models/asset_model.dart';
import '../models/debt_model.dart';
import '../models/envelope_model.dart';
import '../models/scenario_model.dart';
import '../models/strategic_goal_model.dart';
import '../models/sync_queue_item.dart';
import '../models/tax_automation_model.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._internal();
  static Database? _database;
  static bool _useMockFallback = false;

  final ApiService _api = ApiService();

  // In-memory mock storage fallback for web / unsupported SQLite environments
  final List<TransactionModel> _mockTransactions = [];
  final List<AccountModel> _mockAccounts = [];
  final List<SyncQueueItem> _mockQueue = [];
  final List<EnvelopeModel> _mockEnvelopes = [];
  final List<AssetModel> _mockAssets = [];
  final List<DebtModel> _mockDebts = [];
  final List<ScenarioModel> _mockScenarios = [];
  TaxAutomationConfig _taxConfig = const TaxAutomationConfig();
  final List<TaxSkimRecord> _mockTaxSkims = [];
  final List<StrategicGoalModel> _mockStrategicGoals = [];

  static final List<AssetModel> defaultAssets = [
    AssetModel(
      id: 'ASSET_REAL_ESTATE_01',
      name: 'Camps Bay Ocean Villa',
      type: AssetType.tangible,
      category: AssetCategory.realEstate,
      currentValueZar: 14200000.0,
      acquisitionCostZar: 12500000.0,
      acquisitionDate: DateTime(2022, 3, 15),
      depreciationMethod: DepreciationMethod.straightLine,
      usefulLifeYears: 30.0,
      depreciationRatePercent: 3.33,
      location: 'Camps Bay, Cape Town (Western Cape)',
      registrationNumber: 'Deed T90210/2022',
      documentationReference: 'Old Mutual Insure Policy #ZA-CPT-9921',
      ownershipType: OwnershipType.solo,
      myOwnershipPercentage: 100.0,
      partnerOwnershipPercentage: 0.0,
      notes: 'Luxury residential primary holding with uninterrupted Atlantic views',
      includeInNetWorth: true,
      createdAt: DateTime(2022, 3, 15),
      updatedAt: DateTime.now(),
    ),
    AssetModel(
      id: 'ASSET_VEHICLE_01',
      name: 'Porsche 911 GT3 (992)',
      type: AssetType.tangible,
      category: AssetCategory.vehicle,
      currentValueZar: 2950000.0,
      acquisitionCostZar: 3200000.0,
      acquisitionDate: DateTime(2023, 6, 10),
      depreciationMethod: DepreciationMethod.reducingBalance,
      usefulLifeYears: 5.0,
      depreciationRatePercent: 15.0,
      location: 'Private Garage, Camps Bay',
      registrationNumber: 'CA 911-ZAR',
      documentationReference: 'Discovery Insure Comprehensive #DISC-VEH-4412',
      ownershipType: OwnershipType.solo,
      myOwnershipPercentage: 100.0,
      partnerOwnershipPercentage: 0.0,
      linkedLiabilityId: 'DEBT_VEHICLE_FINANCE',
      linkedLiabilityName: 'FNB Asset Finance (Porsche 911)',
      linkedLiabilityAmountZar: 1100000.0,
      notes: 'High-performance GT vehicle held under asset finance schedule',
      includeInNetWorth: true,
      createdAt: DateTime(2023, 6, 10),
      updatedAt: DateTime.now(),
    ),
    AssetModel(
      id: 'ASSET_IP_ALGO_01',
      name: 'Antigravity AI Quantitative Algorithm',
      type: AssetType.intangible,
      category: AssetCategory.ipPatent,
      currentValueZar: 8000000.0,
      acquisitionCostZar: 4500000.0,
      acquisitionDate: DateTime(2024, 1, 20),
      depreciationMethod: DepreciationMethod.amortization,
      usefulLifeYears: 10.0,
      depreciationRatePercent: 10.0,
      location: 'GCP Cloud Vault & GitHub Enterprise',
      registrationNumber: 'Patent Filing ZA2026/00192',
      documentationReference: 'IP Assignment Deed & Syndicate Escrow',
      ownershipType: OwnershipType.joint,
      myOwnershipPercentage: 70.0,
      partnerOwnershipPercentage: 30.0,
      notes: 'Proprietary automated liquidity routing and forecasting engine',
      includeInNetWorth: true,
      createdAt: DateTime(2024, 1, 20),
      updatedAt: DateTime.now(),
    ),
    AssetModel(
      id: 'ASSET_CRYPTO_01',
      name: 'Bitcoin Treasury Reserve (BTC Cold Vault)',
      type: AssetType.intangible,
      category: AssetCategory.digitalAsset,
      currentValueZar: 1850000.0,
      acquisitionCostZar: 1200000.0,
      acquisitionDate: DateTime(2023, 11, 5),
      depreciationMethod: DepreciationMethod.none,
      usefulLifeYears: 0.0,
      depreciationRatePercent: 0.0,
      location: 'Multisig Ledger Hardware Vault (Offline Custody)',
      registrationNumber: 'xpub6D4B...vault-01',
      documentationReference: 'Custody Vault Protocol v2.1',
      ownershipType: OwnershipType.solo,
      myOwnershipPercentage: 100.0,
      partnerOwnershipPercentage: 0.0,
      notes: 'Strategic institutional inflation hedge in multi-sig custody',
      includeInNetWorth: true,
      createdAt: DateTime(2023, 11, 5),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<DebtModel> defaultDebts = [
    DebtModel(
      id: 'DEBT_VEHICLE_FINANCE',
      counterparty: 'FNB Asset Finance (WesBank)',
      direction: DebtDirection.owedByMe,
      debtType: DebtType.assetFinance,
      originalPrincipalZar: 1800000.0,
      currentOutstandingBalanceZar: 1100000.0,
      currency: 'ZAR',
      interestRatePercent: 11.75,
      minimumMonthlyPaymentZar: 34500.0,
      dueDate: DateTime.now().add(const Duration(days: 8)),
      linkedEnvelopeId: 'CAT_SINKING_MAINTENANCE',
      linkedEnvelopeName: 'Vehicle Maintenance & Insurance Sinking Fund',
      status: DebtStatus.current,
      notes: 'Porsche 911 GT3 structured commercial installment sale',
      repayments: [
        DebtRepaymentModel(
          id: 'REP_VEH_01',
          debtId: 'DEBT_VEHICLE_FINANCE',
          amountZar: 34500.0,
          paymentDate: DateTime.now().subtract(const Duration(days: 22)),
          paymentMethod: 'FNB Debit Order',
          sourceEnvelopeId: 'CAT_SINKING_MAINTENANCE',
          sourceEnvelopeName: 'Vehicle Maintenance & Insurance Sinking Fund',
          notes: 'Scheduled monthly installment',
          createdAt: DateTime.now().subtract(const Duration(days: 22)),
        ),
      ],
      createdAt: DateTime(2023, 6, 10),
      updatedAt: DateTime.now(),
    ),
    DebtModel(
      id: 'DEBT_DISCOVERY_CARD',
      counterparty: 'Discovery Bank Corporate Credit',
      direction: DebtDirection.owedByMe,
      debtType: DebtType.creditCard,
      originalPrincipalZar: 150000.0,
      currentOutstandingBalanceZar: 38500.0,
      currency: 'ZAR',
      interestRatePercent: 14.5,
      minimumMonthlyPaymentZar: 8500.0,
      dueDate: DateTime.now().add(const Duration(days: 20)),
      linkedEnvelopeId: 'CAT_TECH_CLOUD',
      linkedEnvelopeName: 'Cloud SaaS & Productivity Tools',
      status: DebtStatus.current,
      notes: 'Operational revolving cloud and travel card',
      repayments: [],
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime.now(),
    ),
    DebtModel(
      id: 'CREDIT_VENTURE_ADVANCE',
      counterparty: 'Kudzai Chimwaza (Syndicated Venture)',
      direction: DebtDirection.owedToMe,
      debtType: DebtType.personalLoan,
      originalPrincipalZar: 450000.0,
      currentOutstandingBalanceZar: 280000.0,
      currency: 'ZAR',
      interestRatePercent: 8.5,
      minimumMonthlyPaymentZar: 35000.0,
      dueDate: DateTime.now().add(const Duration(days: 14)),
      status: DebtStatus.current,
      notes: 'Working capital bridge facility for African tech venture round',
      repayments: [
        DebtRepaymentModel(
          id: 'REP_KUD_01',
          debtId: 'CREDIT_VENTURE_ADVANCE',
          amountZar: 170000.0,
          paymentDate: DateTime.now().subtract(const Duration(days: 35)),
          paymentMethod: 'EFT Wire',
          notes: 'Tranche 1 repayment received',
          createdAt: DateTime.now().subtract(const Duration(days: 35)),
        ),
      ],
      createdAt: DateTime(2025, 10, 1),
      updatedAt: DateTime.now(),
    ),
    DebtModel(
      id: 'CREDIT_APEX_INVOICE',
      counterparty: 'Apex Enterprise Consulting Ltd',
      direction: DebtDirection.owedToMe,
      debtType: DebtType.invoiceReceivable,
      originalPrincipalZar: 185000.0,
      currentOutstandingBalanceZar: 185000.0,
      currency: 'ZAR',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      status: DebtStatus.current,
      notes: 'Q1 Executive Advisory and AI architecture advisory retainer',
      repayments: [],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<EnvelopeModel> defaultEnvelopes = [
    const EnvelopeModel(
      categoryId: 'CAT_HOUSING_RENT',
      categoryName: 'Residential Rent & Levies',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 18500.0,
      actualSpentZar: 0.0,
      isFixedObligation: true,
      notes: 'Primary residence monthly lease and building levies',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_GROCERIES',
      categoryName: 'Groceries & Household',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'DAILY_SPENDING',
      targetCurrency: 'ZAR',
      plannedAmountZar: 6500.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Food markets, Woolworths, and household essentials',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_UTILITIES',
      categoryName: 'Electricity & Municipal Utilities',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 2200.0,
      actualSpentZar: 0.0,
      isFixedObligation: true,
      notes: 'Eskom prepaid electricity and municipal water',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_CONNECTIVITY',
      categoryName: 'Fibre Internet & Mobile Data',
      categoryGroup: 'ESSENTIALS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 1450.0,
      actualSpentZar: 0.0,
      isFixedObligation: true,
      notes: 'High-speed home fibre and roaming mobile eSIM data',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_DINING_LEISURE',
      categoryName: 'Dining, Coffee & Social',
      categoryGroup: 'DISCRETIONARY',
      cashFlowTier: 'DAILY_SPENDING',
      targetCurrency: 'ZAR',
      plannedAmountZar: 3500.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Client dinners, coffee meetings, and personal leisure',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_TECH_CLOUD',
      categoryName: 'Cloud SaaS & Productivity Tools',
      categoryGroup: 'DISCRETIONARY',
      cashFlowTier: 'DAILY_SPENDING',
      targetCurrency: 'ZAR',
      plannedAmountZar: 2800.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'GitHub, Google Cloud, AI tools, and productivity suites',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_SINKING_EMERGENCY',
      categoryName: 'Emergency Reserve Sinking Fund',
      categoryGroup: 'SINKING_FUNDS',
      cashFlowTier: 'LONG_TERM_VAULT',
      targetCurrency: 'ZAR',
      plannedAmountZar: 5000.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Monthly allocation towards 6-month liquid emergency runway',
    ),
    const EnvelopeModel(
      categoryId: 'CAT_SINKING_MAINTENANCE',
      categoryName: 'Vehicle Maintenance & Insurance Sinking Fund',
      categoryGroup: 'SINKING_FUNDS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'ZAR',
      plannedAmountZar: 2500.0,
      actualSpentZar: 0.0,
      isFixedObligation: false,
      notes: 'Tyres, annual vehicle servicing, and comprehensive cover',
    ),
  ];

  static final List<ScenarioModel> defaultScenarios = [
    ScenarioModel(
      id: 'SCENARIO_COMMERCIAL_RE',
      title: 'Acquire Commercial Tech Office (Century City)',
      description: 'Acquire 350sqm prime commercial unit with existing blue-chip software tenant.',
      horizonMonths: 24,
      startDate: DateTime(2026, 10, 1),
      status: ScenarioStatus.active,
      oneTimeExpenses: [
        ScenarioExpense(
          id: 'EXP_RE_DOWNPAYMENT',
          title: 'Commercial Bond Deposit (20%)',
          amountZar: 1200000.0,
          category: 'Real Estate Capital Allocation',
          sourceEnvelopeId: 'CAT_SINKING_EMERGENCY',
          targetDate: DateTime(2026, 10, 1),
        ),
        ScenarioExpense(
          id: 'EXP_RE_TRANSFER_DUTY',
          title: 'SARS Transfer Duty & Conveyancing Fees',
          amountZar: 145000.0,
          category: 'Legal & Transfer Duty',
          sourceEnvelopeId: 'CAT_ESSENTIAL_TAX',
          targetDate: DateTime(2026, 10, 15),
        ),
      ],
      recurringChanges: [
        const ScenarioRecurringChange(
          id: 'REC_RENTAL_INFLOW',
          title: 'Triple-Net Commercial Tenant Inflow',
          monthlyDeltaZar: 42000.0,
          isIncome: true,
          targetEnvelopeId: 'CAT_ESSENTIAL_SAVINGS',
        ),
        const ScenarioRecurringChange(
          id: 'REC_BOND_REPAYMENT',
          title: 'Commercial Mortgage Servicing (FNB)',
          monthlyDeltaZar: -28500.0,
          isIncome: false,
          targetEnvelopeId: 'CAT_ESSENTIAL_HOUSING',
        ),
      ],
      fundingSourcePriorityIds: const ['CAT_SINKING_EMERGENCY', 'CAT_DISCRETIONARY_ENTERTAINMENT'],
      stressTest: const StressTestParameters(
        interestRateDeltaPercent: 1.5,
        incomeReliabilityFactor: 0.90,
        expenseSpikeFactor: 1.10,
      ),
      createdAt: DateTime(2026, 8, 15),
      updatedAt: DateTime.now(),
    ),
    ScenarioModel(
      id: 'SCENARIO_ACCELERATE_PORSCHE',
      title: 'Accelerate WesBank GT3 Payoff (Zero in 12M)',
      description: 'Lump-sum principal reduction and doubled monthly installments to eliminate 11.75% asset finance early.',
      horizonMonths: 12,
      startDate: DateTime(2026, 10, 1),
      status: ScenarioStatus.active,
      oneTimeExpenses: [
        ScenarioExpense(
          id: 'EXP_GT3_LUMP',
          title: 'Immediate Principal Capital Injection',
          amountZar: 250000.0,
          category: 'Debt Principal Reduction',
          sourceEnvelopeId: 'CAT_SINKING_MAINTENANCE',
          targetDate: DateTime(2026, 10, 1),
        ),
      ],
      recurringChanges: [
        const ScenarioRecurringChange(
          id: 'REC_GT3_EXTRA',
          title: 'Accelerated Installment Top-Up',
          monthlyDeltaZar: -40000.0,
          isIncome: false,
          targetEnvelopeId: 'CAT_SINKING_MAINTENANCE',
        ),
      ],
      fundingSourcePriorityIds: const ['CAT_SINKING_MAINTENANCE'],
      stressTest: const StressTestParameters(
        interestRateDeltaPercent: 0.0,
        incomeReliabilityFactor: 1.0,
        expenseSpikeFactor: 1.05,
      ),
      createdAt: DateTime(2026, 8, 20),
      updatedAt: DateTime.now(),
    ),
    ScenarioModel(
      id: 'SCENARIO_SAAS_VENTURE',
      title: 'Launch Antigravity AI Cloud SaaS Tier',
      description: 'Bootstrap enterprise cluster hardware and monetize quantitative risk engine APIs.',
      horizonMonths: 18,
      startDate: DateTime(2026, 11, 1),
      status: ScenarioStatus.draft,
      oneTimeExpenses: [
        ScenarioExpense(
          id: 'EXP_GPU_CLUSTER',
          title: 'Dedicated Enterprise Server Hardware',
          amountZar: 320000.0,
          category: 'Software Infrastructure',
          sourceEnvelopeId: 'CAT_TECH_CLOUD',
          targetDate: DateTime(2026, 11, 1),
        ),
      ],
      recurringChanges: [
        const ScenarioRecurringChange(
          id: 'REC_SAAS_MRR',
          title: 'Enterprise API Subscriptions (MRR)',
          monthlyDeltaZar: 85000.0,
          isIncome: true,
          targetEnvelopeId: 'CAT_ESSENTIAL_SAVINGS',
        ),
        const ScenarioRecurringChange(
          id: 'REC_CLOUD_INFRA',
          title: 'GCP Bandwidth & Datacenter Hosting',
          monthlyDeltaZar: -18000.0,
          isIncome: false,
          targetEnvelopeId: 'CAT_TECH_CLOUD',
        ),
      ],
      fundingSourcePriorityIds: const ['CAT_TECH_CLOUD', 'CAT_DISCRETIONARY_ENTERTAINMENT'],
      stressTest: const StressTestParameters(
        interestRateDeltaPercent: 2.0,
        incomeReliabilityFactor: 0.80,
        expenseSpikeFactor: 1.25,
      ),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime.now(),
    ),
  ];

  static final List<TaxSkimRecord> defaultTaxSkims = [
    TaxSkimRecord(
      id: 'SKIM_2026_01',
      sourceTransactionId: 'TX_INFLOW_ADV_01',
      sourceDescription: 'Executive Advisory Retainer (Apex Capital)',
      grossIncomeZar: 68000.0,
      taxRateAppliedPercent: 27.5,
      skimmedTaxAmountZar: 18700.0,
      targetEnvelopeId: 'CAT_ESSENTIAL_TAX',
      targetEnvelopeName: 'Income Tax & SARS Reserve',
      timestamp: DateTime(2026, 8, 28, 14, 30),
    ),
    TaxSkimRecord(
      id: 'SKIM_2026_02',
      sourceTransactionId: 'TX_INFLOW_TECH_02',
      sourceDescription: 'Quantitative Systems Licensing (ZAR Settlement)',
      grossIncomeZar: 45000.0,
      taxRateAppliedPercent: 27.5,
      skimmedTaxAmountZar: 12375.0,
      targetEnvelopeId: 'CAT_ESSENTIAL_TAX',
      targetEnvelopeName: 'Income Tax & SARS Reserve',
      timestamp: DateTime(2026, 9, 2, 10, 15),
    ),
  ];

  static final List<StrategicGoalModel> defaultStrategicGoals = [
    StrategicGoalModel(
      id: 'GOAL_EMERGENCY_BUFFER',
      rawInputPrompt: 'I want to build a 6-month liquid emergency fund in 18 months without impacting my business runway',
      title: 'Build 6-Month Liquid Emergency Buffer',
      intent: GoalIntent.buildEmergencyReserve,
      priority: GoalPriority.high,
      targetAmountZar: 250000.0,
      currentAmountZar: 145000.0,
      targetHorizonMonths: 18,
      targetDate: DateTime(2028, 3, 1),
      recommendation: StrategicRecommendation(
        recommendedMonthlyAllocationZar: 5833.0,
        primaryTargetEnvelopeId: 'CAT_SINKING_EMERGENCY',
        primaryTargetEnvelopeName: 'Emergency Reserve Sinking Fund',
        debtPrioritizationMessage: 'Maintain minimum payments on asset finance; surplus easily covers this target.',
        reallocationSuggestions: [
          'Reallocate R3,000/mo from Discretionary Dining & Entertainment into Emergency Reserve.',
        ],
        projectedCompletionMonths: 14,
        projectedCompletionDate: DateTime(2027, 11, 1),
        actionSteps: [
          'Direct R5,833/mo on the 1st of each calendar month to Emergency Reserve Sinking Fund.',
          'Automate 15% skim from any ad-hoc consulting inflows into this buffer.',
        ],
        statusNudge: 'Ahead of Pace: Projected to complete 4 months ahead of target date at current savings velocity.',
      ),
      createdAt: DateTime(2026, 7, 10),
      updatedAt: DateTime.now(),
    ),
    StrategicGoalModel(
      id: 'GOAL_ELIMINATE_CARD_DEBT',
      rawInputPrompt: 'I want to pay off my Discovery Card debt of R150,000 completely in 8 months',
      title: 'Eliminate Revolving Credit Card Liability',
      intent: GoalIntent.payOffDebt,
      priority: GoalPriority.high,
      targetAmountZar: 150000.0,
      currentAmountZar: 35000.0,
      targetHorizonMonths: 8,
      targetDate: DateTime(2027, 5, 1),
      recommendation: StrategicRecommendation(
        recommendedMonthlyAllocationZar: 14375.0,
        primaryTargetEnvelopeId: 'CAT_DISCRETIONARY_ENTERTAINMENT',
        primaryTargetEnvelopeName: 'Debt Liquidation Allocation',
        debtPrioritizationMessage: 'Discovery Card carries 18.5% APR. Pay down aggressively before funding low-yield cash deposits.',
        reallocationSuggestions: [
          'Reallocate R4,500/mo from Dining and R2,000/mo from Software infrastructure into debt payoff.',
        ],
        projectedCompletionMonths: 8,
        projectedCompletionDate: DateTime(2027, 5, 1),
        actionSteps: [
          'Execute R14,375 monthly payment on the 25th before the billing cycle interest calculation.',
          'Freeze new revolving charges on Discovery Card until zero balance is achieved.',
        ],
        statusNudge: 'On Track: Saving ~R2,100/mo in compounding interest by hitting this 8-month timeline.',
      ),
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime.now(),
    ),
    StrategicGoalModel(
      id: 'GOAL_DERISK_PORTFOLIO',
      rawInputPrompt: 'Shift more capital into low-risk assets while keeping at least R100k liquid',
      title: 'Portfolio De-Risking & Capital Preservation',
      intent: GoalIntent.deRiskPortfolio,
      priority: GoalPriority.medium,
      targetAmountZar: 500000.0,
      currentAmountZar: 180000.0,
      targetHorizonMonths: 24,
      targetDate: DateTime(2028, 9, 1),
      recommendation: StrategicRecommendation(
        recommendedMonthlyAllocationZar: 13333.0,
        primaryTargetEnvelopeId: 'CAT_ESSENTIAL_SAVINGS',
        primaryTargetEnvelopeName: 'Fixed-Income Treasury Allocation',
        reallocationSuggestions: [
          'Direct quarterly surplus distributions into RSA Retail Government Bonds (9.25% yield).',
        ],
        projectedCompletionMonths: 20,
        projectedCompletionDate: DateTime(2028, 5, 1),
        actionSteps: [
          'Lock in 5-year fixed rate RSA retail bonds with compounding bi-annual coupon reinvestment.',
          'Maintain minimum R100,000 liquid threshold in primary cheque and money market account.',
        ],
        statusNudge: 'Tactical CFO Insight: Secures guaranteed 9.25% real return ahead of projected rate cuts.',
      ),
      createdAt: DateTime(2026, 8, 15),
      updatedAt: DateTime.now(),
    ),
  ];

  SqliteService._internal() {
    _ensureDefaultData();
  }

  void _ensureDefaultData() {
    if (_mockEnvelopes.isEmpty) {
      _mockEnvelopes.addAll(defaultEnvelopes);
    }
    if (_mockAssets.isEmpty) {
      _mockAssets.addAll(defaultAssets);
    }
    if (_mockDebts.isEmpty) {
      _mockDebts.addAll(defaultDebts);
    }
    if (_mockScenarios.isEmpty) {
      _mockScenarios.addAll(defaultScenarios);
    }
    if (_mockTaxSkims.isEmpty) {
      _mockTaxSkims.addAll(defaultTaxSkims);
    }
    if (_mockStrategicGoals.isEmpty) {
      _mockStrategicGoals.addAll(defaultStrategicGoals);
    }
  }

  void _ensureDefaultEnvelopes() {
    _ensureDefaultData();
  }

  /// Invalidate and clear all in-memory and local caches so fresh queries
  /// strictly reflect the live, wiped BigQuery dataset.
  void invalidateAndClearCaches() {
    _mockTransactions.clear();
    _mockAccounts.clear();
    _mockQueue.clear();
    _mockEnvelopes.clear();
    _mockAssets.clear();
    _mockDebts.clear();
    _mockScenarios.clear();
    _mockTaxSkims.clear();
    _mockStrategicGoals.clear();
    _ensureDefaultData();
    debugPrint('[SqliteService] Caches invalidated. Clean live state active.');
  }

  /// Public getter indicating if mock fallback is currently serving SQLite calls
  bool get isUsingMockFallback => kIsWeb || _useMockFallback;

  Future<Database?> get database async {
    // When running on web (kIsWeb), bypass sqflite entirely and directly route to BigQuery
    if (kIsWeb) return null;
    if (_database != null) return _database;
    if (_useMockFallback) return null;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) {
      debugPrint('[SqliteService] Running on Web (kIsWeb). Bypassing sqflite and directly routing queries to BigQuery service.');
      _useMockFallback = true;
      return null;
    }

    try {
      final dbPath = await getDatabasesPath();
      final dbFile = p.join(dbPath, 'ziva_finance.db');

      return await openDatabase(
        dbFile,
        version: 1,
        onCreate: (db, version) async {
          // 1. Local Transactions Cache
          await db.execute('''
            CREATE TABLE local_transactions (
              transaction_id TEXT PRIMARY KEY,
              transaction_date TEXT NOT NULL,
              account_id TEXT NOT NULL,
              category_id TEXT NOT NULL,
              category_name TEXT,
              transaction_type TEXT NOT NULL,
              original_amount REAL NOT NULL,
              original_currency TEXT NOT NULL,
              reporting_amount_zar REAL NOT NULL,
              reporting_amount_usd REAL NOT NULL,
              merchant_or_payee TEXT,
              payment_method TEXT,
              is_tax_deductible INTEGER NOT NULL DEFAULT 0,
              notes TEXT,
              tags TEXT,
              receipt_name TEXT,
              receipt_url TEXT,
              is_synced INTEGER NOT NULL DEFAULT 1,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          // 2. Offline Sync Mutation Queue
          await db.execute('''
            CREATE TABLE sync_queue (
              queue_id TEXT PRIMARY KEY,
              transaction_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              sync_status TEXT NOT NULL DEFAULT 'PENDING',
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            )
          ''');

          // 3. Local Accounts Cache
          await db.execute('''
            CREATE TABLE local_accounts (
              account_id TEXT PRIMARY KEY,
              account_name TEXT NOT NULL,
              financial_institution TEXT,
              country_code TEXT,
              primary_currency TEXT,
              cash_flow_tier TEXT,
              account_type TEXT,
              is_vault_locked INTEGER DEFAULT 0,
              withdrawal_notice_days INTEGER DEFAULT 0,
              account_number_masked TEXT,
              native_balance REAL NOT NULL,
              is_active INTEGER DEFAULT 1
            )
          ''');

          await db.execute('CREATE INDEX idx_tx_date ON local_transactions(transaction_date DESC)');
          await db.execute('CREATE INDEX idx_sync_status ON sync_queue(sync_status)');
        },
      );
    } catch (e) {
      debugPrint('[SqliteService] Database initialization failed: $e. Falling back to clean in-memory mock store.');
      _useMockFallback = true;
      return null;
    }
  }

  // --- Transactions ---

  Future<void> saveTransaction(TransactionModel tx) async {
    // Automatically apply to local envelope balances
    applyTransactionToEnvelopes(tx);

    // Tax Reserve Automation: Smart skimming from qualifying inflows
    if (tx.transactionType.toLowerCase() == 'income' && !tx.notes.contains('[AUTO-TAX-SKIM]')) {
      _processInflowTaxSkim(tx);
    }

    if (kIsWeb) {
      // In web mode, route directly to BigQuery service and update in-memory cache
      _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
      _mockTransactions.insert(0, tx);
      try {
        final res = await _api.postTransaction(tx.toJson());
        if (res['success'] == true) {
          await markTransactionSynced(tx.transactionId);
          debugPrint('[SqliteService] Web: Transaction ${tx.transactionId} posted directly to BigQuery.');
        }
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery post failed: $e (stored locally in memory)');
      }
      return;
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
      _mockTransactions.insert(0, tx);
      return;
    }
    await db.insert(
      'local_transactions',
      tx.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTransactionsBatch(List<TransactionModel> list) async {
    if (kIsWeb || _useMockFallback) {
      for (final tx in list) {
        _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
        _mockTransactions.add(tx);
      }
      return;
    }
    final db = await database;
    if (db == null) {
      for (final tx in list) {
        _mockTransactions.removeWhere((t) => t.transactionId == tx.transactionId);
        _mockTransactions.add(tx);
      }
      return;
    }
    final batch = db.batch();
    for (final tx in list) {
      batch.insert(
        'local_transactions',
        tx.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Fetches transactions. On web (kIsWeb), directly routes to BigQuery service.
  Future<List<TransactionModel>> getTransactions({int limit = 100}) async {
    if (kIsWeb) {
      try {
        final bqTxs = await _api.fetchTransactions(limit: limit);
        _mockTransactions.clear();
        if (bqTxs.isNotEmpty) {
          _mockTransactions.addAll(bqTxs);
          debugPrint('[SqliteService] Web: Successfully retrieved ${bqTxs.length} ledger transactions directly from BigQuery.');
        } else {
          debugPrint('[SqliteService] Web: Live BigQuery transaction table has 0 rows.');
        }
        return bqTxs;
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery fetch failed: $e. Returning empty list.');
        return [];
      }
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      final sorted = List<TransactionModel>.from(_mockTransactions)
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      return sorted.take(limit).toList();
    }
    final result = await db.query(
      'local_transactions',
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: limit,
    );
    return result.map((map) => TransactionModel.fromJson(map)).toList();
  }

  Future<void> markTransactionSynced(String transactionId) async {
    if (kIsWeb || _useMockFallback) {
      final idx = _mockTransactions.indexWhere((t) => t.transactionId == transactionId);
      if (idx != -1) {
        final old = _mockTransactions[idx];
        _mockTransactions[idx] = TransactionModel(
          transactionId: old.transactionId,
          transactionDate: old.transactionDate,
          accountId: old.accountId,
          categoryId: old.categoryId,
          categoryName: old.categoryName,
          transactionType: old.transactionType,
          originalAmount: old.originalAmount,
          originalCurrency: old.originalCurrency,
          reportingAmountZar: old.reportingAmountZar,
          reportingAmountUsd: old.reportingAmountUsd,
          merchantOrPayee: old.merchantOrPayee,
          paymentMethod: old.paymentMethod,
          isTaxDeductible: old.isTaxDeductible,
          notes: old.notes,
          tags: old.tags,
          isSynced: true,
        );
      }
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.update(
      'local_transactions',
      {'is_synced': 1},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Deletes a transaction from BigQuery and local stores
  Future<bool> deleteTransaction(String transactionId) async {
    // 1. Immediately prune from in-memory cache and revert envelope balances
    final idx = _mockTransactions.indexWhere((t) => t.transactionId == transactionId);
    if (idx != -1) {
      final tx = _mockTransactions[idx];
      applyTransactionToEnvelopes(tx, isRevert: true);
      _mockTransactions.removeAt(idx);
    } else {
      _mockTransactions.removeWhere((t) => t.transactionId == transactionId);
    }

    if (kIsWeb) {
      try {
        final success = await _api.deleteTransaction(transactionId);
        debugPrint('[SqliteService] Web: Successfully deleted transaction $transactionId from BigQuery.');
        return success;
      } catch (e) {
        debugPrint('[SqliteService] Web: BigQuery delete call failed: $e (pruned from local session).');
        return true;
      }
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      return true;
    }

    // 2. Delete from local SQLite table
    await db.delete(
      'local_transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    // 3. Delete from BigQuery directly if online, or enqueue deletion mutation
    try {
      await _api.deleteTransaction(transactionId);
    } catch (_) {
      await enqueueMutation(
        transactionId: transactionId,
        payloadJson: jsonEncode({'action': 'DELETE', 'transactionId': transactionId}),
      );
    }
    return true;
  }

  // --- Sync Queue ---

  Future<SyncQueueItem> enqueueMutation({
    required String transactionId,
    required String payloadJson,
  }) async {
    final queueItem = SyncQueueItem(
      queueId: const Uuid().v4(),
      transactionId: transactionId,
      payloadJson: payloadJson,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      syncStatus: SyncStatus.pending,
      retryCount: 0,
    );

    if (kIsWeb) {
      // In web mode, attempt direct sync immediately
      try {
        final Map<String, dynamic> payload =
            jsonDecode(payloadJson) as Map<String, dynamic>;
        final res = await _api.postTransaction(payload);
        if (res['success'] == true) {
          await markTransactionSynced(transactionId);
          return queueItem.copyWith(syncStatus: SyncStatus.synced);
        }
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery mutation push failed: $e (queued in memory)');
      }
      _mockQueue.removeWhere((item) => item.transactionId == transactionId);
      _mockQueue.add(queueItem);
      return queueItem;
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      _mockQueue.removeWhere((item) => item.transactionId == transactionId);
      _mockQueue.add(queueItem);
      return queueItem;
    }

    await db.insert(
      'sync_queue',
      queueItem.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return queueItem;
  }

  Future<List<SyncQueueItem>> getPendingQueue() async {
    if (kIsWeb || _useMockFallback) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .toList();
    }
    final db = await database;
    if (db == null) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .toList();
    }
    final result = await db.query(
      'sync_queue',
      where: "sync_status IN ('PENDING', 'FAILED')",
      orderBy: 'created_at ASC',
    );
    return result.map((map) => SyncQueueItem.fromSqlite(map)).toList();
  }

  Future<List<SyncQueueItem>> getAllQueueItems() async {
    if (kIsWeb || _useMockFallback) {
      return List<SyncQueueItem>.from(_mockQueue);
    }
    final db = await database;
    if (db == null) return List<SyncQueueItem>.from(_mockQueue);
    final result = await db.query(
      'sync_queue',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => SyncQueueItem.fromSqlite(map)).toList();
  }

  Future<void> updateQueueItem(SyncQueueItem item) async {
    if (kIsWeb || _useMockFallback) {
      final idx = _mockQueue.indexWhere((q) => q.queueId == item.queueId);
      if (idx != -1) {
        _mockQueue[idx] = item;
      }
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.update(
      'sync_queue',
      item.toSqliteMap(),
      where: 'queue_id = ?',
      whereArgs: [item.queueId],
    );
  }

  Future<int> getPendingQueueCount() async {
    if (kIsWeb || _useMockFallback) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .length;
    }
    final db = await database;
    if (db == null) {
      return _mockQueue
          .where((item) => item.syncStatus == SyncStatus.pending || item.syncStatus == SyncStatus.failed)
          .length;
    }
    final count = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(1) FROM sync_queue WHERE sync_status IN ('PENDING', 'FAILED')",
    ));
    return count ?? 0;
  }

  Future<void> clearCompletedQueue() async {
    if (kIsWeb || _useMockFallback) {
      _mockQueue.removeWhere((item) => item.syncStatus == SyncStatus.synced);
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.delete('sync_queue', where: "sync_status = 'SYNCED'");
  }

  // --- Accounts ---

  Future<void> saveAccountsBatch(List<AccountModel> accounts) async {
    if (kIsWeb || _useMockFallback) {
      for (final acc in accounts) {
        _mockAccounts.removeWhere((a) => a.accountId == acc.accountId);
        _mockAccounts.add(acc);
      }
      return;
    }
    final db = await database;
    if (db == null) {
      for (final acc in accounts) {
        _mockAccounts.removeWhere((a) => a.accountId == acc.accountId);
        _mockAccounts.add(acc);
      }
      return;
    }
    final batch = db.batch();
    for (final acc in accounts) {
      batch.insert(
        'local_accounts',
        acc.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Fetches accounts. On web (kIsWeb), directly routes to BigQuery service.
  Future<List<AccountModel>> getLocalAccounts() async {
    if (kIsWeb) {
      try {
        final bqAccounts = await _api.fetchAccounts();
        _mockAccounts.clear();
        if (bqAccounts.isNotEmpty) {
          _mockAccounts.addAll(bqAccounts);
          debugPrint('[SqliteService] Web: Successfully retrieved ${bqAccounts.length} accounts directly from BigQuery.');
        } else {
          debugPrint('[SqliteService] Web: Live BigQuery accounts table has 0 rows.');
        }
        return bqAccounts.where((a) => a.isActive).toList();
      } catch (e) {
        debugPrint('[SqliteService] Web: Direct BigQuery accounts fetch failed: $e. Returning empty list.');
        return [];
      }
    }

    final db = await database;
    if (_useMockFallback || db == null) {
      return _mockAccounts.where((a) => a.isActive).toList();
    }
    final result = await db.query('local_accounts', where: 'is_active = 1');
    return result.map((m) => AccountModel.fromJson(m)).toList();
  }

  // --- Envelope Budget Management ---

  /// Retrieve all active budget envelopes
  Future<List<EnvelopeModel>> getEnvelopes() async {
    _ensureDefaultEnvelopes();
    return List<EnvelopeModel>.from(_mockEnvelopes.where((e) => e.isActive));
  }

  /// Create or update an envelope
  Future<void> saveEnvelope(EnvelopeModel envelope) async {
    _ensureDefaultEnvelopes();
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == envelope.categoryId);
    if (idx != -1) {
      _mockEnvelopes[idx] = envelope;
    } else {
      _mockEnvelopes.add(envelope);
    }
  }

  /// Archive/deactivate an envelope
  Future<void> archiveEnvelope(String categoryId) async {
    _ensureDefaultEnvelopes();
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == categoryId);
    if (idx != -1) {
      _mockEnvelopes[idx] = _mockEnvelopes[idx].copyWith(isActive: false);
    }
  }

  /// Move/transfer funds between two envelopes
  Future<void> transferFunds({
    required String fromCategoryId,
    required String toCategoryId,
    required double amount,
  }) async {
    _ensureDefaultEnvelopes();
    if (amount <= 0) return;

    final fromIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == fromCategoryId);
    final toIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == toCategoryId);

    if (fromIdx != -1 && toIdx != -1) {
      final fromEnv = _mockEnvelopes[fromIdx];
      final toEnv = _mockEnvelopes[toIdx];

      _mockEnvelopes[fromIdx] = fromEnv.copyWith(
        plannedAmountZar: (fromEnv.plannedAmountZar - amount).clamp(0.0, double.infinity),
      );
      _mockEnvelopes[toIdx] = toEnv.copyWith(
        plannedAmountZar: toEnv.plannedAmountZar + amount,
      );
    }
  }

  /// Top up an envelope's planned allocation
  Future<void> topUpEnvelope(String categoryId, double amount) async {
    _ensureDefaultEnvelopes();
    if (amount <= 0) return;
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == categoryId);
    if (idx != -1) {
      final env = _mockEnvelopes[idx];
      _mockEnvelopes[idx] = env.copyWith(
        plannedAmountZar: env.plannedAmountZar + amount,
      );
    }
  }

  /// Reduce an envelope's planned allocation
  Future<void> reduceEnvelope(String categoryId, double amount) async {
    _ensureDefaultEnvelopes();
    if (amount <= 0) return;
    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == categoryId);
    if (idx != -1) {
      final env = _mockEnvelopes[idx];
      _mockEnvelopes[idx] = env.copyWith(
        plannedAmountZar: (env.plannedAmountZar - amount).clamp(0.0, double.infinity),
      );
    }
  }

  /// Immediate optimistic reflection of transaction in envelope spent amounts
  void applyTransactionToEnvelopes(TransactionModel tx, {bool isRevert = false}) {
    _ensureDefaultEnvelopes();
    if (tx.categoryId.isEmpty) return;

    final idx = _mockEnvelopes.indexWhere((e) => e.categoryId == tx.categoryId);
    if (idx != -1) {
      final env = _mockEnvelopes[idx];
      final spendDelta = tx.reportingAmountZar.abs();
      final newSpent = isRevert
          ? (env.actualSpentZar - spendDelta).clamp(0.0, double.infinity)
          : env.actualSpentZar + spendDelta;

      _mockEnvelopes[idx] = env.copyWith(actualSpentZar: newSpent);
    }
  }

  // =========================================================================
  // ASSET REGISTRY & MANAGER METHODS
  // =========================================================================

  /// Fetch all active assets
  Future<List<AssetModel>> getAssets() async {
    _ensureDefaultData();
    return List<AssetModel>.from(_mockAssets);
  }

  /// Save or update an asset
  Future<void> saveAsset(AssetModel asset) async {
    _ensureDefaultData();
    final idx = _mockAssets.indexWhere((a) => a.id == asset.id);
    if (idx != -1) {
      _mockAssets[idx] = asset;
    } else {
      _mockAssets.insert(0, asset);
    }
  }

  /// Delete an asset
  Future<void> deleteAsset(String id) async {
    _ensureDefaultData();
    _mockAssets.removeWhere((a) => a.id == id);
  }

  /// Total gross valuation of all assets
  double getTotalAssetsValueZar() {
    _ensureDefaultData();
    return _mockAssets.fold<double>(0.0, (sum, a) => sum + a.currentValueZar);
  }

  /// Total net book value (cost - depreciation) of all assets
  double getTotalAssetsNetBookValueZar() {
    _ensureDefaultData();
    return _mockAssets.fold<double>(0.0, (sum, a) => sum + a.netBookValueZar);
  }

  /// Net equity contribution of all included assets to Net Worth
  double getTotalAssetsNetWorthContributionZar() {
    _ensureDefaultData();
    return _mockAssets.fold<double>(0.0, (sum, a) => sum + a.effectiveNetWorthContributionZar);
  }

  // =========================================================================
  // DEBT & CREDIT LEDGER METHODS
  // =========================================================================

  /// Fetch all debts and credits
  Future<List<DebtModel>> getDebts({DebtDirection? direction}) async {
    _ensureDefaultData();
    if (direction != null) {
      return _mockDebts.where((d) => d.direction == direction).toList();
    }
    return List<DebtModel>.from(_mockDebts);
  }

  /// Save or update a debt/credit entry
  Future<void> saveDebt(DebtModel debt) async {
    _ensureDefaultData();
    final idx = _mockDebts.indexWhere((d) => d.id == debt.id);
    if (idx != -1) {
      _mockDebts[idx] = debt;
    } else {
      _mockDebts.insert(0, debt);
    }
  }

  /// Delete a debt/credit entry
  Future<void> deleteDebt(String id) async {
    _ensureDefaultData();
    _mockDebts.removeWhere((d) => d.id == id);
  }

  /// Record a repayment / settlement event against a debt record
  Future<DebtModel?> recordDebtRepayment({
    required String debtId,
    required double amountZar,
    required String paymentMethod,
    String? sourceEnvelopeId,
    String notes = '',
    DateTime? paymentDate,
  }) async {
    _ensureDefaultData();
    final idx = _mockDebts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return null;

    final debt = _mockDebts[idx];
    final payDate = paymentDate ?? DateTime.now();
    final newBalance = (debt.currentOutstandingBalanceZar - amountZar).clamp(0.0, double.infinity);
    final isFullyPaid = newBalance <= 0.01;

    final repayment = DebtRepaymentModel(
      id: 'REP_${DateTime.now().millisecondsSinceEpoch}',
      debtId: debtId,
      amountZar: amountZar,
      paymentDate: payDate,
      paymentMethod: paymentMethod,
      sourceEnvelopeId: sourceEnvelopeId,
      sourceEnvelopeName: sourceEnvelopeId != null
          ? _mockEnvelopes.firstWhere((e) => e.categoryId == sourceEnvelopeId, orElse: () => _mockEnvelopes.first).categoryName
          : null,
      notes: notes,
      createdAt: DateTime.now(),
    );

    final updatedRepayments = List<DebtRepaymentModel>.from(debt.repayments)..insert(0, repayment);

    final updatedDebt = debt.copyWith(
      currentOutstandingBalanceZar: newBalance,
      status: isFullyPaid ? DebtStatus.paidOff : debt.status,
      repayments: updatedRepayments,
    );

    _mockDebts[idx] = updatedDebt;

    // Optimistically deduct from linked/source envelope if specified
    if (sourceEnvelopeId != null && amountZar > 0) {
      final envIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == sourceEnvelopeId);
      if (envIdx != -1) {
        final env = _mockEnvelopes[envIdx];
        _mockEnvelopes[envIdx] = env.copyWith(
          actualSpentZar: env.actualSpentZar + amountZar,
        );
      }
    }

    // Also deduct linked liability from linked asset if any
    final assetIdx = _mockAssets.indexWhere((a) => a.linkedLiabilityId == debtId);
    if (assetIdx != -1) {
      final asset = _mockAssets[assetIdx];
      final newLiab = (asset.linkedLiabilityAmountZar - amountZar).clamp(0.0, double.infinity);
      _mockAssets[assetIdx] = asset.copyWith(linkedLiabilityAmountZar: newLiab);
    }

    return updatedDebt;
  }

  /// Full payoff Settle Up action
  Future<DebtModel?> settleDebt(String debtId, {String paymentMethod = 'EFT Wire', String? sourceEnvelopeId}) async {
    _ensureDefaultData();
    final idx = _mockDebts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return null;
    final debt = _mockDebts[idx];
    return recordDebtRepayment(
      debtId: debtId,
      amountZar: debt.currentOutstandingBalanceZar,
      paymentMethod: paymentMethod,
      sourceEnvelopeId: sourceEnvelopeId ?? debt.linkedEnvelopeId,
      notes: 'Full Payoff / Settle Up',
    );
  }

  /// Total active debt I owe (Liabilities)
  double getTotalDebtsOwedByMeZar() {
    _ensureDefaultData();
    return _mockDebts
        .where((d) => d.direction == DebtDirection.owedByMe && !d.isPaidOff)
        .fold<double>(0.0, (sum, d) => sum + d.currentOutstandingBalanceZar);
  }

  /// Total debt owed to me (Receivables)
  double getTotalDebtsOwedToMeZar() {
    _ensureDefaultData();
    return _mockDebts
        .where((d) => d.direction == DebtDirection.owedToMe && !d.isPaidOff)
        .fold<double>(0.0, (sum, d) => sum + d.currentOutstandingBalanceZar);
  }

  /// Consolidated Net Worth across Liquid Accounts, Physical/Intangible Assets, and Debts/Receivables
  double calculateConsolidatedNetWorthZar({double liquidAccountsTotalZar = 0.0}) {
    _ensureDefaultData();
    final assetsContribution = getTotalAssetsNetWorthContributionZar();
    final receivables = getTotalDebtsOwedToMeZar();
    final liabilities = getTotalDebtsOwedByMeZar();
    return liquidAccountsTotalZar + assetsContribution + receivables - liabilities;
  }

  // ==========================================
  // PHASE THREE: SCENARIO PLANNER SANDBOX
  // ==========================================

  List<ScenarioModel> getScenarios() {
    _ensureDefaultData();
    return List.unmodifiable(_mockScenarios);
  }

  Future<void> saveScenario(ScenarioModel scenario) async {
    _ensureDefaultData();
    final idx = _mockScenarios.indexWhere((s) => s.id == scenario.id);
    if (idx != -1) {
      _mockScenarios[idx] = scenario.copyWith(updatedAt: DateTime.now());
    } else {
      _mockScenarios.insert(0, scenario);
    }
  }

  Future<ScenarioModel?> duplicateScenario(String scenarioId) async {
    _ensureDefaultData();
    final idx = _mockScenarios.indexWhere((s) => s.id == scenarioId);
    if (idx == -1) return null;
    final original = _mockScenarios[idx];
    final copy = original.copyWith(
      id: 'SCENARIO_${DateTime.now().millisecondsSinceEpoch}',
      title: '${original.title} (Copy)',
      status: ScenarioStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockScenarios.insert(0, copy);
    return copy;
  }

  Future<void> archiveScenario(String scenarioId) async {
    _ensureDefaultData();
    final idx = _mockScenarios.indexWhere((s) => s.id == scenarioId);
    if (idx != -1) {
      _mockScenarios[idx] = _mockScenarios[idx].copyWith(
        status: ScenarioStatus.archived,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Explicit commit step: Applies scenario one-time and recurring moves to live store & BigQuery
  Future<void> applyScenarioToLive(ScenarioModel scenario) async {
    _ensureDefaultData();

    // 1. One-time expenses -> dispatch transactions into target envelopes
    for (final exp in scenario.oneTimeExpenses) {
      final tx = TransactionModel(
        transactionId: 'TX_SCENARIO_${exp.id}_${DateTime.now().millisecondsSinceEpoch}',
        transactionDate: exp.targetDate.toIso8601String().split('T')[0],
        accountId: 'ACC_CHEQ_01',
        categoryId: exp.sourceEnvelopeId ?? 'CAT_DISCRETIONARY_ENTERTAINMENT',
        categoryName: exp.category ?? 'Committed Scenario Outflow',
        transactionType: 'expense',
        originalAmount: exp.amountZar,
        originalCurrency: 'ZAR',
        reportingAmountZar: exp.amountZar,
        reportingAmountUsd: exp.amountZar / 18.5,
        merchantOrPayee: '[COMMITTED SCENARIO] ${exp.title}',
        paymentMethod: 'EFT Wire',
        isTaxDeductible: false,
        notes: 'Applied from Scenario: ${scenario.title}',
        tags: const ['ScenarioCommit', 'CapitalExpenditure'],
        isSynced: false,
      );
      await saveTransaction(tx);
    }

    // 2. Recurring changes -> adjust planned envelope budgets
    for (final rec in scenario.recurringChanges) {
      if (rec.targetEnvelopeId != null) {
        final envIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == rec.targetEnvelopeId);
        if (envIdx != -1) {
          final env = _mockEnvelopes[envIdx];
          final newPlanned = (env.plannedAmountZar + (rec.isIncome ? 0 : rec.monthlyDeltaZar.abs())).clamp(0.0, double.infinity);
          _mockEnvelopes[envIdx] = env.copyWith(plannedAmountZar: newPlanned);
        }
      }
    }

    // 3. Mark scenario as committed
    final idx = _mockScenarios.indexWhere((s) => s.id == scenario.id);
    if (idx != -1) {
      _mockScenarios[idx] = scenario.copyWith(
        status: ScenarioStatus.committed,
        updatedAt: DateTime.now(),
      );
    }
  }

  // ==========================================
  // PHASE THREE: TAX RESERVE AUTOMATION
  // ==========================================

  TaxAutomationConfig getTaxConfig() => _taxConfig;

  Future<void> saveTaxConfig(TaxAutomationConfig config) async {
    _taxConfig = config;
  }

  List<TaxSkimRecord> getTaxSkimRecords() {
    _ensureDefaultData();
    return List.unmodifiable(_mockTaxSkims);
  }

  void _processInflowTaxSkim(TransactionModel tx) {
    if (!_taxConfig.enabled || !_taxConfig.autoSkimOnIncome) return;
    final skimAmount = _taxConfig.calculateSkimAmount(
      grossAmountZar: tx.reportingAmountZar,
      description: tx.merchantOrPayee,
      category: tx.categoryName,
    );
    if (skimAmount <= 0) return;

    final record = TaxSkimRecord(
      id: 'SKIM_${DateTime.now().millisecondsSinceEpoch}',
      sourceTransactionId: tx.transactionId,
      sourceDescription: tx.merchantOrPayee,
      grossIncomeZar: tx.reportingAmountZar,
      taxRateAppliedPercent: _taxConfig.defaultTaxRatePercent,
      skimmedTaxAmountZar: skimAmount,
      targetEnvelopeId: _taxConfig.targetEnvelopeId,
      targetEnvelopeName: _taxConfig.targetEnvelopeName,
      timestamp: DateTime.now(),
    );
    _mockTaxSkims.insert(0, record);

    // Apply to target tax envelope balance
    final envIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == _taxConfig.targetEnvelopeId);
    if (envIdx != -1) {
      final env = _mockEnvelopes[envIdx];
      // Increasing envelope planned allocation & current reserve
      _mockEnvelopes[envIdx] = env.copyWith(
        plannedAmountZar: env.plannedAmountZar + skimAmount,
      );
    }
  }

  TaxReserveStatus calculateTaxReserveStatus() {
    _ensureDefaultData();
    final envIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == _taxConfig.targetEnvelopeId);
    final currentReserve = envIdx != -1 ? _mockEnvelopes[envIdx].currentBalanceZar : 48500.0;
    final ytdSkimmed = _mockTaxSkims.fold<double>(0.0, (sum, s) => sum + s.skimmedTaxAmountZar);

    // Estimated based on total monthly income run-rate ~R195,400/mo
    const monthlyIncomeRunRate = 195400.0;
    const annualIncomeEstimate = monthlyIncomeRunRate * 12;
    final estimatedAnnualTax = annualIncomeEstimate * (_taxConfig.defaultTaxRatePercent / 100.0);
    final quarterEstimatedTax = estimatedAnnualTax / 4.0;
    final quarterReserves = currentReserve.clamp(0.0, double.infinity);

    return TaxReserveStatus(
      currentTaxReserveZar: currentReserve,
      ytdTaxReservedZar: ytdSkimmed > 0 ? ytdSkimmed : 59250.0,
      estimatedAnnualTaxObligationZar: estimatedAnnualTax,
      currentQuarterEstimatedLiabilityZar: quarterEstimatedTax,
      currentQuarterReservesZar: quarterReserves,
    );
  }

  // ==========================================
  // PHASE THREE: STRATEGIC INSIGHTS ENGINE
  // ==========================================

  List<StrategicGoalModel> getStrategicGoals() {
    _ensureDefaultData();
    return List.unmodifiable(_mockStrategicGoals);
  }

  Future<void> saveStrategicGoal(StrategicGoalModel goal) async {
    _ensureDefaultData();
    final idx = _mockStrategicGoals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _mockStrategicGoals[idx] = goal.copyWith(updatedAt: DateTime.now());
    } else {
      _mockStrategicGoals.insert(0, goal);
    }
  }

  Future<void> deleteStrategicGoal(String goalId) async {
    _ensureDefaultData();
    _mockStrategicGoals.removeWhere((g) => g.id == goalId);
  }

  StrategicGoalModel parseNaturalLanguageGoal(String prompt) {
    _ensureDefaultData();
    final envIdx = _mockEnvelopes.indexWhere((e) => e.categoryId == 'CAT_SINKING_EMERGENCY');
    final emergencyReserve = envIdx != -1 ? _mockEnvelopes[envIdx].currentBalanceZar : 45000.0;
    const monthlySurplus = 107200.0;
    final highInterestDebt = getTotalDebtsOwedByMeZar();

    final goal = StrategicGoalModel.parseFromPrompt(
      prompt: prompt,
      currentEmergencyReserveZar: emergencyReserve,
      monthlyNetSurplusZar: monthlySurplus,
      totalHighInterestDebtZar: highInterestDebt,
    );
    return goal;
  }

  StrategicRecommendation getPersonalCfoNextBestMove() {
    final goals = getStrategicGoals();
    if (goals.isNotEmpty) {
      return goals.first.recommendation;
    }
    return StrategicRecommendation(
      recommendedMonthlyAllocationZar: 14500.0,
      primaryTargetEnvelopeId: 'CAT_SINKING_EMERGENCY',
      primaryTargetEnvelopeName: 'Emergency Liquidity Reserve',
      debtPrioritizationMessage: 'Prioritize paying off high-interest revolving balances before discretionary expansions.',
      reallocationSuggestions: ['Reallocate R4,500 from Discretionary Dining into Emergency Fund.'],
      projectedCompletionMonths: 12,
      projectedCompletionDate: DateTime(2027, 3, 1),
      actionSteps: ['Direct R14,500 on 1st of each month to Emergency Liquidity Reserve.'],
      statusNudge: 'Tactical CFO Recommendation: Build 6-Month Emergency Runway to preserve wealth baseline.',
    );
  }
}
