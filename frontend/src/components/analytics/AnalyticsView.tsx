import React, { useState, useEffect, useMemo } from 'react';
import {
  MasterCurrency,
  ExchangeRates,
  PerformanceSummary,
  IncomeStatementPeriod,
  NonOperatingGainRecord,
  SpendHabitBreakdown,
  MonthlyTrendData
} from '../../types/finance';
import { convertCurrency, getCurrencySymbol } from '../../services/currency';
import { api } from '../../services/api';
import {
  TrendingUp,
  TrendingDown,
  Percent,
  Flame,
  PieChart,
  Calendar,
  Sparkles,
  RefreshCw,
  Landmark,
  ArrowUpRight,
  ArrowDownRight,
  HelpCircle,
  BarChart3,
  Layers,
  ChevronRight,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';
import { INITIAL_DEMO_PERFORMANCE_SUMMARY } from '../../services/mockData';

interface AnalyticsViewProps {
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  isLive?: boolean;
}

export const AnalyticsView: React.FC<AnalyticsViewProps> = ({
  masterCurrency,
  rates,
  isLive = false
}) => {
  const [summary, setSummary] = useState<PerformanceSummary | null>(null);
  const [periodType, setPeriodType] = useState<'MONTH' | 'QUARTER'>('MONTH');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [hoveredTrendIndex, setHoveredTrendIndex] = useState<number | null>(null);
  const [selectedGroupFilter, setSelectedGroupFilter] = useState<string | null>(null);

  const fetchSummary = async () => {
    try {
      setLoading(true);
      setError(null);
      if (!isLive) {
        // Demo Mode: strictly use isolated demo fixtures, zero live API calls
        setSummary(INITIAL_DEMO_PERFORMANCE_SUMMARY);
        setLoading(false);
        return;
      }
      const data = await api.getPerformanceSummary();
      setSummary(data);
    } catch (err: any) {
      console.error('Failed to load performance analytics:', err);
      setError(err.message || 'Error fetching analytics from Google Sheets backend');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSummary();
  }, [isLive]);

  // Filter statements by periodType (MONTH vs QUARTER)
  const filteredStatements = useMemo(() => {
    if (!summary?.statements) return [];
    return summary.statements.filter((s) => s.periodType === periodType);
  }, [summary?.statements, periodType]);

  const activeStatement = filteredStatements[0] || null;

  // Format currency helper
  const fmt = (amountZar: number, fromCurr: 'ZAR' | 'USD' = 'ZAR') => {
    const conv = convertCurrency(amountZar, fromCurr, masterCurrency, rates);
    return conv.formatted;
  };

  // Spend habit group totals
  const groupTotals = useMemo(() => {
    if (!summary?.spendHabits) return {};
    const map: Record<string, { zar: number; count: number; items: SpendHabitBreakdown[] }> = {};
    summary.spendHabits.forEach((h) => {
      if (!map[h.categoryGroup]) {
        map[h.categoryGroup] = { zar: 0, count: 0, items: [] };
      }
      map[h.categoryGroup].zar += h.totalSpentZar;
      map[h.categoryGroup].count += h.transactionCount;
      map[h.categoryGroup].items.push(h);
    });
    return map;
  }, [summary?.spendHabits]);

  const totalSpentAllZar = useMemo(() => {
    return Object.values(groupTotals).reduce((sum, g) => sum + g.zar, 0);
  }, [groupTotals]);

  const getGroupColor = (group: string) => {
    switch (group) {
      case 'BUSINESS_PRODUCTIVITY': return { bg: '#10b981', label: 'Business Productivity', border: 'rgba(16, 185, 129, 0.4)' };
      case 'LIVING_EXPENSES': return { bg: '#06b6d4', label: 'Living Essentials', border: 'rgba(6, 182, 212, 0.4)' };
      case 'STATUTORY_OBLIGATIONS': return { bg: '#f43f5e', label: 'Statutory & Levies', border: 'rgba(244, 63, 94, 0.4)' };
      case 'DISCRETIONARY': return { bg: '#f59e0b', label: 'Discretionary', border: 'rgba(245, 158, 11, 0.4)' };
      default: return { bg: '#818cf8', label: group, border: 'rgba(129, 140, 248, 0.4)' };
    }
  };

  const filteredHabits = useMemo(() => {
    if (!summary?.spendHabits) return [];
    if (!selectedGroupFilter) return summary.spendHabits;
    return summary.spendHabits.filter((h) => h.categoryGroup === selectedGroupFilter);
  }, [summary?.spendHabits, selectedGroupFilter]);

  // SVG Trend Chart Data Calculations (grounded only in recorded months)
  const trendData = useMemo(() => {
    if (!summary?.monthlyTrends || summary.monthlyTrends.length === 0) {
      if (summary?.statements && summary.statements.length > 0) {
        // Convert only actual recorded statements to trend points without fabricating synthetic prior months
        return summary.statements.map((s) => ({
          statementPeriod: s.statementPeriod,
          periodStartDate: s.periodStartDate,
          operatingRevenueZar: s.grossOperatingRevenueZar,
          totalOutflowsZar: s.totalComprehensiveOutflowsZar,
          netSurplusZar: s.netCashSurplusZar,
          savingsRatePct: s.savingsRatePct
        }));
      }
      return [];
    }
    return summary.monthlyTrends;
  }, [summary?.monthlyTrends, summary?.statements]);

  // Chart coordinates calculation
  const chartDimensions = { width: 720, height: 260, padding: 40 };
  const chartPoints = useMemo(() => {
    if (trendData.length === 0) return null;
    const revs = trendData.map((d) => d.operatingRevenueZar);
    const spends = trendData.map((d) => d.totalOutflowsZar);
    const surps = trendData.map((d) => d.netSurplusZar);

    const maxVal = Math.max(...revs, ...spends, 1000) * 1.15;
    const minVal = Math.min(...surps, 0) * 1.15;
    const range = maxVal - minVal;

    const getX = (index: number) => {
      if (trendData.length <= 1) return chartDimensions.width / 2;
      return chartDimensions.padding + (index / (trendData.length - 1)) * (chartDimensions.width - chartDimensions.padding * 2);
    };

    const getY = (val: number) => {
      const normalized = (val - minVal) / (range || 1);
      return chartDimensions.height - chartDimensions.padding - normalized * (chartDimensions.height - chartDimensions.padding * 2);
    };

    const revenuePoints = trendData.map((d, i) => ({ x: getX(i), y: getY(d.operatingRevenueZar), val: d.operatingRevenueZar }));
    const outflowPoints = trendData.map((d, i) => ({ x: getX(i), y: getY(d.totalOutflowsZar), val: d.totalOutflowsZar }));
    const surplusPoints = trendData.map((d, i) => ({ x: getX(i), y: getY(d.netSurplusZar), val: d.netSurplusZar }));

    const makePath = (pts: { x: number; y: number }[]) => {
      return pts.reduce((acc, pt, i) => `${acc} ${i === 0 ? 'M' : 'L'} ${pt.x.toFixed(1)},${pt.y.toFixed(1)}`, '');
    };

    return {
      revenuePoints,
      outflowPoints,
      surplusPoints,
      revenuePath: makePath(revenuePoints),
      outflowPath: makePath(outflowPoints),
      surplusPath: makePath(surplusPoints),
      zeroY: getY(0)
    };
  }, [trendData]);

  return (
    <div className="analytics-view">
      {/* View Header */}
      <div className="analytics-header">
        <div>
          <div className="analytics-title-badge">
            <BarChart3 size={16} className="text-gold" />
            <span>FINANCIAL INTELLIGENCE ENGINE</span>
            <span className="analytics-live-tag">
              <span className="wh-dot pulse-live" /> Google Sheets Live Analytics
            </span>
          </div>
          <h1 className="analytics-title">Performance & Analytics Command</h1>
          <p className="analytics-subtitle">
            Structured Income Statements, Spend Habits Distribution, and Non-Operating Asset Yields Grounded in Verified Financial Records.
          </p>
        </div>

        <div className="analytics-controls">
          {/* Statement Granularity Switch */}
          <div className="period-toggle-group">
            <button
              type="button"
              className={`period-toggle-btn ${periodType === 'MONTH' ? 'active' : ''}`}
              onClick={() => setPeriodType('MONTH')}
            >
              <Calendar size={14} />
              Monthly Statements
            </button>
            <button
              type="button"
              className={`period-toggle-btn ${periodType === 'QUARTER' ? 'active' : ''}`}
              onClick={() => setPeriodType('QUARTER')}
            >
              <Layers size={14} />
              Quarterly Rollup
            </button>
          </div>

          <button
            type="button"
            className="analytics-refresh-btn"
            onClick={fetchSummary}
            disabled={loading}
            title="Refresh Live Financial Analytics"
          >
            <RefreshCw size={15} className={loading ? 'spin-animation' : ''} />
            {loading ? 'Refreshing...' : 'Sync Views'}
          </button>
        </div>
      </div>

      {error && (
        <div className="analytics-error-banner">
          <AlertCircle size={18} />
          <span>Error loading analytical models: {error}</span>
          <button type="button" onClick={fetchSummary} className="btn-retry">Retry</button>
        </div>
      )}

      {/* KPI Cards Grid */}
      <div className="analytics-kpi-grid">
        {/* KPI 1: Savings Rate */}
        <div className="analytics-kpi-card">
          <div className="kpi-card-header">
            <div className="kpi-icon-wrap savings-icon">
              <Percent size={18} />
            </div>
            <span className="kpi-card-label">SAVINGS RATE</span>
            <span className={`kpi-chip ${(summary?.kpis.savingsRatePct || 0) >= 20 ? 'chip-emerald' : (summary?.kpis.savingsRatePct || 0) >= 0 ? 'chip-cyan' : 'chip-amber'}`}>
              {(summary?.kpis.savingsRatePct || 0) >= 20 ? 'OPTIMAL' : (summary?.kpis.savingsRatePct || 0) >= 0 ? 'NEUTRAL' : 'DEFICIT'}
            </span>
          </div>
          <div className="kpi-main-metric">
            <span className={`kpi-number ${(summary?.kpis.savingsRatePct || 0) >= 0 ? 'text-emerald' : 'text-amber'}`}>
              {(summary?.kpis.savingsRatePct || 0) > 0 ? '+' : ''}
              {summary?.kpis.savingsRatePct.toFixed(1)}%
            </span>
          </div>
          <div className="kpi-footer-note">
            <span>Net Surplus: <strong>{fmt(summary?.kpis.netCashSurplusZar || 0)}</strong></span>
            <span className="kpi-subtext">50/30/20 Target: 20%</span>
          </div>
        </div>

        {/* KPI 2: 7-Day Rolling Burn Rate */}
        <div className="analytics-kpi-card">
          <div className="kpi-card-header">
            <div className="kpi-icon-wrap burn-icon">
              <Flame size={18} />
            </div>
            <span className="kpi-card-label">7-DAY ROLLING BURN</span>
            <span className={`kpi-chip ${summary?.kpis.burnAlertStatus === 'ELEVATED' ? 'chip-amber' : 'chip-emerald'}`}>
              {summary?.kpis.burnAlertStatus === 'ELEVATED' ? 'ELEVATED (2.6x)' : 'STEADY'}
            </span>
          </div>
          <div className="kpi-main-metric">
            <span className="kpi-number text-white">
              {fmt(summary?.kpis.rolling7dAvgSpendZar || 0)}
              <span className="kpi-unit">/day</span>
            </span>
          </div>
          <div className="kpi-footer-note">
            <span>Latest Day: {fmt(summary?.kpis.latestDailySpendZar || 0)}</span>
            <span className="kpi-subtext">30-day projection: {fmt((summary?.kpis.rolling7dAvgSpendZar || 0) * 30)}</span>
          </div>
        </div>

        {/* KPI 3: Operating Margin */}
        <div className="analytics-kpi-card">
          <div className="kpi-card-header">
            <div className="kpi-icon-wrap margin-icon">
              <TrendingUp size={18} />
            </div>
            <span className="kpi-card-label">OPERATING MARGIN</span>
            <span className="kpi-chip chip-cyan">BUSINESS HEALTH</span>
          </div>
          <div className="kpi-main-metric">
            <span className="kpi-number text-cyan">
              {summary?.kpis.operatingMarginPct.toFixed(1)}%
            </span>
          </div>
          <div className="kpi-footer-note">
            <span>Gross Inflow: {fmt(summary?.kpis.grossOperatingRevenueZar || 0)}</span>
            <span className="kpi-subtext">Isolates business productivity costs</span>
          </div>
        </div>

        {/* KPI 4: Non-Operating Monthly Yield */}
        <div className="analytics-kpi-card">
          <div className="kpi-card-header">
            <div className="kpi-icon-wrap yield-icon">
              <Landmark size={18} />
            </div>
            <span className="kpi-card-label">PASSIVE MONTHLY YIELD</span>
            <span className="kpi-chip chip-gold">BENCHMARK YIELDS</span>
          </div>
          <div className="kpi-main-metric">
            <span className="kpi-number text-gold">
              +{fmt(summary?.kpis.monthlyProjectedGainZar || 0)}
              <span className="kpi-unit">/mo</span>
            </span>
          </div>
          <div className="kpi-footer-note">
            <span>3 Yield Accounts: Discovery, EE, Old Mutual</span>
            <span className="kpi-subtext">Projected annualized: +{fmt((summary?.kpis.monthlyProjectedGainZar || 0) * 12)}/yr</span>
          </div>
        </div>
      </div>

      {/* Center Section: Charts & Habit Breakdowns */}
      <div className="analytics-grid-two-column">
        {/* Left: Revenue & Cash Flow Trends Multi-Line Chart */}
        <div className="analytics-card trend-chart-card">
          <div className="analytics-card-header">
            <div>
              <div className="card-sub-header">ROLLING CASH VELOCITY</div>
              <h2 className="card-primary-title">Revenue vs Expenditure Trends</h2>
            </div>
            <div className="chart-legend-horizontal">
              <span className="legend-item">
                <span className="legend-dot dot-emerald" /> Revenue
              </span>
              <span className="legend-item">
                <span className="legend-dot dot-rose" /> Outflows
              </span>
              <span className="legend-item">
                <span className="legend-dot dot-cyan" /> Net Surplus
              </span>
            </div>
          </div>

          <div className="chart-wrapper">
            {chartPoints ? (
              <svg
                viewBox={`0 0 ${chartDimensions.width} ${chartDimensions.height}`}
                className="analytics-svg-chart"
                preserveAspectRatio="none"
              >
                <defs>
                  <linearGradient id="revenueGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#10b981" stopOpacity="0.25" />
                    <stop offset="100%" stopColor="#10b981" stopOpacity="0.0" />
                  </linearGradient>
                  <linearGradient id="outflowGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#f43f5e" stopOpacity="0.2" />
                    <stop offset="100%" stopColor="#f43f5e" stopOpacity="0.0" />
                  </linearGradient>
                </defs>

                {/* Grid Lines */}
                <line
                  x1={chartDimensions.padding}
                  y1={chartDimensions.padding}
                  x2={chartDimensions.width - chartDimensions.padding}
                  y2={chartDimensions.padding}
                  stroke="rgba(255, 255, 255, 0.06)"
                  strokeDasharray="4 4"
                />
                <line
                  x1={chartDimensions.padding}
                  y1={chartDimensions.height / 2}
                  x2={chartDimensions.width - chartDimensions.padding}
                  y2={chartDimensions.height / 2}
                  stroke="rgba(255, 255, 255, 0.06)"
                  strokeDasharray="4 4"
                />
                <line
                  x1={chartDimensions.padding}
                  y1={chartPoints.zeroY}
                  x2={chartDimensions.width - chartDimensions.padding}
                  y2={chartPoints.zeroY}
                  stroke="rgba(255, 255, 255, 0.15)"
                  strokeWidth="1.5"
                />

                {/* Line Paths */}
                <path
                  d={chartPoints.revenuePath}
                  fill="none"
                  stroke="#10b981"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d={chartPoints.outflowPath}
                  fill="none"
                  stroke="#f43f5e"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <path
                  d={chartPoints.surplusPath}
                  fill="none"
                  stroke="#06b6d4"
                  strokeWidth="2"
                  strokeDasharray="5 3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />

                {/* Data Points */}
                {chartPoints.revenuePoints.map((pt, i) => (
                  <g key={`rev-pt-${i}`} className="chart-node-group">
                    <circle
                      cx={pt.x}
                      cy={pt.y}
                      r={hoveredTrendIndex === i ? 6 : 4}
                      fill="#10b981"
                      stroke="#07090e"
                      strokeWidth="2"
                    />
                    <circle
                      cx={pt.x}
                      cy={chartPoints.outflowPoints[i].y}
                      r={hoveredTrendIndex === i ? 6 : 4}
                      fill="#f43f5e"
                      stroke="#07090e"
                      strokeWidth="2"
                    />
                    <circle
                      cx={pt.x}
                      cy={chartPoints.surplusPoints[i].y}
                      r={hoveredTrendIndex === i ? 6 : 4}
                      fill="#06b6d4"
                      stroke="#07090e"
                      strokeWidth="2"
                    />
                    {/* Invisible hover trigger */}
                    <rect
                      x={pt.x - 20}
                      y={0}
                      width={40}
                      height={chartDimensions.height}
                      fill="transparent"
                      onMouseEnter={() => setHoveredTrendIndex(i)}
                      onMouseLeave={() => setHoveredTrendIndex(null)}
                      style={{ cursor: 'pointer' }}
                    />
                  </g>
                ))}
              </svg>
            ) : (
              <div className="chart-empty-state">Loading timeline telemetry...</div>
            )}

            {/* X-Axis labels */}
            <div className="chart-x-labels">
              {trendData.map((d, i) => (
                <span
                  key={d.statementPeriod}
                  className={`x-label ${hoveredTrendIndex === i ? 'label-active' : ''}`}
                >
                  {d.statementPeriod}
                </span>
              ))}
            </div>

            {/* Interactive Tooltip Card */}
            {hoveredTrendIndex !== null && trendData[hoveredTrendIndex] && (
              <div className="chart-floating-tooltip">
                <div className="tooltip-title">{trendData[hoveredTrendIndex].statementPeriod}</div>
                <div className="tooltip-row text-emerald">
                  <span>Revenue:</span>
                  <strong>{fmt(trendData[hoveredTrendIndex].operatingRevenueZar)}</strong>
                </div>
                <div className="tooltip-row text-rose">
                  <span>Outflows:</span>
                  <strong>{fmt(trendData[hoveredTrendIndex].totalOutflowsZar)}</strong>
                </div>
                <div className="tooltip-row text-cyan">
                  <span>Net Surplus:</span>
                  <strong>{fmt(trendData[hoveredTrendIndex].netSurplusZar)}</strong>
                </div>
                <div className="tooltip-row text-muted">
                  <span>Savings Rate:</span>
                  <span>{trendData[hoveredTrendIndex].savingsRatePct.toFixed(1)}%</span>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Right: Spend Habits Stacked Distribution */}
        <div className="analytics-card spend-habits-card">
          <div className="analytics-card-header">
            <div>
              <div className="card-sub-header">MULTI-TIER EXPENDITURE</div>
              <h2 className="card-primary-title">Spend Habits & Breakdown</h2>
            </div>
            <div className="total-spend-pill">
              Total Outflows: <strong>{fmt(totalSpentAllZar)}</strong>
            </div>
          </div>

          {/* Stacked Proportional Bar */}
          <div className="stacked-bar-container">
            <div className="stacked-bar">
              {Object.entries(groupTotals).map(([group, data]) => {
                const pct = totalSpentAllZar > 0 ? (data.zar / totalSpentAllZar) * 100 : 0;
                const { bg, label } = getGroupColor(group);
                const isSelected = selectedGroupFilter === group;
                return (
                  <div
                    key={group}
                    className={`stacked-segment ${isSelected ? 'segment-selected' : ''}`}
                    style={{ width: `${pct}%`, backgroundColor: bg }}
                    onClick={() => setSelectedGroupFilter(selectedGroupFilter === group ? null : group)}
                    title={`${label}: ${pct.toFixed(1)}% (${fmt(data.zar)})`}
                  />
                );
              })}
            </div>

            {/* Stacked Group Pills */}
            <div className="stacked-legend-row">
              {Object.entries(groupTotals).map(([group, data]) => {
                const pct = totalSpentAllZar > 0 ? (data.zar / totalSpentAllZar) * 100 : 0;
                const { bg, label } = getGroupColor(group);
                const isSelected = selectedGroupFilter === group;
                return (
                  <button
                    key={group}
                    type="button"
                    className={`group-filter-pill ${isSelected ? 'pill-active' : ''}`}
                    onClick={() => setSelectedGroupFilter(selectedGroupFilter === group ? null : group)}
                  >
                    <span className="legend-indicator" style={{ backgroundColor: bg }} />
                    <span className="pill-name">{label}</span>
                    <span className="pill-pct">{pct.toFixed(1)}%</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Category List Drilldown */}
          <div className="habits-list-scroll">
            {filteredHabits.map((item) => {
              const { bg } = getGroupColor(item.categoryGroup);
              return (
                <div key={item.categoryName} className="habit-row-card">
                  <div className="habit-info">
                    <span className="habit-dot" style={{ backgroundColor: bg }} />
                    <div className="habit-names">
                      <div className="habit-title">{item.categoryName}</div>
                      <div className="habit-meta">
                        {item.categoryGroup.replace(/_/g, ' ')} • {item.transactionCount} transaction{item.transactionCount === 1 ? '' : 's'}
                      </div>
                    </div>
                  </div>

                  <div className="habit-metrics">
                    <div className="habit-amount">{fmt(item.totalSpentZar)}</div>
                    <div className="habit-bar-track">
                      <div
                        className="habit-bar-fill"
                        style={{ width: `${Math.min(100, item.pctOfTotalSpend)}%`, backgroundColor: bg }}
                      />
                    </div>
                    <span className="habit-pct-label">{item.pctOfTotalSpend.toFixed(1)}%</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Structured Income Statement (P&L) */}
      <div className="analytics-card statement-card">
        <div className="analytics-card-header">
          <div>
            <div className="card-sub-header">LIVE FINANCIAL STATEMENT VIEW</div>
            <h2 className="card-primary-title">
              Structured Income Statement ({periodType === 'MONTH' ? 'Monthly' : 'Quarterly'})
            </h2>
          </div>
          <div className="statement-meta-badge">
            View: <code>v_income_statement_monthly_quarterly</code>
          </div>
        </div>

        <div className="table-responsive">
          <table className="statement-table">
            <thead>
              <tr>
                <th className="th-line-item">FINANCIAL LINE ITEM</th>
                {filteredStatements.map((s) => (
                  <th key={s.statementPeriod} className="th-period text-right">
                    {s.statementPeriod}
                    <div className="th-sub-dates">{s.periodStartDate} to {s.periodEndDate}</div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {/* SECTION 1: OPERATING ACTIVITIES */}
              <tr className="tr-section-header">
                <td colSpan={filteredStatements.length + 1}>I. OPERATING ACTIVITIES (BUSINESS REVENUE & EXPENSES)</td>
              </tr>
              <tr>
                <td className="td-item-title indent-1">
                  <span className="indicator-plus">+</span> Gross Operating Inflow / Revenue
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right text-emerald">
                    {fmt(s.grossOperatingRevenueZar)}
                  </td>
                ))}
              </tr>
              <tr>
                <td className="td-item-title indent-1">
                  <span className="indicator-minus">-</span> Business Productivity & Deductible Expenses
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right text-rose">
                    ({fmt(s.operatingExpensesZar)})
                  </td>
                ))}
              </tr>
              <tr className="tr-subtotal">
                <td className="td-item-title indent-1 font-bold">
                  = NET OPERATING INCOME (NOI)
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right font-bold text-emerald">
                    {fmt(s.netOperatingIncomeZar)}
                  </td>
                ))}
              </tr>
              <tr className="tr-ratio">
                <td className="td-item-title indent-2 text-muted">Operating Profit Margin %</td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right text-cyan">
                    {s.operatingMarginPct.toFixed(1)}%
                  </td>
                ))}
              </tr>

              {/* SECTION 2: LIVING & COMPREHENSIVE OUTFLOWS */}
              <tr className="tr-section-header">
                <td colSpan={filteredStatements.length + 1}>II. COMPREHENSIVE ALLOCATIONS & PERSONAL LIVING COSTS</td>
              </tr>
              <tr>
                <td className="td-item-title indent-1">
                  <span className="indicator-minus">-</span> Personal Living Essentials (Rent, Groceries, Medical, Utilities)
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right text-rose">
                    ({fmt(s.livingEssentialsZar)})
                  </td>
                ))}
              </tr>
              <tr>
                <td className="td-item-title indent-1">
                  <span className="indicator-minus">-</span> Discretionary Spend (Dining & Lifestyle)
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right text-amber">
                    ({fmt(s.discretionaryExpensesZar)})
                  </td>
                ))}
              </tr>
              <tr>
                <td className="td-item-title indent-1">
                  <span className="indicator-minus">-</span> Statutory Obligations & Tax Levies
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right text-rose">
                    ({fmt(s.statutoryAndDebtZar)})
                  </td>
                ))}
              </tr>
              <tr className="tr-subtotal">
                <td className="td-item-title indent-1 font-bold">
                  = TOTAL COMPREHENSIVE OUTFLOWS
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right font-bold text-rose">
                    ({fmt(s.totalComprehensiveOutflowsZar)})
                  </td>
                ))}
              </tr>

              {/* SECTION 3: BOTTOM LINE CASH SURPLUS */}
              <tr className="tr-section-header tr-bottom-line-header">
                <td colSpan={filteredStatements.length + 1}>III. NET CASH SURPLUS & WEALTH ACCUMULATION</td>
              </tr>
              <tr className="tr-grand-total">
                <td className="td-item-title font-bold text-gold">
                  NET CASH SURPLUS / (DEFICIT)
                </td>
                {filteredStatements.map((s) => (
                  <td
                    key={s.statementPeriod}
                    className={`td-amount text-right font-bold ${s.netCashSurplusZar >= 0 ? 'text-emerald' : 'text-amber'}`}
                  >
                    {s.netCashSurplusZar >= 0 ? '+' : ''}{fmt(s.netCashSurplusZar)}
                  </td>
                ))}
              </tr>
              <tr className="tr-ratio">
                <td className="td-item-title indent-1 text-muted">Savings Rate % (Net Surplus / Gross Revenue)</td>
                {filteredStatements.map((s) => (
                  <td
                    key={s.statementPeriod}
                    className={`td-amount text-right font-bold ${s.savingsRatePct >= 0 ? 'text-emerald' : 'text-amber'}`}
                  >
                    {s.savingsRatePct > 0 ? '+' : ''}{s.savingsRatePct.toFixed(1)}%
                  </td>
                ))}
              </tr>
              <tr>
                <td className="td-item-title indent-1 text-muted">
                  Capital Transferred to Long-Term Vaults (TFSA / Notice Deposits)
                </td>
                {filteredStatements.map((s) => (
                  <td key={s.statementPeriod} className="td-amount text-right text-cyan">
                    {fmt(s.vaultContributionsZar)}
                  </td>
                ))}
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* Section 4: Non-Operating Gains & Asset Yield Tracker */}
      <div className="analytics-card gains-card">
        <div className="analytics-card-header">
          <div>
            <div className="card-sub-header">CAPITAL APPRECIATION & INTEREST ENGINE</div>
            <h2 className="card-primary-title">Non-Operating Gains & Yields</h2>
          </div>
          <div className="statement-meta-badge">
            View: <code>v_non_operating_gains_and_yields</code>
          </div>
        </div>

        <div className="gains-grid">
          {summary?.nonOperatingGains.map((gain) => {
            return (
              <div key={gain.accountId} className="gain-asset-card">
                <div className="gain-card-top">
                  <div className="gain-institution-badge">
                    <Landmark size={14} />
                    <span>{gain.financialInstitution}</span>
                  </div>
                  <span className="gain-yield-pill">
                    {gain.annualizedYieldPct.toFixed(2)}% APY
                  </span>
                </div>

                <div className="gain-account-name">{gain.accountName}</div>
                <div className="gain-classification-tag">
                  {gain.gainClassification.replace(/_/g, ' ')}
                </div>

                <div className="gain-balance-section">
                  <div className="balance-label">Current Vault Balance</div>
                  <div className="balance-val">
                    {fmt(gain.currentVaultBalanceZar)}
                    <span className="balance-native">
                      ({gain.primaryCurrency} {gain.currentVaultBalanceNative.toLocaleString()})
                    </span>
                  </div>
                </div>

                <div className="gain-monthly-projection">
                  <div className="proj-label">Projected 30-Day Passive Gain</div>
                  <div className="proj-val text-gold">
                    +{fmt(gain.monthlyProjectedGainZar)}
                    <span className="proj-sub">/mo</span>
                  </div>
                </div>

                <div className="gain-footer-meta">
                  <span>Notice Period: <strong>{gain.withdrawalNoticeDays === 999 ? 'Locked TFSA' : `${gain.withdrawalNoticeDays} Days`}</strong></span>
                  <span>Currency: <strong>{gain.primaryCurrency}</strong></span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
