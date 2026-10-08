import React from 'react';
import { TaxQuarterSchedule, Transaction, MasterCurrency, ExchangeRates } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import { Landmark, ShieldCheck, FileCheck, CheckCircle2, AlertCircle } from 'lucide-react';
import type { LiveTaxState } from '../../services/liveData';
import { LiveStatusNotice } from '../common/LiveStatusNotice';

interface TaxViewProps {
  taxSchedule: TaxQuarterSchedule | null;
  transactions: Transaction[];
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  isLive?: boolean;
  liveTax?: LiveTaxState;
}

export const TaxView: React.FC<TaxViewProps> = ({
  taxSchedule,
  transactions,
  masterCurrency,
  rates,
  isLive = false,
  liveTax
}) => {
  const deductibleTransactions = transactions.filter((t) => t.isTaxDeductible);

  const grossConv = taxSchedule ? convertCurrency(taxSchedule.grossTaxableInflowZar, 'ZAR', masterCurrency, rates) : null;
  const deductionsConv = taxSchedule ? convertCurrency(taxSchedule.totalAllowableDeductionsZar, 'ZAR', masterCurrency, rates) : null;
  const netTaxableConv = taxSchedule ? convertCurrency(taxSchedule.netTaxableIncomeZar, 'ZAR', masterCurrency, rates) : null;
  const estimatedTaxConv = taxSchedule ? convertCurrency(taxSchedule.estimatedTaxLiabilityZar, 'ZAR', masterCurrency, rates) : null;
  const actualPaidConv = taxSchedule ? convertCurrency(taxSchedule.actualTaxPaidZar, 'ZAR', masterCurrency, rates) : null;
  const outstandingConv = taxSchedule ? convertCurrency(taxSchedule.netTaxOutstandingZar, 'ZAR', masterCurrency, rates) : null;

  const isCreditSurplus = taxSchedule ? taxSchedule.netTaxOutstandingZar < 0 : false;

  return (
    <div className="tax-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>Tax Compliance & Business Offsets (SARS / ZIMRA)</h2>
          <p className="page-subtitle">
            Quarterly provisional tax liability calculations derived from verified ledger records and deductions in Google Sheets.
          </p>
        </div>
        {taxSchedule && (
          <div>
            <span className="badge badge-emerald">
              <CheckCircle2 size={14} /> {taxSchedule.taxQuarter} Status: {taxSchedule.taxSettlementStatus}
            </span>
          </div>
        )}
      </div>

      {isLive && liveTax && (
        <LiveStatusNotice
          status={liveTax.status}
          verifiedAt={liveTax.verifiedAt}
          error={liveTax.error}
          entityName="tax schedule"
          emptyMessage="The live database returned no tax calculation. Projections will calculate once live revenue and deductible expenses are recorded in Google Sheets."
          idPrefix="live-tax"
        />
      )}

      {!taxSchedule ? (
        <div className="glass-panel empty-state-card" style={{ padding: '3.5rem 2rem', textAlign: 'center', marginTop: '1.5rem', borderRadius: '12px' }}>
          <Landmark size={44} className="text-muted" style={{ margin: '0 auto 1rem', opacity: 0.6 }} />
          <h3 style={{ fontSize: '1.25rem', marginBottom: '0.5rem' }}>
            {isLive ? (liveTax?.status === 'unavailable' ? 'Live Tax Schedule Unavailable' : 'No Live Tax Calculations Available') : 'No Tax Schedule'}
          </h3>
          <p className="text-muted" style={{ maxWidth: 520, margin: '0 auto', fontSize: '0.9rem', lineHeight: 1.5 }}>
            {liveTax?.status === 'unavailable'
              ? `Failed to load tax schedule: ${liveTax.error || 'Server error'}. No provisional tax liability is computed until the database responds.`
              : 'Provisional tax liability requires recorded income and deductible expenses in Google Sheets. Once ledger transactions are logged, SARS and ZIMRA compliance calculations will generate automatically.'}
          </p>
        </div>
      ) : (
        <>
          {/* Primary Tax Calculation Meter */}
          <div className="glass-panel tax-meter-card">
            <div className="tax-calc-grid">
              <div className="calc-block">
                <div className="calc-label">Gross Taxable Revenue</div>
                <div className="calc-val mono">{grossConv?.formatted}</div>
                <div className="calc-hint text-muted">Consulting & Inflows</div>
              </div>

              <div className="calc-operator">−</div>

              <div className="calc-block">
                <div className="calc-label">Total Allowable Deductions</div>
                <div className="calc-val mono text-emerald">{deductionsConv?.formatted}</div>
                <div className="calc-hint text-emerald">Tech Hardware, Cloud, Fibre</div>
              </div>

          <div className="calc-operator">=</div>

          <div className="calc-block">
            <div className="calc-label">Net Taxable Income</div>
            <div className="calc-val mono text-gold">{netTaxableConv?.formatted ?? '—'}</div>
            <div className="calc-hint text-gold">Provisional Base</div>
          </div>

          <div className="calc-operator">× {((taxSchedule.effectiveTaxRate || 0.27) * 100).toFixed(0)}% =</div>

          <div className="calc-block calc-block-highlight">
            <div className="calc-label">Est. Tax Liability</div>
            <div className="calc-val mono text-primary">{estimatedTaxConv?.formatted ?? '—'}</div>
            <div className="calc-hint text-muted">Benchmark Provisional</div>
          </div>
        </div>

        {/* Remittance & Settlement Summary */}
        <div className="tax-settlement-bar">
          <div>
            <span className="settle-label">Actual Statutory Remittances:</span>{' '}
            <strong className="mono">{actualPaidConv?.formatted ?? '—'}</strong>{' '}
            <span className="text-muted text-xs">(IRP6 / QPD payments to SARS/ZIMRA)</span>
          </div>
          <div>
            <span className="settle-label">Net Settlement Position:</span>{' '}
            <strong className={`mono ${isCreditSurplus ? 'text-emerald' : 'text-rose'}`}>
              {isCreditSurplus ? `+${Math.abs(taxSchedule.netTaxOutstandingZar).toFixed(2)} (Credit Surplus)` : (outstandingConv?.formatted ?? '—')}
            </strong>
          </div>
        </div>

        <div style={{ marginTop: '0.75rem', padding: '0.6rem 0.8rem', background: 'rgba(255,255,255,0.03)', borderRadius: '6px', fontSize: '0.75rem', color: '#94a3b8', lineHeight: 1.4 }}>
          <strong>Provisional Tax Benchmark Disclosure:</strong> Modeled using the South African 27.00% corporate provisional benchmark rate. Individual marginal rates, rebates, and ZIMRA progressive scales differ. Illustrative planning estimate only; does not constitute professional tax advice.
        </div>
      </div>

      {/* Itemized Audit Schedule */}
      <div className="glass-panel audit-table-wrapper">
        <div className="section-title-bar">
          <div>
            <h3>Itemized Tax-Deductible Business Expense Schedule</h3>
            <p className="section-subtitle">
              Audit-ready breakdown corresponding to <code className="mono">v_tax_deductible_expenses_audit</code>
            </p>
          </div>
          <span className="badge badge-gold">{deductibleTransactions.length} Audit Invoices</span>
        </div>

        <table className="ledger-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Merchant / Vendor</th>
              <th>Tax Line Item</th>
              <th>Tax Invoice Ref</th>
              <th>Native Spend</th>
              <th className="text-right">Deductible Offset</th>
            </tr>
          </thead>
          <tbody>
            {deductibleTransactions.map((tx) => {
              const deductibleConv = convertCurrency(
                tx.taxDeductibleAmountZar || Math.abs(tx.originalAmount),
                'ZAR',
                masterCurrency,
                rates
              );

              return (
                <tr key={tx.transactionId} className="ledger-row">
                  <td className="mono text-muted">{tx.transactionDate}</td>
                  <td>
                    <div className="payee-name">{tx.merchantOrPayee}</div>
                    <div className="payee-acc text-xs text-muted">{tx.categoryName}</div>
                  </td>
                  <td>
                    <span className="badge badge-gold mono">
                      {tx.categoryId === 'CAT_PROD_TECH_HARDWARE' ? 'PRODUCTIVITY_HARDWARE' :
                       tx.categoryId === 'CAT_PROD_SOFTWARE_TOOLS' ? 'BUSINESS_SOFTWARE' :
                       tx.categoryId === 'CAT_ALLOC_INTERNET' ? 'HOME_OFFICE_DEDUCTION' : 'TAX_DEDUCTIBLE'}
                    </span>
                  </td>
                  <td>
                    {tx.taxInvoiceNumber ? (
                      <span className="badge badge-purple mono">🧾 {tx.taxInvoiceNumber}</span>
                    ) : (
                      <span className="badge badge-rose text-xs">Missing Invoice Ref</span>
                    )}
                  </td>
                  <td className="mono">
                    {tx.originalCurrency} {Math.abs(tx.originalAmount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </td>
                  <td className="mono text-right text-emerald">
                    +{deductibleConv.formatted}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      </>
      )}
    </div>
  );
};

