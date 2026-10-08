import type {
  Account,
  CashFlowTier,
  BudgetEnvelope,
  Transaction,
  TaxQuarterSchedule,
  PredictiveBurnMetrics,
  TaxShieldOpportunity,
  ArbitrageSignal,
  InvestmentCounter,
  ExchangeRates
} from '../types/finance.ts';

export type LiveDataStatus =
  | 'loading'      // no live response received yet
  | 'ready'        // live API returned >= 1 record (or valid object)
  | 'empty'        // live API returned 0 records (genuine empty database)
  | 'stale'        // latest refresh failed; showing the last verified live records
  | 'unavailable'; // live API failed and no verified live records exist

// =============================================================================
// 1. ACCOUNTS DOMAIN
// =============================================================================
export type LiveAccountsStatus = LiveDataStatus;

export interface LiveAccountsState {
  data: Account[];
  status: LiveAccountsStatus;
  /** 'LIVE' only when `data` came from a live accounts API response. */
  source: 'LIVE' | 'NONE';
  /** ISO timestamp of the last successful live accounts response. */
  verifiedAt: string | null;
  error: string | null;
}

export const INITIAL_LIVE_ACCOUNTS_STATE: LiveAccountsState = {
  data: [],
  status: 'loading',
  source: 'NONE',
  verifiedAt: null,
  error: null
};

/** True only for snapshots that were produced from a real live API response. */
export function isVerifiedLiveSnapshot(state: unknown): state is LiveAccountsState {
  if (!state || typeof state !== 'object') return false;
  const s = state as Partial<LiveAccountsState>;
  return s.source === 'LIVE' && typeof s.verifiedAt === 'string' && Array.isArray(s.data);
}

/**
 * Derive the next live accounts state from the settled accounts request.
 * - fulfilled array  -> exactly the returned records ('ready' / 'empty')
 * - rejected/invalid -> previous verified live records marked 'stale', else 'unavailable' with no records
 */
export function resolveLiveAccounts(
  result: PromiseSettledResult<unknown>,
  previous: unknown,
  now: string = new Date().toISOString()
): LiveAccountsState {
  if (result.status === 'fulfilled' && Array.isArray(result.value)) {
    const data = result.value as Account[];
    return {
      data,
      status: data.length > 0 ? 'ready' : 'empty',
      source: 'LIVE',
      verifiedAt: now,
      error: null
    };
  }

  const error =
    result.status === 'rejected'
      ? (result.reason instanceof Error ? result.reason.message : String(result.reason))
      : 'Accounts API returned an unexpected payload';

  if (isVerifiedLiveSnapshot(previous)) {
    return { ...previous, status: 'stale', error };
  }

  return { data: [], status: 'unavailable', source: 'NONE', verifiedAt: null, error };
}

/** Accounts to render: live records in Live mode, demo fixtures only in Demo mode. */
export function selectDisplayedAccounts(
  isLive: boolean,
  live: LiveAccountsState,
  demoAccounts: Account[]
): Account[] {
  return isLive ? live.data : demoAccounts;
}

/** Whether balances can be shown as numbers (avoids misleading zero totals). */
export function hasDisplayableBalances(isLive: boolean, live: LiveAccountsState): boolean {
  if (!isLive) return true;
  return live.status === 'ready' || live.status === 'empty' || live.status === 'stale';
}

/** Data-driven tier caption (replaces hardcoded sample institution names). */
export function describeTierInstitutions(accounts: Account[], tier: CashFlowTier): string {
  const names = Array.from(
    new Set(accounts.filter((a) => a.cashFlowTier === tier).map((a) => a.financialInstitution).filter(Boolean))
  );
  if (names.length === 0) return 'No accounts in this tier';
  if (names.length <= 2) return names.join(' & ');
  return `${names.slice(0, 2).join(', ')} +${names.length - 2} more`;
}

// =============================================================================
// 2. BUDGET ENVELOPES DOMAIN (ZERO-BASED BUDGETING)
// =============================================================================
export type LiveEnvelopesStatus = LiveDataStatus;

export interface LiveEnvelopesState {
  data: BudgetEnvelope[];
  status: LiveEnvelopesStatus;
  /** 'LIVE' only when `data` came from a live budget envelopes API response. */
  source: 'LIVE' | 'NONE';
  /** ISO timestamp of the last successful live budgets response. */
  verifiedAt: string | null;
  error: string | null;
}

export const INITIAL_LIVE_ENVELOPES_STATE: LiveEnvelopesState = {
  data: [],
  status: 'loading',
  source: 'NONE',
  verifiedAt: null,
  error: null
};

export function isVerifiedLiveEnvelopesSnapshot(state: unknown): state is LiveEnvelopesState {
  if (!state || typeof state !== 'object') return false;
  const s = state as Partial<LiveEnvelopesState>;
  return s.source === 'LIVE' && typeof s.verifiedAt === 'string' && Array.isArray(s.data);
}

export function resolveLiveEnvelopes(
  result: PromiseSettledResult<unknown>,
  previous: unknown,
  now: string = new Date().toISOString()
): LiveEnvelopesState {
  if (result.status === 'fulfilled' && Array.isArray(result.value)) {
    const data = result.value as BudgetEnvelope[];
    return {
      data,
      status: data.length > 0 ? 'ready' : 'empty',
      source: 'LIVE',
      verifiedAt: now,
      error: null
    };
  }

  const error =
    result.status === 'rejected'
      ? (result.reason instanceof Error ? result.reason.message : String(result.reason))
      : 'Budget envelopes API returned an unexpected payload';

  if (isVerifiedLiveEnvelopesSnapshot(previous)) {
    return { ...previous, status: 'stale', error };
  }

  return { data: [], status: 'unavailable', source: 'NONE', verifiedAt: null, error };
}

export function selectDisplayedEnvelopes(
  isLive: boolean,
  live: LiveEnvelopesState,
  demoEnvelopes: BudgetEnvelope[]
): BudgetEnvelope[] {
  return isLive ? live.data : demoEnvelopes;
}

export function hasDisplayableEnvelopes(isLive: boolean, live: LiveEnvelopesState): boolean {
  if (!isLive) return true;
  return live.status === 'ready' || live.status === 'empty' || live.status === 'stale';
}

// =============================================================================
// 3. TRANSACTIONS DOMAIN (LEDGER)
// =============================================================================
export type LiveTransactionsStatus = LiveDataStatus;

export interface LiveTransactionsState {
  data: Transaction[];
  status: LiveTransactionsStatus;
  source: 'LIVE' | 'NONE';
  verifiedAt: string | null;
  error: string | null;
}

export const INITIAL_LIVE_TRANSACTIONS_STATE: LiveTransactionsState = {
  data: [],
  status: 'loading',
  source: 'NONE',
  verifiedAt: null,
  error: null
};

export function isVerifiedLiveTransactionsSnapshot(state: unknown): state is LiveTransactionsState {
  if (!state || typeof state !== 'object') return false;
  const s = state as Partial<LiveTransactionsState>;
  return s.source === 'LIVE' && typeof s.verifiedAt === 'string' && Array.isArray(s.data);
}

export function resolveLiveTransactions(
  result: PromiseSettledResult<unknown>,
  previous: unknown,
  now: string = new Date().toISOString()
): LiveTransactionsState {
  if (result.status === 'fulfilled' && Array.isArray(result.value)) {
    const data = result.value as Transaction[];
    return {
      data,
      status: data.length > 0 ? 'ready' : 'empty',
      source: 'LIVE',
      verifiedAt: now,
      error: null
    };
  }

  const error =
    result.status === 'rejected'
      ? (result.reason instanceof Error ? result.reason.message : String(result.reason))
      : 'Transactions API returned an unexpected payload';

  if (isVerifiedLiveTransactionsSnapshot(previous)) {
    return { ...previous, status: 'stale', error };
  }

  return { data: [], status: 'unavailable', source: 'NONE', verifiedAt: null, error };
}

export function selectDisplayedTransactions(
  isLive: boolean,
  live: LiveTransactionsState,
  demoTransactions: Transaction[]
): Transaction[] {
  return isLive ? live.data : demoTransactions;
}

// =============================================================================
// 4. TAX COMPLIANCE DOMAIN
// =============================================================================
export type LiveTaxStatus = LiveDataStatus;

export interface LiveTaxState {
  data: TaxQuarterSchedule | null;
  status: LiveTaxStatus;
  source: 'LIVE' | 'NONE';
  verifiedAt: string | null;
  error: string | null;
}

export const INITIAL_LIVE_TAX_STATE: LiveTaxState = {
  data: null,
  status: 'loading',
  source: 'NONE',
  verifiedAt: null,
  error: null
};

export function isVerifiedLiveTaxSnapshot(state: unknown): state is LiveTaxState {
  if (!state || typeof state !== 'object') return false;
  const s = state as Partial<LiveTaxState>;
  return s.source === 'LIVE' && typeof s.verifiedAt === 'string';
}

export function resolveLiveTax(
  result: PromiseSettledResult<unknown>,
  previous: unknown,
  now: string = new Date().toISOString()
): LiveTaxState {
  if (result.status === 'fulfilled') {
    const val = result.value;
    if (val && typeof val === 'object' && ('grossTaxableInflowZar' in val || 'taxYear' in val)) {
      return {
        data: val as TaxQuarterSchedule,
        status: 'ready',
        source: 'LIVE',
        verifiedAt: now,
        error: null
      };
    }
    // Null or empty payload indicates no tax schedule generated
    return {
      data: null,
      status: 'empty',
      source: 'LIVE',
      verifiedAt: now,
      error: null
    };
  }

  const error =
    result.status === 'rejected'
      ? (result.reason instanceof Error ? result.reason.message : String(result.reason))
      : 'Tax schedule API returned an unexpected payload';

  if (isVerifiedLiveTaxSnapshot(previous)) {
    return { ...previous, status: 'stale', error };
  }

  return { data: null, status: 'unavailable', source: 'NONE', verifiedAt: null, error };
}

export function selectDisplayedTaxSchedule(
  isLive: boolean,
  live: LiveTaxState,
  demoTaxSchedule: TaxQuarterSchedule
): TaxQuarterSchedule | null {
  return isLive ? live.data : demoTaxSchedule;
}

// =============================================================================
// 5. WEALTH SUITE DOMAIN (BURN METRICS, INVESTMENTS, ARBITRAGE)
// =============================================================================
export type LiveBurnMetricsStatus = LiveDataStatus;

export interface LiveBurnMetricsState {
  data: PredictiveBurnMetrics | null;
  status: LiveBurnMetricsStatus;
  source: 'LIVE' | 'NONE';
  verifiedAt: string | null;
  error: string | null;
}

export const INITIAL_LIVE_BURN_METRICS_STATE: LiveBurnMetricsState = {
  data: null,
  status: 'loading',
  source: 'NONE',
  verifiedAt: null,
  error: null
};

export function isVerifiedLiveBurnMetricsSnapshot(state: unknown): state is LiveBurnMetricsState {
  if (!state || typeof state !== 'object') return false;
  const s = state as Partial<LiveBurnMetricsState>;
  return s.source === 'LIVE' && typeof s.verifiedAt === 'string';
}

export function resolveLiveBurnMetrics(
  result: PromiseSettledResult<unknown>,
  previous: unknown,
  now: string = new Date().toISOString()
): LiveBurnMetricsState {
  if (result.status === 'fulfilled') {
    const val = result.value;
    const metricsCandidate =
      val && typeof val === 'object'
        ? ('averageDailyBurnZar' in val
            ? val
            : 'metrics' in val && val.metrics && typeof val.metrics === 'object'
            ? val.metrics
            : null)
        : null;
    if (metricsCandidate && typeof metricsCandidate === 'object' && 'averageDailyBurnZar' in metricsCandidate) {
      return {
        data: metricsCandidate as PredictiveBurnMetrics,
        status: 'ready',
        source: 'LIVE',
        verifiedAt: now,
        error: null
      };
    }
    return {
      data: null,
      status: 'empty',
      source: 'LIVE',
      verifiedAt: now,
      error: null
    };
  }

  const error =
    result.status === 'rejected'
      ? (result.reason instanceof Error ? result.reason.message : String(result.reason))
      : 'Burn metrics API returned an unexpected payload';

  if (isVerifiedLiveBurnMetricsSnapshot(previous)) {
    return { ...previous, status: 'stale', error };
  }

  return { data: null, status: 'unavailable', source: 'NONE', verifiedAt: null, error };
}

export function selectDisplayedBurnMetrics(
  isLive: boolean,
  live: LiveBurnMetricsState,
  demoBurnMetrics: PredictiveBurnMetrics
): PredictiveBurnMetrics | null {
  return isLive ? live.data : demoBurnMetrics;
}

export function selectDisplayedTaxOpportunities(
  isLive: boolean,
  demoOpportunities: TaxShieldOpportunity[]
): TaxShieldOpportunity[] {
  // In Live mode, only actual detected opportunities can be shown. Demo mock fixtures must never leak.
  return isLive ? [] : demoOpportunities;
}

export function selectDisplayedArbitrageSignals(
  isLive: boolean,
  demoSignals: ArbitrageSignal[],
  rates?: ExchangeRates
): ArbitrageSignal[] {
  if (!isLive) return demoSignals;

  // In Live mode, compute live arbitrage signal if effective rates have a spread
  if (rates && rates.USD_TO_ZIG_OFFICIAL && rates.USD_TO_ZIG_PARALLEL && rates.USD_TO_ZIG_OFFICIAL !== rates.USD_TO_ZIG_PARALLEL) {
    const spreadPct = ((rates.USD_TO_ZIG_PARALLEL - rates.USD_TO_ZIG_OFFICIAL) / rates.USD_TO_ZIG_OFFICIAL) * 100;
    return [
      {
        id: 'LIVE-ARB-01',
        pair: 'USD / ZiG Domestic Clearing',
        officialRate: rates.USD_TO_ZIG_OFFICIAL,
        parallelRate: rates.USD_TO_ZIG_PARALLEL,
        spreadPct: parseFloat(spreadPct.toFixed(1)),
        recommendation: `Live parallel market rate is trading at a ${spreadPct.toFixed(1)}% premium over official RBZ benchmark.`,
        actionBadge: '⚡ Live FX Disparity',
        direction: 'ZIG_CARD_SWIPE'
      }
    ];
  }
  return [];
}

export function selectDisplayedInvestments(
  isLive: boolean,
  demoInvestments: InvestmentCounter[]
): InvestmentCounter[] {
  // Live mode must only show actual connected holdings; demo counters (Padenga, Naspers, etc.) are demo-only.
  return isLive ? [] : demoInvestments;
}

// =============================================================================
// 6. DEVELOPMENT PROVENANCE DIAGNOSTICS
// =============================================================================
export function logDataProvenance(
  domain: string,
  isLive: boolean,
  status: LiveDataStatus,
  countOrSummary: string | number
): void {
  // Diagnostic logger active only in development, strictly redacting secrets and sensitive rows
  if (typeof process !== 'undefined' && process.env?.NODE_ENV === 'test') return;
  if (typeof window !== 'undefined' && (window as any).__ZIVA_DEBUG_PROVENANCE__) {
    console.debug(`[Ziva Provenance] ${domain} | Mode: ${isLive ? 'LIVE' : 'DEMO'} | Status: ${status} | Records: ${countOrSummary}`);
  }
}

