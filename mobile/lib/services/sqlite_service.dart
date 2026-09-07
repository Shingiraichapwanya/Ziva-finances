import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../models/asset_model.dart';
import '../models/debt_model.dart';
import '../models/bank_sync_model.dart';
import '../models/confidence_rule_model.dart';
import '../models/deposit_slip_model.dart';
import '../models/email_transaction_proposal.dart';
import '../models/envelope_model.dart';
import '../models/legacy_vault_model.dart';
import '../models/predictive_cashflow_model.dart';
import '../models/reconciliation_model.dart';
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

  ApiService _api = ApiService();

  @visibleForTesting
  void setApiForTesting(ApiService api) {
    _api = api;
  }

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

  // Phase Four: Auto Pilot Intelligence collections
  final List<EmailTransactionProposal> _mockEmailProposals = [];
  GoogleWorkspaceConnection _workspaceConnection = const GoogleWorkspaceConnection();
  final List<DepositSlipModel> _mockDepositSlips = [];
  final List<StatementTransaction> _mockStatementTransactions = [];
  final List<ReconciliationMatch> _mockReconciliationMatches = [];
  ConfidenceEngineConfig _confidenceConfig = const ConfidenceEngineConfig();
  final List<AutoAddAuditRecord> _mockAutoAddAuditLogs = [];
  final List<KnownObligation> _mockObligations = [];
  final List<BankSyncConnection> _mockBankSyncConnections = [];
  LegacyVaultConfig _legacyVaultConfig = const LegacyVaultConfig();
  final List<TrustedContact> _mockTrustedContacts = [];
  final List<VaultAuditLog> _mockVaultAuditLogs = [];

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

  static final List<EmailTransactionProposal> defaultEmailProposals = [
    EmailTransactionProposal(
      id: 'PROP_EMAIL_01',
      emailSubject: 'FNB Payment Confirmation: Retainer Deposit',
      senderEmail: 'notifications@fnb.co.za',
      receivedDate: DateTime(2026, 9, 5, 14, 30),
      documentType: EmailDocumentType.paymentNotification,
      extractedAmount: 45000.0,
      currency: 'ZAR',
      counterparty: 'Apex Global Advisory',
      referenceNumber: 'REF-APEX-ADV-992',
      accountIdentifier: 'FNB •••• 4921',
      suggestedEnvelopeId: 'CAT_ESSENTIAL_SAVINGS',
      suggestedAccountId: 'ACC_FNB_01',
      isCredit: true,
      confidenceScore: 0.98,
      confidenceFactors: {
        'Sender Authenticity (DKIM/SPF)': 1.0,
        'Structured Swift Reference': 0.98,
        'Known Counterparty Pattern': 0.96,
      },
      status: ProposalStatus.autoAdded,
      rawSnippet: 'Dear Customer, your account *4921 has been credited with ZAR 45,000.00 from APEX GLOBAL ADVISORY on 05-Sep-2026. Ref: REF-APEX-ADV-992.',
      reviewedAt: DateTime(2026, 9, 5, 14, 31),
      createdTransactionId: 'TX_AUTO_APEX_01',
    ),
    EmailTransactionProposal(
      id: 'PROP_EMAIL_02',
      emailSubject: 'Invoice INV-2026-881 from AWS Cloud EMEA',
      senderEmail: 'no-reply-aws@amazon.com',
      receivedDate: DateTime(2026, 9, 4, 9, 15),
      documentType: EmailDocumentType.invoice,
      extractedAmount: 12450.0,
      currency: 'ZAR',
      counterparty: 'Amazon Web Services EMEA',
      referenceNumber: 'INV-AWS-2026-881',
      accountIdentifier: 'Standard Bank •••• 8820',
      suggestedEnvelopeId: 'CAT_TECH_CLOUD',
      suggestedAccountId: 'ACC_STDBANK_01',
      isCredit: false,
      confidenceScore: 0.96,
      confidenceFactors: {
        'Corporate PDF Attachment': 0.98,
        'Matched Tax Invoice VAT': 0.95,
        'Regular Monthly Run-Rate': 0.95,
      },
      status: ProposalStatus.autoAdded,
      rawSnippet: 'Tax Invoice INV-AWS-2026-881: South Africa Region instances, Bandwidth & S3 storage. Amount: ZAR 12,450.00 charged to card ending in 8820.',
      reviewedAt: DateTime(2026, 9, 4, 9, 16),
      createdTransactionId: 'TX_AUTO_AWS_01',
    ),
    EmailTransactionProposal(
      id: 'PROP_EMAIL_03',
      emailSubject: 'Apple Services Monthly Subscription Receipt',
      senderEmail: 'no_reply@email.apple.com',
      receivedDate: DateTime(2026, 9, 6, 8, 12),
      documentType: EmailDocumentType.receipt,
      extractedAmount: 1899.0,
      currency: 'ZAR',
      counterparty: 'Apple Distribution International',
      referenceNumber: 'APL-ZA-89104',
      accountIdentifier: 'FNB •••• 4921',
      suggestedEnvelopeId: 'CAT_TECH_CLOUD',
      suggestedAccountId: 'ACC_FNB_01',
      isCredit: false,
      confidenceScore: 0.88,
      confidenceFactors: {
        'Verified Apple Sender': 0.95,
        'Uncertain Envelope Split (iCloud vs App)': 0.80,
      },
      status: ProposalStatus.pending,
      rawSnippet: 'Your receipt from Apple for iCloud+ 2TB and Apple One Premier. Total billed: R1,899.00 on Visa card ending in 4921.',
    ),
    EmailTransactionProposal(
      id: 'PROP_EMAIL_04',
      emailSubject: 'Woolworths Food & Cellar Order Confirmation #W-99120',
      senderEmail: 'orders@woolworths.co.za',
      receivedDate: DateTime(2026, 9, 7, 11, 45),
      documentType: EmailDocumentType.receipt,
      extractedAmount: 3420.0,
      currency: 'ZAR',
      counterparty: 'Woolworths Camps Bay',
      referenceNumber: 'WOOL-99120',
      accountIdentifier: 'FNB •••• 4921',
      suggestedEnvelopeId: 'CAT_DISCRETIONARY_ENTERTAINMENT',
      suggestedAccountId: 'ACC_FNB_01',
      isCredit: false,
      confidenceScore: 0.84,
      confidenceFactors: {
        'E-Commerce Order Total Verified': 0.90,
        'Multiple Potential Envelopes (Groceries vs Wine)': 0.78,
      },
      status: ProposalStatus.pending,
      rawSnippet: 'Thank you for your order #W-99120. Items: Organic produce, prime cuts, pantry essentials, and cellar selection. Total: R3,420.00.',
    ),
    EmailTransactionProposal(
      id: 'PROP_EMAIL_05',
      emailSubject: 'Private Syndicate Contribution Receipt',
      senderEmail: 'kudakwashe@syndicate-holdings.co.za',
      receivedDate: DateTime(2026, 9, 7, 16, 20),
      documentType: EmailDocumentType.transferAdvice,
      extractedAmount: 18500.0,
      currency: 'ZAR',
      counterparty: 'Kudakwashe Syndicate',
      referenceNumber: 'SYN-ESCROW-009',
      accountIdentifier: 'Investec •••• 1044',
      suggestedEnvelopeId: 'CAT_ESSENTIAL_SAVINGS',
      suggestedAccountId: 'ACC_INVESTEC_01',
      isCredit: true,
      confidenceScore: 0.62,
      confidenceFactors: {
        'Informal Email Body Structure': 0.60,
        'Unknown Sub-Account ID': 0.55,
        'Amount Unconfirmed by Bank Slip': 0.70,
      },
      status: ProposalStatus.pending,
      rawSnippet: 'Hey Shingi, deposited R18,500 into the Investec holding account for the algorithm escrow sync. Ref SYN-ESCROW-009.',
    ),
  ];

  static final List<DepositSlipModel> defaultDepositSlips = [
    DepositSlipModel(
      id: 'SLIP_2026_01',
      bankName: 'Standard Bank Private',
      imagePath: 'assets/slips/slip_std_bank_85k.jpg',
      uploadedAt: DateTime(2026, 9, 6, 15, 20),
      extractedAmount: 85000.0,
      amountConfidence: 0.94,
      extractedDate: DateTime(2026, 9, 6),
      dateConfidence: 0.91,
      extractedAccountNumber: '00294819284',
      accountConfidence: 0.89,
      extractedBranch: 'Sandton City (0129)',
      branchConfidence: 0.86,
      extractedReference: 'DEP-SANDTON-85K',
      matchedAccountId: 'ACC_STDBANK_01',
      matchedAccountName: 'Standard Bank Private MM Vault',
      matchType: AccountMatchType.exact,
      status: DepositSlipStatus.readyForReview,
      notes: 'Handwritten teller deposit slip: clear figures, teller stamp authenticated.',
    ),
    DepositSlipModel(
      id: 'SLIP_2026_02',
      bankName: 'Ecobank / FBC',
      imagePath: 'assets/slips/slip_fbc_usd_2500.jpg',
      uploadedAt: DateTime(2026, 9, 3, 11, 0),
      extractedAmount: 45000.0, // R45,000 equivalent for $2,500 USD
      amountConfidence: 0.92,
      extractedDate: DateTime(2026, 9, 3),
      dateConfidence: 0.95,
      extractedAccountNumber: '99201948271',
      accountConfidence: 0.88,
      extractedBranch: 'Harare Corporate (001)',
      branchConfidence: 0.85,
      extractedReference: 'USD-CASH-DEP-2500',
      matchedAccountId: 'ACC_ECOBANK_01',
      matchedAccountName: 'Ecobank / FBC Offshore USD',
      matchType: AccountMatchType.exact,
      userCorrectedAmount: 45000.0,
      status: DepositSlipStatus.approvedPendingDeposit,
      notes: 'Offshore USD cash deposit slip converted at R18.00/USD exchange benchmark.',
    ),
    DepositSlipModel(
      id: 'SLIP_2026_03',
      bankName: 'Nedbank Private Wealth',
      imagePath: 'assets/slips/slip_nedbank_120k.jpg',
      uploadedAt: DateTime(2026, 8, 28, 10, 30),
      extractedAmount: 120000.0,
      amountConfidence: 0.98,
      extractedDate: DateTime(2026, 8, 28),
      dateConfidence: 0.98,
      extractedAccountNumber: '1948291048',
      accountConfidence: 0.96,
      extractedBranch: 'V&A Waterfront (0199)',
      branchConfidence: 0.94,
      extractedReference: 'NED-ESTATE-DIV-120K',
      matchedAccountId: 'ACC_INVESTEC_01',
      matchedAccountName: 'Investec Prime Portfolio',
      matchType: AccountMatchType.exact,
      status: DepositSlipStatus.reconciled,
      reconciledTransactionId: 'STMT_NED_120K',
      notes: 'Reconciled with official bank statement on Aug 29.',
    ),
  ];

  static final List<StatementTransaction> defaultStatementTransactions = [
    StatementTransaction(
      id: 'STMT_TX_01',
      accountId: 'ACC_FNB_01',
      accountName: 'First National Bank Private Cheque',
      statementDate: DateTime(2026, 9, 5),
      amountZar: 45000.0,
      isCredit: true,
      reference: 'REF-APEX-ADV-992',
      counterparty: 'Apex Global Advisory',
      source: StatementSource.bankApiSync,
      isReconciled: true,
      matchedInternalId: 'PROP_EMAIL_01',
    ),
    StatementTransaction(
      id: 'STMT_TX_02',
      accountId: 'ACC_STDBANK_01',
      accountName: 'Standard Bank Private MM Vault',
      statementDate: DateTime(2026, 9, 6),
      amountZar: 85000.0,
      isCredit: true,
      reference: 'CASH DEP SANDTON BR 0129',
      counterparty: 'Cash Deposit Teller #4',
      source: StatementSource.statementUploadPdf,
      isReconciled: false,
      matchedInternalId: 'SLIP_2026_01',
    ),
    StatementTransaction(
      id: 'STMT_TX_03',
      accountId: 'ACC_FNB_01',
      accountName: 'First National Bank Private Cheque',
      statementDate: DateTime(2026, 9, 4),
      amountZar: 14375.0,
      isCredit: false,
      reference: 'DISCOVERY CARD SETTLE EFT',
      counterparty: 'Discovery Bank Credit Card',
      source: StatementSource.bankApiSync,
      isReconciled: true,
      matchedInternalId: 'DEBT_DISCOVERY_CARD',
    ),
    StatementTransaction(
      id: 'STMT_TX_04',
      accountId: 'ACC_FNB_01',
      accountName: 'First National Bank Private Cheque',
      statementDate: DateTime(2026, 9, 6),
      amountZar: 7850.0,
      isCredit: false,
      reference: 'VODACOM CORP DIA 100MBPS',
      counterparty: 'Vodacom Business Fibre',
      source: StatementSource.bankApiSync,
      isReconciled: false,
    ),
    StatementTransaction(
      id: 'STMT_TX_05',
      accountId: 'ACC_INVESTEC_01',
      accountName: 'Investec Prime Portfolio',
      statementDate: DateTime(2026, 8, 28),
      amountZar: 120000.0,
      isCredit: true,
      reference: 'NED-ESTATE-DIV-120K',
      counterparty: 'Nedgroup Securities Distribution',
      source: StatementSource.statementUploadCsv,
      isReconciled: true,
      matchedInternalId: 'SLIP_2026_03',
    ),
  ];

  static final List<ReconciliationMatch> defaultReconciliationMatches = [
    ReconciliationMatch(
      id: 'RECON_01',
      statementTransaction: StatementTransaction(
        id: 'STMT_TX_01',
        accountId: 'ACC_FNB_01',
        accountName: 'First National Bank Private Cheque',
        statementDate: DateTime(2026, 9, 5),
        amountZar: 45000.0,
        isCredit: true,
        reference: 'REF-APEX-ADV-992',
        counterparty: 'Apex Global Advisory',
        source: StatementSource.bankApiSync,
        isReconciled: true,
      ),
      matchedItemType: MatchedItemType.emailProposal,
      matchedItemId: 'PROP_EMAIL_01',
      matchedDescription: 'Email Proposal: Apex Advisory Retainer',
      matchScore: 0.99,
      status: ReconciliationMatchStatus.reconciled,
      reconciliationNotes: 'Exact amount, date match (0 days), and matching reference REF-APEX-ADV-992.',
      resolvedAt: DateTime(2026, 9, 5, 14, 35),
    ),
    ReconciliationMatch(
      id: 'RECON_02',
      statementTransaction: StatementTransaction(
        id: 'STMT_TX_02',
        accountId: 'ACC_STDBANK_01',
        accountName: 'Standard Bank Private MM Vault',
        statementDate: DateTime(2026, 9, 6),
        amountZar: 85000.0,
        isCredit: true,
        reference: 'CASH DEP SANDTON BR 0129',
        counterparty: 'Cash Deposit Teller #4',
        source: StatementSource.statementUploadPdf,
      ),
      matchedItemType: MatchedItemType.depositSlip,
      matchedItemId: 'SLIP_2026_01',
      matchedDescription: 'OCR Deposit Slip: Sandton City R85,000',
      matchScore: 0.94,
      status: ReconciliationMatchStatus.needsReview,
      reconciliationNotes: 'Amount matches slip (R85,000.00) on 2026-09-06. Awaiting final user approval of deposit slip.',
      candidateMatchIds: ['SLIP_2026_01'],
    ),
    ReconciliationMatch(
      id: 'RECON_03',
      statementTransaction: StatementTransaction(
        id: 'STMT_TX_04',
        accountId: 'ACC_FNB_01',
        accountName: 'First National Bank Private Cheque',
        statementDate: DateTime(2026, 9, 6),
        amountZar: 7850.0,
        isCredit: false,
        reference: 'VODACOM CORP DIA 100MBPS',
        counterparty: 'Vodacom Business Fibre',
        source: StatementSource.bankApiSync,
      ),
      matchedItemType: MatchedItemType.none,
      matchScore: 0.0,
      status: ReconciliationMatchStatus.unmatchedException,
      reconciliationNotes: 'No matching transaction in internal ledger or pending email capture queue. Suggested: Create missing expense entry.',
    ),
  ];

  static final List<AutoAddAuditRecord> defaultAutoAddAuditLogs = [
    AutoAddAuditRecord(
      id: 'AUDIT_01',
      timestamp: DateTime(2026, 9, 5, 14, 31),
      sourceType: 'Email / Google Workspace',
      createdTransactionId: 'TX_AUTO_APEX_01',
      counterparty: 'Apex Global Advisory',
      amountZar: 45000.0,
      currency: 'ZAR',
      confidenceScore: 0.98,
      decisionReason: 'Confidence 98% exceeded high confidence threshold (95%). Verified bank notification token and structured invoice reference.',
      rawSnippet: 'FNB Alert: R45,000.00 credited to *4921 from Apex Global Advisory. Ref: REF-APEX-ADV-992.',
    ),
    AutoAddAuditRecord(
      id: 'AUDIT_02',
      timestamp: DateTime(2026, 9, 4, 9, 16),
      sourceType: 'Email / Google Workspace',
      createdTransactionId: 'TX_AUTO_AWS_01',
      counterparty: 'Amazon Web Services EMEA',
      amountZar: 12450.0,
      currency: 'ZAR',
      confidenceScore: 0.96,
      decisionReason: 'Confidence 96% exceeded high confidence threshold (95%). Corporate tax invoice PDF verified with standard monthly hosting pattern.',
      rawSnippet: 'AWS EMEA Tax Invoice INV-AWS-2026-881: Total ZAR 12,450.00 charged to Standard Bank *8820.',
    ),
  ];

  static final List<KnownObligation> defaultObligations = [
    KnownObligation(
      id: 'OBLIG_GT3_FINANCE',
      title: 'FNB Asset Finance (Porsche 911 GT3)',
      dueDate: DateTime(2026, 9, 18),
      amountZar: 40000.0,
      targetEnvelopeId: 'CAT_SINKING_MAINTENANCE',
      accountId: 'ACC_FNB_01',
      isRecurring: true,
    ),
    KnownObligation(
      id: 'OBLIG_CAMPS_BAY_MUNI',
      title: 'Camps Bay Villa Municipal Rates & Security',
      dueDate: DateTime(2026, 9, 15),
      amountZar: 18500.0,
      targetEnvelopeId: 'CAT_ESSENTIAL_HOUSING',
      accountId: 'ACC_FNB_01',
      isRecurring: true,
    ),
    KnownObligation(
      id: 'OBLIG_DISCOVERY_HEALTH',
      title: 'Discovery Executive Health & Comprehensive Insure',
      dueDate: DateTime(2026, 9, 22),
      amountZar: 12800.0,
      targetEnvelopeId: 'CAT_ESSENTIAL_HOUSING',
      accountId: 'ACC_FNB_01',
      isRecurring: true,
    ),
    KnownObligation(
      id: 'OBLIG_GCP_CLOUD',
      title: 'Google Cloud Platform Cluster Infrastructure',
      dueDate: DateTime(2026, 9, 29),
      amountZar: 16500.0,
      targetEnvelopeId: 'CAT_TECH_CLOUD',
      accountId: 'ACC_STDBANK_01',
      isRecurring: true,
    ),
  ];

  static final List<BankSyncConnection> defaultBankConnections = [
    BankSyncConnection(
      id: 'SYNC_FNB_01',
      institutionName: 'First National Bank',
      accountNumberMasked: '•••• 4921',
      accountType: 'Private Wealth Cheque',
      currentBalanceZar: 245800.0,
      nativeCurrency: 'ZAR',
      nativeBalance: 245800.0,
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      status: BankSyncStatus.synced,
      provider: 'OpenBanking ZA',
      linkedLocalAccountId: 'ACC_FNB_01',
    ),
    BankSyncConnection(
      id: 'SYNC_STDBANK_01',
      institutionName: 'Standard Bank Private',
      accountNumberMasked: '•••• 8820',
      accountType: 'Money Market Liquidity Vault',
      currentBalanceZar: 520000.0,
      nativeCurrency: 'ZAR',
      nativeBalance: 520000.0,
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 18)),
      status: BankSyncStatus.synced,
      provider: 'Stitch Direct',
      linkedLocalAccountId: 'ACC_STDBANK_01',
    ),
    BankSyncConnection(
      id: 'SYNC_INVESTEC_01',
      institutionName: 'Investec Private Bank',
      accountNumberMasked: '•••• 1044',
      accountType: 'Global Prime Securities Portfolio',
      currentBalanceZar: 1450000.0,
      nativeCurrency: 'ZAR',
      nativeBalance: 1450000.0,
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 42)),
      status: BankSyncStatus.synced,
      provider: 'Plaid Global',
      linkedLocalAccountId: 'ACC_INVESTEC_01',
    ),
    BankSyncConnection(
      id: 'SYNC_ECOBANK_01',
      institutionName: 'Ecobank / FBC Offshore',
      accountNumberMasked: '•••• 7701',
      accountType: 'Offshore USD Liquidity Vault',
      currentBalanceZar: 380000.0,
      nativeCurrency: 'USD',
      nativeBalance: 21111.0,
      lastSyncedAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: BankSyncStatus.synced,
      provider: 'OpenBanking Direct',
      linkedLocalAccountId: 'ACC_ECOBANK_01',
    ),
  ];

  static final List<TrustedContact> defaultTrustedContacts = [
    TrustedContact(
      id: 'CONTACT_SOPHIA',
      fullName: 'Sophia Chapwanya',
      relationship: 'Spouse & Primary Beneficiary',
      email: 'sophia.c@executive.co.za',
      phoneNumber: '+27 82 555 9012',
      accessLevel: VaultAccessLevel.fullDossier,
      isConfirmed: true,
      designatedAt: DateTime(2026, 1, 15),
    ),
    TrustedContact(
      id: 'CONTACT_EXECUTOR',
      fullName: 'Adv. Michael Van Der Merwe',
      relationship: 'Designated Estate Executor (Bowman Gilfillan)',
      email: 'm.vandermerwe@bowmanslaw.com',
      phoneNumber: '+27 21 480 7800',
      accessLevel: VaultAccessLevel.emergencyTrustee,
      isConfirmed: true,
      designatedAt: DateTime(2026, 2, 10),
    ),
    TrustedContact(
      id: 'CONTACT_TARIRO',
      fullName: 'Tariro Chapwanya',
      relationship: 'Heir & Secondary Beneficiary',
      email: 'tariro.c@executive.co.za',
      phoneNumber: '+27 83 992 1104',
      accessLevel: VaultAccessLevel.readOnlySummary,
      isConfirmed: true,
      designatedAt: DateTime(2026, 5, 20),
    ),
  ];

  static final List<VaultAuditLog> defaultVaultAuditLogs = [
    VaultAuditLog(
      id: 'VAULT_LOG_01',
      timestamp: DateTime(2026, 9, 1, 10, 0),
      action: 'VAULT_PIN_VERIFIED',
      actorName: 'Shingirai Chapwanya (Primary Principal)',
      details: 'Vault access unlocked with secondary executive authentication PIN.',
    ),
    VaultAuditLog(
      id: 'VAULT_LOG_02',
      timestamp: DateTime(2026, 8, 15, 14, 20),
      action: 'ESTATE_DOSSIER_EXPORTED',
      actorName: 'Shingirai Chapwanya',
      details: 'Generated complete Estate Portfolio & Asset Registry Dossier for Bowman Gilfillan annual review.',
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
    if (_mockScenarios.isEmpty) {
      _mockScenarios.addAll(defaultScenarios);
    }
    if (_mockTaxSkims.isEmpty) {
      _mockTaxSkims.addAll(defaultTaxSkims);
    }
    if (_mockStrategicGoals.isEmpty) {
      _mockStrategicGoals.addAll(defaultStrategicGoals);
    }
    if (_mockEmailProposals.isEmpty) {
      _mockEmailProposals.addAll(defaultEmailProposals);
    }
    if (_mockDepositSlips.isEmpty) {
      _mockDepositSlips.addAll(defaultDepositSlips);
    }
    if (_mockStatementTransactions.isEmpty) {
      _mockStatementTransactions.addAll(defaultStatementTransactions);
    }
    if (_mockReconciliationMatches.isEmpty) {
      _mockReconciliationMatches.addAll(defaultReconciliationMatches);
    }
    if (_mockAutoAddAuditLogs.isEmpty) {
      _mockAutoAddAuditLogs.addAll(defaultAutoAddAuditLogs);
    }
    if (_mockObligations.isEmpty) {
      _mockObligations.addAll(defaultObligations);
    }
    if (_mockBankSyncConnections.isEmpty) {
      _mockBankSyncConnections.addAll(defaultBankConnections);
    }
    if (_mockTrustedContacts.isEmpty) {
      _mockTrustedContacts.addAll(defaultTrustedContacts);
    }
    if (_mockVaultAuditLogs.isEmpty) {
      _mockVaultAuditLogs.addAll(defaultVaultAuditLogs);
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
    _mockEmailProposals.clear();
    _mockDepositSlips.clear();
    _mockStatementTransactions.clear();
    _mockReconciliationMatches.clear();
    _mockAutoAddAuditLogs.clear();
    _mockObligations.clear();
    _mockBankSyncConnections.clear();
    _mockTrustedContacts.clear();
    _mockVaultAuditLogs.clear();
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

  // --- Transactions (Authoritative BigQuery Write-Back Layer) ---

  Future<TransactionModel> saveTransaction(TransactionModel tx) async {
    // 1. Send the write request directly to BigQuery
    final res = await _api.postTransaction(tx.toJson());
    if (res['success'] != true) {
      throw Exception(res['error'] ?? 'BigQuery rejected transaction persistence');
    }

    final confirmedTx = res['record'] != null
        ? TransactionModel.fromJson(res['record'] as Map<String, dynamic>)
        : tx.copyWith(isSynced: true);

    // 2. Only after confirmed successful BigQuery write, update local cache and envelopes
    _mockTransactions.removeWhere((t) => t.transactionId == confirmedTx.transactionId);
    _mockTransactions.insert(0, confirmedTx);

    applyTransactionToEnvelopes(confirmedTx);

    if (confirmedTx.transactionType.toLowerCase() == 'income' && !confirmedTx.notes.contains('[AUTO-TAX-SKIM]')) {
      _processInflowTaxSkim(confirmedTx);
    }

    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        await db.insert(
          'local_transactions',
          confirmedTx.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    debugPrint('[SqliteService] Transaction ${confirmedTx.transactionId} confirmed in BigQuery fct_transactions.');
    return confirmedTx;
  }

  Future<void> saveTransactionsBatch(List<TransactionModel> list) async {
    for (final tx in list) {
      await saveTransaction(tx);
    }
  }

  /// Fetches transactions directly from BigQuery (fct_transactions).
  Future<List<TransactionModel>> getTransactions({int limit = 100}) async {
    try {
      final bqTxs = await _api.fetchTransactions(limit: limit);
      _mockTransactions.clear();
      if (bqTxs.isNotEmpty) {
        _mockTransactions.addAll(bqTxs);
        debugPrint('[SqliteService] Retrieved ${bqTxs.length} canonical transactions directly from BigQuery.');
      } else {
        debugPrint('[SqliteService] BigQuery fct_transactions table currently has 0 rows.');
      }
      return bqTxs;
    } catch (e) {
      debugPrint('[SqliteService] BigQuery transaction fetch failed: $e');
      rethrow;
    }
  }

  Future<void> markTransactionSynced(String transactionId) async {
    final idx = _mockTransactions.indexWhere((t) => t.transactionId == transactionId);
    if (idx != -1) {
      final old = _mockTransactions[idx];
      _mockTransactions[idx] = old.copyWith(isSynced: true);
    }
    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        await db.update(
          'local_transactions',
          {'is_synced': 1},
          where: 'transaction_id = ?',
          whereArgs: [transactionId],
        );
      }
    }
  }

  /// Deletes a transaction directly from BigQuery (fct_transactions) and updates local state
  Future<bool> deleteTransaction(String transactionId) async {
    // 1. Execute delete directly against BigQuery warehouse
    final success = await _api.deleteTransaction(transactionId);
    if (!success) {
      throw Exception('BigQuery failed to delete transaction $transactionId');
    }

    // 2. Only after confirmed successful deletion, prune local state
    final idx = _mockTransactions.indexWhere((t) => t.transactionId == transactionId);
    if (idx != -1) {
      final tx = _mockTransactions[idx];
      applyTransactionToEnvelopes(tx, isRevert: true);
      _mockTransactions.removeAt(idx);
    } else {
      _mockTransactions.removeWhere((t) => t.transactionId == transactionId);
    }

    if (!kIsWeb) {
      final db = await database;
      if (db != null) {
        await db.delete(
          'local_transactions',
          where: 'transaction_id = ?',
          whereArgs: [transactionId],
        );
      }
    }

    debugPrint('[SqliteService] Successfully deleted transaction $transactionId from BigQuery.');
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
  // DEBT & CREDIT LEDGER METHODS (Authoritative BigQuery Write-Back)
  // =========================================================================

  /// Fetch all debts and credits directly from BigQuery debt_credit_ledger
  Future<List<DebtModel>> getDebts({DebtDirection? direction}) async {
    try {
      final bqDebts = await _api.fetchDebts();
      _mockDebts.clear();
      _mockDebts.addAll(bqDebts);
      if (direction != null) {
        return bqDebts.where((d) => d.direction == direction).toList();
      }
      return bqDebts;
    } catch (e) {
      debugPrint('[SqliteService] BigQuery debt fetch failed: $e');
      rethrow;
    }
  }

  /// Save or update a debt/credit entry directly into BigQuery debt_credit_ledger
  Future<DebtModel> saveDebt(DebtModel debt) async {
    final res = await _api.postDebt(debt.toJson());
    if (res['success'] != true) {
      throw Exception(res['error'] ?? 'BigQuery debt insertion rejected');
    }

    final confirmed = res['record'] != null
        ? DebtModel.fromJson(res['record'] as Map<String, dynamic>)
        : debt;

    final idx = _mockDebts.indexWhere((d) => d.id == confirmed.id);
    if (idx != -1) {
      _mockDebts[idx] = confirmed;
    } else {
      _mockDebts.insert(0, confirmed);
    }
    debugPrint('[SqliteService] Debt ${confirmed.id} confirmed in BigQuery debt_credit_ledger.');
    return confirmed;
  }

  /// Delete a debt/credit entry directly from BigQuery debt_credit_ledger
  Future<void> deleteDebt(String id) async {
    final success = await _api.deleteDebt(id);
    if (!success) {
      throw Exception('Failed to delete debt $id from BigQuery.');
    }
    _mockDebts.removeWhere((d) => d.id == id);
    debugPrint('[SqliteService] Debt $id successfully deleted from BigQuery.');
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

    // Persist settlement state to BigQuery if fully paid
    if (isFullyPaid) {
      try {
        await _api.settleDebt(debtId);
        debugPrint('[SqliteService] Settled status written back to BigQuery for debt $debtId');
      } catch (e) {
        debugPrint('[SqliteService] Failed to write back settlement to BigQuery: $e');
        rethrow;
      }
    }

    _mockDebts[idx] = updatedDebt;

    // Deduct from linked/source envelope if specified
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
    // Persist directly to BigQuery
    await _api.settleDebt(debtId);

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

  // ==========================================
  // PHASE FOUR: AUTO PILOT INTELLIGENCE
  // ==========================================

  // --- 1. Email-to-Ledger Intelligence ---

  List<EmailTransactionProposal> getEmailProposals() {
    _ensureDefaultData();
    return List.unmodifiable(_mockEmailProposals);
  }

  GoogleWorkspaceConnection getWorkspaceConnection() {
    return _workspaceConnection;
  }

  void saveWorkspaceConnection(GoogleWorkspaceConnection conn) {
    _workspaceConnection = conn;
  }

  Future<TransactionModel> keepEmailProposal(String proposalId) async {
    _ensureDefaultData();
    final idx = _mockEmailProposals.indexWhere((p) => p.id == proposalId);
    if (idx == -1) {
      throw Exception('Proposal $proposalId not found');
    }
    final proposal = _mockEmailProposals[idx];
    final txnId = 'TX_EMAIL_${const Uuid().v4().substring(0, 8)}';

    final txn = TransactionModel(
      transactionId: txnId,
      accountId: proposal.suggestedAccountId,
      categoryId: proposal.suggestedEnvelopeId,
      categoryName: 'Email Ingestion Transaction',
      transactionType: proposal.isCredit ? 'INCOME' : 'EXPENSE',
      originalAmount: proposal.isCredit ? proposal.extractedAmount : -proposal.extractedAmount,
      originalCurrency: proposal.currency,
      reportingAmountZar: proposal.extractedAmount,
      reportingAmountUsd: proposal.extractedAmount / 18.5,
      merchantOrPayee: '${proposal.counterparty} (${proposal.referenceNumber})',
      transactionDate: proposal.receivedDate.toIso8601String().substring(0, 10),
      notes: 'Imported from Email: ${proposal.emailSubject}',
    );

    await saveTransaction(txn);

    _mockEmailProposals[idx] = proposal.copyWith(
      status: ProposalStatus.kept,
      reviewedAt: DateTime.now(),
      createdTransactionId: txnId,
    );

    return txn;
  }

  Future<void> removeEmailProposal(String proposalId, {bool ignorePattern = false}) async {
    _ensureDefaultData();
    final idx = _mockEmailProposals.indexWhere((p) => p.id == proposalId);
    if (idx != -1) {
      final proposal = _mockEmailProposals[idx];
      _mockEmailProposals[idx] = proposal.copyWith(
        status: ignorePattern ? ProposalStatus.ignoredPattern : ProposalStatus.removed,
        reviewedAt: DateTime.now(),
      );

      if (ignorePattern) {
        final updatedIgnored = List<String>.from(_workspaceConnection.ignoredPatterns);
        if (!updatedIgnored.contains(proposal.counterparty)) {
          updatedIgnored.add(proposal.counterparty);
          _workspaceConnection = _workspaceConnection.copyWith(ignoredPatterns: updatedIgnored);
        }
      }
    }
  }

  Future<int> scanGoogleWorkspaceEmails({bool manualTrigger = false}) async {
    _ensureDefaultData();
    _workspaceConnection = _workspaceConnection.copyWith(lastScanTime: DateTime.now());

    final newProposals = [
      EmailTransactionProposal(
        id: 'PROP_SCAN_${DateTime.now().millisecondsSinceEpoch}',
        emailSubject: 'Uber Trip & Business Travel Receipt',
        senderEmail: 'uber.southafrica@uber.com',
        receivedDate: DateTime.now().subtract(const Duration(hours: 3)),
        documentType: EmailDocumentType.receipt,
        extractedAmount: 640.0,
        currency: 'ZAR',
        counterparty: 'Uber Cape Town Corporate',
        referenceNumber: 'UBR-CPT-${DateTime.now().millisecond}',
        accountIdentifier: 'FNB •••• 4921',
        suggestedEnvelopeId: 'CAT_SINKING_MAINTENANCE',
        suggestedAccountId: 'ACC_FNB_01',
        isCredit: false,
        confidenceScore: 0.96,
        confidenceFactors: {
          'Verified Transport Merchant': 0.98,
          'Receipt Matching Format': 0.95,
        },
        status: ProposalStatus.pending,
        rawSnippet: 'Receipt for your Uber trip on Sep 7, 2026. Total ZAR 640.00 charged to FNB •••• 4921.',
      ),
      EmailTransactionProposal(
        id: 'PROP_SCAN_${DateTime.now().millisecondsSinceEpoch + 1}',
        emailSubject: 'Payment Received from Apex Retainer',
        senderEmail: 'billing@apexconsulting.co.za',
        receivedDate: DateTime.now().subtract(const Duration(hours: 5)),
        documentType: EmailDocumentType.paymentNotification,
        extractedAmount: 28500.0,
        currency: 'ZAR',
        counterparty: 'Apex Consulting Global',
        referenceNumber: 'STRIPE-PAY-7721',
        accountIdentifier: 'Standard Bank •••• 8820',
        suggestedEnvelopeId: 'CAT_ESSENTIAL_SAVINGS',
        suggestedAccountId: 'ACC_STDBANK_01',
        isCredit: true,
        confidenceScore: 0.97,
        confidenceFactors: {
          'Cryptographic Webhook Signature': 1.0,
          'Bank Direct Deposit Match': 0.98,
        },
        status: ProposalStatus.pending,
        rawSnippet: 'Payout of ZAR 28,500.00 has been sent to your Standard Bank account ending in 8820. Ref: STRIPE-PAY-7721.',
      ),
    ];

    int autoAddedCount = 0;
    for (final prop in newProposals) {
      if (_evaluateConfidenceAndAutoAdd(prop)) {
        autoAddedCount++;
      } else {
        _mockEmailProposals.insert(0, prop);
      }
    }
    if (manualTrigger) {
      debugPrint('[SqliteService] Manual email scan ingested ${newProposals.length} docs ($autoAddedCount auto-added).');
    }

    return newProposals.length;
  }

  // --- 2. Handwritten Bank Deposit Slips OCR Pipeline ---

  List<DepositSlipModel> getDepositSlips() {
    _ensureDefaultData();
    return List.unmodifiable(_mockDepositSlips);
  }

  Future<DepositSlipModel> processDepositSlipOcr({
    required String bankName,
    String? imagePath,
    String? imageDataUri,
    double? manualAmount,
    String? manualAccount,
    String? reference,
  }) async {
    _ensureDefaultData();
    final slipId = 'SLIP_${DateTime.now().millisecondsSinceEpoch}';

    // OCR Heuristic: parse bank details and map internal account
    String matchedAccId = 'ACC_STDBANK_01';
    String matchedAccName = 'Standard Bank Private MM Vault';
    if (bankName.toLowerCase().contains('fnb')) {
      matchedAccId = 'ACC_FNB_01';
      matchedAccName = 'First National Bank Private Cheque';
    } else if (bankName.toLowerCase().contains('investec')) {
      matchedAccId = 'ACC_INVESTEC_01';
      matchedAccName = 'Investec Prime Portfolio';
    } else if (bankName.toLowerCase().contains('ecobank') || bankName.toLowerCase().contains('fbc')) {
      matchedAccId = 'ACC_ECOBANK_01';
      matchedAccName = 'Ecobank / FBC Offshore USD';
    }

    final amount = manualAmount ?? 65000.0;

    final newSlip = DepositSlipModel(
      id: slipId,
      bankName: bankName,
      imagePath: imagePath ?? 'assets/slips/deposit_slip_uploaded.jpg',
      imageDataUri: imageDataUri,
      uploadedAt: DateTime.now(),
      extractedAmount: amount,
      amountConfidence: 0.93,
      extractedDate: DateTime.now(),
      dateConfidence: 0.90,
      extractedAccountNumber: '00294819284',
      accountConfidence: 0.88,
      extractedBranch: '$bankName Corporate Teller Branch',
      branchConfidence: 0.84,
      extractedReference: reference ?? 'DEP-OCR-${const Uuid().v4().substring(0, 6).toUpperCase()}',
      matchedAccountId: manualAccount ?? matchedAccId,
      matchedAccountName: matchedAccName,
      matchType: manualAccount != null ? AccountMatchType.manual : AccountMatchType.exact,
      status: DepositSlipStatus.readyForReview,
      notes: 'Processed through Ziva OCR pipeline for handwritten deposit slips.',
    );

    _mockDepositSlips.insert(0, newSlip);
    return newSlip;
  }

  void updateDepositSlipCorrection(
    String slipId, {
    double? correctedAmount,
    DateTime? correctedDate,
    String? correctedAccountId,
  }) {
    _ensureDefaultData();
    final idx = _mockDepositSlips.indexWhere((s) => s.id == slipId);
    if (idx != -1) {
      _mockDepositSlips[idx] = _mockDepositSlips[idx].copyWith(
        userCorrectedAmount: correctedAmount,
        userCorrectedDate: correctedDate,
        userCorrectedAccountId: correctedAccountId,
      );
    }
  }

  Future<TransactionModel> approvePendingDeposit(String slipId) async {
    _ensureDefaultData();
    final idx = _mockDepositSlips.indexWhere((s) => s.id == slipId);
    if (idx == -1) {
      throw Exception('Deposit slip $slipId not found');
    }
    final slip = _mockDepositSlips[idx];
    final txnId = 'TX_SLIP_${const Uuid().v4().substring(0, 8)}';

    final txn = TransactionModel(
      transactionId: txnId,
      accountId: slip.effectiveAccountId ?? 'ACC_STDBANK_01',
      categoryId: 'CAT_ESSENTIAL_SAVINGS',
      categoryName: 'Bank Deposit / Inflow',
      transactionType: 'INCOME',
      originalAmount: slip.effectiveAmount,
      originalCurrency: 'ZAR',
      reportingAmountZar: slip.effectiveAmount,
      reportingAmountUsd: slip.effectiveAmount / 18.5,
      merchantOrPayee: 'Bank Deposit: ${slip.bankName} (${slip.extractedReference ?? slip.id})',
      transactionDate: slip.effectiveDate.toIso8601String().substring(0, 10),
      notes: 'Authenticated handwritten deposit slip approved via OCR pipeline.',
    );

    await saveTransaction(txn);

    _mockDepositSlips[idx] = slip.copyWith(
      status: DepositSlipStatus.approvedPendingDeposit,
      reconciledTransactionId: txnId,
    );

    return txn;
  }

  // --- 3. Reconciliation Engine ---

  List<StatementTransaction> getStatementTransactions() {
    _ensureDefaultData();
    return List.unmodifiable(_mockStatementTransactions);
  }

  List<ReconciliationMatch> getReconciliationMatches() {
    _ensureDefaultData();
    return List.unmodifiable(_mockReconciliationMatches);
  }

  Future<void> runReconciliationEngine() async {
    _ensureDefaultData();
    _mockReconciliationMatches.clear();

    for (final stmt in _mockStatementTransactions) {
      // 1. Try matching with approved deposit slips
      final matchingSlip = _mockDepositSlips.firstWhere(
        (s) =>
            (s.effectiveAmount - stmt.amountZar).abs() < 1.0 &&
            (s.effectiveDate.difference(stmt.statementDate).inDays).abs() <= 2,
        orElse: () => DepositSlipModel(id: '', uploadedAt: DateTime.now()),
      );

      if (matchingSlip.id.isNotEmpty) {
        _mockReconciliationMatches.add(
          ReconciliationMatch(
            id: 'RECON_${stmt.id}',
            statementTransaction: stmt.copyWith(isReconciled: true, matchedInternalId: matchingSlip.id),
            matchedItemType: MatchedItemType.depositSlip,
            matchedItemId: matchingSlip.id,
            matchedDescription: 'Deposit Slip: ${matchingSlip.bankName} (R${matchingSlip.effectiveAmount.toStringAsFixed(2)})',
            matchScore: 0.96,
            status: ReconciliationMatchStatus.reconciled,
            reconciliationNotes: 'Matched with handwritten deposit slip on amount and date.',
            resolvedAt: DateTime.now(),
          ),
        );
        continue;
      }

      // 2. Try matching with email proposals
      final matchingEmail = _mockEmailProposals.firstWhere(
        (p) =>
            (p.extractedAmount - stmt.amountZar).abs() < 1.0 &&
            (p.receivedDate.difference(stmt.statementDate).inDays).abs() <= 2,
        orElse: () => EmailTransactionProposal(
          id: '',
          emailSubject: '',
          senderEmail: '',
          receivedDate: DateTime.now(),
          documentType: EmailDocumentType.receipt,
          extractedAmount: 0,
          counterparty: '',
          referenceNumber: '',
          accountIdentifier: '',
          confidenceScore: 0,
          rawSnippet: '',
        ),
      );

      if (matchingEmail.id.isNotEmpty) {
        _mockReconciliationMatches.add(
          ReconciliationMatch(
            id: 'RECON_${stmt.id}',
            statementTransaction: stmt.copyWith(isReconciled: true, matchedInternalId: matchingEmail.id),
            matchedItemType: MatchedItemType.emailProposal,
            matchedItemId: matchingEmail.id,
            matchedDescription: 'Email Proposal: ${matchingEmail.counterparty}',
            matchScore: 0.98,
            status: ReconciliationMatchStatus.reconciled,
            reconciliationNotes: 'Matched with parsed email document and statement line.',
            resolvedAt: DateTime.now(),
          ),
        );
        continue;
      }

      // 3. Try matching with local ledger transactions
      final matchingTx = _mockTransactions.firstWhere(
        (t) {
          final txDate = DateTime.tryParse(t.transactionDate) ?? DateTime.now();
          return (t.reportingAmountZar - stmt.amountZar).abs() < 1.0 &&
              (txDate.difference(stmt.statementDate).inDays).abs() <= 2;
        },
        orElse: () => TransactionModel(
          transactionId: '',
          transactionDate: '',
          accountId: '',
          categoryId: '',
          transactionType: 'EXPENSE',
          originalAmount: 0,
          originalCurrency: 'ZAR',
          reportingAmountZar: 0,
          reportingAmountUsd: 0,
          merchantOrPayee: '',
        ),
      );

      if (matchingTx.transactionId.isNotEmpty) {
        _mockReconciliationMatches.add(
          ReconciliationMatch(
            id: 'RECON_${stmt.id}',
            statementTransaction: stmt.copyWith(isReconciled: true, matchedInternalId: matchingTx.transactionId),
            matchedItemType: MatchedItemType.internalLedger,
            matchedItemId: matchingTx.transactionId,
            matchedDescription: 'Ledger Entry: ${matchingTx.merchantOrPayee}',
            matchScore: 0.95,
            status: ReconciliationMatchStatus.reconciled,
            reconciliationNotes: 'Direct match with internal recorded transaction.',
            resolvedAt: DateTime.now(),
          ),
        );
        continue;
      }

      // 4. If no match found -> flag as exception
      _mockReconciliationMatches.add(
        ReconciliationMatch(
          id: 'RECON_${stmt.id}',
          statementTransaction: stmt.copyWith(isReconciled: false),
          matchedItemType: MatchedItemType.none,
          matchScore: 0.0,
          status: ReconciliationMatchStatus.unmatchedException,
          reconciliationNotes: 'No matching transaction in internal ledger or pending email queue. Action needed.',
        ),
      );
    }
  }

  ReconciliationSummary getReconciliationSummary() {
    _ensureDefaultData();
    final matches = getReconciliationMatches();
    final reconciled = matches.where((m) => m.status == ReconciliationMatchStatus.reconciled).toList();
    final unreconciled = matches.where((m) => m.status != ReconciliationMatchStatus.reconciled).toList();

    final reconciledTotal = reconciled.fold<double>(0.0, (s, m) => s + m.statementTransaction.amountZar);
    final unreconciledTotal = unreconciled.fold<double>(0.0, (s, m) => s + m.statementTransaction.amountZar);

    final Map<String, int> breakdowns = {};
    for (final m in matches) {
      final acc = m.statementTransaction.accountName;
      breakdowns[acc] = (breakdowns[acc] ?? 0) + 1;
    }

    return ReconciliationSummary(
      reconciledCount: reconciled.length,
      reconciledTotalZar: reconciledTotal,
      unreconciledCount: unreconciled.length,
      unreconciledTotalZar: unreconciledTotal,
      exceptionsCount: unreconciled.length,
      accountBreakdowns: breakdowns,
    );
  }

  Future<void> resolveReconciliationMismatch(
    String matchId, {
    required String action, // 'confirmAsMissing', 'linkExisting', 'discard'
    String? targetInternalId,
  }) async {
    _ensureDefaultData();
    final idx = _mockReconciliationMatches.indexWhere((m) => m.id == matchId);
    if (idx != -1) {
      final current = _mockReconciliationMatches[idx];
      if (action == 'confirmAsMissing') {
        // Create the missing transaction directly from statement
        final stmt = current.statementTransaction;
        final txn = TransactionModel(
          transactionId: 'TX_STMT_${const Uuid().v4().substring(0, 8)}',
          accountId: stmt.accountId,
          categoryId: 'CAT_ESSENTIAL_HOUSING',
          categoryName: 'Bank Statement Item',
          transactionType: stmt.isCredit ? 'INCOME' : 'EXPENSE',
          originalAmount: stmt.isCredit ? stmt.amountZar : -stmt.amountZar,
          originalCurrency: 'ZAR',
          reportingAmountZar: stmt.amountZar,
          reportingAmountUsd: stmt.amountZar / 18.5,
          merchantOrPayee: '${stmt.counterparty} (${stmt.reference})',
          transactionDate: stmt.statementDate.toIso8601String().substring(0, 10),
          notes: 'Auto-resolved from official bank statement line item.',
        );
        await saveTransaction(txn);
        _mockReconciliationMatches[idx] = current.copyWith(
          status: ReconciliationMatchStatus.reconciled,
          matchedItemType: MatchedItemType.internalLedger,
          matchedItemId: txn.transactionId,
          matchedDescription: txn.merchantOrPayee,
          matchScore: 1.0,
          reconciliationNotes: 'Resolved: Missing transaction generated and reconciled.',
          resolvedAt: DateTime.now(),
        );
      } else if (action == 'discard') {
        _mockReconciliationMatches.removeAt(idx);
      }
    }
  }

  // --- 4. Confidence Engine & Auto-Add Rules ---

  ConfidenceEngineConfig getConfidenceConfig() {
    return _confidenceConfig;
  }

  void saveConfidenceConfig(ConfidenceEngineConfig config) {
    _confidenceConfig = config;
  }

  List<AutoAddAuditRecord> getAutoAddAuditLogs() {
    _ensureDefaultData();
    return List.unmodifiable(_mockAutoAddAuditLogs);
  }

  bool _evaluateConfidenceAndAutoAdd(EmailTransactionProposal proposal) {
    if (!_confidenceConfig.autoAddEnabled) return false;
    final threshold = _confidenceConfig.highConfidenceThresholdPercent / 100.0;

    if (proposal.confidenceScore >= threshold) {
      final txnId = 'TX_AUTO_${const Uuid().v4().substring(0, 8)}';
      final txn = TransactionModel(
        transactionId: txnId,
        accountId: proposal.suggestedAccountId,
        categoryId: proposal.suggestedEnvelopeId,
        categoryName: 'Auto-Added Email Transaction',
        transactionType: proposal.isCredit ? 'INCOME' : 'EXPENSE',
        originalAmount: proposal.isCredit ? proposal.extractedAmount : -proposal.extractedAmount,
        originalCurrency: proposal.currency,
        reportingAmountZar: proposal.extractedAmount,
        reportingAmountUsd: proposal.extractedAmount / 18.5,
        merchantOrPayee: 'Auto-Added (Email): ${proposal.counterparty}',
        transactionDate: proposal.receivedDate.toIso8601String().substring(0, 10),
        notes: 'Auto-added by Confidence Engine (${proposal.formattedConfidence} confidence).',
      );

      saveTransaction(txn);

      final auditRecord = AutoAddAuditRecord(
        id: 'AUDIT_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        sourceType: 'Email / Google Workspace',
        createdTransactionId: txnId,
        counterparty: proposal.counterparty,
        amountZar: proposal.extractedAmount,
        currency: proposal.currency,
        confidenceScore: proposal.confidenceScore,
        decisionReason: 'Confidence ${proposal.formattedConfidence} met high confidence threshold (${_confidenceConfig.highConfidenceThresholdPercent.toStringAsFixed(0)}%).',
        rawSnippet: proposal.rawSnippet,
      );

      _mockAutoAddAuditLogs.insert(0, auditRecord);
      _mockEmailProposals.insert(
        0,
        proposal.copyWith(
          status: ProposalStatus.autoAdded,
          createdTransactionId: txnId,
          reviewedAt: DateTime.now(),
        ),
      );
      return true;
    }
    return false;
  }

  // --- 5. Predictive Cash Flow Alerts & Early Warning System ---

  List<KnownObligation> getKnownObligations() {
    _ensureDefaultData();
    return List.unmodifiable(_mockObligations);
  }

  PredictiveCashFlowProjection calculatePredictiveCashFlowProjections({int horizonDays = 30}) {
    _ensureDefaultData();

    // Calculate total liquid cash across accounts
    double currentLiquid = 0.0;
    for (final a in _mockAccounts) {
      currentLiquid += a.nativeBalance;
    }
    if (currentLiquid <= 0) currentLiquid = 245800.0 + 520000.0; // Benchmark liquidity

    // Upcoming obligations within horizon
    final horizonEnd = DateTime.now().add(Duration(days: horizonDays));
    final relevantObligations = _mockObligations.where((o) => o.dueDate.isBefore(horizonEnd)).toList();
    final obligationsTotal = relevantObligations.fold<double>(0.0, (s, o) => s + o.amountZar);

    // Projected daily burn rate based on standard living costs
    const dailyBurnRate = 3200.0;
    const expectedInflows = 45000.0; // Upcoming advisory retainer

    final projectedLiquid = currentLiquid - obligationsTotal - (dailyBurnRate * horizonDays) + expectedInflows;

    final List<PredictiveAlert> alerts = [];

    // Early warning alert if projected liquid balance drops below safe threshold (R60,000)
    if (projectedLiquid < 150000.0) {
      alerts.add(
        PredictiveAlert(
          id: 'ALERT_CASH_CRUNCH_01',
          severity: AlertSeverity.critical,
          headline: 'High-Probability Cash Squeeze Ahead in ${horizonDays > 14 ? 14 : horizonDays} Days',
          explanation: 'At current spending velocity (R3,200/day) plus upcoming debt obligations (R$obligationsTotal), projected liquid reserves will compress to R${projectedLiquid.toStringAsFixed(0)}.',
          targetName: 'First National Bank Operating Cheque',
          breachDate: DateTime.now().add(Duration(days: horizonDays > 14 ? 14 : horizonDays)),
          projectedShortfallZar: 60000.0,
          suggestedMitigations: [
            'Sweep R45,000 from Standard Bank Money Market Vault into FNB Operating.',
            'Delay SaaS Server Expansion by 14 days to preserve R32,000 liquidity.',
            'Trigger early collection on Apex Retainer receivable.',
          ],
        ),
      );
    }

    // Envelope burn warning
    alerts.add(
      PredictiveAlert(
        id: 'ALERT_ENVELOPE_BURN_02',
        severity: AlertSeverity.warning,
        headline: 'Discretionary Dining Burn Rate Exceeds Monthly Ceiling',
        explanation: 'Dining and entertainment envelope is on track to exhaust budget 9 days before month-end.',
        targetName: 'Discretionary Dining & Hospitality',
        breachDate: DateTime.now().add(const Duration(days: 9)),
        projectedShortfallZar: 4200.0,
        suggestedMitigations: [
          'Cap dining out spend to R1,200/week for remainder of month.',
          'Rebalance R3,000 from General Sinking fund.',
        ],
      ),
    );

    return PredictiveCashFlowProjection(
      horizonDays: horizonDays,
      currentLiquidZar: currentLiquid,
      projectedLiquidZar: projectedLiquid,
      dailyBurnRateZar: dailyBurnRate,
      upcomingObligationsTotalZar: obligationsTotal,
      expectedInflowsTotalZar: expectedInflows,
      upcomingObligations: relevantObligations,
      alerts: alerts,
    );
  }

  List<PredictiveAlert> getPredictiveAlerts() {
    return calculatePredictiveCashFlowProjections().alerts;
  }

  // --- 6. Real-Time Bank Balance Sync APIs ---

  List<BankSyncConnection> getBankConnections() {
    _ensureDefaultData();
    return List.unmodifiable(_mockBankSyncConnections);
  }

  Future<void> syncBankBalances() async {
    _ensureDefaultData();
    for (int i = 0; i < _mockBankSyncConnections.length; i++) {
      final conn = _mockBankSyncConnections[i];
      _mockBankSyncConnections[i] = conn.copyWith(
        lastSyncedAt: DateTime.now(),
        status: BankSyncStatus.synced,
      );

      // Propagate live balance to corresponding local account
      final accIdx = _mockAccounts.indexWhere((a) => a.accountId == conn.linkedLocalAccountId);
      if (accIdx != -1) {
        _mockAccounts[accIdx] = _mockAccounts[accIdx].copyWith(
          nativeBalance: conn.currentBalanceZar,
        );
      }
    }

    // Trigger statement reconciliation against newly updated bank feed
    await runReconciliationEngine();
  }

  // --- 7. Legacy & Estate Vault ---

  LegacyVaultConfig getLegacyVaultConfig() {
    return _legacyVaultConfig;
  }

  void saveLegacyVaultConfig(LegacyVaultConfig config) {
    _legacyVaultConfig = config;
  }

  List<TrustedContact> getTrustedContacts() {
    _ensureDefaultData();
    return List.unmodifiable(_mockTrustedContacts);
  }

  Future<void> saveTrustedContact(TrustedContact contact) async {
    _ensureDefaultData();
    final idx = _mockTrustedContacts.indexWhere((c) => c.id == contact.id);
    if (idx != -1) {
      _mockTrustedContacts[idx] = contact;
    } else {
      _mockTrustedContacts.add(contact);
    }
  }

  Future<void> deleteTrustedContact(String contactId) async {
    _ensureDefaultData();
    _mockTrustedContacts.removeWhere((c) => c.id == contactId);
  }

  List<VaultAuditLog> getVaultAuditLogs() {
    _ensureDefaultData();
    return List.unmodifiable(_mockVaultAuditLogs);
  }

  void logVaultAction(String action, String actor, String details) {
    _ensureDefaultData();
    _mockVaultAuditLogs.insert(
      0,
      VaultAuditLog(
        id: 'LOG_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        action: action,
        actorName: actor,
        details: details,
      ),
    );
  }

  Map<String, dynamic> generateEstateDossier() {
    _ensureDefaultData();
    logVaultAction('ESTATE_DOSSIER_VIEWED', 'Shingirai Chapwanya', 'Generated Executive Legacy & Estate Dossier summary.');

    final includedAssets = _mockAssets.where((a) => _legacyVaultConfig.includedAssetIds.contains(a.id)).toList();
    final includedAccounts = _mockAccounts.where((a) => _legacyVaultConfig.includedAccountIds.contains(a.accountId)).toList();

    double totalAssetValuation = 0.0;
    for (final a in includedAssets) {
      totalAssetValuation += a.currentValueZar * (a.myOwnershipPercentage / 100.0);
    }

    double totalCashLiquidity = 0.0;
    for (final acc in includedAccounts) {
      totalCashLiquidity += acc.nativeBalance;
    }

    final totalDebts = getTotalDebtsOwedByMeZar();

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'principalName': 'Shingirai Chapwanya',
      'totalEstateValuationZar': totalAssetValuation + totalCashLiquidity - totalDebts,
      'assetHoldingsValuationZar': totalAssetValuation,
      'liquidCashValuationZar': totalCashLiquidity,
      'outstandingDebtsZar': totalDebts,
      'includedAssetsCount': includedAssets.length,
      'assets': includedAssets.map((a) => a.toJson()).toList(),
      'accounts': includedAccounts.map((a) => a.toJson()).toList(),
      'trustedContacts': _mockTrustedContacts.map((c) => c.toJson()).toList(),
      'executorDirectives': _legacyVaultConfig.executorDirectives,
      'emergencyTrusteeNotes': _legacyVaultConfig.emergencyTrusteeNotes,
    };
  }
}

