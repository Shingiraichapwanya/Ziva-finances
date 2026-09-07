import React, { useState, useEffect } from 'react';
import {
  Handshake,
  Plus,
  ArrowUpRight,
  ArrowDownLeft,
  CheckCircle2,
  Clock,
  Search,
  Filter,
  RefreshCw,
  User,
  DollarSign
} from 'lucide-react';
import { DebtRecord, DebtBalance, MasterCurrency } from '../../types/finance';
import { financeApi } from '../../services/api';

interface DebtLedgerViewProps {
  masterCurrency: MasterCurrency;
}

export const DebtLedgerView: React.FC<DebtLedgerViewProps> = ({ masterCurrency }) => {
  const [debts, setDebts] = useState<DebtRecord[]>([]);
  const [balances, setBalances] = useState<DebtBalance[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'Pending' | 'Settled'>('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Form State
  const [formPerson, setFormPerson] = useState('');
  const [formDirection, setFormDirection] = useState<'owed_to_me' | 'owed_by_me'>('owed_to_me');
  const [formAmount, setFormAmount] = useState('');
  const [formCurrency, setFormCurrency] = useState<string>(masterCurrency);
  const [formDate, setFormDate] = useState(new Date().toISOString().split('T')[0]);
  const [formNotes, setFormNotes] = useState('');

  const loadData = async () => {
    setIsLoading(true);
    try {
      const [debtsData, balancesData] = await Promise.all([
        financeApi.getDebts(),
        financeApi.getDebtBalances()
      ]);
      setDebts(debtsData);
      setBalances(balancesData);
    } catch (err) {
      console.error('Failed to load debts data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleSettle = async (id: string) => {
    try {
      await financeApi.settleDebt(id);
      await loadData();
    } catch (err) {
      console.error('Failed to settle debt:', err);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formPerson || !formAmount || isNaN(Number(formAmount))) return;

    setIsSubmitting(true);
    try {
      await financeApi.createDebt({
        personName: formPerson.trim(),
        direction: formDirection,
        amount: parseFloat(formAmount),
        currency: formCurrency,
        date: formDate,
        notes: formNotes.trim()
      });
      setIsModalOpen(false);
      setFormPerson('');
      setFormAmount('');
      setFormNotes('');
      await loadData();
    } catch (err) {
      console.error('Failed to create debt entry:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Calculations
  const totalOwedToMe = balances.reduce((sum, b) => sum + (b.totalOwedToMe || 0), 0);
  const totalOwedByMe = balances.reduce((sum, b) => sum + (b.totalOwedByMe || 0), 0);
  const netPosition = totalOwedToMe - totalOwedByMe;

  const filteredDebts = debts.filter((d) => {
    const matchesFilter = filterStatus === 'ALL' || d.status === filterStatus;
    const matchesSearch =
      d.personName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      d.notes.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesFilter && matchesSearch;
  });

  return (
    <div className="debt-ledger-view" style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      {/* Header Bar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 700, margin: 0, display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Handshake size={28} style={{ color: '#F59E0B' }} />
            Debt & Credit Ledger
          </h1>
          <p style={{ color: '#94A3B8', fontSize: '13px', margin: '4px 0 0 0' }}>
            Peer-to-peer loans, shared expenses, and net balances powered by BigQuery
          </p>
        </div>
        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            type="button"
            onClick={loadData}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '8px 14px',
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: '8px',
              color: '#CBD5E1',
              cursor: 'pointer'
            }}
          >
            <RefreshCw size={15} />
            Refresh
          </button>
          <button
            type="button"
            onClick={() => setIsModalOpen(true)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '8px 16px',
              background: 'linear-gradient(135deg, #F59E0B, #D97706)',
              border: 'none',
              borderRadius: '8px',
              color: '#FFFFFF',
              fontWeight: 600,
              cursor: 'pointer',
              boxShadow: '0 2px 10px rgba(245,158,11,0.3)'
            }}
          >
            <Plus size={16} />
            Log New Entry
          </button>
        </div>
      </div>

      {/* Summary KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px', marginBottom: '28px' }}>
        <div style={{ background: '#131822', border: '1px solid rgba(16,185,129,0.2)', borderRadius: '12px', padding: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', color: '#10B981', fontSize: '12px', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
            <span>People Owe You</span>
            <ArrowDownLeft size={18} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: '#F8FAFC', marginTop: '10px' }}>
            ${totalOwedToMe.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
          <div style={{ color: '#64748B', fontSize: '11px', marginTop: '4px' }}>
            Incoming pending receivables across {balances.filter(b => b.totalOwedToMe > 0).length} people
          </div>
        </div>

        <div style={{ background: '#131822', border: '1px solid rgba(239,68,68,0.2)', borderRadius: '12px', padding: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', color: '#EF4444', fontSize: '12px', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
            <span>You Owe Others</span>
            <ArrowUpRight size={18} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: '#F8FAFC', marginTop: '10px' }}>
            ${totalOwedByMe.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
          <div style={{ color: '#64748B', fontSize: '11px', marginTop: '4px' }}>
            Outgoing obligations across {balances.filter(b => b.totalOwedByMe > 0).length} people
          </div>
        </div>

        <div style={{ background: '#131822', border: `1px solid ${netPosition >= 0 ? 'rgba(16,185,129,0.3)' : 'rgba(239,68,68,0.3)'}`, borderRadius: '12px', padding: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', color: netPosition >= 0 ? '#10B981' : '#EF4444', fontSize: '12px', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px' }}>
            <span>Net Balance Position</span>
            <DollarSign size={18} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: netPosition >= 0 ? '#10B981' : '#EF4444', marginTop: '10px' }}>
            {netPosition >= 0 ? '+' : ''}${netPosition.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
          </div>
          <div style={{ color: '#64748B', fontSize: '11px', marginTop: '4px' }}>
            {netPosition > 0 ? 'You are owed money overall' : netPosition < 0 ? 'You owe money overall' : 'All accounts settled'}
          </div>
        </div>
      </div>

      {/* People Net Balances Section */}
      <div style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, color: '#E2E8F0', marginBottom: '16px' }}>
          Individual Balances (debt_credit_balances View)
        </h2>
        {balances.length === 0 ? (
          <div style={{ background: '#131822', padding: '24px', borderRadius: '12px', textAlign: 'center', color: '#64748B', border: '1px solid rgba(255,255,255,0.06)' }}>
            No outstanding pending balances. All debts are settled!
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '14px' }}>
            {balances.map((b) => {
              const isPositive = b.netBalance > 0;
              const isNegative = b.netBalance < 0;
              return (
                <div
                  key={b.personName}
                  style={{
                    background: '#131822',
                    border: '1px solid rgba(255,255,255,0.07)',
                    borderRadius: '12px',
                    padding: '16px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between'
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <div
                        style={{
                          width: '36px',
                          height: '36px',
                          borderRadius: '50%',
                          background: 'rgba(255,255,255,0.05)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontWeight: 700,
                          color: '#F59E0B'
                        }}
                      >
                        {b.personName.substring(0, 2).toUpperCase()}
                      </div>
                      <div>
                        <div style={{ fontWeight: 600, color: '#F1F5F9', fontSize: '14px' }}>{b.personName}</div>
                        <div style={{ fontSize: '11px', color: '#64748B' }}>
                          {isPositive ? 'Owes you' : isNegative ? 'You owe' : 'Settled'}
                        </div>
                      </div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <div
                        style={{
                          fontWeight: 700,
                          fontSize: '16px',
                          color: isPositive ? '#10B981' : isNegative ? '#EF4444' : '#94A3B8'
                        }}
                      >
                        {isPositive ? '+' : ''}${Math.abs(b.netBalance).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </div>
                      <span
                        style={{
                          display: 'inline-block',
                          fontSize: '10px',
                          fontWeight: 600,
                          padding: '2px 6px',
                          borderRadius: '4px',
                          marginTop: '4px',
                          background: isPositive ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.1)',
                          color: isPositive ? '#10B981' : '#EF4444'
                        }}
                      >
                        {b.balanceDirection}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Ledger Transactions Table Section */}
      <div style={{ background: '#131822', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.07)', padding: '20px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
          <h2 style={{ fontSize: '16px', fontWeight: 600, color: '#E2E8F0', margin: 0 }}>
            Ledger Entries (debt_credit_ledger)
          </h2>
          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <Search size={14} style={{ position: 'absolute', left: '10px', top: '10px', color: '#64748B' }} />
              <input
                type="text"
                placeholder="Search person or notes..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{
                  padding: '7px 12px 7px 32px',
                  background: 'rgba(255,255,255,0.04)',
                  border: '1px solid rgba(255,255,255,0.08)',
                  borderRadius: '6px',
                  color: '#F8FAFC',
                  fontSize: '12px',
                  outline: 'none'
                }}
              />
            </div>
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value as any)}
              style={{
                padding: '7px 10px',
                background: 'rgba(255,255,255,0.04)',
                border: '1px solid rgba(255,255,255,0.08)',
                borderRadius: '6px',
                color: '#CBD5E1',
                fontSize: '12px'
              }}
            >
              <option value="ALL">All Statuses</option>
              <option value="Pending">Pending Only</option>
              <option value="Settled">Settled Only</option>
            </select>
          </div>
        </div>

        {/* Table */}
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.08)', color: '#64748B', fontSize: '11px', textTransform: 'uppercase' }}>
                <th style={{ padding: '10px 12px' }}>Date</th>
                <th style={{ padding: '10px 12px' }}>Person</th>
                <th style={{ padding: '10px 12px' }}>Direction</th>
                <th style={{ padding: '10px 12px' }}>Notes / Context</th>
                <th style={{ padding: '10px 12px', textAlign: 'right' }}>Amount</th>
                <th style={{ padding: '10px 12px', textAlign: 'center' }}>Status</th>
                <th style={{ padding: '10px 12px', textAlign: 'right' }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredDebts.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ padding: '24px', textAlign: 'center', color: '#64748B' }}>
                    No ledger records found matching filter.
                  </td>
                </tr>
              ) : (
                filteredDebts.map((d) => (
                  <tr key={d.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.04)', color: '#E2E8F0' }}>
                    <td style={{ padding: '12px' }}>{d.date}</td>
                    <td style={{ padding: '12px', fontWeight: 600 }}>{d.personName}</td>
                    <td style={{ padding: '12px' }}>
                      <span
                        style={{
                          fontSize: '11px',
                          padding: '3px 8px',
                          borderRadius: '4px',
                          background: d.direction === 'owed_to_me' ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.1)',
                          color: d.direction === 'owed_to_me' ? '#10B981' : '#EF4444',
                          fontWeight: 500
                        }}
                      >
                        {d.direction === 'owed_to_me' ? 'Owed to Me' : 'Owed by Me'}
                      </span>
                    </td>
                    <td style={{ padding: '12px', color: '#94A3B8' }}>{d.notes || '—'}</td>
                    <td style={{ padding: '12px', textAlign: 'right', fontWeight: 700 }}>
                      ${d.amount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} {d.currency}
                    </td>
                    <td style={{ padding: '12px', textAlign: 'center' }}>
                      <span
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '11px',
                          fontWeight: 600,
                          padding: '2px 8px',
                          borderRadius: '12px',
                          background: d.status === 'Settled' ? 'rgba(148,163,184,0.1)' : 'rgba(245,158,11,0.1)',
                          color: d.status === 'Settled' ? '#94A3B8' : '#F59E0B'
                        }}
                      >
                        {d.status === 'Settled' ? <CheckCircle2 size={12} /> : <Clock size={12} />}
                        {d.status}
                      </span>
                    </td>
                    <td style={{ padding: '12px', textAlign: 'right' }}>
                      {d.status === 'Pending' && (
                        <button
                          type="button"
                          onClick={() => handleSettle(d.id)}
                          style={{
                            padding: '4px 10px',
                            fontSize: '11px',
                            fontWeight: 600,
                            borderRadius: '4px',
                            background: 'rgba(16,185,129,0.15)',
                            color: '#10B981',
                            border: '1px solid rgba(16,185,129,0.3)',
                            cursor: 'pointer'
                          }}
                        >
                          Mark Settled
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Log Debt Modal */}
      {isModalOpen && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.7)',
            backdropFilter: 'blur(4px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999
          }}
        >
          <div
            style={{
              background: '#131822',
              border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: '16px',
              padding: '24px',
              width: '100%',
              maxWidth: '480px'
            }}
          >
            <h2 style={{ fontSize: '18px', fontWeight: 700, margin: '0 0 16px 0', color: '#F8FAFC' }}>
              Log Debt / Loan Entry
            </h2>
            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ fontSize: '11px', fontWeight: 600, color: '#94A3B8', textTransform: 'uppercase' }}>
                  Person Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Alice Smith, Bob Jones"
                  value={formPerson}
                  onChange={(e) => setFormPerson(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    marginTop: '4px',
                    background: 'rgba(255,255,255,0.05)',
                    border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: '6px',
                    color: '#FFF'
                  }}
                />
              </div>

              <div>
                <label style={{ fontSize: '11px', fontWeight: 600, color: '#94A3B8', textTransform: 'uppercase' }}>
                  Debt Direction *
                </label>
                <div style={{ display: 'flex', gap: '8px', marginTop: '4px' }}>
                  <button
                    type="button"
                    onClick={() => setFormDirection('owed_to_me')}
                    style={{
                      flex: 1,
                      padding: '8px',
                      borderRadius: '6px',
                      fontSize: '12px',
                      fontWeight: 600,
                      border: formDirection === 'owed_to_me' ? '1px solid #10B981' : '1px solid rgba(255,255,255,0.1)',
                      background: formDirection === 'owed_to_me' ? 'rgba(16,185,129,0.2)' : 'rgba(255,255,255,0.03)',
                      color: formDirection === 'owed_to_me' ? '#10B981' : '#94A3B8',
                      cursor: 'pointer'
                    }}
                  >
                    They owe ME (owed_to_me)
                  </button>
                  <button
                    type="button"
                    onClick={() => setFormDirection('owed_by_me')}
                    style={{
                      flex: 1,
                      padding: '8px',
                      borderRadius: '6px',
                      fontSize: '12px',
                      fontWeight: 600,
                      border: formDirection === 'owed_by_me' ? '1px solid #EF4444' : '1px solid rgba(255,255,255,0.1)',
                      background: formDirection === 'owed_by_me' ? 'rgba(239,68,68,0.2)' : 'rgba(255,255,255,0.03)',
                      color: formDirection === 'owed_by_me' ? '#EF4444' : '#94A3B8',
                      cursor: 'pointer'
                    }}
                  >
                    I owe THEM (owed_by_me)
                  </button>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ fontSize: '11px', fontWeight: 600, color: '#94A3B8', textTransform: 'uppercase' }}>
                    Amount *
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0.01"
                    required
                    placeholder="0.00"
                    value={formAmount}
                    onChange={(e) => setFormAmount(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      marginTop: '4px',
                      background: 'rgba(255,255,255,0.05)',
                      border: '1px solid rgba(255,255,255,0.1)',
                      borderRadius: '6px',
                      color: '#FFF'
                    }}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '11px', fontWeight: 600, color: '#94A3B8', textTransform: 'uppercase' }}>
                    Currency
                  </label>
                  <select
                    value={formCurrency}
                    onChange={(e) => setFormCurrency(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '8px 10px',
                      marginTop: '4px',
                      background: '#1E293B',
                      border: '1px solid rgba(255,255,255,0.1)',
                      borderRadius: '6px',
                      color: '#FFF'
                    }}
                  >
                    <option value="USD">USD</option>
                    <option value="ZAR">ZAR</option>
                    <option value="EUR">EUR</option>
                    <option value="GBP">GBP</option>
                  </select>
                </div>
              </div>

              <div>
                <label style={{ fontSize: '11px', fontWeight: 600, color: '#94A3B8', textTransform: 'uppercase' }}>
                  Date *
                </label>
                <input
                  type="date"
                  required
                  value={formDate}
                  onChange={(e) => setFormDate(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    marginTop: '4px',
                    background: 'rgba(255,255,255,0.05)',
                    border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: '6px',
                    color: '#FFF'
                  }}
                />
              </div>

              <div>
                <label style={{ fontSize: '11px', fontWeight: 600, color: '#94A3B8', textTransform: 'uppercase' }}>
                  Notes / Memo
                </label>
                <input
                  type="text"
                  placeholder="e.g. Dinner split, Uber ride, Fuel"
                  value={formNotes}
                  onChange={(e) => setFormNotes(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    marginTop: '4px',
                    background: 'rgba(255,255,255,0.05)',
                    border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: '6px',
                    color: '#FFF'
                  }}
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '12px' }}>
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  style={{
                    padding: '8px 14px',
                    borderRadius: '6px',
                    background: 'transparent',
                    border: '1px solid rgba(255,255,255,0.15)',
                    color: '#94A3B8',
                    cursor: 'pointer'
                  }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  style={{
                    padding: '8px 18px',
                    borderRadius: '6px',
                    background: '#F59E0B',
                    border: 'none',
                    color: '#FFF',
                    fontWeight: 600,
                    cursor: 'pointer'
                  }}
                >
                  {isSubmitting ? 'Saving to BigQuery...' : 'Save Entry'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
