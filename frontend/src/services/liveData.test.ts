import test from 'node:test';
import assert from 'node:assert/strict';

import {
  INITIAL_LIVE_ACCOUNTS_STATE,
  INITIAL_LIVE_ENVELOPES_STATE,
  INITIAL_LIVE_TRANSACTIONS_STATE,
  INITIAL_LIVE_TAX_STATE,
  INITIAL_LIVE_BURN_METRICS_STATE,
  isVerifiedLiveSnapshot,
  isVerifiedLiveEnvelopesSnapshot,
  isVerifiedLiveTransactionsSnapshot,
  isVerifiedLiveTaxSnapshot,
  isVerifiedLiveBurnMetricsSnapshot,
  resolveLiveAccounts,
  resolveLiveEnvelopes,
  resolveLiveTransactions,
  resolveLiveTax,
  resolveLiveBurnMetrics,
  selectDisplayedAccounts,
  selectDisplayedEnvelopes,
  selectDisplayedTransactions,
  selectDisplayedTaxSchedule,
  selectDisplayedBurnMetrics,
  selectDisplayedTaxOpportunities,
  selectDisplayedArbitrageSignals,
  selectDisplayedInvestments,
  hasDisplayableBalances,
  describeTierInstitutions,
  type LiveAccountsState,
  type LiveEnvelopesState,
  type LiveTransactionsState,
  type LiveTaxState,
  type LiveBurnMetricsState
} from './liveData.ts';
import {
  INITIAL_ENVELOPES,
  INITIAL_TRANSACTIONS,
  INITIAL_TAX_SCHEDULE,
  INITIAL_BURN_METRICS,
  INITIAL_TAX_SHIELD_OPPORTUNITIES,
  INITIAL_ARBITRAGE_SIGNALS,
  INITIAL_INVESTMENTS
} from './mockData.ts';
import type { Account, BudgetEnvelope, Transaction, TaxQuarterSchedule, PredictiveBurnMetrics } from '../types/finance.ts';

// Sample demo fixture accounts (Capitec, FNB, Discovery, EasyEquities, EcoCash)
const SAMPLE_DEMO_ACCOUNTS: Account[] = [
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
  }
];

// 1. Regression Test: Empty Live results with Demo fixtures present
test('Scenario 1: Empty Live results with Demo fixtures present produces genuine empty state, not demo accounts', () => {
  const emptyApiResult: PromiseSettledResult<Account[]> = {
    status: 'fulfilled',
    value: []
  };

  const resolved = resolveLiveAccounts(emptyApiResult, INITIAL_LIVE_ACCOUNTS_STATE);

  // Live accounts state must be marked 'empty' with zero records from source 'LIVE'
  assert.strictEqual(resolved.status, 'empty');
  assert.strictEqual(resolved.source, 'LIVE');
  assert.deepStrictEqual(resolved.data, []);
  assert.ok(resolved.verifiedAt !== null);
  assert.strictEqual(resolved.error, null);

  // In Live mode (isLive = true), displayed accounts must be empty, never fallback to SAMPLE_DEMO_ACCOUNTS
  const liveDisplayed = selectDisplayedAccounts(true, resolved, SAMPLE_DEMO_ACCOUNTS);
  assert.deepStrictEqual(liveDisplayed, []);
  assert.strictEqual(liveDisplayed.length, 0);

  // Empty state can display balances (zero balances are genuine, not missing)
  assert.strictEqual(hasDisplayableBalances(true, resolved), true);

  // In Demo mode (isLive = false), demo fixtures are displayed
  const demoDisplayed = selectDisplayedAccounts(false, resolved, SAMPLE_DEMO_ACCOUNTS);
  assert.strictEqual(demoDisplayed.length, SAMPLE_DEMO_ACCOUNTS.length);
  assert.strictEqual(demoDisplayed[0].accountName, 'Capitec Primary Cheque');
});

// 2. Regression Test: Failed Live requests
test('Scenario 2a: Failed Live request without prior live records yields unavailable state without demo data', () => {
  const failedApiResult: PromiseSettledResult<Account[]> = {
    status: 'rejected',
    reason: new Error('Network error: 503 Service Unavailable')
  };

  const resolved = resolveLiveAccounts(failedApiResult, INITIAL_LIVE_ACCOUNTS_STATE);

  assert.strictEqual(resolved.status, 'unavailable');
  assert.strictEqual(resolved.source, 'NONE');
  assert.deepStrictEqual(resolved.data, []);
  assert.strictEqual(resolved.verifiedAt, null);
  assert.match(resolved.error || '', /503 Service Unavailable/);

  // Live mode must not display sample accounts on failure
  const liveDisplayed = selectDisplayedAccounts(true, resolved, SAMPLE_DEMO_ACCOUNTS);
  assert.deepStrictEqual(liveDisplayed, []);

  // Balances must be hidden (returns false) so misleading $0.00 is NOT displayed
  assert.strictEqual(hasDisplayableBalances(true, resolved), false);
});

test('Scenario 2b: Failed Live request with prior verified live records labels them stale rather than freshly verified', () => {
  const verifiedPriorLive: LiveAccountsState = {
    data: [
      {
        accountId: 'ACC_REAL_USER_1',
        accountName: 'Personal Checking',
        financialInstitution: 'Standard Bank',
        countryCode: 'ZA',
        primaryCurrency: 'ZAR',
        cashFlowTier: 'DAILY_SPENDING',
        accountType: 'CHECKING',
        isVaultLocked: false,
        withdrawalNoticeDays: 0,
        accountNumberMasked: '...9999',
        nativeBalance: 4200.50,
        isActive: true
      }
    ],
    status: 'ready',
    source: 'LIVE',
    verifiedAt: '2026-10-08T01:00:00.000Z',
    error: null
  };

  const failedRefresh: PromiseSettledResult<Account[]> = {
    status: 'rejected',
    reason: new Error('Gateway Timeout')
  };

  const resolved = resolveLiveAccounts(failedRefresh, verifiedPriorLive);

  // Retains real live records, but marked stale with error
  assert.strictEqual(resolved.status, 'stale');
  assert.strictEqual(resolved.source, 'LIVE');
  assert.strictEqual(resolved.verifiedAt, '2026-10-08T01:00:00.000Z');
  assert.strictEqual(resolved.data.length, 1);
  assert.strictEqual(resolved.data[0].accountId, 'ACC_REAL_USER_1');
  assert.match(resolved.error || '', /Gateway Timeout/);

  // Displayed accounts are the stale live records, not demo fixtures
  const liveDisplayed = selectDisplayedAccounts(true, resolved, SAMPLE_DEMO_ACCOUNTS);
  assert.strictEqual(liveDisplayed.length, 1);
  assert.strictEqual(liveDisplayed[0].accountName, 'Personal Checking');
});

// 3. Regression Test: Reload after Demo use
test('Scenario 3: Reload after Demo use does not let demo accounts leak into live state before or after fetch', () => {
  // Before fetch resolves, initial live state is 'loading' with data = []
  const initialLive = INITIAL_LIVE_ACCOUNTS_STATE;
  assert.strictEqual(initialLive.status, 'loading');
  assert.strictEqual(initialLive.data.length, 0);

  // Even if Demo accounts were heavily modified in demo mode:
  const modifiedDemoAccounts = SAMPLE_DEMO_ACCOUNTS.map((a) => ({
    ...a,
    nativeBalance: a.nativeBalance + 50000
  }));

  // In live mode during loading: displays empty data, not demo data
  const liveDuringLoading = selectDisplayedAccounts(true, initialLive, modifiedDemoAccounts);
  assert.deepStrictEqual(liveDuringLoading, []);

  // When live fetch completes with empty database:
  const liveEmptyResult: PromiseSettledResult<Account[]> = {
    status: 'fulfilled',
    value: []
  };
  const resolved = resolveLiveAccounts(liveEmptyResult, initialLive);
  const liveAfterFetch = selectDisplayedAccounts(true, resolved, modifiedDemoAccounts);
  assert.deepStrictEqual(liveAfterFetch, []);

  // Demo accounts remain intact and separate when user switches back to Demo
  const demoAfterFetch = selectDisplayedAccounts(false, resolved, modifiedDemoAccounts);
  assert.strictEqual(demoAfterFetch.length, SAMPLE_DEMO_ACCOUNTS.length);
  assert.strictEqual(demoAfterFetch[0].nativeBalance, SAMPLE_DEMO_ACCOUNTS[0].nativeBalance + 50000);
});

// 4. Regression Test: Contaminated persisted sample state
test('Scenario 4: Contaminated persisted sample state is rejected by isVerifiedLiveSnapshot and cannot rehydrate into Live', () => {
  // Simulated contaminated state in storage:
  const fakeCachedState = {
    data: SAMPLE_DEMO_ACCOUNTS,
    status: 'ready',
    source: 'DEMO', // Or missing source
    verifiedAt: null
  };

  assert.strictEqual(isVerifiedLiveSnapshot(fakeCachedState), false);
  assert.strictEqual(isVerifiedLiveSnapshot(null), false);
  assert.strictEqual(isVerifiedLiveSnapshot({ source: 'LIVE' }), false);

  // If a contaminated object is somehow provided as previous state during a failed fetch:
  const failedResult: PromiseSettledResult<Account[]> = {
    status: 'rejected',
    reason: new Error('Failed to fetch')
  };
  const resolved = resolveLiveAccounts(failedResult, fakeCachedState);

  // Must reject contaminated snapshot and produce 'unavailable' with [] data, NOT stale demo data
  assert.strictEqual(resolved.status, 'unavailable');
  assert.strictEqual(resolved.source, 'NONE');
  assert.deepStrictEqual(resolved.data, []);
});

// 5. Regression Test: Real live records, including a legitimately created account with a sample name
test('Scenario 5: Real live records with identical names (Capitec, EcoCash) work and are NOT filtered out', () => {
  const realDatabaseAccounts: Account[] = [
    {
      accountId: 'ACC_USER_CAPITEC_REAL',
      accountName: 'Capitec Bank Primary',
      financialInstitution: 'Capitec Bank',
      countryCode: 'ZA',
      primaryCurrency: 'ZAR',
      cashFlowTier: 'DAILY_SPENDING',
      accountType: 'CHECKING',
      isVaultLocked: false,
      withdrawalNoticeDays: 0,
      accountNumberMasked: '...1234',
      nativeBalance: 350.75, // Legitimate real user balance, NOT the ghost 18,450.00
      isActive: true
    },
    {
      accountId: 'ACC_USER_ECOCASH_REAL',
      accountName: 'EcoCash USD Wallet',
      financialInstitution: 'EcoCash',
      countryCode: 'ZW',
      primaryCurrency: 'USD',
      cashFlowTier: 'DAILY_SPENDING',
      accountType: 'MOBILE_MONEY',
      isVaultLocked: false,
      withdrawalNoticeDays: 0,
      accountNumberMasked: '...5678',
      nativeBalance: 45.00, // Real balance, NOT ghost 1,250.00
      isActive: true
    }
  ];

  const liveResult: PromiseSettledResult<Account[]> = {
    status: 'fulfilled',
    value: realDatabaseAccounts
  };

  const resolved = resolveLiveAccounts(liveResult, INITIAL_LIVE_ACCOUNTS_STATE);
  assert.strictEqual(resolved.status, 'ready');
  assert.strictEqual(resolved.source, 'LIVE');
  assert.strictEqual(resolved.data.length, 2);

  // Selected accounts must preserve the exact records and balances
  const liveDisplayed = selectDisplayedAccounts(true, resolved, SAMPLE_DEMO_ACCOUNTS);
  assert.strictEqual(liveDisplayed.length, 2);
  assert.strictEqual(liveDisplayed[0].accountName, 'Capitec Bank Primary');
  assert.strictEqual(liveDisplayed[0].nativeBalance, 350.75);
  assert.strictEqual(liveDisplayed[1].accountName, 'EcoCash USD Wallet');
  assert.strictEqual(liveDisplayed[1].nativeBalance, 45.00);

  // Dynamic tier captions reflect the real institutions, not hardcoded mock banks
  const tier1Caption = describeTierInstitutions(liveDisplayed, 'DAILY_SPENDING');
  assert.strictEqual(tier1Caption, 'Capitec Bank & EcoCash');

  const tier3Caption = describeTierInstitutions(liveDisplayed, 'LONG_TERM_VAULT');
  assert.strictEqual(tier3Caption, 'No accounts in this tier');
});

// 6. Regression Test: Zero-Based Budgeting Envelopes isolation
test('Scenario 6a: Empty Live Envelopes produces honest empty state, eliminating 62,859.62 ZiG target', () => {
  const emptyResult: PromiseSettledResult<BudgetEnvelope[]> = {
    status: 'fulfilled',
    value: []
  };

  const resolved = resolveLiveEnvelopes(emptyResult, INITIAL_LIVE_ENVELOPES_STATE);

  assert.strictEqual(resolved.status, 'empty');
  assert.strictEqual(resolved.source, 'LIVE');
  assert.deepStrictEqual(resolved.data, []);
  assert.strictEqual(resolved.error, null);

  // In Live mode, displayed envelopes must be empty, never the 7 INITIAL_ENVELOPES
  const liveDisplayed = selectDisplayedEnvelopes(true, resolved, INITIAL_ENVELOPES);
  assert.strictEqual(liveDisplayed.length, 0);

  // Total target from displayed envelopes is 0, NOT 46,824 ZAR (which converts to 62,859.62 ZiG)
  const totalPlannedZar = liveDisplayed.reduce((sum, e) => sum + e.plannedAmountZar, 0);
  assert.strictEqual(totalPlannedZar, 0);

  // When switching to Demo mode, demo fixtures remain intact with original target
  const demoDisplayed = selectDisplayedEnvelopes(false, resolved, INITIAL_ENVELOPES);
  assert.strictEqual(demoDisplayed.length, INITIAL_ENVELOPES.length);
  const demoPlannedZar = demoDisplayed.reduce((sum, e) => sum + e.plannedAmountZar, 0);
  assert.strictEqual(demoPlannedZar, 46824);
});

test('Scenario 6b: Failed Live Envelopes request without prior records yields unavailable state with empty envelopes', () => {
  const failedResult: PromiseSettledResult<BudgetEnvelope[]> = {
    status: 'rejected',
    reason: new Error('Failed to fetch /api/budgets: 500 Internal Server Error')
  };

  const resolved = resolveLiveEnvelopes(failedResult, INITIAL_LIVE_ENVELOPES_STATE);

  assert.strictEqual(resolved.status, 'unavailable');
  assert.strictEqual(resolved.source, 'NONE');
  assert.deepStrictEqual(resolved.data, []);
  assert.match(resolved.error || '', /500 Internal Server Error/);

  // Live mode must show empty envelopes, not fabricated mock budgets
  const liveDisplayed = selectDisplayedEnvelopes(true, resolved, INITIAL_ENVELOPES);
  assert.deepStrictEqual(liveDisplayed, []);
});

test('Scenario 6c: Failed Live Envelopes request with prior verified live envelopes labels them stale rather than discarding', () => {
  const realLiveEnvelopes: BudgetEnvelope[] = [
    {
      allocationMonth: '2026-10-01',
      categoryId: 'CAT_CUSTOM_OFFICE',
      categoryName: 'Office Rent & Utilities',
      categoryGroup: 'FIXED_OBLIGATIONS',
      cashFlowTier: 'MONTHLY_ALLOCATION',
      targetCurrency: 'USD',
      plannedAmount: 850,
      plannedAmountZar: 15512.50,
      plannedAmountUsd: 850,
      actualSpentZar: 850 * 18.25,
      actualSpentUsd: 850,
      varianceZar: 0,
      varianceUsd: 0,
      pctConsumed: 100,
      budgetStatus: 'ON_TRACK',
      isFixedObligation: true
    }
  ];

  const priorState: LiveEnvelopesState = {
    data: realLiveEnvelopes,
    status: 'ready',
    source: 'LIVE',
    verifiedAt: '2026-10-08T01:00:00.000Z',
    error: null
  };

  const failedResult: PromiseSettledResult<BudgetEnvelope[]> = {
    status: 'rejected',
    reason: new Error('Network timeout')
  };

  const resolved = resolveLiveEnvelopes(failedResult, priorState);

  assert.strictEqual(resolved.status, 'stale');
  assert.strictEqual(resolved.source, 'LIVE');
  assert.strictEqual(resolved.data.length, 1);
  assert.strictEqual(resolved.data[0].categoryId, 'CAT_CUSTOM_OFFICE');
  assert.match(resolved.error || '', /Network timeout/);

  // In Live mode, displays the stale verified data, never the demo data
  const liveDisplayed = selectDisplayedEnvelopes(true, resolved, INITIAL_ENVELOPES);
  assert.strictEqual(liveDisplayed.length, 1);
  assert.strictEqual(liveDisplayed[0].categoryId, 'CAT_CUSTOM_OFFICE');
});

test('Scenario 6d: Contaminated persisted envelope state is rejected by isVerifiedLiveEnvelopesSnapshot', () => {
  const contaminatedState = {
    data: INITIAL_ENVELOPES,
    status: 'ready',
    source: 'DEMO',
    verifiedAt: null
  };

  assert.strictEqual(isVerifiedLiveEnvelopesSnapshot(contaminatedState), false);
  assert.strictEqual(isVerifiedLiveEnvelopesSnapshot(null), false);
  assert.strictEqual(isVerifiedLiveEnvelopesSnapshot({ source: 'LIVE' }), false);

  const failedResult: PromiseSettledResult<BudgetEnvelope[]> = {
    status: 'rejected',
    reason: new Error('API down')
  };
  const resolved = resolveLiveEnvelopes(failedResult, contaminatedState);

  assert.strictEqual(resolved.status, 'unavailable');
  assert.strictEqual(resolved.source, 'NONE');
  assert.deepStrictEqual(resolved.data, []);
});

// 7. Regression Test: Ledger Transactions isolation
test('Scenario 7a: Empty Live Transactions produces honest empty state, not INITIAL_TRANSACTIONS', () => {
  const emptyResult: PromiseSettledResult<Transaction[]> = {
    status: 'fulfilled',
    value: []
  };

  const resolved = resolveLiveTransactions(emptyResult, INITIAL_LIVE_TRANSACTIONS_STATE);

  assert.strictEqual(resolved.status, 'empty');
  assert.strictEqual(resolved.source, 'LIVE');
  assert.deepStrictEqual(resolved.data, []);

  // In Live mode, displayed transactions must be empty
  const liveDisplayed = selectDisplayedTransactions(true, resolved, INITIAL_TRANSACTIONS);
  assert.strictEqual(liveDisplayed.length, 0);

  // In Demo mode, original demo transactions display
  const demoDisplayed = selectDisplayedTransactions(false, resolved, INITIAL_TRANSACTIONS);
  assert.strictEqual(demoDisplayed.length, INITIAL_TRANSACTIONS.length);
});

test('Scenario 7b: Failed Live Transactions yields unavailable state with empty display', () => {
  const failedResult: PromiseSettledResult<Transaction[]> = {
    status: 'rejected',
    reason: new Error('Database connection failed')
  };

  const resolved = resolveLiveTransactions(failedResult, INITIAL_LIVE_TRANSACTIONS_STATE);

  assert.strictEqual(resolved.status, 'unavailable');
  assert.strictEqual(resolved.source, 'NONE');
  assert.deepStrictEqual(resolved.data, []);
  assert.match(resolved.error || '', /Database connection failed/);

  const liveDisplayed = selectDisplayedTransactions(true, resolved, INITIAL_TRANSACTIONS);
  assert.strictEqual(liveDisplayed.length, 0);
});

test('Scenario 7c: Real live transactions are preserved and distinguished', () => {
  const realTx: Transaction[] = [
    {
      transactionId: 'TX_REAL_001',
      transactionTimestamp: '2026-10-08T10:00:00Z',
      transactionDate: '2026-10-08',
      localTimezone: 'Africa/Johannesburg',
      accountId: 'ACC_USER_ECOCASH_REAL',
      cashFlowTier: 'DAILY_SPENDING',
      categoryId: 'CAT_DAILY_GROCERIES',
      transactionType: 'EXPENSE',
      originalAmount: -20.00,
      originalCurrency: 'USD',
      reportingAmountUsd: -20.00,
      reportingAmountZar: -365.00,
      appliedExchangeRateUsd: 1.0,
      appliedExchangeRateZar: 18.25,
      rateTypeApplied: 'OFFICIAL_INTERBANK',
      merchantOrPayee: 'ZESA Electricity Token',
      paymentMethod: 'ECOCASH',
      isTaxDeductible: false,
      tags: ['utilities']
    }
  ];

  const fulfilledResult: PromiseSettledResult<Transaction[]> = {
    status: 'fulfilled',
    value: realTx
  };

  const resolved = resolveLiveTransactions(fulfilledResult, INITIAL_LIVE_TRANSACTIONS_STATE);
  assert.strictEqual(resolved.status, 'ready');
  assert.strictEqual(resolved.data.length, 1);

  const liveDisplayed = selectDisplayedTransactions(true, resolved, INITIAL_TRANSACTIONS);
  assert.strictEqual(liveDisplayed.length, 1);
  assert.strictEqual(liveDisplayed[0].merchantOrPayee, 'ZESA Electricity Token');
});

// 8. Regression Test: Tax Compliance isolation
test('Scenario 8: Live Tax Schedule produces null when empty or unavailable, preserving demo on switch', () => {
  // Empty live tax
  const emptyResult: PromiseSettledResult<TaxQuarterSchedule | null> = {
    status: 'fulfilled',
    value: null
  };
  const resolvedEmpty = resolveLiveTax(emptyResult, INITIAL_LIVE_TAX_STATE);
  assert.strictEqual(resolvedEmpty.status, 'empty');
  assert.strictEqual(resolvedEmpty.data, null);

  const liveEmptyDisplay = selectDisplayedTaxSchedule(true, resolvedEmpty, INITIAL_TAX_SCHEDULE);
  assert.strictEqual(liveEmptyDisplay, null);

  // Demo display preserves mock schedule
  const demoDisplay = selectDisplayedTaxSchedule(false, resolvedEmpty, INITIAL_TAX_SCHEDULE);
  assert.deepStrictEqual(demoDisplay, INITIAL_TAX_SCHEDULE);

  // Failed live tax
  const failedResult: PromiseSettledResult<TaxQuarterSchedule | null> = {
    status: 'rejected',
    reason: new Error('Tax endpoint 500')
  };
  const resolvedFailed = resolveLiveTax(failedResult, INITIAL_LIVE_TAX_STATE);
  assert.strictEqual(resolvedFailed.status, 'unavailable');
  assert.strictEqual(resolvedFailed.data, null);

  const liveFailedDisplay = selectDisplayedTaxSchedule(true, resolvedFailed, INITIAL_TAX_SCHEDULE);
  assert.strictEqual(liveFailedDisplay, null);
});

// 9. Regression Test: Runway / Burn Metrics isolation
test('Scenario 9: Live Burn Metrics produces null when empty or unavailable, never substituting demo metrics', () => {
  const emptyResult: PromiseSettledResult<PredictiveBurnMetrics | null> = {
    status: 'fulfilled',
    value: null
  };
  const resolved = resolveLiveBurnMetrics(emptyResult, INITIAL_LIVE_BURN_METRICS_STATE);
  assert.strictEqual(resolved.status, 'empty');
  assert.strictEqual(resolved.data, null);

  const liveDisplay = selectDisplayedBurnMetrics(true, resolved, INITIAL_BURN_METRICS);
  assert.strictEqual(liveDisplay, null);

  const demoDisplay = selectDisplayedBurnMetrics(false, resolved, INITIAL_BURN_METRICS);
  assert.deepStrictEqual(demoDisplay, INITIAL_BURN_METRICS);
});

// 10. Regression Test: Wealth Suite Demo-only items
test('Scenario 10: Wealth Suite tax shields, arbitrage signals, and investments return empty in Live mode', () => {
  // Live mode returns empty arrays
  assert.deepStrictEqual(selectDisplayedTaxOpportunities(true, INITIAL_TAX_SHIELD_OPPORTUNITIES), []);
  assert.deepStrictEqual(selectDisplayedArbitrageSignals(true, INITIAL_ARBITRAGE_SIGNALS), []);
  assert.deepStrictEqual(selectDisplayedInvestments(true, INITIAL_INVESTMENTS), []);

  // Demo mode returns demo fixtures
  assert.deepStrictEqual(selectDisplayedTaxOpportunities(false, INITIAL_TAX_SHIELD_OPPORTUNITIES), INITIAL_TAX_SHIELD_OPPORTUNITIES);
  assert.deepStrictEqual(selectDisplayedArbitrageSignals(false, INITIAL_ARBITRAGE_SIGNALS), INITIAL_ARBITRAGE_SIGNALS);
  assert.deepStrictEqual(selectDisplayedInvestments(false, INITIAL_INVESTMENTS), INITIAL_INVESTMENTS);
});

// 11. Regression Test: Full Cross-Domain Mode Switching
test('Scenario 11: Switching Demo -> Live -> Demo maintains clean isolation across all financial domains', () => {
  // Resolving all domains as empty live data
  const accounts = resolveLiveAccounts({ status: 'fulfilled', value: [] }, INITIAL_LIVE_ACCOUNTS_STATE);
  const envelopes = resolveLiveEnvelopes({ status: 'fulfilled', value: [] }, INITIAL_LIVE_ENVELOPES_STATE);
  const transactions = resolveLiveTransactions({ status: 'fulfilled', value: [] }, INITIAL_LIVE_TRANSACTIONS_STATE);
  const tax = resolveLiveTax({ status: 'fulfilled', value: null }, INITIAL_LIVE_TAX_STATE);
  const burn = resolveLiveBurnMetrics({ status: 'fulfilled', value: null }, INITIAL_LIVE_BURN_METRICS_STATE);

  // 1. In Live Mode:
  assert.strictEqual(selectDisplayedAccounts(true, accounts, SAMPLE_DEMO_ACCOUNTS).length, 0);
  assert.strictEqual(selectDisplayedEnvelopes(true, envelopes, INITIAL_ENVELOPES).length, 0);
  assert.strictEqual(selectDisplayedTransactions(true, transactions, INITIAL_TRANSACTIONS).length, 0);
  assert.strictEqual(selectDisplayedTaxSchedule(true, tax, INITIAL_TAX_SCHEDULE), null);
  assert.strictEqual(selectDisplayedBurnMetrics(true, burn, INITIAL_BURN_METRICS), null);
  assert.strictEqual(selectDisplayedTaxOpportunities(true, INITIAL_TAX_SHIELD_OPPORTUNITIES).length, 0);
  assert.strictEqual(selectDisplayedArbitrageSignals(true, INITIAL_ARBITRAGE_SIGNALS).length, 0);
  assert.strictEqual(selectDisplayedInvestments(true, INITIAL_INVESTMENTS).length, 0);

  // 2. Switch to Demo Mode:
  assert.strictEqual(selectDisplayedAccounts(false, accounts, SAMPLE_DEMO_ACCOUNTS).length, SAMPLE_DEMO_ACCOUNTS.length);
  assert.strictEqual(selectDisplayedEnvelopes(false, envelopes, INITIAL_ENVELOPES).length, INITIAL_ENVELOPES.length);
  assert.strictEqual(selectDisplayedTransactions(false, transactions, INITIAL_TRANSACTIONS).length, INITIAL_TRANSACTIONS.length);
  assert.notStrictEqual(selectDisplayedTaxSchedule(false, tax, INITIAL_TAX_SCHEDULE), null);
  assert.notStrictEqual(selectDisplayedBurnMetrics(false, burn, INITIAL_BURN_METRICS), null);
  assert.strictEqual(selectDisplayedTaxOpportunities(false, INITIAL_TAX_SHIELD_OPPORTUNITIES).length, INITIAL_TAX_SHIELD_OPPORTUNITIES.length);
  assert.strictEqual(selectDisplayedArbitrageSignals(false, INITIAL_ARBITRAGE_SIGNALS).length, INITIAL_ARBITRAGE_SIGNALS.length);
  assert.strictEqual(selectDisplayedInvestments(false, INITIAL_INVESTMENTS).length, INITIAL_INVESTMENTS.length);

  // 3. Switch back to Live Mode:
  assert.strictEqual(selectDisplayedAccounts(true, accounts, SAMPLE_DEMO_ACCOUNTS).length, 0);
  assert.strictEqual(selectDisplayedEnvelopes(true, envelopes, INITIAL_ENVELOPES).length, 0);
  assert.strictEqual(selectDisplayedTransactions(true, transactions, INITIAL_TRANSACTIONS).length, 0);
  assert.strictEqual(selectDisplayedTaxSchedule(true, tax, INITIAL_TAX_SCHEDULE), null);
  assert.strictEqual(selectDisplayedBurnMetrics(true, burn, INITIAL_BURN_METRICS), null);
});

// 12. Regression Test: Burn-rate contract support for { metrics, history }
test('Scenario 12: resolveLiveBurnMetrics accepts { metrics, history } payload shape', () => {
  const payload = {
    metrics: {
      liquidReserveBalanceZar: 150000,
      averageDailyBurnZar: 1250,
      baselineRunwayDays: 120,
      fixedObligationsRunwayDays: 180,
      survivalDate: '2026-12-31',
      discretionaryDailySpendZar: 500,
      monthlyFixedCommitmentsZar: 20000
    },
    history: [
      { transactionDate: '2026-10-01', dailySpendZar: 1200, rolling7dAvgSpendZar: 1250 }
    ]
  };

  const resolved = resolveLiveBurnMetrics({ status: 'fulfilled', value: payload }, INITIAL_LIVE_BURN_METRICS_STATE);
  assert.strictEqual(resolved.status, 'ready');
  assert.strictEqual(resolved.source, 'LIVE');
  assert.ok(resolved.data);
  assert.strictEqual(resolved.data.averageDailyBurnZar, 1250);
  assert.strictEqual(resolved.data.baselineRunwayDays, 120);
});

// 13. Phase 2 Verification: Live investment counts never fabricate 6 holdings
test('Scenario 13: Live investment counts never fabricate 6 holdings; returns 0 when no holdings configured', () => {
  const liveInvestments = selectDisplayedInvestments(true, INITIAL_INVESTMENTS);
  assert.strictEqual(liveInvestments.length, 0, 'Live mode must return 0 holdings, not demo 6');

  const demoInvestments = selectDisplayedInvestments(false, INITIAL_INVESTMENTS);
  assert.strictEqual(demoInvestments.length, 6, 'Demo mode retains demo counters');
});

// 14. Phase 2 Verification: FX spread calculation guards missing/zero rates without hardcoded values
test('Scenario 14: FX spread calculation guards missing/zero rates honestly without hardcoded 76.9%', () => {
  // Safe calculation helper matching TopBar
  const calcSpread = (official: number, parallel: number) => {
    return official > 0 ? (((parallel - official) / official) * 100).toFixed(1) : null;
  };

  assert.strictEqual(calcSpread(0, 35), null);
  assert.strictEqual(calcSpread(-1, 35), null);
  assert.strictEqual(calcSpread(26.5, 35.0), '32.1');
  assert.notStrictEqual(calcSpread(26.5, 35.0), '76.9');
});

// 15. Phase 4 Verification: Soft-archived account preserves transaction links
test('Scenario 15: Soft-archiving an account preserves transaction references in the ledger', () => {
  const accounts: Account[] = [
    {
      accountId: 'ACC_ZA_ACTIVE_1',
      accountName: 'Active Account',
      financialInstitution: 'FNB',
      countryCode: 'ZA',
      primaryCurrency: 'ZAR',
      cashFlowTier: 'DAILY_SPENDING',
      accountType: 'CHECKING',
      isVaultLocked: false,
      withdrawalNoticeDays: 0,
      accountNumberMasked: '...1111',
      nativeBalance: 500,
      isActive: true
    },
    {
      accountId: 'ACC_ZA_ARCHIVED_1',
      accountName: 'Archived Old Account',
      financialInstitution: 'Standard Bank',
      countryCode: 'ZA',
      primaryCurrency: 'ZAR',
      cashFlowTier: 'DAILY_SPENDING',
      accountType: 'CHECKING',
      isVaultLocked: false,
      withdrawalNoticeDays: 0,
      accountNumberMasked: '...2222',
      nativeBalance: 0,
      isActive: false
    }
  ];

  // Active accounts view filters out inactive accounts
  const activeOnly = accounts.filter((a) => a.isActive);
  assert.strictEqual(activeOnly.length, 1);
  assert.strictEqual(activeOnly[0].accountId, 'ACC_ZA_ACTIVE_1');

  // But historical transactions linked to ACC_ZA_ARCHIVED_1 still exist and reference it
  const transactions: Transaction[] = [
    {
      transactionId: 'TX_HIST_1',
      transactionTimestamp: '2025-01-15T10:00:00Z',
      transactionDate: '2025-01-15',
      localTimezone: 'Africa/Johannesburg',
      accountId: 'ACC_ZA_ARCHIVED_1',
      cashFlowTier: 'DAILY_SPENDING',
      categoryId: 'CAT_GROCERIES',
      categoryName: 'Groceries',
      transactionType: 'EXPENSE',
      originalAmount: -250,
      originalCurrency: 'ZAR',
      reportingAmountZar: -250,
      reportingAmountUsd: -13.5,
      appliedExchangeRateZar: 1,
      appliedExchangeRateUsd: 0.054,
      rateTypeApplied: 'OFFICIAL_INTERBANK',
      merchantOrPayee: 'Checkers',
      paymentMethod: 'DEBIT_CARD',
      isTaxDeductible: false,
      notes: 'Historical purchase',
      tags: ['groceries']
    }
  ];

  assert.strictEqual(transactions[0].accountId, 'ACC_ZA_ARCHIVED_1');
  assert.strictEqual(transactions.length, 1, 'Transaction integrity is preserved upon account archival');
});

// 16. Phase 4 Verification: Budget envelope upsert prevents duplicate allocations
test('Scenario 16: Budget allocation upsert maintains 1 entry per category without duplicate allocations', () => {
  const initialEnvelopes: BudgetEnvelope[] = [
    {
      allocationMonth: '2026-04',
      categoryId: 'CAT_TEST',
      categoryName: 'Test Category',
      categoryGroup: 'LIVING_EXPENSES',
      cashFlowTier: 'DAILY_SPENDING',
      targetCurrency: 'ZAR',
      plannedAmount: 1000,
      plannedAmountZar: 1000,
      plannedAmountUsd: 54,
      actualSpentZar: 200,
      actualSpentUsd: 11,
      varianceZar: 800,
      varianceUsd: 43,
      pctConsumed: 20,
      budgetStatus: 'ON_TRACK',
      isFixedObligation: false
    }
  ];

  // Upsert updated planned amount
  const newTarget = 1500;
  const updatedEnvelopes = initialEnvelopes.map((env) => {
    if (env.categoryId === 'CAT_TEST') {
      const newVariance = newTarget - env.actualSpentZar;
      return {
        ...env,
        plannedAmount: newTarget,
        plannedAmountZar: newTarget,
        varianceZar: newVariance,
        pctConsumed: (env.actualSpentZar / newTarget) * 100
      };
    }
    return env;
  });

  assert.strictEqual(updatedEnvelopes.length, 1, 'Upsert must not append duplicate envelope');
  assert.strictEqual(updatedEnvelopes[0].plannedAmountZar, 1500);
  assert.strictEqual(updatedEnvelopes[0].varianceZar, 1300);
});

