import React, { useState, useEffect } from 'react';
import './App.css';
import { MasterCurrency, Transaction } from './types/finance';
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
import { financeApi } from './services/api';

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

  // Application Data States (Hydrated with BigQuery authoritative records)
  const [accounts, setAccounts] = useState(INITIAL_ACCOUNTS);
  const [envelopes, setEnvelopes] = useState(INITIAL_ENVELOPES);
  const [transactions, setTransactions] = useState(INITIAL_TRANSACTIONS);
  const [taxSchedule, setTaxSchedule] = useState(INITIAL_TAX_SCHEDULE);
  const [burnMetrics, setBurnMetrics] = useState(INITIAL_BURN_METRICS);
  const [rates, setRates] = useState(DEFAULT_RATES);
  const [isOnline, setIsOnline] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Live BigQuery Hydration
  const fetchLiveData = async () => {
    setIsRefreshing(true);
    try {
      await financeApi.checkHealth();
      
      const [liveRates, liveAccounts, liveTxs, liveEnvelopes, liveTax] = await Promise.allSettled([
        financeApi.getExchangeRates(),
        financeApi.getAccounts(),
        financeApi.getTransactions(100),
        financeApi.getBudgetEnvelopes(),
        financeApi.getTaxSchedule()
      ]);

      if (liveRates.status === 'fulfilled') setRates(liveRates.value);
      if (liveAccounts.status === 'fulfilled' && liveAccounts.value.length > 0) setAccounts(liveAccounts.value);
      if (liveTxs.status === 'fulfilled' && liveTxs.value.length > 0) setTransactions(liveTxs.value);
      if (liveEnvelopes.status === 'fulfilled' && liveEnvelopes.value.length > 0) setEnvelopes(liveEnvelopes.value);
      if (liveTax.status === 'fulfilled' && liveTax.value) setTaxSchedule(liveTax.value);

      setIsOnline(true);
    } catch (err) {
      console.warn('BigQuery backend unreachable, operating in offline/demo mode:', err);
      setIsOnline(false);
    } finally {
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    fetchLiveData();
  }, []);

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
    setTransactions((prev) => [newTx, ...prev]);

    // 1. Update matching Account balance
    setAccounts((prev) =>
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

    // 2. Update matching Budget Envelope
    setEnvelopes((prev) =>
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

    // 3. If Tax Deductible, update Tax Schedule
    if (newTx.isTaxDeductible) {
      setTaxSchedule((prev) => {
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

    // 4. If online, asynchronously persist transaction to BigQuery
    if (isOnline) {
      financeApi.createTransaction(newTx).catch((err) => {
        console.warn('Could not write transaction to BigQuery, keeping local copy:', err);
      });
    }
  };

  const handleManualSync = () => {
    fetchLiveData();
  };

  return (
    <div className="app-container">
      {/* Sidebar Navigation */}
      <Sidebar currentTab={currentTab} onSelectTab={setCurrentTab} />

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
        />

        <main className="page-body">
          {currentTab === 'dashboard' && (
            <DashboardView
              accounts={accounts}
              envelopes={envelopes}
              transactions={transactions}
              masterCurrency={masterCurrency}
              rates={rates}
              burnMetrics={burnMetrics}
              taxSchedule={taxSchedule}
              onNavigate={setCurrentTab}
              onOpenCopilot={() => setIsCopilotOpen(true)}
            />
          )}

          {currentTab === 'accounts' && (
            <AccountsView
              accounts={accounts}
              masterCurrency={masterCurrency}
              rates={rates}
            />
          )}

          {currentTab === 'ledger' && (
            <TransactionsView
              transactions={transactions}
              masterCurrency={masterCurrency}
              rates={rates}
              onAddTransaction={handleAddTransaction}
            />
          )}

          {currentTab === 'debts' && (
            <DebtLedgerView
              masterCurrency={masterCurrency}
            />
          )}

          {currentTab === 'budgets' && (
            <BudgetsView
              envelopes={envelopes}
              masterCurrency={masterCurrency}
              rates={rates}
            />
          )}

          {currentTab === 'tax' && (
            <TaxView
              taxSchedule={taxSchedule}
              transactions={transactions}
              masterCurrency={masterCurrency}
              rates={rates}
            />
          )}

          {currentTab === 'wealth' && (
            <WealthManagementView
              burnMetrics={burnMetrics}
              taxOpportunities={INITIAL_TAX_SHIELD_OPPORTUNITIES}
              arbitrageSignals={INITIAL_ARBITRAGE_SIGNALS}
              investments={INITIAL_INVESTMENTS}
              masterCurrency={masterCurrency}
              rates={rates}
            />
          )}

          {currentTab === 'analytics' && (
            <AnalyticsView
              masterCurrency={masterCurrency}
              rates={rates}
            />
          )}

          {currentTab === 'settings' && (
            <SettingsView
              masterCurrency={masterCurrency}
              onSelectCurrency={handleSelectCurrency}
              isOnline={isOnline}
              onManualSync={handleManualSync}
            />
          )}
        </main>
      </div>

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
      />
    </div>
  );
}

export default App;
