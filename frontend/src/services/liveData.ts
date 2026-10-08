/**
 * liveData.ts - Source-of-truth rules for "BigQuery Live" account data.
 *
 * Live mode must only ever display records returned by the live accounts API.
 * Demo fixtures (mockData.ts) are never used as a fallback for empty or failed
 * live responses. Kept free of React/runtime imports so it can be unit tested
 * with `node --test`.
 */

import type { Account, CashFlowTier } from '../types/finance';

export type LiveAccountsStatus =
  | 'loading'      // no live response received yet
  | 'ready'        // live API returned >= 1 record
  | 'empty'        // live API returned 0 records (genuine empty database)
  | 'stale'        // latest refresh failed; showing the last verified live records
  | 'unavailable'; // live API failed and no verified live records exist

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
