import React, { useState } from 'react';
import { BudgetEnvelope, MasterCurrency, ExchangeRates, CashFlowTier } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { PieChart, AlertTriangle, CheckCircle2, Plus, Edit3, X } from 'lucide-react';
import type { LiveEnvelopesState } from '../../services/liveData';
import { hasDisplayableEnvelopes } from '../../services/liveData';
import { LiveStatusNotice } from '../common/LiveStatusNotice';

interface BudgetsViewProps {
  envelopes: BudgetEnvelope[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  isLive?: boolean;
  liveEnvelopes?: LiveEnvelopesState;
  onUpsertBudget?: (allocationData: {
    categoryId: string;
    allocationMonth: string;
    plannedAmount: number;
    targetCurrency?: string;
    cashFlowTier?: string;
    isFixedObligation?: boolean;
    notes?: string;
  }) => Promise<void>;
}

export const BudgetsView: React.FC<BudgetsViewProps> = ({
  envelopes,
  masterCurrency,
  rates,
  isLive = false,
  liveEnvelopes,
  onUpsertBudget
}) => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Form fields
  const [categoryId, setCategoryId] = useState('');
  const [allocationMonth, setAllocationMonth] = useState(() => new Date().toISOString().slice(0, 7)); // 'YYYY-MM'
  const [plannedAmount, setPlannedAmount] = useState<number | ''>('');
  const [targetCurrency, setTargetCurrency] = useState<'ZAR' | 'USD' | 'ZIG'>('ZAR');
  const [cashFlowTier, setCashFlowTier] = useState<CashFlowTier>('DAILY_SPENDING');
  const [isFixedObligation, setIsFixedObligation] = useState(false);
  const [notes, setNotes] = useState('');

  const openForNew = () => {
    setCategoryId('');
    setAllocationMonth(new Date().toISOString().slice(0, 7));
    setPlannedAmount('');
    setTargetCurrency('ZAR');
    setCashFlowTier('DAILY_SPENDING');
    setIsFixedObligation(false);
    setNotes('');
    setFormError(null);
    setIsModalOpen(true);
  };

  const openForEdit = (env: BudgetEnvelope) => {
    setCategoryId(env.categoryId);
    setAllocationMonth(env.allocationMonth ? env.allocationMonth.slice(0, 7) : new Date().toISOString().slice(0, 7));
    setPlannedAmount(env.plannedAmountZar);
    setTargetCurrency('ZAR');
    setCashFlowTier(env.cashFlowTier);
    setIsFixedObligation(env.isFixedObligation);
    setNotes('');
    setFormError(null);
    setIsModalOpen(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!categoryId.trim()) {
      setFormError('Category ID is required');
      return;
    }
    if (!allocationMonth.trim()) {
      setFormError('Allocation month is required');
      return;
    }
    const num = typeof plannedAmount === 'number' ? plannedAmount : parseFloat(plannedAmount || '0');
    if (isNaN(num) || num < 0) {
      setFormError('Planned amount must be a non-negative number');
      return;
    }
    if (!onUpsertBudget) return;

    try {
      setIsSubmitting(true);
      setFormError(null);
      await onUpsertBudget({
        categoryId: categoryId.trim(),
        allocationMonth: allocationMonth.trim(),
        plannedAmount: num,
        targetCurrency,
        cashFlowTier,
        isFixedObligation,
        notes: notes.trim()
      });
      setIsModalOpen(false);
    } catch (err: any) {
      setFormError(err.message || 'Failed to save budget envelope');
    } finally {
      setIsSubmitting(false);
    }
  };

  const showCalculations = !liveEnvelopes || hasDisplayableEnvelopes(isLive, liveEnvelopes);
  const totalPlannedZar = envelopes.reduce((s, e) => s + e.plannedAmountZar, 0);
  const totalSpentZar = envelopes.reduce((s, e) => s + e.actualSpentZar, 0);
  const totalVarianceZar = totalPlannedZar - totalSpentZar;

  const plannedMaster = convertCurrency(totalPlannedZar, 'ZAR', masterCurrency, rates);
  const spentMaster = convertCurrency(totalSpentZar, 'ZAR', masterCurrency, rates);
  const varianceMaster = convertCurrency(totalVarianceZar, 'ZAR', masterCurrency, rates);

  const isDataAvailable = showCalculations && (!isLive || (liveEnvelopes && (liveEnvelopes.status === 'ready' || liveEnvelopes.status === 'stale')));

  return (
    <div className="budgets-view animate-fade-in">
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h2>Zero-Based Budgeting Envelopes</h2>
          <p className="page-subtitle">
            Every Rand, Dollar, and ZiG assigned to a concrete envelope or savings sink.
          </p>
        </div>
        {onUpsertBudget && (
          <button
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', whiteSpace: 'nowrap' }}
            onClick={openForNew}
          >
            <Plus size={16} /> Set Envelope Target
          </button>
        )}
      </div>

      {isLive && liveEnvelopes && (
        <LiveStatusNotice
          status={liveEnvelopes.status}
          verifiedAt={liveEnvelopes.verifiedAt}
          error={liveEnvelopes.error}
          entityName="budget envelopes"
          emptyMessage="The live database returned no budget allocations from the fct_budget_allocations tab. Add envelope targets to track monthly spending."
          idPrefix="live-budgets"
        />
      )}

      {/* Macro ZBB Overview */}
      <div className="budget-macro-grid">
        <div className="glass-panel macro-stat-card">
          <div className="stat-label">Total Monthly Target</div>
          <div className="stat-value mono">
            {isDataAvailable ? (envelopes.length > 0 ? plannedMaster.formatted : '—') : '—'}
          </div>
          <div className="stat-hint text-muted">
            {isLive && liveEnvelopes?.status === 'empty' ? 'No envelopes defined' : 'Zero-Based Envelope Sum'}
          </div>
        </div>

        <div className="glass-panel macro-stat-card">
          <div className="stat-label">Actual Consumed to Date</div>
          <div className="stat-value mono text-gold">
            {isDataAvailable ? (envelopes.length > 0 ? spentMaster.formatted : '—') : '—'}
          </div>
          <div className="stat-hint text-emerald">
            {isDataAvailable && envelopes.length > 0
              ? `${totalPlannedZar > 0 ? Math.round((totalSpentZar / totalPlannedZar) * 100) : 0}% of Monthly Capital`
              : 'Awaiting spend records'}
          </div>
        </div>

        <div className="glass-panel macro-stat-card">
          <div className="stat-label">Remaining Safe Variance</div>
          <div className={`stat-value mono ${totalVarianceZar >= 0 ? 'text-emerald' : 'text-rose'}`}>
            {isDataAvailable ? (envelopes.length > 0 ? varianceMaster.formatted : '—') : '—'}
          </div>
          <div className="stat-hint text-muted">
            {isDataAvailable && envelopes.length > 0
              ? (totalVarianceZar >= 0 ? 'Surplus Available' : 'Deficit Offset Required')
              : 'No variance to compute'}
          </div>
        </div>
      </div>

      {/* Envelopes Grid or Honest Empty State */}
      {envelopes.length === 0 ? (
        <div className="glass-panel empty-state-card" style={{ padding: '3.5rem 2rem', textAlign: 'center', marginTop: '1.5rem', borderRadius: '12px' }}>
          <PieChart size={44} className="text-muted" style={{ margin: '0 auto 1rem', opacity: 0.6 }} />
          <h3 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>
            {isLive ? 'No Live Budget Envelopes' : 'No Budget Envelopes Defined'}
          </h3>
          <p className="text-muted" style={{ maxWidth: 520, margin: '0 auto', fontSize: '0.9rem', lineHeight: 1.5 }}>
            {isLive
              ? 'Google Sheets fct_budget_allocations tab has no active envelope rows. Once envelope allocations are added to your spreadsheet, real-time consumption and variance meters will display here.'
              : 'Add envelope targets to allocate your income across spending tiers.'}
          </p>
        </div>
      ) : (
        <div className="envelopes-grid">
          {envelopes.map((env) => {
            const plannedConv = convertCurrency(env.plannedAmountZar, 'ZAR', masterCurrency, rates);
            const spentConv = convertCurrency(env.actualSpentZar, 'ZAR', masterCurrency, rates);
            const varianceConv = convertCurrency(env.varianceZar, 'ZAR', masterCurrency, rates);

            const isOver = env.budgetStatus === 'OVER_BUDGET';
            const isNear = env.budgetStatus === 'NEAR_LIMIT';

            return (
              <div key={env.categoryId} className={`glass-panel envelope-card ${isOver ? 'card-over-budget' : ''}`}>
                <div className="envelope-card-top">
                  <div>
                    <div className="env-category-group mono text-muted">{env.categoryGroup}</div>
                    <h4 className="env-title">{env.categoryName}</h4>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    {onUpsertBudget && (
                      <button
                        type="button"
                        className="btn-icon-subtle"
                        title="Edit envelope target"
                        style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', padding: '4px' }}
                        onClick={() => openForEdit(env)}
                      >
                        <Edit3 size={14} />
                      </button>
                    )}
                    {isOver ? (
                      <span className="badge badge-rose">
                        <AlertTriangle size={12} /> OVER BUDGET
                      </span>
                    ) : isNear ? (
                      <span className="badge badge-gold">⚠️ NEAR LIMIT</span>
                    ) : (
                      <span className="badge badge-emerald">
                        <CheckCircle2 size={12} /> ON TRACK
                      </span>
                    )}
                  </div>
                </div>

                {/* Progress Bar */}
                <div className="env-meter-wrap">
                  <div className="meter-track">
                    <div
                      className={`meter-fill ${isOver ? 'bg-rose' : isNear ? 'bg-gold' : 'bg-emerald'}`}
                      style={{ width: `${Math.min(100, env.pctConsumed)}%` }}
                    />
                  </div>
                  <div className="env-pct mono">{env.pctConsumed.toFixed(1)}% Consumed</div>
                </div>

                {/* Card Figures */}
                <div className="env-figures-grid">
                  <div>
                    <div className="fig-label">Target</div>
                    <div className="fig-val mono">{plannedConv.formatted}</div>
                  </div>
                  <div>
                    <div className="fig-label">Spent</div>
                    <div className="fig-val mono text-primary">{spentConv.formatted}</div>
                  </div>
                  <div>
                    <div className="fig-label">Remaining</div>
                    <div className={`fig-val mono ${env.varianceZar >= 0 ? 'text-emerald' : 'text-rose'}`}>
                      {varianceConv.formatted}
                    </div>
                  </div>
                </div>

                <div className="env-footer-meta" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span className="mono text-muted text-xs">Tier: {env.cashFlowTier}</span>
                  {env.isFixedObligation && (
                    <span className="badge badge-indigo badge-compact">Fixed Obligation</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal: Set / Edit Envelope Target */}
      {isModalOpen && (
        <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '1rem' }}>
          <div className="glass-panel" style={{ width: '100%', maxWidth: '500px', maxHeight: '90vh', overflowY: 'auto', padding: '1.5rem', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.1)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h3 style={{ margin: 0, fontSize: '1.2rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Plus size={20} className="text-emerald" /> Set Envelope Target
              </h3>
              <button
                type="button"
                onClick={() => setIsModalOpen(false)}
                style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>

            {formError && (
              <div style={{ padding: '0.6rem 0.8rem', backgroundColor: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: '6px', color: '#f87171', fontSize: '0.85rem', marginBottom: '1rem' }}>
                {formError}
              </div>
            )}

            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Category ID *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. CAT_FOOD_GROCERIES"
                  value={categoryId}
                  onChange={(e) => setCategoryId(e.target.value)}
                  style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Allocation Month (YYYY-MM) *</label>
                  <input
                    type="text"
                    required
                    placeholder="2026-04"
                    value={allocationMonth}
                    onChange={(e) => setAllocationMonth(e.target.value)}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Target Currency</label>
                  <select
                    value={targetCurrency}
                    onChange={(e) => setTargetCurrency(e.target.value as any)}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: '#1e293b', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                  >
                    <option value="ZAR">ZAR</option>
                    <option value="USD">USD</option>
                    <option value="ZIG">ZIG</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Planned Monthly Amount *</label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    required
                    placeholder="0.00"
                    value={plannedAmount}
                    onChange={(e) => setPlannedAmount(e.target.value === '' ? '' : parseFloat(e.target.value))}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Cash Flow Tier</label>
                  <select
                    value={cashFlowTier}
                    onChange={(e) => setCashFlowTier(e.target.value as CashFlowTier)}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: '#1e293b', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                  >
                    <option value="DAILY_SPENDING">Tier 1: Daily</option>
                    <option value="MONTHLY_ALLOCATION">Tier 2: Monthly</option>
                    <option value="LONG_TERM_VAULT">Tier 3: Vault</option>
                  </select>
                </div>
              </div>

              <div>
                <label style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', cursor: 'pointer', fontSize: '0.85rem' }}>
                  <input
                    type="checkbox"
                    checked={isFixedObligation}
                    onChange={(e) => setIsFixedObligation(e.target.checked)}
                  />
                  <span>Fixed Obligation (Non-discretionary essential commitment)</span>
                </label>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Notes / Description</label>
                <input
                  type="text"
                  placeholder="e.g. Monthly groceries allocation"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                />
              </div>

              <div style={{ padding: '0.6rem 0.8rem', background: 'rgba(16, 185, 129, 0.08)', border: '1px solid rgba(16, 185, 129, 0.2)', borderRadius: '6px', fontSize: '0.75rem', color: '#a7f3d0', lineHeight: 1.4 }}>
                <strong>Safe Upsert Semantics:</strong> Target updates are written to <code>fct_budget_allocations</code> keyed by <code>(allocation_month, category_id)</code>. If an envelope already exists for this month, its planned target is updated; otherwise a new allocation row is created. Historic allocation periods remain untouched.
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '0.5rem' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setIsModalOpen(false)}
                  disabled={isSubmitting}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={isSubmitting}
                >
                  {isSubmitting ? 'Saving...' : 'Save Envelope'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

