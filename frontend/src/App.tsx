import React, { useState, useEffect, useRef } from 'react';
import './App.css';
import { MasterCurrency, Transaction, Account, BudgetEnvelope } from './types/finance';
import { TopBar } from './components/layout/TopBar';
import { Sidebar, NavTab } from './components/layout/Sidebar';
import { DashboardView } from './components/dashboard/DashboardView';
import { AccountsView } from './components/accounts/AccountsView';
import { TransactionsView } from './components/ledger/TransactionsView';
import { DebtLedgerView } from './components/debts/DebtLedgerView';
import { BudgetsView } from './components/budgets/BudgetsView';
import { TaxView } from './components/tax/TaxView';
import { WealthManagementView } from './components/wealth/WealthManagementView';
import { AnalyticsView } from './components/analytics/AnalyticsView';
import { SettingsView } from './components/settings/SettingsView';
import { ReceiptScanModal } from './components/sync/ReceiptScanModal';
import { GeminiCopilotDrawer } from './components/copilot/GeminiCopilotDrawer';
import { AuthModal } from './components/auth/AuthModal';

import {
  INITIAL_ACCOUNTS,
  INITIAL_ENVELOPES,
  INITIAL_TRANSACTIONS,
  INITIAL_TAX_SCHEDULE,
  INITIAL_BURN_METRICS,
  INITIAL_TAX_SHIELD_OPPORTUNITIES,
  INITIAL_ARBITRAGE_SIGNALS,
  INITIAL_INVESTMENTS
} from './services/mockData';
import { DEFAULT_RATES } from './services/currency';
import { financeApi, UserSession } from './services/api';
import {
  INITIAL_LIVE_ACCOUNTS_STATE,
  LiveAccountsState,
  resolveLiveAccounts,
  selectDisplayedAccounts,
  INITIAL_LIVE_ENVELOPES_STATE,
  LiveEnvelopesState,
  resolveLiveEnvelopes,
  selectDisplayedEnvelopes,
  INITIAL_LIVE_TRANSACTIONS_STATE,
  LiveTransactionsState,
  resolveLiveTransactions,
  selectDisplayedTransactions,
  INITIAL_LIVE_TAX_STATE,
  LiveTaxState,
  resolveLiveTax,
  selectDisplayedTaxSchedule,
  INITIAL_LIVE_BURN_METRICS_STATE,
  LiveBurnMetricsState,
  resolveLiveBurnMetrics,
  selectDisplayedBurnMetrics,
  selectDisplayedTaxOpportunities,
  selectDisplayedArbitrageSignals,
  selectDisplayedInvestments
} from './services/liveData';

export function App() {
  // Master Currency State (Persisted in localStorage)
  const [masterCurrency, setMasterCurrency] = useState<MasterCurrency>(() => {
    const saved = localStorage.getItem('ziva_master_currency');
    return (saved as MasterCurrency) || 'ZAR';
  });

  const handleSelectCurrency = (cur: MasterCurrency) => {
    setMasterCurrency(cur);
    localStorage.setItem('ziva_master_currency', cur);
  };

  // Active Navigation Tab
  const [currentTab, setCurrentTab] = useState<NavTab>('dashboard');

  // Application Data States (Hydrated with Google Sheets authoritative records)
  // Demo fixtures and live records are strictly separated across all domains so demo fixtures never leak into Live mode.
  const [demoAccounts, setDemoAccounts] = useState(INITIAL_ACCOUNTS);
  const [liveAccounts, setLiveAccounts] = useState<LiveAccountsState>(INITIAL_LIVE_ACCOUNTS_STATE);

  const [demoEnvelopes, setDemoEnvelopes] = useState(INITIAL_ENVELOPES);
  const [liveEnvelopes, setLiveEnvelopes] = useState<LiveEnvelopesState>(INITIAL_LIVE_ENVELOPES_STATE);

  const [demoTransactions, setDemoTransactions] = useState(INITIAL_TRANSACTIONS);
  const [liveTransactions, setLiveTransactions] = useState<LiveTransactionsState>(INITIAL_LIVE_TRANSACTIONS_STATE);

  const [demoTaxSchedule, setDemoTaxSchedule] = useState(INITIAL_TAX_SCHEDULE);
  const [liveTaxSchedule, setLiveTaxSchedule] = useState<LiveTaxState>(INITIAL_LIVE_TAX_STATE);

  const [demoBurnMetrics, setDemoBurnMetrics] = useState(INITIAL_BURN_METRICS);
  const [liveBurnMetrics, setLiveBurnMetrics] = useState<LiveBurnMetricsState>(INITIAL_LIVE_BURN_METRICS_STATE);

  const [rates, setRates] = useState(DEFAULT_RATES);
  const [isOnline, setIsOnline] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Owner Authentication & Session State
  const [session, setSession] = useState<UserSession>({ authenticated: false });
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);

  // Mobile Navigation Drawer State
  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);

  // Monotonic id so a slow, superseded fetch can never overwrite newer state
  const fetchSeqRef = useRef(0);

  // Check existing session on initial load (survives iOS PWA reopenings for 30 days)
  useEffect(() => {
    const checkInitialAuth = async () => {
      try {
        const s = await financeApi.checkSession();
        setSession(s);
        if (s.authenticated) {
          setIsOnline(true);
          fetchLiveData();
        }
      } catch (err) {
        console.warn('Initial session check failed:', err);
      }
    };
    checkInitialAuth();
  }, []);

  // Live Google Sheets Hydration (requires authenticated owner session)
  const fetchLiveData = async () => {
    const seq = ++fetchSeqRef.current;
    const isCurrent = () => seq === fetchSeqRef.current;
    setIsRefreshing(true);
    try {
      await financeApi.checkHealth();

      const [liveRates, liveAccountsResult, liveTxs, liveEnvelopesResult, liveTax, liveBurn] = await Promise.allSettled([
        financeApi.getExchangeRates(),
        financeApi.getAccounts(),
        financeApi.getTransactions(100),
        financeApi.getBudgetEnvelopes(),
        financeApi.getTaxSchedule(),
        financeApi.getDailyBurnMetrics()
      ]);
      if (!isCurrent()) return;

      if (liveRates.status === 'fulfilled') setRates(liveRates.value);
      // Live state resolvers: exactly what Google Sheets returned (empty stays empty; failure -> stale/unavailable, never demo)
      setLiveAccounts((prev) => resolveLiveAccounts(liveAccountsResult, prev));
      setLiveEnvelopes((prev) => resolveLiveEnvelopes(liveEnvelopesResult, prev));
      setLiveTransactions((prev) => resolveLiveTransactions(liveTxs, prev));
      setLiveTaxSchedule((prev) => resolveLiveTax(liveTax, prev));
      setLiveBurnMetrics((prev) => resolveLiveBurnMetrics(liveBurn, prev));

      setIsOnline(true);
    } catch (err: any) {
      if (!isCurrent()) return;
      console.warn('Google Sheets live backend unreachable or unauthenticated:', err);
      if (err.message?.includes('401') || err.message?.includes('Unauthorized')) {
        setSession({ authenticated: false });
        setIsAuthModalOpen(true);
      }
    } finally {
      if (isCurrent()) setIsRefreshing(false);
    }
  };

  const handleAuthSuccess = (newSession: UserSession) => {
    setSession(newSession);
    setIsAuthModalOpen(false);
    setIsOnline(true);
    fetchLiveData();
  };

  const handleLogout = async () => {
    await financeApi.logout();
    setSession({ authenticated: false });
    setIsOnline(false); // Switch to Demo mode on logout
    setLiveAccounts(INITIAL_LIVE_ACCOUNTS_STATE); // Clear live state from memory
    setLiveEnvelopes(INITIAL_LIVE_ENVELOPES_STATE);
    setLiveTransactions(INITIAL_LIVE_TRANSACTIONS_STATE);
    setLiveTaxSchedule(INITIAL_LIVE_TAX_STATE);
    setLiveBurnMetrics(INITIAL_LIVE_BURN_METRICS_STATE);
  };

  const handleToggleLiveMode = () => {
    if (isOnline) {
      // Switch from Live to Demo mode
      setIsOnline(false);
    } else {
      // User wants to switch to Live mode: requires authenticated owner
      if (!session.authenticated) {
        setIsAuthModalOpen(true);
      } else {
        setIsOnline(true);
        fetchLiveData();
      }
    }
  };

  // Data rendered by every view: live records in Live mode, demo fixtures only in Demo mode
  const accounts = selectDisplayedAccounts(isOnline, liveAccounts, demoAccounts);
  const envelopes = selectDisplayedEnvelopes(isOnline, liveEnvelopes, demoEnvelopes);
  const transactions = selectDisplayedTransactions(isOnline, liveTransactions, demoTransactions);
  const taxSchedule = selectDisplayedTaxSchedule(isOnline, liveTaxSchedule, demoTaxSchedule);
  const burnMetrics = selectDisplayedBurnMetrics(isOnline, liveBurnMetrics, demoBurnMetrics);
  const taxOpportunities = selectDisplayedTaxOpportunities(isOnline, INITIAL_TAX_SHIELD_OPPORTUNITIES);
  const arbitrageSignals = selectDisplayedArbitrageSignals(isOnline, INITIAL_ARBITRAGE_SIGNALS, rates);
  const investments = selectDisplayedInvestments(isOnline, INITIAL_INVESTMENTS);

  // Modals & Drawers State
  const [isReceiptModalOpen, setIsReceiptModalOpen] = useState(false);
  const [isCopilotOpen, setIsCopilotOpen] = useState(false);

  // Global Keyboard Shortcut: Ctrl+K / Cmd+K toggles Copilot
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setIsCopilotOpen((prev) => !prev);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Handle Ingest of New Transaction (optimistic ledger & balance updates)
  const handleAddTransaction = (newTx: Transaction) => {
    if (isOnline) {
      // 1. Update live transactions
      setLiveTransactions((prev) => ({
        ...prev,
        data: [newTx, ...prev.data],
        status: 'ready'
      }));

      // 2. Update matching live Account balance
      setLiveAccounts((prev) => ({
        ...prev,
        data: prev.data.map((acc) => {
          if (acc.accountId === newTx.accountId) {
            return {
              ...acc,
              nativeBalance: acc.nativeBalance + newTx.originalAmount
            };
          }
          return acc;
        })
      }));

      // 3. Update matching live Budget Envelope
      setLiveEnvelopes((prev) => ({
        ...prev,
        data: prev.data.map((env) => {
          if (env.categoryId === newTx.categoryId) {
            const addedZar = Math.abs(newTx.reportingAmountZar);
            const newSpent = env.actualSpentZar + addedZar;
            const newVariance = env.plannedAmountZar - newSpent;
            const newPct = env.plannedAmountZar > 0 ? (newSpent / env.plannedAmountZar) * 100 : 100;
            return {
              ...env,
              actualSpentZar: newSpent,
              varianceZar: newVariance,
              pctConsumed: newPct,
              budgetStatus: newPct > 100 ? 'OVER_BUDGET' : newPct >= 90 ? 'NEAR_LIMIT' : 'ON_TRACK'
            };
          }
          return env;
        })
      }));

      // 4. Asynchronously persist transaction to Google Sheets (ONLY in Live mode)
      financeApi.createTransaction(newTx).catch((err) => {
        console.warn('Could not write transaction to Google Sheets, keeping local copy:', err);
      });
    } else {
      // Demo Mode updates: strictly update demo state, NEVER write to Google Sheets!
      setDemoTransactions((prev) => [newTx, ...prev]);
      setDemoAccounts((prev) =>
        prev.map((acc) => {
          if (acc.accountId === newTx.accountId) {
            return {
              ...acc,
              nativeBalance: acc.nativeBalance + newTx.originalAmount
            };
          }
          return acc;
        })
      );
      setDemoEnvelopes((prev) =>
        prev.map((env) => {
          if (env.categoryId === newTx.categoryId) {
            const addedZar = Math.abs(newTx.reportingAmountZar);
            const newSpent = env.actualSpentZar + addedZar;
            const newVariance = env.plannedAmountZar - newSpent;
            const newPct = env.plannedAmountZar > 0 ? (newSpent / env.plannedAmountZar) * 100 : 100;
            return {
              ...env,
              actualSpentZar: newSpent,
              varianceZar: newVariance,
              pctConsumed: newPct,
              budgetStatus: newPct > 100 ? 'OVER_BUDGET' : newPct >= 90 ? 'NEAR_LIMIT' : 'ON_TRACK'
            };
          }
          return env;
        })
      );

      // If Tax Deductible, update Demo Tax Schedule
      if (newTx.isTaxDeductible) {
        setDemoTaxSchedule((prev) => {
          const offsetZar = Math.abs(newTx.reportingAmountZar);
          const newAllowableDeductions = prev.totalAllowableDeductionsZar + offsetZar;
          const newNetTaxable = Math.max(0, prev.grossTaxableInflowZar - newAllowableDeductions);
          const newEstimatedTax = parseFloat((newNetTaxable * prev.effectiveTaxRate).toFixed(2));
          const newOutstanding = parseFloat((newEstimatedTax - prev.actualTaxPaidZar).toFixed(2));

          return {
            ...prev,
            productivityExpensesOffsetZar: prev.productivityExpensesOffsetZar + offsetZar,
            totalAllowableDeductionsZar: newAllowableDeductions,
            netTaxableIncomeZar: newNetTaxable,
            estimatedTaxLiabilityZar: newEstimatedTax,
            netTaxOutstandingZar: newOutstanding,
            taxSettlementStatus: newOutstanding <= 0 ? 'SETTLED' : 'PAYMENT_PENDING',
            taxDeductibleCount: prev.taxDeductibleCount + 1
          };
        });
      }
    }
  };

  const handleDeleteTransaction = async (id: string) => {
    if (isOnline) {
      const prevLiveTransactions = liveTransactions;
      setLiveTransactions((prev) => ({
        ...prev,
        data: prev.data.filter((t) => t.transactionId !== id)
      }));

      try {
        await financeApi.deleteTransaction(id);
      } catch (err: any) {
        console.error('Failed to delete live transaction:', err);
        setLiveTransactions(prevLiveTransactions); // Rollback
        alert(`Failed to delete transaction from Google Sheets: ${err.message || 'Server error'}`);
      }
    } else {
      setDemoTransactions((prev) => prev.filter((t) => t.transactionId !== id));
    }
  };

  const handleCreateAccount = async (accountData: Partial<Account>) => {
    if (isOnline) {
      await financeApi.createAccount(accountData);
      const updated = await financeApi.getAccounts();
      setLiveAccounts((prev) => ({
        ...prev,
        status: 'ready',
        data: updated,
        verifiedAt: new Date().toISOString()
      }));
    } else {
      const countryCode = accountData.countryCode || 'ZA';
      const cleanName = (accountData.accountName || '').replace(/[^a-zA-Z0-9]/g, '_').toUpperCase();
      const newAcc: Account = {
        accountId: `ACC_${countryCode}_${cleanName.slice(0, 15)}_${Date.now().toString().slice(-4)}`,
        accountName: accountData.accountName || 'New Account',
        financialInstitution: accountData.financialInstitution || 'Primary Bank',
        countryCode: (accountData.countryCode || 'ZA') as 'ZA' | 'ZW',
        primaryCurrency: accountData.primaryCurrency || 'ZAR',
        cashFlowTier: accountData.cashFlowTier || 'DAILY_SPENDING',
        accountType: accountData.accountType || 'CHECKING',
        isVaultLocked: Boolean(accountData.isVaultLocked),
        withdrawalNoticeDays: accountData.withdrawalNoticeDays || 0,
        accountNumberMasked: accountData.accountNumberMasked || '...0000',
        nativeBalance: 0,
        isActive: true
      };
      setDemoAccounts((prev) => [newAcc, ...prev]);
    }
  };

  const handleArchiveAccount = async (accountId: string) => {
    if (isOnline) {
      await financeApi.archiveAccount(accountId);
      const updated = await financeApi.getAccounts();
      setLiveAccounts((prev) => ({
        ...prev,
        status: 'ready',
        data: updated,
        verifiedAt: new Date().toISOString()
      }));
    } else {
      setDemoAccounts((prev) => prev.filter((a) => a.accountId !== accountId));
    }
  };

  const handleUpsertBudget = async (allocationData: {
    categoryId: string;
    allocationMonth: string;
    plannedAmount: number;
    targetCurrency?: string;
    cashFlowTier?: string;
    isFixedObligation?: boolean;
    notes?: string;
  }) => {
    if (isOnline) {
      await financeApi.upsertBudgetAllocation(allocationData);
      const updated = await financeApi.getBudgetEnvelopes();
      setLiveEnvelopes((prev) => ({
        ...prev,
        status: 'ready',
        data: updated,
        verifiedAt: new Date().toISOString()
      }));
    } else {
      const plannedZar = allocationData.plannedAmount;
      setDemoEnvelopes((prev) => {
        const idx = prev.findIndex((e) => e.categoryId === allocationData.categoryId);
        if (idx !== -1) {
          const updated = [...prev];
          const curr = updated[idx];
          const variance = plannedZar - curr.actualSpentZar;
          const pct = plannedZar > 0 ? (curr.actualSpentZar / plannedZar) * 100 : 0;
          updated[idx] = {
            ...curr,
            plannedAmountZar: plannedZar,
            varianceZar: variance,
            pctConsumed: pct,
            budgetStatus: pct > 100 ? 'OVER_BUDGET' : pct >= 90 ? 'NEAR_LIMIT' : 'ON_TRACK'
          };
          return updated;
        } else {
          const newEnv: BudgetEnvelope = {
            allocationMonth: allocationData.allocationMonth,
            categoryId: allocationData.categoryId,
            categoryName: allocationData.categoryId,
            categoryGroup: 'LIVING_EXPENSES',
            cashFlowTier: (allocationData.cashFlowTier as any) || 'DAILY_SPENDING',
            targetCurrency: (allocationData.targetCurrency as any) || 'ZAR',
            plannedAmount: plannedZar,
            plannedAmountZar: plannedZar,
            plannedAmountUsd: parseFloat((plannedZar / 18.5).toFixed(2)),
            actualSpentZar: 0,
            actualSpentUsd: 0,
            varianceZar: plannedZar,
            varianceUsd: parseFloat((plannedZar / 18.5).toFixed(2)),
            pctConsumed: 0,
            budgetStatus: 'ON_TRACK',
            isFixedObligation: Boolean(allocationData.isFixedObligation)
          };
          return [...prev, newEnv];
        }
      });
    }
  };

  const handleManualSync = () => {
    fetchLiveData();
  };

  return (
    <div className="app-container">
      {/* Sidebar Navigation */}
      <Sidebar
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        isOpen={isMobileNavOpen}
        onClose={() => setIsMobileNavOpen(false)}
      />

      {/* Main Content Area */}
      <div className="main-content">
        <TopBar
          masterCurrency={masterCurrency}
          onSelectCurrency={handleSelectCurrency}
          rates={rates}
          isOnline={isOnline}
          onOpenReceiptModal={() => setIsReceiptModalOpen(true)}
          onRefresh={fetchLiveData}
          isRefreshing={isRefreshing}
          onOpenCopilot={() => setIsCopilotOpen(true)}
          onToggleNav={() => setIsMobileNavOpen((prev) => !prev)}
          isNavOpen={isMobileNavOpen}
          session={session}
          onOpenAuthModal={() => setIsAuthModalOpen(true)}
          onToggleLiveMode={handleToggleLiveMode}
        />

        <main className="page-body">
          {currentTab === 'dashboard' && (
            <DashboardView
              accounts={accounts}
              isLive={isOnline}
              liveAccounts={liveAccounts}
              envelopes={envelopes}
              transactions={transactions}
              masterCurrency={masterCurrency}
              rates={rates}
              burnMetrics={burnMetrics}
              taxSchedule={taxSchedule}
              investments={investments}
              onNavigate={setCurrentTab}
              onOpenCopilot={() => setIsCopilotOpen(true)}
            />
          )}

          {currentTab === 'accounts' && (
            <AccountsView
              accounts={accounts}
              isLive={isOnline}
              liveAccounts={liveAccounts}
              masterCurrency={masterCurrency}
              rates={rates}
              onCreateAccount={handleCreateAccount}
              onArchiveAccount={handleArchiveAccount}
            />
          )}

          {currentTab === 'ledger' && (
            <TransactionsView
              transactions={transactions}
              masterCurrency={masterCurrency}
              rates={rates}
              onAddTransaction={handleAddTransaction}
              onDeleteTransaction={handleDeleteTransaction}
              accounts={accounts}
              isLive={isOnline}
              liveTransactions={liveTransactions}
            />
          )}

          {currentTab === 'debts' && (
            <DebtLedgerView
              masterCurrency={masterCurrency}
              rates={rates}
              isLive={isOnline}
            />
          )}

          {currentTab === 'budgets' && (
            <BudgetsView
              envelopes={envelopes}
              masterCurrency={masterCurrency}
              rates={rates}
              isLive={isOnline}
              liveEnvelopes={liveEnvelopes}
              onUpsertBudget={handleUpsertBudget}
            />
          )}

          {currentTab === 'tax' && (
            <TaxView
              taxSchedule={taxSchedule}
              transactions={transactions}
              masterCurrency={masterCurrency}
              rates={rates}
              isLive={isOnline}
              liveTax={liveTaxSchedule}
            />
          )}

          {currentTab === 'wealth' && (
            <WealthManagementView
              burnMetrics={burnMetrics}
              taxOpportunities={taxOpportunities}
              arbitrageSignals={arbitrageSignals}
              investments={investments}
              masterCurrency={masterCurrency}
              rates={rates}
              isLive={isOnline}
              liveBurnMetrics={liveBurnMetrics}
              envelopes={envelopes}
              transactions={transactions}
            />
          )}

          {currentTab === 'analytics' && (
            <AnalyticsView
              masterCurrency={masterCurrency}
              rates={rates}
              isLive={isOnline}
            />
          )}

          {currentTab === 'settings' && (
            <SettingsView
              masterCurrency={masterCurrency}
              onSelectCurrency={handleSelectCurrency}
              isOnline={isOnline}
              onManualSync={handleManualSync}
              session={session}
              onLogout={handleLogout}
            />
          )}
        </main>
      </div>

      {/* Owner Authentication Modal */}
      <AuthModal
        isOpen={isAuthModalOpen}
        onSuccess={handleAuthSuccess}
        onSwitchToDemo={() => {
          setIsAuthModalOpen(false);
          setIsOnline(false);
        }}
      />

      {/* Receipt Camera & Archiving Modal */}
      <ReceiptScanModal
        isOpen={isReceiptModalOpen}
        onClose={() => setIsReceiptModalOpen(false)}
        onSaveReceiptTransaction={handleAddTransaction}
      />

      {/* Gemini AI Financial Copilot Drawer */}
      <GeminiCopilotDrawer
        isOpen={isCopilotOpen}
        onClose={() => setIsCopilotOpen(false)}
        masterCurrency={masterCurrency}
        rates={rates}
        isLive={isOnline}
      />
    </div>
  );
}

export default App;
