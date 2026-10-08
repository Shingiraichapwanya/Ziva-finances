/**
 * api.ts - Type-Safe Google Sheets Live REST API Client for Ziva Finance
 * Connects frontend to the Express backend running on /api
 * Handles Owner Authentication (Google OAuth + WebAuthn Passkeys),
 * Session persistence for iOS PWA, and Receipt Archiving/OCR.
 */

import type {
  Account,
  BudgetEnvelope,
  ExchangeRates,
  TaxQuarterSchedule,
  Transaction,
  IncomeStatementPeriod,
  NonOperatingGainRecord,
  PerformanceSummary
} from '../types/finance.ts';

export const API_BASE_URL =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_API_BASE_URL) ||
  (typeof window !== 'undefined' && window.location.hostname === 'localhost'
    ? 'http://localhost:3001'
    : 'https://ziva-finances-1.onrender.com');

const API_BASE = `${API_BASE_URL}/api`;

// ==========================================
// SESSION & CSRF STORAGE FOR IPHONE PWA
// ==========================================
const SESSION_STORAGE_KEY = 'ziva_session_token';
const CSRF_STORAGE_KEY = 'ziva_csrf_token';

let inMemorySessionToken: string | null = null;
let inMemoryCsrfToken: string | null = null;

export function getSessionToken(): string | null {
  try {
    if (typeof localStorage !== 'undefined') {
      return localStorage.getItem(SESSION_STORAGE_KEY);
    }
  } catch {}
  return inMemorySessionToken;
}

export function setSessionToken(token: string | null): void {
  inMemorySessionToken = token;
  try {
    if (typeof localStorage !== 'undefined') {
      if (token) {
        localStorage.setItem(SESSION_STORAGE_KEY, token);
      } else {
        localStorage.removeItem(SESSION_STORAGE_KEY);
      }
    }
  } catch (err) {
    console.warn('Could not store session token in localStorage', err);
  }
}

export function getCsrfToken(): string | null {
  try {
    if (typeof sessionStorage !== 'undefined') {
      return sessionStorage.getItem(CSRF_STORAGE_KEY);
    }
  } catch {}
  return inMemoryCsrfToken;
}

export function setCsrfToken(token: string | null): void {
  inMemoryCsrfToken = token;
  try {
    if (typeof sessionStorage !== 'undefined') {
      if (token) {
        sessionStorage.setItem(CSRF_STORAGE_KEY, token);
      } else {
        sessionStorage.removeItem(CSRF_STORAGE_KEY);
      }
    }
  } catch (err) {
    console.warn('Could not store CSRF token in sessionStorage', err);
  }
}

/**
 * Universal authenticated fetch:
 * Attaches credentials: 'include' (for HttpOnly cookies)
 * Attaches Authorization: Bearer <token> (for iOS PWA cross-domain reliability)
 * Attaches X-CSRF-Token for mutations
 */
export async function authFetch(url: string, options: RequestInit = {}): Promise<Response> {
  const headers = new Headers(options.headers || {});
  
  const token = getSessionToken();
  if (token && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  const method = (options.method || 'GET').toUpperCase();
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
    const csrf = getCsrfToken();
    if (csrf && !headers.has('X-CSRF-Token')) {
      headers.set('X-CSRF-Token', csrf);
    }
  }

  return fetch(url, {
    ...options,
    headers,
    credentials: 'include'
  });
}

// ==========================================
// INTERFACES & TYPES
// ==========================================

export interface HealthStatus {
  status: string;
  source: string;
  storage: string;
  timestamp: string;
}

export interface UserSession {
  authenticated: boolean;
  user?: {
    email: string;
    isOwner?: boolean;
    name?: string;
    picture?: string;
  };
  csrfToken?: string;
  hasPasskeys?: boolean;
  isOffline?: boolean;
}

export interface PasskeyInfo {
  id: string;
  name: string;
  createdAt: string;
  counter: number;
}

export interface ReceiptFileReference {
  originalFilename: string;
  driveFileId?: string;
  driveWebViewLink?: string;
  localPath?: string;
  mimetype: string;
  sizeBytes: number;
}

export interface ReceiptExtractedData {
  merchant: string;
  date: string;
  totalAmount: number;
  subtotal: number;
  taxAmount: number;
  currency: string;
  invoiceNumber: string;
  confidence: 'HIGH' | 'MEDIUM' | 'LOW' | 'MANUAL_REVIEW';
  rawOcrSnippet: string;
  extractedLineItems?: Array<{ description: string; amount: number }>;
}

export interface ReceiptDraft {
  draftId: string;
  storageDestination: 'GOOGLE_DRIVE_PRIVATE' | 'LOCAL_PRIVATE_ARCHIVE';
  fileReference: ReceiptFileReference;
  extractedData: ReceiptExtractedData;
  status: 'AWAITING_REVIEW' | 'CONFIRMED' | 'DISCARDED';
  createdAt: string;
  confirmedAt?: string;
  transactionId?: string;
}

export interface CopilotInsightItem {
  id: string;
  type: 'RUNWAY' | 'TAX' | 'CURRENCY' | 'BUDGET';
  urgency: 'HIGH' | 'MEDIUM' | 'LOW' | 'OPTIMAL';
  title: string;
  summary: string;
  action: string;
  metric: string;
  category: string;
}

export interface CopilotMetrics {
  liquidReserveZar: number;
  vaultTotalZar: number;
  averageDailyBurnZar: number;
  baselineRunwayDays: number;
  fixedObligationsRunwayDays: number;
  survivalDate: string;
  monthlyFixedCommitmentsZar: number;
  taxSavingsAtRiskZar: number;
  taxDeductibleUnverifiedCount: number;
  spreadPct: number;
  burnStatus: 'OPTIMAL' | 'STABLE' | 'ACCELERATING';
}

export interface CopilotInsightsResponse {
  metrics: CopilotMetrics;
  insights: CopilotInsightItem[];
  generatedAt: string;
}

export interface CopilotChatResponse {
  reply: string;
  model: string;
  metrics: CopilotMetrics;
}

// ==========================================
// API CLIENT
// ==========================================

export const financeApi = {
  // ----------------------------------------
  // AUTHENTICATION & WEBAUTHN PASSKEYS
  // ----------------------------------------

  /**
   * Check current session status
   */
  async checkSession(): Promise<UserSession> {
    try {
      const res = await authFetch(`${API_BASE}/auth/session`, { signal: AbortSignal.timeout(5000) });
      if (res.status === 401) {
        setSessionToken(null);
        setCsrfToken(null);
        return { authenticated: false };
      }
      if (!res.ok) {
        return { authenticated: false, isOffline: true };
      }
      const data = await res.json();
      if (data.csrfToken) {
        setCsrfToken(data.csrfToken);
      }
      return data;
    } catch {
      // Network failure / offline: preserve stored credentials and report offline status
      return { authenticated: false, isOffline: true };
    }
  },

  /**
   * Log in with Google Identity credential (ID token)
   */
  async loginWithGoogle(credential: string): Promise<UserSession> {
    const res = await fetch(`${API_BASE}/auth/google/callback`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ credential }),
      credentials: 'include'
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Google sign-in failed');
    }
    const data = await res.json();
    if (data.session?.id) {
      setSessionToken(data.session.id);
    }
    if (data.csrfToken) {
      setCsrfToken(data.csrfToken);
    }
    return {
      authenticated: true,
      user: data.session?.user,
      csrfToken: data.csrfToken
    };
  },

  /**
   * Terminate session and revoke server-side token
   */
  async logout(): Promise<void> {
    try {
      await authFetch(`${API_BASE}/auth/logout`, { method: 'POST' });
    } catch (err) {
      console.warn('Logout request failed:', err);
    } finally {
      setSessionToken(null);
      setCsrfToken(null);
    }
  },

  /**
   * WebAuthn: Get Passkey Registration Options
   */
  async getPasskeyRegisterOptions(): Promise<any> {
    const res = await authFetch(`${API_BASE}/auth/passkey/register-options`, {
      method: 'POST'
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Failed to initialize passkey registration');
    }
    return res.json();
  },

  /**
   * WebAuthn: Verify Passkey Registration Response
   */
  async verifyPasskeyRegistration(registrationResponse: any, name?: string): Promise<{ success: boolean; credentialId: string }> {
    const res = await authFetch(`${API_BASE}/auth/passkey/register-verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ response: registrationResponse, name })
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Failed to verify passkey');
    }
    return res.json();
  },

  /**
   * WebAuthn: Get Passkey Authentication/Login Options
   */
  async getPasskeyLoginOptions(): Promise<any> {
    const res = await fetch(`${API_BASE}/auth/passkey/login-options`, {
      credentials: 'include'
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Failed to get passkey login options');
    }
    return res.json();
  },

  /**
   * WebAuthn: Verify Passkey Login Response
   */
  async verifyPasskeyLogin(authenticationResponse: any): Promise<UserSession> {
    const res = await fetch(`${API_BASE}/auth/passkey/login-verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ response: authenticationResponse }),
      credentials: 'include'
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Passkey verification failed');
    }
    const data = await res.json();
    if (data.session?.id) {
      setSessionToken(data.session.id);
    }
    if (data.csrfToken) {
      setCsrfToken(data.csrfToken);
    }
    return {
      authenticated: true,
      user: data.session?.user,
      csrfToken: data.csrfToken
    };
  },

  /**
   * List registered passkeys for owner
   */
  async listPasskeys(): Promise<PasskeyInfo[]> {
    const res = await authFetch(`${API_BASE}/auth/passkey/list`);
    if (!res.ok) return [];
    const data = await res.json();
    const list = Array.isArray(data) ? data : (data.credentials || []);
    return list.map((p: any) => ({
      id: p.id,
      name: p.deviceName || p.name || 'Security Key',
      createdAt: p.createdAt || new Date().toISOString(),
      counter: p.counter || 0,
      lastUsedAt: p.lastUsedAt
    }));
  },

  /**
   * Revoke a registered passkey
   */
  async deletePasskey(credentialId: string): Promise<boolean> {
    const res = await authFetch(`${API_BASE}/auth/passkey/${encodeURIComponent(credentialId)}`, {
      method: 'DELETE'
    });
    return res.ok;
  },

  // ----------------------------------------
  // RECEIPT ARCHIVING, OCR & DRAFTS
  // ----------------------------------------

  /**
   * Upload receipt (image/PDF up to 10MB) for private Drive storage and OCR extraction
   */
  async uploadReceipt(file: File): Promise<{ success: boolean; draft: ReceiptDraft }> {
    const formData = new FormData();
    formData.append('receipt', file);

    const res = await authFetch(`${API_BASE}/receipts/upload`, {
      method: 'POST',
      body: formData
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Receipt upload failed');
    }
    return res.json();
  },

  /**
   * Get all active receipt drafts awaiting review
   */
  async getReceiptDrafts(): Promise<ReceiptDraft[]> {
    const res = await authFetch(`${API_BASE}/receipts/drafts`);
    if (!res.ok) return [];
    const data = await res.json();
    return data.drafts || [];
  },

  /**
   * Confirm an editable draft and post idempotently to Google Sheets
   */
  async confirmReceiptDraft(
    draftId: string,
    overrides?: Partial<ReceiptExtractedData> & {
      amount?: number;
      totalAmount?: number;
      accountId?: string;
      categoryId?: string;
      isTaxDeductible?: boolean;
    }
  ): Promise<{ success: boolean; transactionId: string; draft: ReceiptDraft }> {
    const reviewedData = {
      ...overrides,
      amount: overrides?.amount ?? overrides?.totalAmount
    };
    const res = await authFetch(`${API_BASE}/receipts/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ draftId, reviewedData })
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || 'Failed to confirm receipt to Google Sheets');
    }
    return res.json();
  },

  /**
   * Cancel / discard an unconfirmed receipt draft
   */
  async deleteReceiptDraft(draftId: string): Promise<boolean> {
    const res = await authFetch(`${API_BASE}/receipts/drafts/${encodeURIComponent(draftId)}`, {
      method: 'DELETE'
    });
    return res.ok;
  },

  // ----------------------------------------
  // CORE FINANCIAL DATA (SHEETS LIVE READS/WRITES)
  // ----------------------------------------

  /**
   * Minimal public health check (non-sensitive)
   */
  async checkHealth(): Promise<HealthStatus> {
    const res = await fetch(`${API_BASE}/health`, { signal: AbortSignal.timeout(4000) });
    if (!res.ok) throw new Error(`Health check failed: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch latest live effective exchange rates
   */
  async getExchangeRates(): Promise<ExchangeRates> {
    const res = await authFetch(`${API_BASE}/rates`, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) throw new Error(`Failed to fetch exchange rates: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch accounts and calculated live balances
   */
  async getAccounts(includeArchived = false): Promise<Account[]> {
    const res = await authFetch(`${API_BASE}/accounts${includeArchived ? '?includeArchived=true' : ''}`, {
      signal: AbortSignal.timeout(10000)
    });
    if (!res.ok) throw new Error(`Failed to fetch accounts: ${res.statusText}`);
    return res.json();
  },

  /**
   * Create a new financial account in dim_accounts
   */
  async createAccount(accountData: Partial<Account>): Promise<{ success: boolean; accountId: string; account: Account }> {
    const res = await authFetch(`${API_BASE}/accounts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(accountData),
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Failed to create account: ${res.statusText}`);
    }
    return res.json();
  },

  /**
   * Update existing account metadata in dim_accounts
   */
  async updateAccount(accountId: string, updates: Partial<Account>): Promise<{ success: boolean; accountId: string }> {
    const res = await authFetch(`${API_BASE}/accounts/${encodeURIComponent(accountId)}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updates),
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Failed to update account: ${res.statusText}`);
    }
    return res.json();
  },

  /**
   * Soft-archive an account in dim_accounts (preserves linked transactions)
   */
  async archiveAccount(accountId: string): Promise<{ success: boolean; accountId: string; archived: boolean }> {
    const res = await authFetch(`${API_BASE}/accounts/${encodeURIComponent(accountId)}`, {
      method: 'DELETE',
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Failed to archive account: ${res.statusText}`);
    }
    return res.json();
  },

  /**
   * Fetch primary ledger transactions
   */
  async getTransactions(limit = 100): Promise<Transaction[]> {
    const res = await authFetch(`${API_BASE}/transactions?limit=${limit}`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch transactions: ${res.statusText}`);
    return res.json();
  },

  /**
   * Ingest a new transaction directly into Google Sheets fct_transactions
   */
  async createTransaction(transactionData: Partial<Transaction>): Promise<{ success: boolean; transactionId: string; record: any }> {
    const res = await authFetch(`${API_BASE}/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(transactionData),
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to persist transaction to Google Sheets: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch budget envelopes vs actuals
   */
  async getBudgetEnvelopes(): Promise<BudgetEnvelope[]> {
    const res = await authFetch(`${API_BASE}/budgets`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch budgets: ${res.statusText}`);
    return res.json();
  },

  /**
   * Upsert monthly budget envelope allocation in fct_budget_allocations
   */
  async upsertBudgetAllocation(allocationData: {
    categoryId: string;
    allocationMonth: string;
    plannedAmount: number;
    targetCurrency?: string;
    cashFlowTier?: string;
    isFixedObligation?: boolean;
    notes?: string;
  }): Promise<{ success: boolean; action: string; allocation: any }> {
    const res = await authFetch(`${API_BASE}/budgets/allocate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(allocationData),
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Failed to upsert budget allocation: ${res.statusText}`);
    }
    return res.json();
  },

  /**
   * Fetch quarterly tax liability schedule
   */
  async getTaxSchedule(): Promise<TaxQuarterSchedule | null> {
    const res = await authFetch(`${API_BASE}/tax-schedule`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch tax schedule: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch vault holdings
   */
  async getVaultHoldings(): Promise<any[]> {
    const res = await authFetch(`${API_BASE}/vault`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch vault holdings: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch daily burn metrics
   */
  async getDailyBurnMetrics(): Promise<any[]> {
    const res = await authFetch(`${API_BASE}/burn-rate`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch burn rate: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch Gemini AI Copilot predictive insights & burn metrics
   */
  async getCopilotInsights(): Promise<CopilotInsightsResponse> {
    const res = await authFetch(`${API_BASE}/copilot/insights`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch Copilot insights: ${res.statusText}`);
    return res.json();
  },

  /**
   * Send prompt to Gemini AI Copilot
   */
  async askCopilot(prompt: string, apiKey?: string): Promise<CopilotChatResponse> {
    const res = await authFetch(`${API_BASE}/copilot/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, apiKey }),
      signal: AbortSignal.timeout(20000)
    });
    if (!res.ok) throw new Error(`Failed to ask Copilot: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch structured income statements (monthly or quarterly)
   */
  async getIncomeStatements(periodType?: 'MONTH' | 'QUARTER'): Promise<IncomeStatementPeriod[]> {
    const query = periodType ? `?periodType=${periodType}` : '';
    const res = await authFetch(`${API_BASE}/analytics/income-statement${query}`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch income statements: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch non-operating gains and yields
   */
  async getNonOperatingGains(): Promise<NonOperatingGainRecord[]> {
    const res = await authFetch(`${API_BASE}/analytics/non-operating-gains`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch non-operating gains: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch consolidated performance and analytics summary
   */
  async getPerformanceSummary(): Promise<PerformanceSummary> {
    const res = await authFetch(`${API_BASE}/analytics/summary`, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) throw new Error(`Failed to fetch analytics summary: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch all debt/credit ledger records
   */
  async getDebts(status?: string): Promise<any[]> {
    const query = status ? `?status=${status}` : '';
    const res = await authFetch(`${API_BASE}/debts${query}`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch debts: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch net debt/credit balances summarized per person
   */
  async getDebtBalances(person?: string): Promise<any[]> {
    const query = person ? `?person=${encodeURIComponent(person)}` : '';
    const res = await authFetch(`${API_BASE}/debts/balances${query}`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch debt balances: ${res.statusText}`);
    return res.json();
  },

  /**
   * Create a new debt or credit entry
   */
  async createDebt(debtData: {
    personName: string;
    direction: 'owed_to_me' | 'owed_by_me';
    amount: number;
    currency?: string;
    date?: string;
    notes?: string;
  }): Promise<{ success: boolean; debtId: string }> {
    const res = await authFetch(`${API_BASE}/debts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(debtData),
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to create debt record: ${res.statusText}`);
    return res.json();
  },

  /**
   * Mark a debt entry as Settled
   */
  async settleDebt(id: string): Promise<{ success: boolean; debtId: string; status: string }> {
    const res = await authFetch(`${API_BASE}/debts/${encodeURIComponent(id)}/settle`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to settle debt: ${res.statusText}`);
    return res.json();
  },

  /**
   * Delete a transaction from Google Sheets
   */
  async deleteTransaction(id: string): Promise<{ success: boolean; transactionId: string }> {
    const res = await authFetch(`${API_BASE}/transactions/${encodeURIComponent(id)}`, {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to delete transaction: ${res.statusText}`);
    return res.json();
  },

  /**
   * Reopen / Unsettle a debt entry
   */
  async reopenDebt(id: string): Promise<{ success: boolean; debtId: string; status: string }> {
    const res = await authFetch(`${API_BASE}/debts/${encodeURIComponent(id)}/reopen`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to reopen debt: ${res.statusText}`);
    return res.json();
  },

  /**
   * Delete a debt entry
   */
  async deleteDebt(id: string): Promise<{ success: boolean; debtId: string }> {
    const res = await authFetch(`${API_BASE}/debts/${encodeURIComponent(id)}`, {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to delete debt: ${res.statusText}`);
    return res.json();
  },

  /**
   * Get safe public Google Sheets configuration mappings
   */
  async getSheetsConfig(): Promise<any> {
    const res = await authFetch(`${API_BASE}/sheets/config`, {
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(10000)
    });
    if (!res.ok) throw new Error(`Failed to fetch sheets config: ${res.statusText}`);
    return res.json();
  }
};

export const api = financeApi;
