import React from 'react';
import {
  Account,
  BudgetEnvelope,
  Transaction,
  MasterCurrency,
  ExchangeRates,
  PredictiveBurnMetrics,
  TaxQuarterSchedule,
  InvestmentCounter
} from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import {
  TrendingUp,
  Flame,
  ShieldCheck,
  ArrowRightLeft,
  Briefcase,
  Layers,
  ArrowUpRight,
  ArrowDownLeft,
  ChevronRight
} from 'lucide-react';
import { NavTab } from '../layout/Sidebar';
import { CopilotBriefingCard } from '../copilot/CopilotBriefingCard';
import { LiveAccountsState, describeTierInstitutions, hasDisplayableBalances } from '../../services/liveData';
import { LiveAccountsNotice } from '../accounts/LiveAccountsNotice';

interface DashboardViewProps {
  accounts: Account[];
  /** True when the top bar shows "Google Sheets Live". */
  isLive?: boolean;
  liveAccounts?: LiveAccountsState;
  envelopes: BudgetEnvelope[];
  transactions: Transaction[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  burnMetrics: PredictiveBurnMetrics | null;
  taxSchedule: TaxQuarterSchedule | null;
  investments?: InvestmentCounter[];
  onNavigate: (tab: NavTab) => void;
  onOpenCopilot: () => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({
  accounts,
  isLive = false,
  liveAccounts,
  envelopes,
  transactions,
  masterCurrency,
  rates,
  burnMetrics,
  taxSchedule,
  investments,
  onNavigate,
  onOpenCopilot
}) => {
  // 1. Calculate Total Net Worth across all accounts in Master Currency
  let totalNetWorthMaster = 0;
  let tier1TotalMaster = 0;
  let tier2TotalMaster = 0;
  let tier3TotalMaster = 0;

  accounts.forEach((acc) => {
    const conv = convertCurrency(acc.nativeBalance, acc.primaryCurrency, masterCurrency, rates);
    totalNetWorthMaster += conv.amount;
    if (acc.cashFlowTier === 'DAILY_SPENDING') tier1TotalMaster += conv.amount;
    else if (acc.cashFlowTier === 'MONTHLY_ALLOCATION') tier2TotalMaster += conv.amount;
    else if (acc.cashFlowTier === 'LONG_TERM_VAULT') tier3TotalMaster += conv.amount;
  });

  // Dual/Tri-currency secondary representations
  const netWorthZar = convertCurrency(totalNetWorthMaster, masterCurrency, 'ZAR', rates);
  const netWorthUsd = convertCurrency(totalNetWorthMaster, masterCurrency, 'USD', rates);
  const netWorthZig = convertCurrency(totalNetWorthMaster, masterCurrency, 'ZiG', rates);

  // Never render a fabricated zero when live balances could not be loaded
  const showBalances = !liveAccounts || hasDisplayableBalances(isLive, liveAccounts);
  const fmt = (amount: number) =>
    showBalances ? convertCurrency(amount, masterCurrency, masterCurrency, rates).formatted : '—';

  // 2. Budget Health Aggregates
  const totalPlannedZar = envelopes.reduce((sum, e) => sum + e.plannedAmountZar, 0);
  const totalSpentZar = envelopes.reduce((sum, e) => sum + e.actualSpentZar, 0);
  const budgetPct = totalPlannedZar > 0 ? Math.min(100, Math.round((totalSpentZar / totalPlannedZar) * 100)) : 0;

  const plannedMaster = convertCurrency(totalPlannedZar, 'ZAR', masterCurrency, rates);
  const spentMaster = convertCurrency(totalSpentZar, 'ZAR', masterCurrency, rates);

  return (
    <div className="dashboard-view animate-fade-in">
      {isLive && liveAccounts && <LiveAccountsNotice live={liveAccounts} />}

      {/* 1. Net Worth Hero Banner */}
      <section className="glass-panel hero-net-worth">
        <div className="hero-content">
          <div className="hero-caption">
            <span className="badge badge-gold">CONSOLIDATED NET WORTH</span>
            <span className="hero-time">Real-Time Live Sheet Valuation</span>
          </div>
          <h1 className="hero-amount mono">
            {fmt(totalNetWorthMaster)}
          </h1>
          <div className="hero-subcurrencies mono">
            <span className="sub-cur-pill">{showBalances ? netWorthZar.formatted : '—'} ZAR</span>
            <span className="sub-cur-pill">{showBalances ? netWorthUsd.formatted : '—'} USD</span>
            <span className="sub-cur-pill">{showBalances ? netWorthZig.formatted : '—'} ZiG</span>
          </div>
        </div>

        {/* Three-Tier Cash Flow Distribution */}
        <div className="tier-breakdown-grid">
          <div className="tier-col" onClick={() => onNavigate('accounts')}>
            <div className="tier-tag">TIER 1: DAILY SPEND</div>
            <div className="tier-val mono">
              {fmt(tier1TotalMaster)}
            </div>
            <div className="tier-desc">{describeTierInstitutions(accounts, 'DAILY_SPENDING')}</div>
          </div>
          <div className="tier-col" onClick={() => onNavigate('accounts')}>
            <div className="tier-tag">TIER 2: MONTHLY ALLOC</div>
            <div className="tier-val mono">
              {fmt(tier2TotalMaster)}
            </div>
            <div className="tier-desc">{describeTierInstitutions(accounts, 'MONTHLY_ALLOCATION')}</div>
          </div>
          <div className="tier-col tier-col-vault" onClick={() => onNavigate('accounts')}>
            <div className="tier-tag">TIER 3: LONG-TERM VAULT</div>
            <div className="tier-val mono text-gold">
              {fmt(tier3TotalMaster)}
            </div>
            <div className="tier-desc">{describeTierInstitutions(accounts, 'LONG_TERM_VAULT')}</div>
          </div>
        </div>
      </section>

      {/* 2. Gemini AI Financial Intelligence Briefing */}
      <CopilotBriefingCard onOpenCopilot={onOpenCopilot} masterCurrency={masterCurrency} isLive={isLive} />

      {/* 3. Wealth Management Suite Snapshot Tiles */}
      <section className="wealth-tiles-row">
        {/* Tile 1: Predictive Burn */}
        <div className="glass-panel wealth-tile" onClick={() => onNavigate('wealth')}>
          <div className="tile-header">
            <div className="tile-icon-box bg-rose">
              <Flame size={18} className="text-rose" />
            </div>
            <span className="badge badge-rose">RUNWAY FORECAST</span>
          </div>
          <div className="tile-title">Predictive Burn</div>
          <div className="tile-metric mono text-rose">
            {burnMetrics ? `${burnMetrics.baselineRunwayDays} ` : '— '}
            {burnMetrics && <span className="metric-unit">Days</span>}
          </div>
          <div className="tile-footer">
            <span>
              {burnMetrics
                ? `Burn: R${burnMetrics.averageDailyBurnZar.toLocaleString()}/day`
                : 'Awaiting spend history'}
            </span>
            <ChevronRight size={14} />
          </div>
        </div>

        {/* Tile 2: Tax Shield */}
        <div className="glass-panel wealth-tile" onClick={() => onNavigate('wealth')}>
          <div className="tile-header">
            <div className="tile-icon-box bg-emerald">
              <ShieldCheck size={18} className="text-emerald" />
            </div>
            <span className="badge badge-emerald">27% DEDUCTIONS</span>
          </div>
          <div className="tile-title">Tax Shield Offsets</div>
          <div className="tile-metric mono text-emerald">
            {taxSchedule ? `R ${taxSchedule.productivityExpensesOffsetZar.toLocaleString()}` : '—'}
          </div>
          <div className="tile-footer">
            <span>
              {taxSchedule
                ? (taxSchedule.productivityExpensesOffsetZar > 0 ? 'Qualifying Deductions' : 'No deductions logged')
                : 'Awaiting tax records'}
            </span>
            <ChevronRight size={14} />
          </div>
        </div>

        {/* Tile 3: Currency Arbitrage */}
        <div className="glass-panel wealth-tile" onClick={() => onNavigate('wealth')}>
          <div className="tile-header">
            <div className="tile-icon-box bg-cyan">
              <ArrowRightLeft size={18} className="text-cyan" />
            </div>
            <span className="badge badge-cyan">SPREAD ALERT</span>
          </div>
          <div className="tile-title">Currency Arbitrage</div>
          <div className="tile-metric mono text-cyan">
            +{rates.USD_TO_ZIG_OFFICIAL > 0 ? (((rates.USD_TO_ZIG_PARALLEL - rates.USD_TO_ZIG_OFFICIAL) / rates.USD_TO_ZIG_OFFICIAL) * 100).toFixed(1) : '0.0'}% <span className="metric-unit">ZiG Spread</span>
          </div>
          <div className="tile-footer">
            <span>Action: Settle via ZiG Swipe</span>
            <ChevronRight size={14} />
          </div>
        </div>

        {/* Tile 4: Investments (VFEX + JSE) */}
        <div className="glass-panel wealth-tile" onClick={() => onNavigate('wealth')}>
          <div className="tile-header">
            <div className="tile-icon-box bg-purple">
              <Briefcase size={18} className="text-purple" />
            </div>
            <span className="badge badge-purple">GEMINI ADVISORY</span>
          </div>
          <div className="tile-title">Investment Hub</div>
          <div className="tile-metric mono text-purple">
            {investments ? investments.length : (isLive ? 0 : 6)} <span className="metric-unit">Holdings</span>
          </div>
          <div className="tile-footer">
            <span>
              {isLive
                ? (investments && investments.length > 0 ? 'Live Tracked Holdings' : 'Vault Not Configured')
                : 'Demo: VFEX (USD) & JSE (ZAR)'}
            </span>
            <ChevronRight size={14} />
          </div>
        </div>
      </section>

      {/* 3. Monthly Zero-Based Budget Envelope Health */}
      <section className="glass-panel budget-health-section">
        <div className="section-title-bar">
          <div>
            <h3>Monthly Zero-Based Budget Health (Current Month)</h3>
            <p className="section-subtitle">
              Sourced directly from live budget allocations in Google Sheets
            </p>
          </div>
          <button className="btn btn-ghost" onClick={() => onNavigate('budgets')}>
            View All Envelopes <ChevronRight size={14} />
          </button>
        </div>

        {envelopes.length === 0 ? (
          <div style={{ padding: '2rem 1rem', textAlign: 'center' }}>
            <p className="text-muted" style={{ margin: 0 }}>
              {isLive
                ? 'No live budget envelopes configured in Google Sheets.'
                : 'No budget envelopes defined.'}
            </p>
          </div>
        ) : (
          <>
            {/* Visual Progress Bar */}
            <div className="budget-meter-container">
              <div className="budget-meter-header">
                <span className="meter-label">
                  Spent: <strong className="mono">{spentMaster.formatted}</strong> of{' '}
                  <strong className="mono">{plannedMaster.formatted}</strong>
                </span>
                <span className="badge badge-emerald">🟢 ON TRACK ({budgetPct}% CONSUMED)</span>
              </div>
              <div className="meter-track">
                <div className="meter-fill bg-emerald" style={{ width: `${budgetPct}%` }} />
              </div>
            </div>

            {/* Envelope Mini-Grid */}
            <div className="envelope-mini-grid">
              {envelopes.slice(0, 4).map((env) => {
                const spentConv = convertCurrency(env.actualSpentZar, 'ZAR', masterCurrency, rates);
                const plannedConv = convertCurrency(env.plannedAmountZar, 'ZAR', masterCurrency, rates);
                return (
                  <div key={env.categoryId} className="envelope-mini-card">
                    <div className="env-card-title">{env.categoryName}</div>
                    <div className="env-card-amount mono">
                      {spentConv.formatted} / {plannedConv.formatted}
                    </div>
                    <div className="env-card-bar">
                      <div
                        className={`env-bar-fill ${env.budgetStatus === 'OVER_BUDGET' ? 'bg-rose' : 'bg-gold'}`}
                        style={{ width: `${Math.min(100, env.pctConsumed)}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </section>

      {/* 4. Recent Transactions Preview */}
      <section className="glass-panel recent-tx-section">
        <div className="section-title-bar">
          <div>
            <h3>Recent Financial Movements</h3>
            <p className="section-subtitle">Real-time ledger events recorded in Google Sheets</p>
          </div>
          <button className="btn btn-ghost" onClick={() => onNavigate('ledger')}>
            View Full Ledger <ChevronRight size={14} />
          </button>
        </div>

        {transactions.length === 0 ? (
          <div style={{ padding: '2rem 1rem', textAlign: 'center' }}>
            <p className="text-muted" style={{ margin: 0 }}>
              {isLive ? 'No live transactions recorded in Google Sheets yet.' : 'No transactions recorded yet.'}
            </p>
          </div>
        ) : (
          <div className="tx-list">
            {transactions.slice(0, 5).map((tx) => {
              const isIncome = tx.transactionType === 'INCOME';
              const conv = convertCurrency(tx.originalAmount, tx.originalCurrency, masterCurrency, rates);
              return (
                <div key={tx.transactionId} className="tx-item">
                  <div className="tx-left">
                    <div className={`tx-icon-bubble ${isIncome ? 'income' : 'expense'}`}>
                      {isIncome ? <ArrowDownLeft size={16} /> : <ArrowUpRight size={16} />}
                    </div>
                    <div>
                      <div className="tx-payee">{tx.merchantOrPayee}</div>
                      <div className="tx-meta">
                        <span>{tx.transactionDate}</span>
                        <span>•</span>
                        <span>{tx.categoryName}</span>
                        {tx.isTaxDeductible && (
                          <span className="badge badge-gold badge-compact">💼 Tax Deductible</span>
                        )}
                        {tx.taxInvoiceNumber && (
                          <span className="badge badge-purple badge-compact">🧾 {tx.taxInvoiceNumber}</span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="tx-right text-right">
                    <div className={`tx-amount mono ${isIncome ? 'text-emerald' : 'text-primary'}`}>
                      {isIncome ? '+' : ''}{conv.formatted}
                    </div>
                    <div className="tx-native-hint mono text-muted">
                      {tx.originalCurrency} {Math.abs(tx.originalAmount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
};
