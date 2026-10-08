import React, { useState } from 'react';
import { Account, MasterCurrency, ExchangeRates, CashFlowTier } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { Lock, Unlock, ShieldAlert, CreditCard, Landmark, Wallet, CheckCircle2 } from 'lucide-react';
import { LiveAccountsState, describeTierInstitutions, hasDisplayableBalances } from '../../services/liveData';
import { LiveAccountsNotice } from './LiveAccountsNotice';

interface AccountsViewProps {
  accounts: Account[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  /** True when the top bar shows "BigQuery Live". */
  isLive?: boolean;
  liveAccounts?: LiveAccountsState;
}

export const AccountsView: React.FC<AccountsViewProps> = ({ accounts, masterCurrency, rates, isLive = false, liveAccounts }) => {
  const [selectedTier, setSelectedTier] = useState<CashFlowTier | 'ALL'>('ALL');
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
      <div className="page-header">
        <div>
          <h2>Accounts & Cash Flow Tiers</h2>
          <p className="page-subtitle">
            Master register of financial institutions segregated into operational, fixed envelope, and protected wealth vaults.
          </p>
        </div>
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
              <div className="acc-card-footer">
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
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
