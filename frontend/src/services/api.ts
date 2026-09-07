/**
 * api.ts - Type-Safe BigQuery REST API Client for Ziva Finance
 * Connects frontend to the Express BigQuery backend running on /api
 */

import {
  Account,
  BudgetEnvelope,
  ExchangeRates,
  TaxQuarterSchedule,
  Transaction,
  IncomeStatementPeriod,
  NonOperatingGainRecord,
  PerformanceSummary
} from '../types/finance';

const API_BASE = '/api';

export interface HealthStatus {
  status: string;
  project: string;
  dataset: string;
  location: string;
  timestamp: string;
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

export const financeApi = {
  /**
   * Check connection status to BigQuery backend
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
    const res = await fetch(`${API_BASE}/rates`, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) throw new Error(`Failed to fetch exchange rates: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch accounts and calculated live balances
   */
  async getAccounts(): Promise<Account[]> {
    const res = await fetch(`${API_BASE}/accounts`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch accounts: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch primary ledger transactions
   */
  async getTransactions(limit = 100): Promise<Transaction[]> {
    const res = await fetch(`${API_BASE}/transactions?limit=${limit}`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch transactions: ${res.statusText}`);
    return res.json();
  },

  /**
   * Ingest a new transaction (manual entry or receipt scan) into BigQuery
   */
  async createTransaction(transactionData: Partial<Transaction>): Promise<{ success: boolean; transactionId: string; record: any }> {
    const res = await fetch(`${API_BASE}/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(transactionData),
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to ingest transaction into BigQuery: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch budget envelopes vs actuals
   */
  async getBudgetEnvelopes(): Promise<BudgetEnvelope[]> {
    const res = await fetch(`${API_BASE}/budgets`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch budgets: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch quarterly tax liability schedule
   */
  async getTaxSchedule(): Promise<TaxQuarterSchedule | null> {
    const res = await fetch(`${API_BASE}/tax-schedule`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch tax schedule: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch vault holdings
   */
  async getVaultHoldings(): Promise<any[]> {
    const res = await fetch(`${API_BASE}/vault`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch vault holdings: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch daily burn metrics
   */
  async getDailyBurnMetrics(): Promise<any[]> {
    const res = await fetch(`${API_BASE}/burn-rate`, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) throw new Error(`Failed to fetch burn rate: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch Gemini AI Copilot predictive insights & burn metrics
   */
  async getCopilotInsights(): Promise<CopilotInsightsResponse> {
    const res = await fetch(`${API_BASE}/copilot/insights`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch Copilot insights: ${res.statusText}`);
    return res.json();
  },

  /**
   * Send prompt to Gemini AI Copilot
   */
  async askCopilot(prompt: string, apiKey?: string): Promise<CopilotChatResponse> {
    const res = await fetch(`${API_BASE}/copilot/chat`, {
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
    const res = await fetch(`${API_BASE}/analytics/income-statement${query}`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch income statements: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch non-operating gains and yields
   */
  async getNonOperatingGains(): Promise<NonOperatingGainRecord[]> {
    const res = await fetch(`${API_BASE}/analytics/non-operating-gains`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch non-operating gains: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch consolidated performance and analytics summary
   */
  async getPerformanceSummary(): Promise<PerformanceSummary> {
    const res = await fetch(`${API_BASE}/analytics/summary`, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) throw new Error(`Failed to fetch analytics summary: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch all debt/credit ledger records
   */
  async getDebts(status?: string): Promise<any[]> {
    const query = status ? `?status=${status}` : '';
    const res = await fetch(`${API_BASE}/debts${query}`, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) throw new Error(`Failed to fetch debts: ${res.statusText}`);
    return res.json();
  },

  /**
   * Fetch net debt/credit balances summarized per person
   */
  async getDebtBalances(person?: string): Promise<any[]> {
    const query = person ? `?person=${encodeURIComponent(person)}` : '';
    const res = await fetch(`${API_BASE}/debts/balances${query}`, { signal: AbortSignal.timeout(12000) });
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
    const res = await fetch(`${API_BASE}/debts`, {
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
    const res = await fetch(`${API_BASE}/debts/${id}/settle`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) throw new Error(`Failed to settle debt: ${res.statusText}`);
    return res.json();
  }
};

export const api = financeApi;

