/**
 * finance.ts - TypeScript Data Models for Ziva Finance
 * Mirrors Google BigQuery DDLs, analytical views, and Wealth Management schemas.
 */

export type CurrencyCode = 'ZAR' | 'USD' | 'ZiG';
export type MasterCurrency = 'ZAR' | 'USD' | 'ZiG';

export type CashFlowTier = 'DAILY_SPENDING' | 'MONTHLY_ALLOCATION' | 'LONG_TERM_VAULT';

export interface ExchangeRates {
  USD_TO_ZAR: number;
  ZAR_TO_USD: number;
  USD_TO_ZIG_OFFICIAL: number;
  ZIG_TO_USD_OFFICIAL: number;
  USD_TO_ZIG_PARALLEL: number;
  ZIG_TO_USD_PARALLEL: number;
  ZAR_TO_ZIG_OFFICIAL: number;
  ZAR_TO_ZIG_PARALLEL: number;
  lastUpdated: string;
}

export interface Account {
  accountId: string;
  accountName: string;
  financialInstitution: string;
  countryCode: 'ZA' | 'ZW';
  primaryCurrency: CurrencyCode;
  cashFlowTier: CashFlowTier;
  accountType: 'CHECKING' | 'SAVINGS' | 'MOBILE_MONEY' | 'INVESTMENT_BROKER' | 'PHYSICAL_CASH';
  isVaultLocked: boolean;
  withdrawalNoticeDays: number;
  accountNumberMasked: string;
  nativeBalance: number;
  isActive: boolean;
}

export interface Category {
  categoryId: string;
  categoryName: string;
  parentCategoryId: string | null;
  categoryGroup: 'INCOME' | 'LIVING_EXPENSES' | 'BUSINESS_PRODUCTIVITY' | 'DEBT_OBLIGATIONS' | 'STATUTORY_OBLIGATIONS' | 'DISCRETIONARY' | 'VAULT_INVESTMENTS' | 'INTERNAL_TRANSFERS';
  cashFlowTier: CashFlowTier;
  isEssentialNeed: boolean;
  isTaxDeductible: boolean;
  taxLineItem?: string;
  description?: string;
}

export interface Transaction {
  transactionId: string;
  transactionTimestamp: string;
  transactionDate: string;
  localTimezone: string;
  accountId: string;
  cashFlowTier: CashFlowTier;
  categoryId: string;
  categoryName?: string;
  transactionType: 'EXPENSE' | 'INCOME' | 'INTERNAL_TRANSFER' | 'ALLOCATION_TRANSFER' | 'VAULT_CONTRIBUTION' | 'VAULT_WITHDRAWAL';
  originalAmount: number; // Signed: negative for expenses
  originalCurrency: CurrencyCode;
  reportingAmountUsd: number;
  reportingAmountZar: number;
  appliedExchangeRateUsd: number;
  appliedExchangeRateZar: number;
  rateTypeApplied: 'OFFICIAL_INTERBANK' | 'MARKET_PARALLEL' | 'FIXED_BASE';
  merchantOrPayee: string;
  paymentMethod: string;
  isTaxDeductible: boolean;
  taxDeductibleAmountZar?: number;
  taxDeductibleAmountUsd?: number;
  taxInvoiceNumber?: string;
  receiptImageUrl?: string;
  notes?: string;
  tags: string[];
  isSynced?: boolean;
}

export interface BudgetEnvelope {
  allocationMonth: string;
  categoryId: string;
  categoryName: string;
  categoryGroup: string;
  cashFlowTier: CashFlowTier;
  targetCurrency: CurrencyCode;
  plannedAmount: number;
  plannedAmountZar: number;
  plannedAmountUsd: number;
  actualSpentZar: number;
  actualSpentUsd: number;
  varianceZar: number;
  varianceUsd: number;
  pctConsumed: number;
  budgetStatus: 'ON_TRACK' | 'NEAR_LIMIT' | 'OVER_BUDGET';
  isFixedObligation: boolean;
}

export interface TaxQuarterSchedule {
  taxYear: number;
  taxQuarter: string;
  grossTaxableInflowZar: number;
  grossTaxableInflowUsd: number;
  productivityExpensesOffsetZar: number;
  totalAllowableDeductionsZar: number;
  totalAllowableDeductionsUsd: number;
  netTaxableIncomeZar: number;
  netTaxableIncomeUsd: number;
  effectiveTaxRate: number; // e.g. 0.27
  estimatedTaxLiabilityZar: number;
  actualTaxPaidZar: number;
  netTaxOutstandingZar: number;
  taxSettlementStatus: 'SETTLED' | 'PAYMENT_PENDING' | 'CREDIT_SURPLUS' | 'NO_TAX_LIABILITY';
  taxDeductibleCount: number;
}

export interface PredictiveBurnMetrics {
  liquidReserveBalanceZar: number;
  averageDailyBurnZar: number;
  baselineRunwayDays: number;
  fixedObligationsRunwayDays: number;
  survivalDate: string;
  discretionaryDailySpendZar: number;
  monthlyFixedCommitmentsZar: number;
}

export interface TaxShieldOpportunity {
  id: string;
  title: string;
  categoryName: string;
  currentClaimedZar: number;
  targetThresholdZar: number;
  potentialDeductionZar: number;
  taxSavingsZar: number; // 27% of potential deduction
  recommendation: string;
  urgency: 'HIGH' | 'MEDIUM' | 'INFO';
}

export interface ArbitrageSignal {
  id: string;
  pair: string;
  officialRate: number;
  parallelRate: number;
  spreadPct: number;
  recommendation: string;
  actionBadge: string;
  direction: 'ZIG_CARD_SWIPE' | 'USD_CASH' | 'OFFSHORE_CONVERT';
}

export interface InvestmentCounter {
  symbol: string;
  name: string;
  market: 'VFEX' | 'JSE';
  nativeCurrency: CurrencyCode;
  lastPrice: number;
  change24h: number;
  peRatio?: number;
  dividendYield?: number;
  sector: string;
  holdingUnits: number;
  holdingValueNative: number;
  geminiAdvisory: {
    macroInsight: string;
    defensiveScore: 'HIGH' | 'MODERATE' | 'SPECULATIVE';
    disclaimer: string;
  };
}

export interface IncomeStatementPeriod {
  periodType: 'MONTH' | 'QUARTER';
  statementPeriod: string; // e.g. '2026-09' or '2026-Q3'
  periodStartDate: string;
  periodEndDate: string;
  grossOperatingRevenueZar: number;
  operatingExpensesZar: number;
  netOperatingIncomeZar: number;
  operatingMarginPct: number;
  livingEssentialsZar: number;
  discretionaryExpensesZar: number;
  statutoryAndDebtZar: number;
  totalComprehensiveOutflowsZar: number;
  netCashSurplusZar: number;
  savingsRatePct: number;
  vaultContributionsZar: number;
  grossOperatingRevenueUsd: number;
  operatingExpensesUsd: number;
  netOperatingIncomeUsd: number;
  livingEssentialsUsd: number;
  discretionaryExpensesUsd: number;
  statutoryAndDebtUsd: number;
  netCashSurplusUsd: number;
  vaultContributionsUsd: number;
}

export interface NonOperatingGainRecord {
  accountId: string;
  accountName: string;
  financialInstitution: string;
  countryCode: string;
  primaryCurrency: CurrencyCode;
  accountType: string;
  withdrawalNoticeDays: number;
  currentVaultBalanceNative: number;
  currentVaultBalanceZar: number;
  currentVaultBalanceUsd: number;
  gainClassification: string;
  annualizedYieldPct: number;
  monthlyProjectedGainZar: number;
  monthlyProjectedGainUsd: number;
}

export interface SpendHabitBreakdown {
  categoryGroup: string;
  categoryName: string;
  iconName?: string;
  transactionCount: number;
  totalSpentZar: number;
  totalSpentUsd: number;
  pctOfTotalSpend: number;
}

export interface MonthlyTrendData {
  statementPeriod: string;
  periodStartDate: string;
  operatingRevenueZar: number;
  operatingRevenueUsd: number;
  totalOutflowsZar: number;
  netSurplusZar: number;
  netSurplusUsd: number;
  savingsRatePct: number;
  operatingMarginPct: number;
}

export interface PerformanceKPIs {
  savingsRatePct: number;
  operatingMarginPct: number;
  rolling7dAvgSpendZar: number;
  rolling7dAvgSpendUsd: number;
  latestDailySpendZar: number;
  burnAlertStatus: 'NORMAL' | 'ELEVATED' | 'CRITICAL';
  burnVelocityRatio: number;
  netCashSurplusZar: number;
  netCashSurplusUsd: number;
  grossOperatingRevenueZar: number;
  grossOperatingRevenueUsd: number;
  monthlyProjectedGainZar: number;
  monthlyProjectedGainUsd: number;
}

export interface PerformanceSummary {
  kpis: PerformanceKPIs;
  spendHabits: SpendHabitBreakdown[];
  monthlyTrends: MonthlyTrendData[];
  statements: IncomeStatementPeriod[];
  nonOperatingGains: NonOperatingGainRecord[];
}

export type DebtDirection = 'owed_to_me' | 'owed_by_me';
export type DebtStatus = 'Pending' | 'Settled';

export interface DebtRecord {
  id: string;
  personName: string;
  direction: DebtDirection;
  amount: number;
  currency: string;
  date: string;
  status: DebtStatus;
  notes: string;
  createdAt: string;
  updatedAt: string;
}

export interface DebtBalance {
  personName: string;
  totalOwedToMe: number;
  totalOwedByMe: number;
  netBalance: number;
  balanceDirection: 'they_owe_me' | 'i_owe_them' | 'settled_or_zero';
}


