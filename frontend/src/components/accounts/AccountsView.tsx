import React, { useState } from 'react';
import { Account, MasterCurrency, ExchangeRates, CashFlowTier, CurrencyCode } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { Lock, Unlock, ShieldAlert, CreditCard, Landmark, Wallet, CheckCircle2, Plus, Archive, X, AlertTriangle } from 'lucide-react';
import { LiveAccountsState, describeTierInstitutions, hasDisplayableBalances } from '../../services/liveData';
import { LiveAccountsNotice } from './LiveAccountsNotice';

interface AccountsViewProps {
  accounts: Account[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  /** True when the top bar shows "Google Sheets Live". */
  isLive?: boolean;
  liveAccounts?: LiveAccountsState;
  onCreateAccount?: (accountData: Partial<Account>) => Promise<void>;
  onArchiveAccount?: (accountId: string) => Promise<void>;
}

export const AccountsView: React.FC<AccountsViewProps> = ({
  accounts,
  masterCurrency,
  rates,
  isLive = false,
  liveAccounts,
  onCreateAccount,
  onArchiveAccount
}) => {
  const [selectedTier, setSelectedTier] = useState<CashFlowTier | 'ALL'>('ALL');
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // New Account form state
  const [newAccountName, setNewAccountName] = useState('');
  const [newInstitution, setNewInstitution] = useState('');
  const [newCountryCode, setNewCountryCode] = useState<'ZA' | 'ZW'>('ZA');
  const [newCurrency, setNewCurrency] = useState<CurrencyCode>('ZAR');
  const [newCashFlowTier, setNewCashFlowTier] = useState<CashFlowTier>('DAILY_SPENDING');
  const [newAccountType, setNewAccountType] = useState<Account['accountType']>('CHECKING');
  const [newIsVaultLocked, setNewIsVaultLocked] = useState(false);
  const [newNoticeDays, setNewNoticeDays] = useState(0);
  const [newMaskedNumber, setNewMaskedNumber] = useState('');

  // Archive confirmation state
  const [archiveTarget, setArchiveTarget] = useState<Account | null>(null);
  const [isArchiving, setIsArchiving] = useState(false);

  const handleCreateSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAccountName.trim()) {
      setFormError('Account name is required');
      return;
    }
    if (!onCreateAccount) return;

    try {
      setIsSubmitting(true);
      setFormError(null);
      await onCreateAccount({
        accountName: newAccountName.trim(),
        financialInstitution: newInstitution.trim() || 'Primary Bank',
        countryCode: newCountryCode,
        primaryCurrency: newCurrency,
        cashFlowTier: newCashFlowTier,
        accountType: newAccountType,
        isVaultLocked: newIsVaultLocked,
        withdrawalNoticeDays: newIsVaultLocked ? newNoticeDays : 0,
        accountNumberMasked: newMaskedNumber.trim() || '...0000'
      });
      setIsCreateOpen(false);
      setNewAccountName('');
      setNewInstitution('');
      setNewMaskedNumber('');
    } catch (err: any) {
      setFormError(err.message || 'Failed to create account');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleArchiveConfirm = async () => {
    if (!archiveTarget || !onArchiveAccount) return;
    try {
      setIsArchiving(true);
      await onArchiveAccount(archiveTarget.accountId);
      setArchiveTarget(null);
    } catch (err: any) {
      alert(`Failed to archive account: ${err.message || 'Server error'}`);
    } finally {
      setIsArchiving(false);
    }
  };

  const showBalances = !liveAccounts || hasDisplayableBalances(isLive, liveAccounts);
  const formatTotal = (amount: number) =>
    showBalances ? convertCurrency(amount, masterCurrency, masterCurrency, rates).formatted : '—';

  const tiers: { id: CashFlowTier | 'ALL'; label: string; desc: string }[] = [
    { id: 'ALL', label: 'All Accounts', desc: 'Consolidated portfolio view' },
    { id: 'DAILY_SPENDING', label: 'Tier 1: Daily Spending', desc: 'Cheque & mobile wallets' },
    { id: 'MONTHLY_ALLOCATION', label: 'Tier 2: Monthly Staging', desc: 'Fixed bills & rent accounts' },
    { id: 'LONG_TERM_VAULT', label: 'Tier 3: Long-Term Vault', desc: '32-day notices & equity brokers' }
  ];

  const filteredAccounts = selectedTier === 'ALL'
    ? accounts
    : accounts.filter((a) => a.cashFlowTier === selectedTier);

  // Calculate totals per tier
  const tierTotals = accounts.reduce(
    (acc, a) => {
      const conv = convertCurrency(a.nativeBalance, a.primaryCurrency, masterCurrency, rates);
      acc[a.cashFlowTier] = (acc[a.cashFlowTier] || 0) + conv.amount;
      acc.TOTAL += conv.amount;
      return acc;
    },
    { DAILY_SPENDING: 0, MONTHLY_ALLOCATION: 0, LONG_TERM_VAULT: 0, TOTAL: 0 }
  );

  return (
    <div className="accounts-view animate-fade-in">
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h2>Accounts & Cash Flow Tiers</h2>
          <p className="page-subtitle">
            Master register of financial institutions segregated into operational, fixed envelope, and protected wealth vaults.
          </p>
        </div>
        {onCreateAccount && (
          <button
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', whiteSpace: 'nowrap' }}
            onClick={() => setIsCreateOpen(true)}
          >
            <Plus size={16} /> New Account
          </button>
        )}
      </div>

      {isLive && liveAccounts && <LiveAccountsNotice live={liveAccounts} />}

      {/* Tier Summary Cards */}
      <div className="tier-summary-row">
        <div
          className={`glass-panel tier-summary-card ${selectedTier === 'DAILY_SPENDING' ? 'active-tier' : ''}`}
          onClick={() => setSelectedTier('DAILY_SPENDING')}
        >
          <div className="tier-badge-label">TIER 1 • DAILY</div>
          <div className="tier-amount mono">
            {formatTotal(tierTotals.DAILY_SPENDING)}
          </div>
          <div className="tier-caption">{describeTierInstitutions(accounts, 'DAILY_SPENDING')}</div>
        </div>

        <div
          className={`glass-panel tier-summary-card ${selectedTier === 'MONTHLY_ALLOCATION' ? 'active-tier' : ''}`}
          onClick={() => setSelectedTier('MONTHLY_ALLOCATION')}
        >
          <div className="tier-badge-label">TIER 2 • MONTHLY</div>
          <div className="tier-amount mono">
            {formatTotal(tierTotals.MONTHLY_ALLOCATION)}
          </div>
          <div className="tier-caption">{describeTierInstitutions(accounts, 'MONTHLY_ALLOCATION')}</div>
        </div>

        <div
          className={`glass-panel tier-summary-card tier-card-vault ${selectedTier === 'LONG_TERM_VAULT' ? 'active-tier' : ''}`}
          onClick={() => setSelectedTier('LONG_TERM_VAULT')}
        >
          <div className="tier-badge-label text-gold">TIER 3 • VAULT</div>
          <div className="tier-amount mono text-gold">
            {formatTotal(tierTotals.LONG_TERM_VAULT)}
          </div>
          <div className="tier-caption">{describeTierInstitutions(accounts, 'LONG_TERM_VAULT')}</div>
        </div>
      </div>

      {/* Filter Tabs */}
      <div className="filter-pill-bar">
        {tiers.map((t) => (
          <button
            key={t.id}
            className={`filter-pill ${selectedTier === t.id ? 'active' : ''}`}
            onClick={() => setSelectedTier(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Long-Term Vault Holdings Banner (surfacing Tier 3 vault parameters without double-counting) */}
      {selectedTier === 'LONG_TERM_VAULT' && (
        <div className="glass-panel" style={{ padding: '1.25rem', marginBottom: '1.5rem', borderRadius: '12px', border: '1px solid rgba(245, 158, 11, 0.25)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.5rem' }}>
            <Lock size={18} className="text-gold" />
            <h3 style={{ margin: 0, fontSize: '1.05rem', color: '#f59e0b' }}>Long-Term Protected Vault Holdings</h3>
          </div>
          <p style={{ margin: '0 0 1rem', fontSize: '0.85rem', color: '#94a3b8', lineHeight: 1.5 }}>
            Tier 3 assets represent long-term capital preservation, 32-day fixed notice deposits, and brokerage equity balances. These holdings are consolidated into your overall net worth without double-counting liquid operational funds.
          </p>
          <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap' }}>
            <div>
              <span style={{ fontSize: '0.75rem', color: '#64748b' }}>Vault Balance Base:</span>
              <div className="mono" style={{ fontSize: '1.1rem', fontWeight: 600, color: '#f59e0b' }}>
                {formatTotal(tierTotals.LONG_TERM_VAULT)}
              </div>
            </div>
            <div>
              <span style={{ fontSize: '0.75rem', color: '#64748b' }}>Accounts in Vault:</span>
              <div className="mono" style={{ fontSize: '1.1rem', fontWeight: 600 }}>
                {accounts.filter((a) => a.cashFlowTier === 'LONG_TERM_VAULT').length}
              </div>
            </div>
            <div>
              <span style={{ fontSize: '0.75rem', color: '#64748b' }}>Withdrawal Protection:</span>
              <div className="mono" style={{ fontSize: '1.1rem', fontWeight: 600, color: '#10b981' }}>
                {accounts.some((a) => a.cashFlowTier === 'LONG_TERM_VAULT' && a.isVaultLocked) ? 'Notice Window Enforced' : 'Liquid / Notice'}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Accounts Grid */}
      {filteredAccounts.length === 0 && (!isLive || liveAccounts?.status !== 'unavailable') && (
        <div className="glass-panel live-empty-state" id="accounts-empty-state">
          {isLive
            ? (liveAccounts?.status === 'loading'
                ? 'Loading accounts from the live database…'
                : selectedTier === 'ALL'
                  ? 'No accounts exist in the live database yet.'
                  : 'No live accounts in this tier.')
            : 'No accounts in this tier.'}
        </div>
      )}
      <div className="accounts-grid">
        {filteredAccounts.map((acc) => {
          const conv = convertCurrency(acc.nativeBalance, acc.primaryCurrency, masterCurrency, rates);
          return (
            <div key={acc.accountId} className="glass-panel account-card">
              <div className="account-card-top">
                <div className="acc-institution-wrap">
                  <div className="acc-icon-box">
                    {acc.accountType === 'INVESTMENT_BROKER' ? (
                      <Landmark size={20} className="text-gold" />
                    ) : acc.accountType === 'MOBILE_MONEY' ? (
                      <Wallet size={20} className="text-cyan" />
                    ) : (
                      <CreditCard size={20} className="text-emerald" />
                    )}
                  </div>
                  <div>
                    <div className="acc-inst-name">{acc.financialInstitution}</div>
                    <div className="acc-name">{acc.accountName}</div>
                  </div>
                </div>

                <div className="acc-country-flag">
                  {acc.countryCode === 'ZA' ? '🇿🇦' : '🇿🇼'}
                </div>
              </div>

              {/* Account Balance */}
              <div className="acc-balance-block">
                <div className="acc-master-balance mono">
                  {conv.formatted}
                </div>
                <div className="acc-native-sub mono">
                  Native: <strong>{acc.primaryCurrency} {acc.nativeBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}</strong>
                </div>
              </div>

                {/* Security & Notice Parameters */}
                <div className="acc-card-footer" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <div className="acc-tier-pill mono">{acc.cashFlowTier}</div>
                  {acc.isVaultLocked ? (
                    <span className="badge badge-gold" title={`Withdrawal notice: ${acc.withdrawalNoticeDays} days`}>
                      <Lock size={12} /> {acc.withdrawalNoticeDays}d Notice
                    </span>
                  ) : (
                    <span className="badge badge-emerald">
                      <Unlock size={12} /> Liquid 0d
                    </span>
                  )}
                  <span className="acc-mask mono">{acc.accountNumberMasked}</span>
                  {onArchiveAccount && (
                    <button
                      type="button"
                      className="btn-icon-subtle"
                      title={`Archive account ${acc.accountName}`}
                      style={{ marginLeft: 'auto', background: 'transparent', border: 'none', color: '#64748b', cursor: 'pointer', padding: '4px', display: 'flex', alignItems: 'center' }}
                      onClick={(e) => {
                        e.stopPropagation();
                        setArchiveTarget(acc);
                      }}
                    >
                      <Archive size={14} />
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Modal: Create New Financial Account */}
        {isCreateOpen && (
          <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '1rem' }}>
            <div className="glass-panel" style={{ width: '100%', maxWidth: '540px', maxHeight: '90vh', overflowY: 'auto', padding: '1.5rem', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.1)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                <h3 style={{ margin: 0, fontSize: '1.2rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <Plus size={20} className="text-emerald" /> New Financial Account
                </h3>
                <button
                  type="button"
                  onClick={() => setIsCreateOpen(false)}
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

              <form onSubmit={handleCreateSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Account Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Discovery Bank Platinum Cheque"
                    value={newAccountName}
                    onChange={(e) => setNewAccountName(e.target.value)}
                    className="form-control"
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Institution</label>
                    <input
                      type="text"
                      placeholder="e.g. Discovery Bank, Ecocash"
                      value={newInstitution}
                      onChange={(e) => setNewInstitution(e.target.value)}
                      style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Masked Account Number</label>
                    <input
                      type="text"
                      placeholder="e.g. ...8841"
                      value={newMaskedNumber}
                      onChange={(e) => setNewMaskedNumber(e.target.value)}
                      style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Jurisdiction</label>
                    <select
                      value={newCountryCode}
                      onChange={(e) => setNewCountryCode(e.target.value as 'ZA' | 'ZW')}
                      style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: '#1e293b', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                    >
                      <option value="ZA">🇿🇦 South Africa (ZA)</option>
                      <option value="ZW">🇿🇼 Zimbabwe (ZW)</option>
                    </select>
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Primary Currency</label>
                    <select
                      value={newCurrency}
                      onChange={(e) => setNewCurrency(e.target.value as any)}
                      style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: '#1e293b', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                    >
                      <option value="ZAR">ZAR (South African Rand)</option>
                      <option value="USD">USD (US Dollar)</option>
                      <option value="ZiG">ZiG (Zimbabwe Gold)</option>
                    </select>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Cash Flow Tier</label>
                    <select
                      value={newCashFlowTier}
                      onChange={(e) => setNewCashFlowTier(e.target.value as CashFlowTier)}
                      style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: '#1e293b', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                    >
                      <option value="DAILY_SPENDING">Tier 1: Daily Spending</option>
                      <option value="MONTHLY_ALLOCATION">Tier 2: Monthly Allocation</option>
                      <option value="LONG_TERM_VAULT">Tier 3: Long-Term Vault</option>
                    </select>
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Account Type</label>
                    <select
                      value={newAccountType}
                      onChange={(e) => setNewAccountType(e.target.value as any)}
                      style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', background: '#1e293b', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                    >
                      <option value="CHECKING">Checking / Cheque</option>
                      <option value="SAVINGS">Savings Account</option>
                      <option value="MOBILE_MONEY">Mobile Money Wallet</option>
                      <option value="INVESTMENT_BROKER">Investment Brokerage</option>
                      <option value="PHYSICAL_CASH">Physical Cash</option>
                    </select>
                  </div>
                </div>

                <div style={{ padding: '0.8rem', backgroundColor: 'rgba(255,255,255,0.03)', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.05)' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', cursor: 'pointer', fontSize: '0.85rem' }}>
                    <input
                      type="checkbox"
                      checked={newIsVaultLocked}
                      onChange={(e) => setNewIsVaultLocked(e.target.checked)}
                    />
                    <span>Enforce Withdrawal Notice Window (Vault Protection)</span>
                  </label>
                  {newIsVaultLocked && (
                    <div style={{ marginTop: '0.6rem' }}>
                      <label style={{ display: 'block', fontSize: '0.8rem', color: '#94a3b8', marginBottom: '0.3rem' }}>Notice Days Required</label>
                      <input
                        type="number"
                        min="1"
                        max="365"
                        value={newNoticeDays}
                        onChange={(e) => setNewNoticeDays(parseInt(e.target.value || '0', 10))}
                        style={{ width: '100px', padding: '0.4rem', borderRadius: '6px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', color: '#fff' }}
                      />
                    </div>
                  )}
                </div>

                <div style={{ padding: '0.6rem 0.8rem', background: 'rgba(16, 185, 129, 0.08)', border: '1px solid rgba(16, 185, 129, 0.2)', borderRadius: '6px', fontSize: '0.75rem', color: '#a7f3d0', lineHeight: 1.4 }}>
                  <strong>Ledger Grounding:</strong> Balances are derived dynamically from recorded transactions in Google Sheets. Registering an account appends its metadata to <code>dim_accounts</code> without fabricating artificial opening balance transactions.
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '0.5rem' }}>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={() => setIsCreateOpen(false)}
                    disabled={isSubmitting}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={isSubmitting}
                  >
                    {isSubmitting ? 'Registering...' : 'Register Account'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal: Archive Account Confirmation */}
        {archiveTarget && (
          <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '1rem' }}>
            <div className="glass-panel" style={{ width: '100%', maxWidth: '460px', padding: '1.5rem', borderRadius: '12px', border: '1px solid rgba(239,68,68,0.3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
                <div style={{ width: 36, height: 36, borderRadius: '50%', backgroundColor: 'rgba(239,68,68,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ef4444' }}>
                  <AlertTriangle size={20} />
                </div>
                <h3 style={{ margin: 0, fontSize: '1.15rem' }}>Archive Account</h3>
              </div>

              <p style={{ fontSize: '0.9rem', color: '#cbd5e1', lineHeight: 1.5, marginBottom: '1rem' }}>
                Are you sure you want to archive <strong>{archiveTarget.accountName}</strong> (<code>{archiveTarget.accountId}</code>)?
              </p>

              <div style={{ padding: '0.75rem', backgroundColor: 'rgba(255,255,255,0.03)', borderRadius: '8px', fontSize: '0.8rem', color: '#94a3b8', lineHeight: 1.4, marginBottom: '1.5rem' }}>
                <strong>Integrity Protection:</strong> Archiving sets <code>is_active = false</code> in <code>dim_accounts</code>. All historical transactions referencing this account remain safely intact in <code>fct_transactions</code>.
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setArchiveTarget(null)}
                  disabled={isArchiving}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="btn btn-danger"
                  style={{ backgroundColor: '#dc2626', borderColor: '#b91c1c' }}
                  onClick={handleArchiveConfirm}
                  disabled={isArchiving}
                >
                  {isArchiving ? 'Archiving...' : 'Confirm Archive'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  };
