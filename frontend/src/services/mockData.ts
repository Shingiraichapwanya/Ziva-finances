/**
 * mockData.ts - Authentic Seed Data Hydration
 * Mirrored directly from BigQuery tables and analytical views in budget-tracker-507418.personal_finance
 */

import type {
  Account,
  BudgetEnvelope,
  Transaction,
  TaxQuarterSchedule,
  PredictiveBurnMetrics,
  TaxShieldOpportunity,
  ArbitrageSignal,
  InvestmentCounter,
  DebtRecord,
  DebtBalance,
  PerformanceSummary
} from '../types/finance.ts';

export const INITIAL_ACCOUNTS: Account[] = [
  // South Africa
  {
    accountId: 'ACC_ZA_CAPITEC_DAILY',
    accountName: 'Capitec Primary Cheque',
    financialInstitution: 'Capitec Bank',
    countryCode: 'ZA',
    primaryCurrency: 'ZAR',
    cashFlowTier: 'DAILY_SPENDING',
    accountType: 'CHECKING',
    isVaultLocked: false,
    withdrawalNoticeDays: 0,
    accountNumberMasked: '...4091',
    nativeBalance: 18450.00,
    isActive: true
  },
  {
    accountId: 'ACC_ZA_FNB_MONTHLY',
    accountName: 'FNB Monthly Bills Fusion',
    financialInstitution: 'First National Bank',
    countryCode: 'ZA',
    primaryCurrency: 'ZAR',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    accountType: 'CHECKING',
    isVaultLocked: false,
    withdrawalNoticeDays: 0,
    accountNumberMasked: '...8812',
    nativeBalance: 32800.00,
    isActive: true
  },
  {
    accountId: 'ACC_ZA_DISCOVERY_VAULT',
    accountName: 'Discovery 32-Day Notice Emergency',
    financialInstitution: 'Discovery Bank',
    countryCode: 'ZA',
    primaryCurrency: 'ZAR',
    cashFlowTier: 'LONG_TERM_VAULT',
    accountType: 'SAVINGS',
    isVaultLocked: true,
    withdrawalNoticeDays: 32,
    accountNumberMasked: '...1940',
    nativeBalance: 150000.00,
    isActive: true
  },
  {
    accountId: 'ACC_ZA_EE_EQUITIES_VAULT',
    accountName: 'EasyEquities S&P500 & Top40 TFSA',
    financialInstitution: 'EasyEquities',
    countryCode: 'ZA',
    primaryCurrency: 'ZAR',
    cashFlowTier: 'LONG_TERM_VAULT',
    accountType: 'INVESTMENT_BROKER',
    isVaultLocked: true,
    withdrawalNoticeDays: 999,
    accountNumberMasked: '...EE77',
    nativeBalance: 680000.00,
    isActive: true
  },

  // Zimbabwe
  {
    accountId: 'ACC_ZW_ECOCASH_USD',
    accountName: 'EcoCash USD Wallet',
    financialInstitution: 'EcoCash',
    countryCode: 'ZW',
    primaryCurrency: 'USD',
    cashFlowTier: 'DAILY_SPENDING',
    accountType: 'MOBILE_MONEY',
    isVaultLocked: false,
    withdrawalNoticeDays: 0,
    accountNumberMasked: '...0772',
    nativeBalance: 1250.00,
    isActive: true
  },
  {
    accountId: 'ACC_ZW_ECOCASH_ZIG',
    accountName: 'EcoCash ZiG Wallet',
    financialInstitution: 'EcoCash',
    countryCode: 'ZW',
    primaryCurrency: 'ZiG',
    cashFlowTier: 'DAILY_SPENDING',
    accountType: 'MOBILE_MONEY',
    isVaultLocked: false,
    withdrawalNoticeDays: 0,
    accountNumberMasked: '...0772',
    nativeBalance: 8900.00,
    isActive: true
  },
  {
    accountId: 'ACC_ZW_STANBIC_NOSTRO',
    accountName: 'Stanbic Nostro FCA Bills',
    financialInstitution: 'Stanbic Bank Zimbabwe',
    countryCode: 'ZW',
    primaryCurrency: 'USD',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    accountType: 'CHECKING',
    isVaultLocked: false,
    withdrawalNoticeDays: 0,
    accountNumberMasked: '...5521',
    nativeBalance: 4500.00,
    isActive: true
  },
  {
    accountId: 'ACC_ZW_OM_UNITTRUST_VAULT',
    accountName: 'Old Mutual USD Balanced Unit Trust',
    financialInstitution: 'Old Mutual Zimbabwe',
    countryCode: 'ZW',
    primaryCurrency: 'USD',
    cashFlowTier: 'LONG_TERM_VAULT',
    accountType: 'INVESTMENT_BROKER',
    isVaultLocked: true,
    withdrawalNoticeDays: 14,
    accountNumberMasked: '...OM09',
    nativeBalance: 28000.00,
    isActive: true
  }
];

export const INITIAL_ENVELOPES: BudgetEnvelope[] = [
  {
    allocationMonth: '2026-09-01',
    categoryId: 'CAT_DAILY_DINING',
    categoryName: 'Restaurants, Takeaways & Coffee',
    categoryGroup: 'DISCRETIONARY',
    cashFlowTier: 'DAILY_SPENDING',
    targetCurrency: 'ZAR',
    plannedAmount: 3500,
    plannedAmountZar: 3500,
    plannedAmountUsd: 191.78,
    actualSpentZar: 1580,
    actualSpentUsd: 86.58,
    varianceZar: 1920,
    varianceUsd: 105.20,
    pctConsumed: 45.1,
    budgetStatus: 'ON_TRACK',
    isFixedObligation: false
  },
  {
    allocationMonth: '2026-09-01',
    categoryId: 'CAT_DAILY_GROCERIES',
    categoryName: 'Groceries & Household Supplies',
    categoryGroup: 'LIVING_EXPENSES',
    cashFlowTier: 'DAILY_SPENDING',
    targetCurrency: 'ZAR',
    plannedAmount: 6000,
    plannedAmountZar: 6000,
    plannedAmountUsd: 328.77,
    actualSpentZar: 4250,
    actualSpentUsd: 232.88,
    varianceZar: 1750,
    varianceUsd: 95.89,
    pctConsumed: 70.8,
    budgetStatus: 'ON_TRACK',
    isFixedObligation: false
  },
  {
    allocationMonth: '2026-09-01',
    categoryId: 'CAT_PROD_TECH_HARDWARE',
    categoryName: 'Productivity Tech & Work Hardware',
    categoryGroup: 'BUSINESS_PRODUCTIVITY',
    cashFlowTier: 'DAILY_SPENDING',
    targetCurrency: 'ZAR',
    plannedAmount: 8000,
    plannedAmountZar: 8000,
    plannedAmountUsd: 438.36,
    actualSpentZar: 7500,
    actualSpentUsd: 410.96,
    varianceZar: 500,
    varianceUsd: 27.40,
    pctConsumed: 93.8,
    budgetStatus: 'NEAR_LIMIT',
    isFixedObligation: false
  },
  {
    allocationMonth: '2026-09-01',
    categoryId: 'CAT_PROD_SOFTWARE_TOOLS',
    categoryName: 'Business Software, Cloud & AI Subscriptions',
    categoryGroup: 'BUSINESS_PRODUCTIVITY',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    targetCurrency: 'USD',
    plannedAmount: 100,
    plannedAmountZar: 1825,
    plannedAmountUsd: 100,
    actualSpentZar: 730,
    actualSpentUsd: 40,
    varianceZar: 1095,
    varianceUsd: 60,
    pctConsumed: 40.0,
    budgetStatus: 'ON_TRACK',
    isFixedObligation: true
  },
  {
    allocationMonth: '2026-09-01',
    categoryId: 'CAT_ALLOC_RENT',
    categoryName: 'Residential Rent & Levies',
    categoryGroup: 'LIVING_EXPENSES',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    targetCurrency: 'ZAR',
    plannedAmount: 14500,
    plannedAmountZar: 14500,
    plannedAmountUsd: 794.52,
    actualSpentZar: 14500,
    actualSpentUsd: 794.52,
    varianceZar: 0,
    varianceUsd: 0,
    pctConsumed: 100.0,
    budgetStatus: 'ON_TRACK',
    isFixedObligation: true
  },
  {
    allocationMonth: '2026-09-01',
    categoryId: 'CAT_ALLOC_INTERNET',
    categoryName: 'High-Speed Home Fibre',
    categoryGroup: 'LIVING_EXPENSES',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    targetCurrency: 'ZAR',
    plannedAmount: 999,
    plannedAmountZar: 999,
    plannedAmountUsd: 54.74,
    actualSpentZar: 999,
    actualSpentUsd: 54.74,
    varianceZar: 0,
    varianceUsd: 0,
    pctConsumed: 100.0,
    budgetStatus: 'ON_TRACK',
    isFixedObligation: true
  },
  {
    allocationMonth: '2026-09-01',
    categoryId: 'CAT_TAX_STATUTORY_PROVISIONAL',
    categoryName: 'Provisional & Statutory Tax Payments',
    categoryGroup: 'STATUTORY_OBLIGATIONS',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    targetCurrency: 'ZAR',
    plannedAmount: 12000,
    plannedAmountZar: 12000,
    plannedAmountUsd: 657.53,
    actualSpentZar: 12000,
    actualSpentUsd: 657.53,
    varianceZar: 0,
    varianceUsd: 0,
    pctConsumed: 100.0,
    budgetStatus: 'ON_TRACK',
    isFixedObligation: true
  }
];

export const INITIAL_TRANSACTIONS: Transaction[] = [
  {
    transactionId: 'TX_SEED_20260901_01',
    transactionTimestamp: '2026-09-01T08:00:00Z',
    transactionDate: '2026-09-01',
    localTimezone: 'Africa/Johannesburg',
    accountId: 'ACC_ZA_FNB_MONTHLY',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    categoryId: 'CAT_INC_SALARY',
    categoryName: 'Consulting & Employment Income',
    transactionType: 'INCOME',
    originalAmount: 55000,
    originalCurrency: 'ZAR',
    reportingAmountUsd: 3013.70,
    reportingAmountZar: 55000,
    appliedExchangeRateUsd: 0.054795,
    appliedExchangeRateZar: 1.0,
    rateTypeApplied: 'OFFICIAL_INTERBANK',
    merchantOrPayee: 'Enterprise Retainer Client',
    paymentMethod: 'EFT',
    isTaxDeductible: false,
    tags: ['income', 'retainer', 'zar'],
    isSynced: true
  },
  {
    transactionId: 'TX_SEED_20260901_02',
    transactionTimestamp: '2026-09-01T09:00:00Z',
    transactionDate: '2026-09-01',
    localTimezone: 'Africa/Johannesburg',
    accountId: 'ACC_ZA_FNB_MONTHLY',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    categoryId: 'CAT_ALLOC_RENT',
    categoryName: 'Residential Rent & Levies',
    transactionType: 'EXPENSE',
    originalAmount: -14500,
    originalCurrency: 'ZAR',
    reportingAmountUsd: -794.52,
    reportingAmountZar: -14500,
    appliedExchangeRateUsd: 0.054795,
    appliedExchangeRateZar: 1.0,
    rateTypeApplied: 'OFFICIAL_INTERBANK',
    merchantOrPayee: 'Property Management Co',
    paymentMethod: 'DIRECT_DEBIT',
    isTaxDeductible: false,
    tags: ['living-expenses', 'rent', 'zar'],
    isSynced: true
  },
  {
    transactionId: 'TX_SEED_20260901_03',
    transactionTimestamp: '2026-09-01T10:15:00Z',
    transactionDate: '2026-09-01',
    localTimezone: 'Africa/Johannesburg',
    accountId: 'ACC_ZA_FNB_MONTHLY',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    categoryId: 'CAT_ALLOC_INTERNET',
    categoryName: 'High-Speed Home Fibre',
    transactionType: 'EXPENSE',
    originalAmount: -999,
    originalCurrency: 'ZAR',
    reportingAmountUsd: -54.74,
    reportingAmountZar: -999,
    appliedExchangeRateUsd: 0.054795,
    appliedExchangeRateZar: 1.0,
    rateTypeApplied: 'OFFICIAL_INTERBANK',
    merchantOrPayee: 'Cool Ideas Fibre',
    paymentMethod: 'DIRECT_DEBIT',
    isTaxDeductible: true,
    taxDeductibleAmountZar: 999,
    taxDeductibleAmountUsd: 54.74,
    taxInvoiceNumber: 'INV-CI-2026-09',
    tags: ['home-office', 'tax-deductible', 'zar'],
    isSynced: true
  },
  {
    transactionId: 'TX_SEED_20260902_04',
    transactionTimestamp: '2026-09-02T11:30:00Z',
    transactionDate: '2026-09-02',
    localTimezone: 'Africa/Johannesburg',
    accountId: 'ACC_ZA_CAPITEC_DAILY',
    cashFlowTier: 'DAILY_SPENDING',
    categoryId: 'CAT_PROD_TECH_HARDWARE',
    categoryName: 'Productivity Tech & Work Hardware',
    transactionType: 'EXPENSE',
    originalAmount: -7500,
    originalCurrency: 'ZAR',
    reportingAmountUsd: -410.96,
    reportingAmountZar: -7500,
    appliedExchangeRateUsd: 0.054795,
    appliedExchangeRateZar: 1.0,
    rateTypeApplied: 'OFFICIAL_INTERBANK',
    merchantOrPayee: 'Incredible Connection / Dell ZA',
    paymentMethod: 'DEBIT_CARD',
    isTaxDeductible: true,
    taxDeductibleAmountZar: 7500,
    taxDeductibleAmountUsd: 410.96,
    taxInvoiceNumber: 'INV-DELL-9921',
    tags: ['hardware', 'work-equipment', 'tax-deductible'],
    isSynced: true
  },
  {
    transactionId: 'TX_SEED_20260902_05',
    transactionTimestamp: '2026-09-02T13:45:00Z',
    transactionDate: '2026-09-02',
    localTimezone: 'Africa/Harare',
    accountId: 'ACC_ZW_STANBIC_NOSTRO',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    categoryId: 'CAT_PROD_SOFTWARE_TOOLS',
    categoryName: 'Business Software, Cloud & AI Subscriptions',
    transactionType: 'EXPENSE',
    originalAmount: -40,
    originalCurrency: 'USD',
    reportingAmountUsd: -40,
    reportingAmountZar: -730,
    appliedExchangeRateUsd: 1.0,
    appliedExchangeRateZar: 18.25,
    rateTypeApplied: 'OFFICIAL_INTERBANK',
    merchantOrPayee: 'Anthropic / OpenAI Team',
    paymentMethod: 'DEBIT_CARD',
    isTaxDeductible: true,
    taxDeductibleAmountZar: 730,
    taxDeductibleAmountUsd: 40,
    taxInvoiceNumber: 'INV-ANTH-312',
    tags: ['software', 'ai-tooling', 'tax-deductible'],
    isSynced: true
  },
  {
    transactionId: 'TX_SEED_20260903_06',
    transactionTimestamp: '2026-09-03T10:00:00Z',
    transactionDate: '2026-09-03',
    localTimezone: 'Africa/Johannesburg',
    accountId: 'ACC_ZA_FNB_MONTHLY',
    cashFlowTier: 'MONTHLY_ALLOCATION',
    categoryId: 'CAT_TAX_STATUTORY_PROVISIONAL',
    categoryName: 'Provisional & Statutory Tax Payments',
    transactionType: 'EXPENSE',
    originalAmount: -12000,
    originalCurrency: 'ZAR',
    reportingAmountUsd: -657.53,
    reportingAmountZar: -12000,
    appliedExchangeRateUsd: 0.054795,
    appliedExchangeRateZar: 1.0,
    rateTypeApplied: 'OFFICIAL_INTERBANK',
    merchantOrPayee: 'South African Revenue Service (SARS)',
    paymentMethod: 'EFT',
    isTaxDeductible: false,
    taxInvoiceNumber: 'SARS-2026-IRP6-Q1',
    tags: ['tax-payment', 'sars', 'statutory'],
    isSynced: true
  },
  {
    transactionId: 'TX_SEED_20260904_07',
    transactionTimestamp: '2026-09-04T12:15:00Z',
    transactionDate: '2026-09-04',
    localTimezone: 'Africa/Harare',
    accountId: 'ACC_ZW_ECOCASH_ZIG',
    cashFlowTier: 'DAILY_SPENDING',
    categoryId: 'CAT_DAILY_AIRTIME',
    categoryName: 'Mobile Airtime & Bundles',
    transactionType: 'EXPENSE',
    originalAmount: -245,
    originalCurrency: 'ZiG',
    reportingAmountUsd: -10.00,
    reportingAmountZar: -182.50,
    appliedExchangeRateUsd: 0.040816,
    appliedExchangeRateZar: 0.744900,
    rateTypeApplied: 'MARKET_PARALLEL',
    merchantOrPayee: 'Econet Wireless SmartBiz',
    paymentMethod: 'MOBILE_MONEY_ECOCASH',
    isTaxDeductible: false,
    tags: ['daily-spending', 'zig', 'airtime'],
    isSynced: true
  }
];

export const INITIAL_TAX_SCHEDULE: TaxQuarterSchedule = {
  taxYear: 2026,
  taxQuarter: '2026-Q3',
  grossTaxableInflowZar: 55000,
  grossTaxableInflowUsd: 3013.70,
  productivityExpensesOffsetZar: 12730,
  totalAllowableDeductionsZar: 13729,
  totalAllowableDeductionsUsd: 752.27,
  netTaxableIncomeZar: 41271,
  netTaxableIncomeUsd: 2261.42,
  effectiveTaxRate: 0.2700,
  estimatedTaxLiabilityZar: 11143.17,
  actualTaxPaidZar: 12000,
  netTaxOutstandingZar: -856.83,
  taxSettlementStatus: 'SETTLED',
  taxDeductibleCount: 4
};

export const INITIAL_BURN_METRICS: PredictiveBurnMetrics = {
  liquidReserveBalanceZar: 201250, // Capitec (18.45k) + FNB (32.8k) + Discovery 32d (150k)
  averageDailyBurnZar: 1420,
  baselineRunwayDays: 141, // 201250 / 1420
  fixedObligationsRunwayDays: 245,
  survivalDate: '2027-01-23',
  discretionaryDailySpendZar: 620,
  monthlyFixedCommitmentsZar: 24000
};

export const INITIAL_TAX_SHIELD_OPPORTUNITIES: TaxShieldOpportunity[] = [
  {
    id: 'TS-01',
    title: 'Work Equipment Depreciation Write-Off',
    categoryName: 'Productivity Tech & Work Hardware',
    currentClaimedZar: 7500,
    targetThresholdZar: 12000,
    potentialDeductionZar: 4500,
    taxSavingsZar: 1215, // 27% of 4500
    recommendation: 'Purchasing planned secondary monitor or desk ergonomics before end of Q3 directly lowers net taxable income by R4,500.',
    urgency: 'HIGH'
  },
  {
    id: 'TS-02',
    title: 'Home Office Fibre Connectivity Allocation',
    categoryName: 'High-Speed Home Fibre',
    currentClaimedZar: 999,
    targetThresholdZar: 2997,
    potentialDeductionZar: 1998,
    taxSavingsZar: 539.46,
    recommendation: 'Ensure all upcoming 2 months of uncapped fibre invoices are flagged under HOME_OFFICE_DEDUCTION.',
    urgency: 'MEDIUM'
  },
  {
    id: 'TS-03',
    title: 'Developer AI & Cloud Tooling Subscriptions',
    categoryName: 'Business Software, Cloud & AI Subscriptions',
    currentClaimedZar: 730,
    targetThresholdZar: 3650,
    potentialDeductionZar: 2920,
    taxSavingsZar: 788.40,
    recommendation: 'Annual upfront payment of GitHub Copilot and Google Cloud compute qualifies for immediate operating expense write-off.',
    urgency: 'INFO'
  }
];

export const INITIAL_ARBITRAGE_SIGNALS: ArbitrageSignal[] = [
  {
    id: 'ARB-01',
    pair: 'USD / ZiG Domestic Clearing',
    officialRate: 13.85,
    parallelRate: 24.50,
    spreadPct: 76.9,
    recommendation: 'Vendors pricing goods in ZiG at the official RBZ benchmark (e.g. supermarkets/fuel) offer a 43.4% purchasing power discount when paying via EcoCash ZiG Swipe.',
    actionBadge: '⚡ Settle via ZiG Swipe',
    direction: 'ZIG_CARD_SWIPE'
  },
  {
    id: 'ARB-02',
    pair: 'USD Cash vs Nostro Digital',
    officialRate: 1.00,
    parallelRate: 1.05,
    spreadPct: 5.0,
    recommendation: 'Retailers offering 5-10% cash settlement discounts justify using physical USD petty cash over card payments.',
    actionBadge: '💵 Use USD Cash',
    direction: 'USD_CASH'
  },
  {
    id: 'ARB-03',
    pair: 'ZAR / USD Offshore Corridors',
    officialRate: 18.25,
    parallelRate: 18.25,
    spreadPct: 0.0,
    recommendation: 'ZAR is currently trading within favorable 1-standard-deviation band against USD. Ideal window to execute monthly S&P 500 ETF sweeps on EasyEquities.',
    actionBadge: '📈 Fund Offshore TFSA',
    direction: 'OFFSHORE_CONVERT'
  }
];

export const INITIAL_INVESTMENTS: InvestmentCounter[] = [
  // Victoria Falls Stock Exchange (VFEX)
  {
    symbol: 'PHL.VF',
    name: 'Padenga Holdings Limited',
    market: 'VFEX',
    nativeCurrency: 'USD',
    lastPrice: 0.22,
    change24h: 3.4,
    peRatio: 7.8,
    dividendYield: 4.8,
    sector: 'Agribusiness & Export',
    holdingUnits: 15000,
    holdingValueNative: 3300.00,
    geminiAdvisory: {
      macroInsight: 'Padenga maintains pure export USD cash flows from crocodile skins and mining operations, shielding balance sheet strength from domestic currency volatility in Zimbabwe.',
      defensiveScore: 'HIGH',
      disclaimer: 'Educational market analysis only. Not financial advice.'
    }
  },
  {
    symbol: 'SIM.VF',
    name: 'Simbisa Brands Limited',
    market: 'VFEX',
    nativeCurrency: 'USD',
    lastPrice: 0.38,
    change24h: -0.8,
    peRatio: 11.2,
    dividendYield: 3.9,
    sector: 'Quick Service Restaurants',
    holdingUnits: 8000,
    holdingValueNative: 3040.00,
    geminiAdvisory: {
      macroInsight: 'Simbisa has expanded regional footprint across Kenya, Ghana, and Zimbabwe. Benefits from rapid customer migration to USD cash transactions, reducing local credit default risks.',
      defensiveScore: 'MODERATE',
      disclaimer: 'Educational market analysis only. Not financial advice.'
    }
  },
  {
    symbol: 'CMCL.VF',
    name: 'Caledonia Mining Corporation',
    market: 'VFEX',
    nativeCurrency: 'USD',
    lastPrice: 14.50,
    change24h: 2.1,
    peRatio: 9.4,
    dividendYield: 4.2,
    sector: 'Gold Mining & Resources',
    holdingUnits: 450,
    holdingValueNative: 6525.00,
    geminiAdvisory: {
      macroInsight: 'Gold mining producer benefiting from historic high global bullion prices and direct USD royalty incentives on the VFEX tax-exempt platform.',
      defensiveScore: 'HIGH',
      disclaimer: 'Educational market analysis only. Not financial advice.'
    }
  },

  // Johannesburg Stock Exchange (JSE)
  {
    symbol: 'NPN',
    name: 'Naspers Ltd - N Shares',
    market: 'JSE',
    nativeCurrency: 'ZAR',
    lastPrice: 3845.00,
    change24h: 1.2,
    peRatio: 18.5,
    dividendYield: 0.4,
    sector: 'Technology & Global E-Commerce',
    holdingUnits: 35,
    holdingValueNative: 134575.00,
    geminiAdvisory: {
      macroInsight: 'Naspers acts as a liquid ZAR hedge against Rand depreciation due to Tencent and global consumer internet portfolio earnings.',
      defensiveScore: 'MODERATE',
      disclaimer: 'Educational market analysis only. Not financial advice.'
    }
  },
  {
    symbol: 'CPI',
    name: 'Capitec Bank Holdings',
    market: 'JSE',
    nativeCurrency: 'ZAR',
    lastPrice: 2780.00,
    change24h: 0.9,
    peRatio: 22.1,
    dividendYield: 2.3,
    sector: 'Retail Banking & Fintech',
    holdingUnits: 65,
    holdingValueNative: 180700.00,
    geminiAdvisory: {
      macroInsight: 'Market leader in South African low-cost digital banking. Consistent ROE > 25% with expanding value-added services (VAS) and business banking divisions.',
      defensiveScore: 'HIGH',
      disclaimer: 'Educational market analysis only. Not financial advice.'
    }
  },
  {
    symbol: 'STX500',
    name: 'Satrix S&P 500 Feeder ETF',
    market: 'JSE',
    nativeCurrency: 'ZAR',
    lastPrice: 114.50,
    change24h: 0.6,
    peRatio: 24.2,
    dividendYield: 1.1,
    sector: 'Global Index Equities',
    holdingUnits: 2500,
    holdingValueNative: 286250.00,
    geminiAdvisory: {
      macroInsight: 'Core wealth preservation instrument for South African investors. Automatically delivers dollarized compound returns inside a tax-free savings account (TFSA).',
      defensiveScore: 'HIGH',
      disclaimer: 'Educational market analysis only. Not financial advice.'
    }
  }
];

export const INITIAL_DEMO_DEBTS: DebtRecord[] = [
  {
    id: 'DEBT-DEMO-001',
    personName: 'Tendai Moyo',
    direction: 'owed_to_me',
    amount: 250,
    currency: 'USD',
    date: '2026-09-15',
    status: 'Pending',
    notes: 'Short-term bridge for hardware import duty',
    createdAt: '2026-09-15T10:00:00Z',
    updatedAt: '2026-09-15T10:00:00Z'
  },
  {
    id: 'DEBT-DEMO-002',
    personName: 'Lerato Khumalo',
    direction: 'owed_by_me',
    amount: 1500,
    currency: 'ZAR',
    date: '2026-09-28',
    status: 'Pending',
    notes: 'Coworking space group membership split',
    createdAt: '2026-09-28T14:30:00Z',
    updatedAt: '2026-09-28T14:30:00Z'
  },
  {
    id: 'DEBT-DEMO-003',
    personName: 'Farai Chitepo',
    direction: 'owed_to_me',
    amount: 100,
    currency: 'USD',
    date: '2026-08-10',
    status: 'Settled',
    notes: 'Starlink kit customs reimbursement',
    createdAt: '2026-08-10T09:00:00Z',
    updatedAt: '2026-08-25T16:00:00Z'
  }
];

export const INITIAL_DEMO_DEBT_BALANCES: DebtBalance[] = [
  {
    personName: 'Tendai Moyo',
    totalOwedToMe: 250,
    totalOwedByMe: 0,
    netBalance: 250,
    balanceDirection: 'they_owe_me'
  },
  {
    personName: 'Lerato Khumalo',
    totalOwedToMe: 0,
    totalOwedByMe: 1500,
    netBalance: -1500,
    balanceDirection: 'i_owe_them'
  }
];

export const INITIAL_DEMO_PERFORMANCE_SUMMARY: PerformanceSummary = {
  kpis: {
    savingsRatePct: 41.5,
    operatingMarginPct: 53.2,
    rolling7dAvgSpendZar: 1420,
    rolling7dAvgSpendUsd: 77.8,
    latestDailySpendZar: 1150,
    burnAlertStatus: 'NORMAL',
    burnVelocityRatio: 0.81,
    netCashSurplusZar: 23500,
    netCashSurplusUsd: 1287.67,
    grossOperatingRevenueZar: 56500,
    grossOperatingRevenueUsd: 3095.89,
    monthlyProjectedGainZar: 3200,
    monthlyProjectedGainUsd: 175.34
  },
  spendHabits: [
    {
      categoryGroup: 'LIVING_ESSENTIALS',
      categoryName: 'Groceries & Household Sustenance',
      transactionCount: 14,
      totalSpentZar: 8500,
      totalSpentUsd: 465.75,
      pctOfTotalSpend: 25.7
    },
    {
      categoryGroup: 'OPERATIONAL_EXPENSE',
      categoryName: 'Productivity Tech & Work Hardware',
      transactionCount: 6,
      totalSpentZar: 11200,
      totalSpentUsd: 613.70,
      pctOfTotalSpend: 33.9
    },
    {
      categoryGroup: 'DISCRETIONARY',
      categoryName: 'Dining & Specialty Coffee',
      transactionCount: 18,
      totalSpentZar: 4200,
      totalSpentUsd: 230.14,
      pctOfTotalSpend: 12.7
    }
  ],
  monthlyTrends: [
    {
      statementPeriod: '2026-07',
      periodStartDate: '2026-07-01',
      operatingRevenueZar: 52000,
      operatingRevenueUsd: 2849.32,
      totalOutflowsZar: 31000,
      netSurplusZar: 21000,
      netSurplusUsd: 1150.68,
      savingsRatePct: 40.4,
      operatingMarginPct: 51.5
    },
    {
      statementPeriod: '2026-08',
      periodStartDate: '2026-08-01',
      operatingRevenueZar: 54500,
      operatingRevenueUsd: 2986.30,
      totalOutflowsZar: 32200,
      netSurplusZar: 22300,
      netSurplusUsd: 1221.92,
      savingsRatePct: 40.9,
      operatingMarginPct: 52.1
    },
    {
      statementPeriod: '2026-09',
      periodStartDate: '2026-09-01',
      operatingRevenueZar: 56500,
      operatingRevenueUsd: 3095.89,
      totalOutflowsZar: 33000,
      netSurplusZar: 23500,
      netSurplusUsd: 1287.67,
      savingsRatePct: 41.5,
      operatingMarginPct: 53.2
    }
  ],
  statements: [],
  nonOperatingGains: []
};
