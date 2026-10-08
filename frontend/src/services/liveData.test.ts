import test from 'node:test';
import assert from 'node:assert/strict';

import {
  INITIAL_LIVE_ACCOUNTS_STATE,
  isVerifiedLiveSnapshot,
  resolveLiveAccounts,
  selectDisplayedAccounts,
  hasDisplayableBalances,
  describeTierInstitutions,
  type LiveAccountsState
} from './liveData.ts';
import type { Account } from '../types/finance.ts';

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
