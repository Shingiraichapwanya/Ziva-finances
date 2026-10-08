import React, { useState } from 'react';
import {
  PredictiveBurnMetrics,
  TaxShieldOpportunity,
  ArbitrageSignal,
  InvestmentCounter,
  MasterCurrency,
  ExchangeRates,
  BudgetEnvelope,
  Transaction
} from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import {
  Flame,
  ShieldCheck,
  ArrowRightLeft,
  Briefcase,
  Sliders,
  Sparkles,
  TrendingUp,
  AlertTriangle,
  Lightbulb,
  Info
} from 'lucide-react';
import type { LiveBurnMetricsState } from '../../services/liveData';
import { LiveStatusNotice } from '../common/LiveStatusNotice';

interface WealthManagementViewProps {
  burnMetrics: PredictiveBurnMetrics | null;
  taxOpportunities: TaxShieldOpportunity[];
  arbitrageSignals: ArbitrageSignal[];
  investments: InvestmentCounter[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  isLive?: boolean;
  liveBurnMetrics?: LiveBurnMetricsState;
  envelopes?: BudgetEnvelope[];
  transactions?: Transaction[];
}

export const WealthManagementView: React.FC<WealthManagementViewProps> = ({
  burnMetrics,
  taxOpportunities,
  arbitrageSignals,
  investments,
  masterCurrency,
  rates,
  isLive = false,
  liveBurnMetrics,
  envelopes = [],
  transactions = []
}) => {
  const [activeTab, setActiveTab] = useState<'burn' | 'tax-shield' | 'arbitrage' | 'investments'>('burn');

  // Interactive Cutback Simulator State
  const [diningCutback, setDiningCutback] = useState(0); // 0 to 100%
  const [subscriptionsCutback, setSubscriptionsCutback] = useState(0);
  const [discretionaryCutback, setDiscretionaryCutback] = useState(0);

  // Derive category spending from actual envelopes or transactions (30-day baseline)
  // 1. Dining & Food
  const diningDailyZar = React.useMemo(() => {
    if (transactions && transactions.length > 0) {
      const diningTxs = transactions.filter(t =>
        t.transactionType === 'EXPENSE' &&
        /dining|restaurant|coffee|food|cafe/i.test(t.categoryName || t.categoryId || '')
      );
      if (diningTxs.length > 0) {
        const sum = diningTxs.reduce((s, t) => s + Math.abs(t.reportingAmountZar || t.originalAmount), 0);
        return Math.round((sum / 30) * 100) / 100;
      }
    }
    if (envelopes && envelopes.length > 0) {
      const env = envelopes.find(e => /dining|restaurant|coffee|food|cafe/i.test(e.categoryName || e.categoryId));
      if (env) {
        const amt = env.actualSpentZar > 0 ? env.actualSpentZar : env.plannedAmountZar;
        return Math.round((amt / 30) * 100) / 100;
      }
    }
    return 0;
  }, [transactions, envelopes]);

  // 2. Subscriptions & Software
  const subscriptionsDailyZar = React.useMemo(() => {
    if (transactions && transactions.length > 0) {
      const subTxs = transactions.filter(t =>
        t.transactionType === 'EXPENSE' &&
        /subscription|streaming|software|netflix|spotify|cloud|tools/i.test(t.categoryName || t.categoryId || t.merchantOrPayee || '')
      );
      if (subTxs.length > 0) {
        const sum = subTxs.reduce((s, t) => s + Math.abs(t.reportingAmountZar || t.originalAmount), 0);
        return Math.round((sum / 30) * 100) / 100;
      }
    }
    if (envelopes && envelopes.length > 0) {
      const env = envelopes.find(e => /subscription|streaming|software|tools/i.test(e.categoryName || e.categoryId));
      if (env) {
        const amt = env.actualSpentZar > 0 ? env.actualSpentZar : env.plannedAmountZar;
        return Math.round((amt / 30) * 100) / 100;
      }
    }
    return 0;
  }, [transactions, envelopes]);

  // 3. General Discretionary
  const generalDiscretionaryDailyZar = React.useMemo(() => {
    if (transactions && transactions.length > 0) {
      const discTxs = transactions.filter(t =>
        t.transactionType === 'EXPENSE' &&
        !/dining|restaurant|coffee|food|cafe|subscription|streaming|software|netflix|spotify|cloud|tools/i.test(t.categoryName || t.categoryId || '') &&
        /discretionary|incidentals|entertainment|shopping|personal/i.test(t.categoryName || t.categoryId || '')
      );
      if (discTxs.length > 0) {
        const sum = discTxs.reduce((s, t) => s + Math.abs(t.reportingAmountZar || t.originalAmount), 0);
        return Math.round((sum / 30) * 100) / 100;
      }
    }
    if (envelopes && envelopes.length > 0) {
      const envs = envelopes.filter(e =>
        e.categoryGroup === 'DISCRETIONARY' &&
        !/dining|restaurant|coffee|subscription|streaming/i.test(e.categoryName)
      );
      if (envs.length > 0) {
        const sum = envs.reduce((s, e) => s + (e.actualSpentZar > 0 ? e.actualSpentZar : e.plannedAmountZar), 0);
        return Math.round((sum / 30) * 100) / 100;
      }
    }
    return 0;
  }, [transactions, envelopes]);

  const eligibleDailySpendZar = diningDailyZar + subscriptionsDailyZar + generalDiscretionaryDailyZar;
  const rawSavedDailyZar =
    (diningDailyZar * (diningCutback / 100)) +
    (subscriptionsDailyZar * (subscriptionsCutback / 100)) +
    (generalDiscretionaryDailyZar * (discretionaryCutback / 100));
  const savedDailyZar = Math.min(rawSavedDailyZar, eligibleDailySpendZar);

  const baselineBurnZar = burnMetrics?.averageDailyBurnZar || 0;
  const liquidReserveZar = burnMetrics?.liquidReserveBalanceZar || 0;

  // Genuine adjusted daily burn rate: savings deducted from baseline burn without arbitrary 800 floor
  const adjustedDailyBurnZar = baselineBurnZar > 0 ? Math.max(0, baselineBurnZar - savedDailyZar) : 0;
  const adjustedRunwayDays = adjustedDailyBurnZar > 0 ? Math.floor(liquidReserveZar / adjustedDailyBurnZar) : 0;
  const additionalDaysGained = burnMetrics ? Math.max(0, adjustedRunwayDays - burnMetrics.baselineRunwayDays) : 0;

  const burnRateConv = convertCurrency(adjustedDailyBurnZar, 'ZAR', masterCurrency, rates);
  const liquidReserveConv = convertCurrency(liquidReserveZar, 'ZAR', masterCurrency, rates);

  return (
    <div className="wealth-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>Wealth Management & Intelligence Suite</h2>
          <p className="page-subtitle">
            Capital runway modeling, tax liability minimization, currency spread arbitrage, and Gemini-powered VFEX/JSE intelligence.
          </p>
        </div>
      </div>

      {isLive && liveBurnMetrics && (
        <LiveStatusNotice
          status={liveBurnMetrics.status}
          verifiedAt={liveBurnMetrics.verifiedAt}
          error={liveBurnMetrics.error}
          entityName="wealth burn metrics"
          emptyMessage="The live database returned no historical burn metrics. Calculations will appear once spending records are established in Google Sheets."
          idPrefix="live-wealth"
        />
      )}

      {/* Sub-Navigation Tabs */}
      <div className="wealth-subnav">
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'burn' ? 'active' : ''}`}
          onClick={() => setActiveTab('burn')}
        >
          <Flame size={16} />
          <span>Predictive Burn</span>
        </button>
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'tax-shield' ? 'active' : ''}`}
          onClick={() => setActiveTab('tax-shield')}
        >
          <ShieldCheck size={16} />
          <span>Tax Shield (27% Offsets)</span>
        </button>
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'arbitrage' ? 'active' : ''}`}
          onClick={() => setActiveTab('arbitrage')}
        >
          <ArrowRightLeft size={16} />
          <span>Currency Arbitrage</span>
        </button>
        <button
          type="button"
          className={`wealth-tab-btn ${activeTab === 'investments' ? 'active' : ''}`}
          onClick={() => setActiveTab('investments')}
        >
          <Sparkles size={16} />
          <span>Investments (VFEX + JSE)</span>
        </button>
      </div>

      {/* TAB 1: PREDICTIVE BURN */}
      {activeTab === 'burn' && (
        <div className="wealth-panel-content">
          {!burnMetrics ? (
            <div className="glass-panel empty-state-card" style={{ padding: '3.5rem 2rem', textAlign: 'center', borderRadius: '12px' }}>
              <Flame size={44} className="text-muted" style={{ margin: '0 auto 1rem', opacity: 0.6 }} />
              <h3 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>
                {isLive ? 'No Live Burn Rate History' : 'No Burn Metrics Available'}
              </h3>
              <p className="text-muted" style={{ maxWidth: 520, margin: '0 auto', fontSize: '0.9rem', lineHeight: 1.5 }}>
                {isLive
                  ? 'Predictive runway modeling requires at least 14 days of recorded spending in Google Sheets. Add transactions to your ledger to calculate burn rate velocity.'
                  : 'Add expenses to establish your daily burn velocity.'}
              </p>
            </div>
          ) : (
            <>
              <div className="burn-hero-grid">
                <div className="glass-panel burn-stat-card">
                  <div className="stat-label">Estimated Liquid Runway</div>
                  <div className="burn-big-num mono text-rose">
                    {adjustedRunwayDays} <span className="burn-unit">Days</span>
                  </div>
                  <div className="stat-hint">
                    {additionalDaysGained > 0 ? (
                      <span className="text-emerald">+{additionalDaysGained} days gained via simulation cuts!</span>
                    ) : (
                      <span>Based on 30-day trailing daily burn</span>
                    )}
                  </div>
                </div>

                <div className="glass-panel burn-stat-card">
                  <div className="stat-label">Adjusted Daily Burn Velocity</div>
                  <div className="burn-big-num mono text-gold">{burnRateConv.formatted} / day</div>
                  <div className="stat-hint text-muted">
                    Liquid Capital Base: {liquidReserveConv.formatted} (Notice ≤ 32d)
                  </div>
                </div>

                <div className="glass-panel burn-stat-card">
                  <div className="stat-label">Essential Fixed Bills Runway</div>
                  <div className="burn-big-num mono text-emerald">
                    {burnMetrics.fixedObligationsRunwayDays} <span className="burn-unit">Days</span>
                  </div>
                  <div className="stat-hint text-muted">Assuming zero discretionary spend</div>
                </div>
              </div>

              {/* Interactive Scenario Simulator */}
              <div className="glass-panel simulator-card">
                <div className="section-title-bar">
                  <div>
                    <h3>Interactive Runway Scenario Simulator</h3>
                    <p className="section-subtitle">
                      Tweak category discretionary spending cuts below to see how many days of survival runway you unlock.
                    </p>
                  </div>
                  <span className="badge badge-gold">
                    <Sliders size={14} /> Real-Time Modeling
                  </span>
                </div>

                <div className="sliders-grid">
                  <div className="slider-group">
                    <div className="slider-label-row">
                      <span>Dining & Coffee {diningDailyZar > 0 ? `(R${diningDailyZar.toFixed(0)}/day base)` : '(No recorded spend)'}</span>
                      <span className="slider-val mono">{diningCutback}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      step="10"
                      value={diningCutback}
                      onChange={(e) => setDiningCutback(parseInt(e.target.value))}
                      className="scenario-slider"
                      disabled={diningDailyZar === 0}
                    />
                  </div>

                  <div className="slider-group">
                    <div className="slider-label-row">
                      <span>Streaming & Subscriptions {subscriptionsDailyZar > 0 ? `(R${subscriptionsDailyZar.toFixed(0)}/day base)` : '(No recorded spend)'}</span>
                      <span className="slider-val mono">{subscriptionsCutback}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      step="10"
                      value={subscriptionsCutback}
                      onChange={(e) => setSubscriptionsCutback(parseInt(e.target.value))}
                      className="scenario-slider"
                      disabled={subscriptionsDailyZar === 0}
                    />
                  </div>

                  <div className="slider-group">
                    <div className="slider-label-row">
                      <span>General Discretionary {generalDiscretionaryDailyZar > 0 ? `(R${generalDiscretionaryDailyZar.toFixed(0)}/day base)` : '(No recorded spend)'}</span>
                      <span className="slider-val mono">{discretionaryCutback}%</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="100"
                      step="10"
                      value={discretionaryCutback}
                      onChange={(e) => setDiscretionaryCutback(parseInt(e.target.value))}
                      className="scenario-slider"
                      disabled={generalDiscretionaryDailyZar === 0}
                    />
                  </div>
                </div>

                <div style={{ marginTop: '1rem', padding: '0.6rem 0.8rem', background: 'rgba(255,255,255,0.03)', borderRadius: '6px', fontSize: '0.75rem', color: '#94a3b8', lineHeight: 1.4 }}>
                  <strong>Scenario Assumptions:</strong> Daily category baselines derived from active monthly envelopes or 30-day recorded transactions (Total eligible discretionary: R{eligibleDailySpendZar.toFixed(0)}/day). Daily simulated cuts strictly capped to eligible spend.
                </div>
              </div>
            </>
          )}
        </div>
      )}

      {/* TAB 2: TAX SHIELD */}
      {activeTab === 'tax-shield' && (
        <div className="wealth-panel-content">
          <div className="tax-shield-intro glass-panel">
            <div className="intro-icon bg-emerald">
              <ShieldCheck size={28} className="text-emerald" />
            </div>
            <div>
              <h3>Ziva Tax Shield Optimization Engine</h3>
              <p>
                Continuously analyzes your gross consulting inflows against allowable business write-offs under South African and Zimbabwean tax codes. Every R1,000 in qualifying business equipment, cloud infra, or home office expenses reduces your provisional tax bill by <strong>R270.00 (27.00% benchmark)</strong>.
              </p>
            </div>
          </div>

          {taxOpportunities.length === 0 ? (
            <div className="glass-panel empty-state-card" style={{ padding: '3.5rem 2rem', textAlign: 'center', marginTop: '1.5rem', borderRadius: '12px' }}>
              <ShieldCheck size={44} className="text-muted" style={{ margin: '0 auto 1rem', opacity: 0.6 }} />
              <h3 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>
                {isLive ? 'No Live Tax Shield Opportunities Detected' : 'No Tax Shield Opportunities'}
              </h3>
              <p className="text-muted" style={{ maxWidth: 520, margin: '0 auto', fontSize: '0.9rem', lineHeight: 1.5 }}>
                {isLive
                  ? 'Tax shield optimizations evaluate qualifying productivity and home office deductions. As eligible deductible expenses are recorded in Google Sheets, opportunities will surface here.'
                  : 'No tax shield opportunities currently flagged.'}
              </p>
            </div>
          ) : (
            <div className="opportunities-list">
              {taxOpportunities.map((opp) => {
                const currentConv = convertCurrency(opp.currentClaimedZar, 'ZAR', masterCurrency, rates);
                const targetConv = convertCurrency(opp.targetThresholdZar, 'ZAR', masterCurrency, rates);
                const savingsConv = convertCurrency(opp.taxSavingsZar, 'ZAR', masterCurrency, rates);

                return (
                  <div key={opp.id} className="glass-panel opportunity-card">
                    <div className="opp-header">
                      <div>
                        <span className="badge badge-gold">{opp.categoryName}</span>
                        <h4 className="opp-title">{opp.title}</h4>
                      </div>
                      <div className="text-right">
                        <div className="opp-tax-saving mono text-emerald">+{savingsConv.formatted}</div>
                        <div className="opp-tax-label">Tax Saved at 27%</div>
                      </div>
                    </div>

                    <p className="opp-rec">{opp.recommendation}</p>

                    <div className="opp-footer">
                      <div className="opp-threshold-bar">
                        <span className="text-muted text-xs mono">
                          Claimed: {currentConv.formatted} / Benchmark: {targetConv.formatted}
                        </span>
                      </div>
                      <span className="badge badge-emerald">Strategy: Tax Year 2026</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* TAB 3: CURRENCY ARBITRAGE */}
      {activeTab === 'arbitrage' && (
        <div className="wealth-panel-content">
          <div className="arbitrage-spread-hero glass-panel">
            <div className="spread-badge-box">
              <span className="spread-pct mono text-cyan">
                +{rates.USD_TO_ZIG_OFFICIAL > 0 ? (((rates.USD_TO_ZIG_PARALLEL - rates.USD_TO_ZIG_OFFICIAL) / rates.USD_TO_ZIG_OFFICIAL) * 100).toFixed(1) : '0.0'}%
              </span>
              <span className="spread-caption">Parallel Rate Premium over Official RBZ Benchmark</span>
            </div>
            <div className="spread-rates-grid">
              <div>
                <div className="rate-sub">RBZ Official Interbank</div>
                <div className="rate-bold mono">1 USD = ZiG {rates.USD_TO_ZIG_OFFICIAL.toFixed(2)}</div>
              </div>
              <div>
                <div className="rate-sub">Market Clearing Parallel</div>
                <div className="rate-bold mono text-cyan">1 USD = ZiG {rates.USD_TO_ZIG_PARALLEL.toFixed(2)}</div>
              </div>
            </div>
          </div>

          {arbitrageSignals.length === 0 ? (
            <div className="glass-panel empty-state-card" style={{ padding: '3rem 2rem', textAlign: 'center', marginTop: '1.5rem', borderRadius: '12px' }}>
              <ArrowRightLeft size={44} className="text-muted" style={{ margin: '0 auto 1rem', opacity: 0.6 }} />
              <h3 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>No Active Arbitrage Disparities</h3>
              <p className="text-muted" style={{ maxWidth: 520, margin: '0 auto', fontSize: '0.9rem', lineHeight: 1.5 }}>
                Official and market rates are closely aligned or no corridor disparities are detected.
              </p>
            </div>
          ) : (
            <div className="signals-grid">
              {arbitrageSignals.map((sig) => (
                <div key={sig.id} className="glass-panel signal-card">
                  <div className="signal-top">
                    <span className="badge badge-cyan">{sig.pair}</span>
                    <span className="badge badge-gold">{sig.actionBadge}</span>
                  </div>
                  <h4 className="signal-title">{sig.actionBadge}</h4>
                  <p className="signal-desc">{sig.recommendation}</p>
                  <div className="signal-footer mono text-muted text-xs">
                    Official: {sig.officialRate} | Market: {sig.parallelRate} (Spread: +{sig.spreadPct}%)
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* TAB 4: INVESTMENTS (VFEX + JSE) WITH GEMINI */}
      {activeTab === 'investments' && (
        <div className="wealth-panel-content">
          {investments.length === 0 ? (
            <div className="glass-panel empty-state-card" style={{ padding: '3.5rem 2rem', textAlign: 'center', borderRadius: '12px' }}>
              <Briefcase size={44} className="text-muted" style={{ margin: '0 auto 1rem', opacity: 0.6 }} />
              <h3 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>
                {isLive ? 'No Live Investment Holdings Connected' : 'No Investment Holdings'}
              </h3>
              <p className="text-muted" style={{ maxWidth: 520, margin: '0 auto', fontSize: '0.9rem', lineHeight: 1.5 }}>
                {isLive
                  ? 'Google Sheets currently has no tracked VFEX or JSE investment counters. Register holdings in your spreadsheet to track portfolio valuations and Gemini intelligence.'
                  : 'Register equity holdings to view portfolio valuations and analysis.'}
              </p>
            </div>
          ) : (
            <>
              {/* Gemini Advisory Header Card */}
              <div className="glass-panel gemini-advisory-banner">
                <div className="gemini-icon-pill">
                  <Sparkles size={20} className="text-purple" />
                  <span>Gemini Investment Intelligence</span>
                </div>
                <p className="gemini-lead-insight">
                  "Cross-border portfolio analysis: Holding pure export USD counters on the Victoria Falls Stock Exchange (Padenga, Caledonia) delivers an effective hedge against regional currency depreciation. On the JSE, Satrix S&P 500 and Capitec Bank provide steady compounding with dual-currency diversification."
                </p>
                <div className="gemini-disclaimer">
                  <Info size={14} />
                  <span>
                    Educational market advisory only. Does not constitute personalized financial or investment advice.
                  </span>
                </div>
              </div>

              {/* Holdings Grid */}
              <div className="investments-table-wrapper glass-panel">
                <div className="section-title-bar">
                  <div>
                    <h3>Victoria Falls Stock Exchange (VFEX) & Johannesburg Stock Exchange (JSE)</h3>
                    <p className="section-subtitle">Multi-market equities and ETF holdings tracked in Long-Term Vault</p>
                  </div>
                </div>

                <div className="holdings-grid">
                  {investments.map((stock) => {
                    const isVfex = stock.market === 'VFEX';
                    const conv = convertCurrency(
                      stock.holdingValueNative,
                      stock.nativeCurrency,
                      masterCurrency,
                      rates
                    );

                    return (
                      <div key={stock.symbol} className="glass-panel stock-card">
                        <div className="stock-card-top">
                          <div>
                            <div className="stock-symbol-row">
                              <span className="stock-symbol mono">{stock.symbol}</span>
                              <span className={`badge ${isVfex ? 'badge-cyan' : 'badge-gold'}`}>
                                {stock.market} ({stock.nativeCurrency})
                              </span>
                            </div>
                            <div className="stock-name">{stock.name}</div>
                          </div>
                          <div className="text-right">
                            <div className="stock-price mono">
                              {stock.nativeCurrency === 'USD' ? '$' : 'R'} {stock.lastPrice.toFixed(2)}
                            </div>
                            <div className={`stock-change mono text-xs ${stock.change24h >= 0 ? 'text-emerald' : 'text-rose'}`}>
                              {stock.change24h >= 0 ? '+' : ''}{stock.change24h}%
                            </div>
                          </div>
                        </div>

                        <div className="stock-holding-row">
                          <div className="holding-units text-muted text-xs mono">
                            Holding: {stock.holdingUnits.toLocaleString()} units
                          </div>
                          <div className="holding-master-val mono">
                            Valuation: <strong>{conv.formatted}</strong>
                          </div>
                        </div>

                        {/* Gemini Reasoning Pill */}
                        <div className="gemini-pill-box">
                          <div className="gemini-pill-header">
                            <Sparkles size={12} className="text-purple" />
                            <span>Gemini Context</span>
                            <span className="badge badge-purple badge-compact">Defensive: {stock.geminiAdvisory.defensiveScore}</span>
                          </div>
                          <p className="gemini-pill-text">{stock.geminiAdvisory.macroInsight}</p>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
};

