import React, { useState } from 'react';
import { Transaction, MasterCurrency, ExchangeRates, CurrencyCode, Account } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { Search, Plus, Filter, ArrowUpRight, ArrowDownLeft, FileText, CheckCircle, Trash2, Sliders, Sparkles } from 'lucide-react';
import type { LiveTransactionsState } from '../../services/liveData';
import { LiveStatusNotice } from '../common/LiveStatusNotice';

interface TransactionsViewProps {
  transactions: Transaction[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  onAddTransaction: (tx: Transaction) => void;
  onDeleteTransaction?: (id: string) => Promise<void> | void;
  isLive?: boolean;
  liveTransactions?: LiveTransactionsState;
  accounts?: Account[];
}

const STANDARD_CATEGORIES = [
  { id: 'CAT_DAILY_GROCERIES', name: 'Groceries & Household Supplies', tier: 'DAILY_SPENDING', deductible: false },
  { id: 'CAT_DAILY_DINING', name: 'Restaurants, Takeaways & Coffee', tier: 'DAILY_SPENDING', deductible: false },
  { id: 'CAT_DAILY_TRANSPORT', name: 'Fuel, Rideshare & Commute', tier: 'DAILY_SPENDING', deductible: false },
  { id: 'CAT_PROD_TECH_HARDWARE', name: 'Productivity Tech & Hardware', tier: 'DAILY_SPENDING', deductible: true },
  { id: 'CAT_PROD_SOFTWARE_TOOLS', name: 'Software, AI Subscriptions & SaaS', tier: 'DAILY_SPENDING', deductible: true },
  { id: 'CAT_ALLOC_INTERNET', name: 'Home Office Fibre & Internet', tier: 'MONTHLY_ALLOCATION', deductible: true },
  { id: 'CAT_ALLOC_HOUSING', name: 'Rent & Levies', tier: 'MONTHLY_ALLOCATION', deductible: false },
  { id: 'CAT_ALLOC_UTILITIES', name: 'Electricity & Municipal Water', tier: 'MONTHLY_ALLOCATION', deductible: false },
  { id: 'CAT_DEBT_REPAYMENT', name: 'Debt & Facility Repayment', tier: 'MONTHLY_ALLOCATION', deductible: false },
  { id: 'CAT_TAX_STATUTORY_PROVISIONAL', name: 'Provisional Tax Remittance (SARS/ZIMRA)', tier: 'MONTHLY_ALLOCATION', deductible: false },
  { id: 'CAT_INC_CONSULTING', name: 'Consulting & Software Revenue', tier: 'DAILY_SPENDING', isIncome: true, deductible: false },
  { id: 'CAT_INC_SALARY', name: 'Retainer / Salary Inflow', tier: 'DAILY_SPENDING', isIncome: true, deductible: false },
  { id: 'CAT_DISC_GENERAL', name: 'General Discretionary & Lifestyle', tier: 'DAILY_SPENDING', deductible: false }
];

export const TransactionsView: React.FC<TransactionsViewProps> = ({
  transactions,
  masterCurrency,
  rates,
  onAddTransaction,
  onDeleteTransaction,
  isLive = false,
  liveTransactions,
  accounts = []
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCurrency, setSelectedCurrency] = useState<CurrencyCode | 'ALL'>('ALL');
  const [onlyTaxDeductible, setOnlyTaxDeductible] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);
  const [entryMode, setEntryMode] = useState<'nlp' | 'structured'>('structured');
  const [isDeletingId, setIsDeletingId] = useState<string | null>(null);

  // Quick NLP Ingest State
  const [nlpInput, setNlpInput] = useState('');

  // Structured Form State
  const [structMerchant, setStructMerchant] = useState('');
  const [structAmount, setStructAmount] = useState('');
  const [structCurrency, setStructCurrency] = useState<CurrencyCode>('ZAR');
  const [structType, setStructType] = useState<'EXPENSE' | 'INCOME' | 'INTERNAL_TRANSFER'>('EXPENSE');
  const [structAccount, setStructAccount] = useState('');
  const [structCategory, setStructCategory] = useState(STANDARD_CATEGORIES[0].id);
  const [structDate, setStructDate] = useState(new Date().toISOString().split('T')[0]);
  const [structIsTax, setStructIsTax] = useState(false);
  const [structInvoiceRef, setStructInvoiceRef] = useState('');
  const [structNotes, setStructNotes] = useState('');
  const [formError, setFormError] = useState<string | null>(null);

  const filteredTransactions = transactions.filter((tx) => {
    const matchesSearch =
      tx.merchantOrPayee.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (tx.categoryName && tx.categoryName.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (tx.taxInvoiceNumber && tx.taxInvoiceNumber.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (tx.notes && tx.notes.toLowerCase().includes(searchTerm.toLowerCase()));

    const matchesCurrency = selectedCurrency === 'ALL' || tx.originalCurrency === selectedCurrency;
    const matchesTax = !onlyTaxDeductible || tx.isTaxDeductible;

    return matchesSearch && matchesCurrency && matchesTax;
  });

  // Resolve dynamic account for quick NLP spend without hardcoded IDs
  const resolveAccountForCurrency = (curr: CurrencyCode) => {
    const matching = accounts.find((a) => a.primaryCurrency === curr && a.isActive);
    if (matching) return matching.accountId;
    if (accounts.length > 0) return accounts[0].accountId;
    return curr === 'USD' ? 'ACC_ZW_ECOCASH_USD' : curr === 'ZiG' ? 'ACC_ZW_ECOCASH_ZIG' : 'ACC_ZA_CAPITEC_DAILY';
  };

  const handleQuickSpend = (e: React.FormEvent) => {
    e.preventDefault();
    if (!nlpInput.trim()) return;

    const text = nlpInput.trim();
    const isWork = /work|hardware|laptop|monitor|screen|ai|claude|chatgpt/i.test(text);
    const invoiceMatch = text.match(/(?:inv|ref|receipt)[\s:#-]+([A-Za-z0-9_-]+)/i);

    let amount = 100;
    const numMatch = text.match(/(\d+(?:\.\d{1,2})?)/);
    if (numMatch) amount = parseFloat(numMatch[1]);

    let currency: CurrencyCode = 'ZAR';
    if (/usd|\$/i.test(text)) currency = 'USD';
    else if (/zig/i.test(text)) currency = 'ZiG';

    const accountId = resolveAccountForCurrency(currency);

    const newTx: Transaction = {
      transactionId: `TX_UI_${Date.now().toString().slice(-6)}`,
      transactionTimestamp: new Date().toISOString(),
      transactionDate: new Date().toISOString().split('T')[0],
      localTimezone: 'Africa/Johannesburg',
      accountId,
      cashFlowTier: 'DAILY_SPENDING',
      categoryId: isWork ? 'CAT_PROD_TECH_HARDWARE' : 'CAT_DAILY_DINING',
      categoryName: isWork ? 'Productivity Tech & Work Hardware' : 'Restaurants, Takeaways & Coffee',
      transactionType: 'EXPENSE',
      originalAmount: -amount,
      originalCurrency: currency,
      reportingAmountUsd: currency === 'USD' ? -amount : -amount * rates.ZAR_TO_USD,
      reportingAmountZar: currency === 'ZAR' ? -amount : -amount * rates.USD_TO_ZAR,
      appliedExchangeRateUsd: rates.ZAR_TO_USD,
      appliedExchangeRateZar: 1.0,
      rateTypeApplied: 'OFFICIAL_INTERBANK',
      merchantOrPayee: text.replace(/spent|paid|bought|for|on/gi, '').trim() || 'Direct Expense',
      paymentMethod: 'DEBIT_CARD',
      isTaxDeductible: isWork,
      taxDeductibleAmountZar: isWork ? amount : undefined,
      taxInvoiceNumber: invoiceMatch ? invoiceMatch[1] : undefined,
      tags: ['ui-ingest', currency.toLowerCase(), isWork ? 'tax-deductible' : 'personal'],
      isSynced: true
    };

    onAddTransaction(newTx);
    setNlpInput('');
    setShowAddForm(false);
  };

  const handleStructuredSpend = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    const numAmount = parseFloat(structAmount);
    if (isNaN(numAmount) || numAmount <= 0) {
      setFormError('Please enter a valid amount greater than 0.');
      return;
    }

    if (!structMerchant.trim()) {
      setFormError('Payee / Merchant name is required.');
      return;
    }

    const selectedAcc = accounts.find((a) => a.accountId === structAccount) || accounts[0];
    const accId = selectedAcc ? selectedAcc.accountId : resolveAccountForCurrency(structCurrency);
    const cat = STANDARD_CATEGORIES.find((c) => c.id === structCategory) || STANDARD_CATEGORIES[0];

    const signedAmount = structType === 'INCOME' ? Math.abs(numAmount) : -Math.abs(numAmount);

    const newTx: Transaction = {
      transactionId: `TX_UI_${Date.now().toString().slice(-6)}`,
      transactionTimestamp: new Date().toISOString(),
      transactionDate: structDate,
      localTimezone: 'Africa/Johannesburg',
      accountId: accId,
      cashFlowTier: (selectedAcc?.cashFlowTier || cat.tier || 'DAILY_SPENDING') as any,
      categoryId: cat.id,
      categoryName: cat.name,
      transactionType: structType,
      originalAmount: signedAmount,
      originalCurrency: structCurrency,
      reportingAmountUsd: structCurrency === 'USD' ? signedAmount : signedAmount * rates.ZAR_TO_USD,
      reportingAmountZar: structCurrency === 'ZAR' ? signedAmount : signedAmount * rates.USD_TO_ZAR,
      appliedExchangeRateUsd: rates.ZAR_TO_USD,
      appliedExchangeRateZar: 1.0,
      rateTypeApplied: 'OFFICIAL_INTERBANK',
      merchantOrPayee: structMerchant.trim(),
      paymentMethod: 'DEBIT_CARD',
      isTaxDeductible: structIsTax,
      taxDeductibleAmountZar: structIsTax ? Math.abs(numAmount) : undefined,
      taxInvoiceNumber: structInvoiceRef.trim() || undefined,
      notes: structNotes.trim() || undefined,
      tags: ['structured-ui', structCurrency.toLowerCase(), structIsTax ? 'tax-deductible' : 'personal'],
      isSynced: true
    };

    onAddTransaction(newTx);
    setStructMerchant('');
    setStructAmount('');
    setStructInvoiceRef('');
    setStructNotes('');
    setShowAddForm(false);
  };

  const handleDelete = async (tx: Transaction) => {
    const confirmed = window.confirm(
      `Are you sure you want to delete the transaction "${tx.merchantOrPayee}" (${tx.originalCurrency} ${Math.abs(tx.originalAmount).toFixed(2)}) on ${tx.transactionDate}?\n\nThis will permanently remove the record from Google Sheets.`
    );
    if (!confirmed) return;

    if (onDeleteTransaction) {
      setIsDeletingId(tx.transactionId);
      try {
        await onDeleteTransaction(tx.transactionId);
      } finally {
        setIsDeletingId(null);
      }
    }
  };

  return (
    <div className="transactions-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>Financial Transaction Ledger</h2>
          <p className="page-subtitle">
            Unified multi-account double-entry ledger recorded in Google Sheets.
          </p>
        </div>
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => setShowAddForm(!showAddForm)}
        >
          <Plus size={16} />
          <span>Log Spend</span>
        </button>
      </div>

      {isLive && liveTransactions && (
        <LiveStatusNotice
          status={liveTransactions.status}
          verifiedAt={liveTransactions.verifiedAt}
          error={liveTransactions.error}
          entityName="transactions"
          emptyMessage="The live database returned no transactions from the fct_transactions tab. Ingested expenses and income will appear here."
          idPrefix="live-transactions"
        />
      )}

      {/* Add Transaction Form (Structured + NLP toggle) */}
      {showAddForm && (
        <div className="glass-panel" style={{ padding: '1.5rem', marginBottom: '1.5rem', borderRadius: '12px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem', borderBottom: '1px solid rgba(255,255,255,0.06)', paddingBottom: '0.75rem' }}>
            <h4 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>Record Ledger Transaction</h4>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button
                type="button"
                className={`filter-pill-sm ${entryMode === 'structured' ? 'active' : ''}`}
                onClick={() => setEntryMode('structured')}
              >
                Structured Entry
              </button>
              <button
                type="button"
                className={`filter-pill-sm ${entryMode === 'nlp' ? 'active' : ''}`}
                onClick={() => setEntryMode('nlp')}
              >
                Natural Language (Quick)
              </button>
            </div>
          </div>

          {formError && (
            <div style={{ padding: '0.6rem 0.8rem', background: 'rgba(239,68,68,0.1)', color: '#fca5a5', borderRadius: '6px', fontSize: '0.85rem', marginBottom: '1rem' }}>
              {formError}
            </div>
          )}

          {entryMode === 'nlp' ? (
            <form onSubmit={handleQuickSpend} className="quick-spend-form" style={{ padding: 0 }}>
              <div className="input-group">
                <input
                  type="text"
                  className="nlp-input mono"
                  placeholder="e.g. Spent 4500 ZAR standing desk for work invoice INV-WORK-771"
                  value={nlpInput}
                  onChange={(e) => setNlpInput(e.target.value)}
                  autoFocus
                />
                <button type="submit" className="btn btn-primary">
                  Ingest to Warehouse
                </button>
              </div>
              <div className="form-hint" style={{ marginTop: '0.75rem' }}>
                💡 Type natural language phrases with currencies (<code>ZAR</code>, <code>USD</code>, <code>ZiG</code>) and invoice references to automatically trigger tax deductions.
              </div>
            </form>
          ) : (
            <form onSubmit={handleStructuredSpend}>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1rem' }}>
                <div>
                  <label className="form-label" style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '0.25rem' }}>Payee / Merchant</label>
                  <input
                    type="text"
                    className="form-input"
                    placeholder="e.g. Takealot, AWS, Woolworths"
                    value={structMerchant}
                    onChange={(e) => setStructMerchant(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '0.25rem' }}>Amount</label>
                  <input
                    type="number"
                    step="0.01"
                    min="0.01"
                    className="form-input mono"
                    placeholder="0.00"
                    value={structAmount}
                    onChange={(e) => setStructAmount(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '0.25rem' }}>Currency</label>
                  <select
                    className="form-input mono"
                    value={structCurrency}
                    onChange={(e) => setStructCurrency(e.target.value as CurrencyCode)}
                  >
                    <option value="ZAR">🇿🇦 ZAR</option>
                    <option value="USD">🇺🇸 USD</option>
                    <option value="ZiG">🇿🇼 ZiG</option>
                  </select>
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '0.25rem' }}>Transaction Type</label>
                  <select
                    className="form-input"
                    value={structType}
                    onChange={(e) => setStructType(e.target.value as any)}
                  >
                    <option value="EXPENSE">Expense</option>
                    <option value="INCOME">Income / Revenue</option>
                    <option value="INTERNAL_TRANSFER">Transfer</option>
                  </select>
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '0.25rem' }}>Account</label>
                  <select
                    className="form-input mono"
                    value={structAccount}
                    onChange={(e) => setStructAccount(e.target.value)}
                  >
                    {accounts.length > 0 ? (
                      accounts.map((a) => (
                        <option key={a.accountId} value={a.accountId}>
                          {a.accountName} ({a.primaryCurrency})
                        </option>
                      ))
                    ) : (
                      <option value="">Default {structCurrency} Account</option>
                    )}
                  </select>
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '0.25rem' }}>Category</label>
                  <select
                    className="form-input"
                    value={structCategory}
                    onChange={(e) => {
                      setStructCategory(e.target.value);
                      const cat = STANDARD_CATEGORIES.find((c) => c.id === e.target.value);
                      if (cat && cat.deductible !== undefined) setStructIsTax(cat.deductible);
                    }}
                  >
                    {STANDARD_CATEGORIES.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '0.75rem', color: '#94a3b8', display: 'block', marginBottom: '0.25rem' }}>Date</label>
                  <input
                    type="date"
                    className="form-input mono"
                    value={structDate}
                    onChange={(e) => setStructDate(e.target.value)}
                    required
                  />
                </div>
              </div>

              {/* Tax & Invoice Ref */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '1.5rem', marginBottom: '1rem', padding: '0.75rem', background: 'rgba(255,255,255,0.02)', borderRadius: '6px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', cursor: 'pointer', fontSize: '0.85rem' }}>
                  <input
                    type="checkbox"
                    checked={structIsTax}
                    onChange={(e) => setStructIsTax(e.target.checked)}
                  />
                  <span>💼 Tax Deductible (SARS / ZIMRA Offset)</span>
                </label>

                {structIsTax && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flex: 1 }}>
                    <span style={{ fontSize: '0.75rem', color: '#94a3b8' }}>Invoice Ref:</span>
                    <input
                      type="text"
                      className="form-input mono"
                      placeholder="e.g. INV-2026-991"
                      value={structInvoiceRef}
                      onChange={(e) => setStructInvoiceRef(e.target.value)}
                      style={{ maxWidth: 220, padding: '0.35rem 0.6rem', fontSize: '0.8rem' }}
                    />
                  </div>
                )}
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setShowAddForm(false)}
                >
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Save to Google Sheets
                </button>
              </div>
            </form>
          )}
        </div>
      )}

      {/* Filter Bar */}
      <div className="ledger-controls glass-panel">
        <div className="search-box">
          <Search size={16} className="text-muted" />
          <input
            type="text"
            placeholder="Search merchant, category, or invoice ref..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>

        <div className="controls-right">
          {/* Currency Pill Filter */}
          <div className="currency-filter-pills">
            {(['ALL', 'ZAR', 'USD', 'ZiG'] as (CurrencyCode | 'ALL')[]).map((cur) => (
              <button
                key={cur}
                type="button"
                className={`filter-pill-sm ${selectedCurrency === cur ? 'active' : ''}`}
                onClick={() => setSelectedCurrency(cur)}
              >
                {cur}
              </button>
            ))}
          </div>

          {/* Tax Deductible Toggle */}
          <label className="tax-toggle-label">
            <input
              type="checkbox"
              checked={onlyTaxDeductible}
              onChange={(e) => setOnlyTaxDeductible(e.target.checked)}
            />
            <span>💼 Tax Deductible Only</span>
          </label>
        </div>
      </div>

      {/* Table or Honest Empty State */}
      {transactions.length === 0 ? (
        <div className="glass-panel empty-state-card" style={{ padding: '3.5rem 2rem', textAlign: 'center', marginTop: '1.5rem', borderRadius: '12px' }}>
          <FileText size={44} className="text-muted" style={{ margin: '0 auto 1rem', opacity: 0.6 }} />
          <h3 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>
            {isLive ? 'No Live Transactions Found' : 'No Transactions Recorded'}
          </h3>
          <p className="text-muted" style={{ maxWidth: 520, margin: '0 auto', fontSize: '0.9rem', lineHeight: 1.5 }}>
            {isLive
              ? 'Google Sheets fct_transactions tab has no recorded rows. Add expenses via Log Spend or confirm receipts to populate your live ledger.'
              : 'Record your first transaction above or scan a receipt to see activity here.'}
          </p>
        </div>
      ) : filteredTransactions.length === 0 ? (
        <div className="glass-panel" style={{ padding: '2.5rem', textAlign: 'center', marginTop: '1.5rem', borderRadius: '12px' }}>
          <p className="text-muted">No transactions match your search and filter criteria.</p>
        </div>
      ) : (
        <div className="glass-panel ledger-table-wrapper">
          <table className="ledger-table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Payee / Merchant</th>
                <th>Category & Tier</th>
                <th>Tax Compliance</th>
                <th>Native Amount</th>
                <th className="text-right">Master Valuation</th>
                <th style={{ width: '40px', textAlign: 'center' }}></th>
              </tr>
            </thead>
            <tbody>
              {filteredTransactions.map((tx) => {
                const isIncome = tx.transactionType === 'INCOME';
                const conv = convertCurrency(tx.originalAmount, tx.originalCurrency, masterCurrency, rates);

                return (
                  <tr key={tx.transactionId} className="ledger-row">
                    <td className="mono text-muted">{tx.transactionDate}</td>
                    <td>
                      <div className="payee-name">{tx.merchantOrPayee}</div>
                      <div className="payee-acc mono text-muted">{tx.accountId}</div>
                    </td>
                    <td>
                      <div className="category-title">{tx.categoryName || tx.categoryId}</div>
                      <span className="tier-tag-sub mono">{tx.cashFlowTier}</span>
                    </td>
                    <td>
                      {tx.isTaxDeductible ? (
                        <div className="tax-badge-wrap">
                          <span className="badge badge-gold">💼 DEDUCTIBLE</span>
                          {tx.taxInvoiceNumber && (
                            <span className="badge badge-purple mono">🧾 {tx.taxInvoiceNumber}</span>
                          )}
                        </div>
                      ) : tx.categoryId === 'CAT_TAX_STATUTORY_PROVISIONAL' ? (
                        <span className="badge badge-cyan">🏛️ STATUTORY REMITTANCE</span>
                      ) : (
                        <span className="text-muted text-xs">—</span>
                      )}
                    </td>
                    <td className="mono">
                      <span className={isIncome ? 'text-emerald' : 'text-primary'}>
                        {tx.originalCurrency} {Math.abs(tx.originalAmount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </span>
                    </td>
                    <td className="mono text-right">
                      <strong className={isIncome ? 'text-emerald' : 'text-primary'}>
                        {isIncome ? '+' : ''}{conv.formatted}
                      </strong>
                    </td>
                    <td style={{ textAlign: 'center' }}>
                      <button
                        type="button"
                        className="btn-icon-only"
                        onClick={() => handleDelete(tx)}
                        disabled={isDeletingId === tx.transactionId}
                        title={`Delete transaction: ${tx.merchantOrPayee}`}
                        style={{
                          background: 'transparent',
                          border: 'none',
                          color: '#f87171',
                          cursor: 'pointer',
                          opacity: isDeletingId === tx.transactionId ? 0.4 : 0.8
                        }}
                      >
                        <Trash2 size={14} />
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
