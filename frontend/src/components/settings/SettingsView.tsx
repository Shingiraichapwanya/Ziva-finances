import React, { useState, useEffect } from 'react';
import { MasterCurrency } from '../../types/finance';
import {
  Settings,
  ShieldCheck,
  Database,
  GitBranch,
  HardDrive,
  RefreshCw,
  Fingerprint,
  Plus,
  Trash2,
  Lock,
  LogOut,
  AlertTriangle,
  Loader2,
  CheckCircle2
} from 'lucide-react';
import { startRegistration, browserSupportsWebAuthn } from '@simplewebauthn/browser';
import { financeApi, PasskeyInfo, UserSession } from '../../services/api';

interface SettingsViewProps {
  masterCurrency: MasterCurrency;
  onSelectCurrency: (c: MasterCurrency) => void;
  isOnline: boolean;
  onManualSync: () => void;
  session?: UserSession;
  onLogout?: () => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({
  masterCurrency,
  onSelectCurrency,
  isOnline,
  onManualSync,
  session,
  onLogout
}) => {
  const [passkeys, setPasskeys] = useState<PasskeyInfo[]>([]);
  const [loadingPasskeys, setLoadingPasskeys] = useState(false);
  const [registeringPasskey, setRegisteringPasskey] = useState(false);
  const [passkeyError, setPasskeyError] = useState<string | null>(null);
  const [passkeySuccess, setPasskeySuccess] = useState<string | null>(null);
  const [newPasskeyName, setNewPasskeyName] = useState('');
  const [webAuthnSupported, setWebAuthnSupported] = useState(false);
  const [sheetsConfig, setSheetsConfig] = useState<any>(null);

  useEffect(() => {
    setWebAuthnSupported(browserSupportsWebAuthn());
    if (session?.authenticated) {
      loadPasskeys();
    }
    if (isOnline) {
      financeApi.getSheetsConfig()
        .then((cfg) => setSheetsConfig(cfg))
        .catch(() => {});
    }
  }, [session?.authenticated, isOnline]);

  const loadPasskeys = async () => {
    setLoadingPasskeys(true);
    try {
      const keys = await financeApi.listPasskeys();
      setPasskeys(keys);
    } catch (err) {
      console.warn('Failed to load passkeys:', err);
    } finally {
      setLoadingPasskeys(false);
    }
  };

  const handleRegisterPasskey = async () => {
    if (!session?.authenticated) {
      setPasskeyError('You must be signed in as the owner to register a passkey.');
      return;
    }
    setRegisteringPasskey(true);
    setPasskeyError(null);
    setPasskeySuccess(null);

    try {
      // 1. Get creation options from backend
      const options = await financeApi.getPasskeyRegisterOptions();

      // 2. Start browser WebAuthn registration (triggers Face ID / Touch ID / device passcode)
      const regResp = await startRegistration({ optionsJSON: options });

      // 3. Verify with backend
      const name = newPasskeyName.trim() || `iPhone (${new Date().toLocaleDateString()})`;
      await financeApi.verifyPasskeyRegistration(regResp, name);

      setPasskeySuccess('Passkey registered successfully! You can now use Face ID to sign in.');
      setNewPasskeyName('');
      loadPasskeys();
    } catch (err: any) {
      if (err.name === 'NotAllowedError') {
        setPasskeyError('Registration was canceled or timed out.');
      } else {
        setPasskeyError(err.message || 'Failed to register passkey.');
      }
    } finally {
      setRegisteringPasskey(false);
    }
  };

  const handleDeletePasskey = async (id: string) => {
    if (!confirm('Are you sure you want to revoke this passkey?')) return;
    try {
      await financeApi.deletePasskey(id);
      loadPasskeys();
    } catch (err: any) {
      setPasskeyError(err.message || 'Failed to revoke passkey.');
    }
  };

  return (
    <div className="settings-view animate-fade-in">
      <div className="page-header">
        <div>
          <h2>System Settings & Cloud Diagnostics</h2>
          <p className="page-subtitle">
            Configure viewing preferences, manage owner biometric passkeys, monitor Google Sheets Live telemetry, and manage offline data.
          </p>
        </div>
      </div>

      <div className="settings-grid">
        {/* Card 1: Viewing Preferences */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <Settings size={20} className="text-gold" />
            <h3>Viewing & Currency Preferences</h3>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Default Master Currency</div>
              <div className="setting-desc">Primary currency used to normalize all balances and reports</div>
            </div>
            <select
              className="settings-select mono"
              value={masterCurrency}
              onChange={(e) => onSelectCurrency(e.target.value as MasterCurrency)}
            >
              <option value="ZAR">🇿🇦 ZAR - South African Rand</option>
              <option value="USD">🇺🇸 USD - United States Dollar</option>
              <option value="ZiG">🇿🇼 ZiG - Zimbabwe Gold</option>
            </select>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Zimbabwe Rate Display Benchmark</div>
              <div className="setting-desc">Reporting conversions display market parallel benchmark rate</div>
            </div>
            <span className="badge badge-cyan mono">MARKET_PARALLEL (Display Benchmark)</span>
          </div>
        </div>

        {/* Card 2: Owner Privacy & Biometric Passkey (WebAuthn / Face ID) */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <Fingerprint size={20} className="text-gold" />
            <h3>Owner Privacy & Biometric Passkeys</h3>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Authenticated Session</div>
              <div className="setting-desc">
                {session?.authenticated ? (
                  <>
                    Owner: <span className="mono text-emerald">{session.user?.email}</span> • 30-Day Remembered Session
                  </>
                ) : (
                  'Not authenticated • Operating in Sandbox/Demo Mode'
                )}
              </div>
            </div>
            {session?.authenticated && onLogout && (
              <button
                type="button"
                className="btn btn-secondary"
                onClick={onLogout}
                style={{ padding: '0.4rem 0.75rem', fontSize: '0.8rem', gap: '0.4rem' }}
              >
                <LogOut size={14} />
                <span>Sign Out</span>
              </button>
            )}
          </div>

          {passkeySuccess && (
            <div
              style={{
                background: 'rgba(16, 185, 129, 0.15)',
                border: '1px solid rgba(16, 185, 129, 0.3)',
                borderRadius: '6px',
                padding: '0.65rem',
                fontSize: '0.8rem',
                color: '#6ee7b7',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                margin: '0.5rem 0'
              }}
            >
              <CheckCircle2 size={16} />
              <span>{passkeySuccess}</span>
            </div>
          )}

          {passkeyError && (
            <div
              style={{
                background: 'rgba(239, 68, 68, 0.15)',
                border: '1px solid rgba(239, 68, 68, 0.3)',
                borderRadius: '6px',
                padding: '0.65rem',
                fontSize: '0.8rem',
                color: '#fca5a5',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                margin: '0.5rem 0'
              }}
            >
              <AlertTriangle size={16} />
              <span>{passkeyError}</span>
            </div>
          )}

          <div style={{ marginTop: '0.5rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
              <span className="setting-title" style={{ fontSize: '0.85rem' }}>Registered Devices / Passkeys</span>
              {loadingPasskeys && <Loader2 size={14} className="animate-spin text-muted" />}
            </div>

            {passkeys.length === 0 ? (
              <div className="text-muted text-xs" style={{ padding: '0.5rem 0' }}>
                No passkeys registered yet. Add a passkey to sign in effortlessly using Face ID or Touch ID.
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {passkeys.map((pk) => (
                  <div
                    key={pk.id}
                    className="glass-panel"
                    style={{
                      padding: '0.5rem 0.75rem',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      fontSize: '0.8rem'
                    }}
                  >
                    <div>
                      <div style={{ fontWeight: 600 }}>{pk.name}</div>
                      <span className="mono text-muted text-xs">
                        Added: {new Date(pk.createdAt).toLocaleDateString()}
                      </span>
                    </div>
                    <button
                      type="button"
                      className="btn-icon-only"
                      onClick={() => handleDeletePasskey(pk.id)}
                      title="Revoke passkey"
                      style={{ background: 'transparent', border: 'none', color: '#fca5a5', cursor: 'pointer' }}
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                ))}
              </div>
            )}

            {session?.authenticated && webAuthnSupported && (
              <div style={{ marginTop: '0.75rem', display: 'flex', gap: '0.5rem' }}>
                <input
                  type="text"
                  className="form-input"
                  placeholder="Passkey name (e.g. My iPhone 15)"
                  value={newPasskeyName}
                  onChange={(e) => setNewPasskeyName(e.target.value)}
                  style={{ fontSize: '0.8rem', padding: '0.4rem 0.6rem' }}
                />
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={handleRegisterPasskey}
                  disabled={registeringPasskey}
                  style={{ fontSize: '0.8rem', padding: '0.4rem 0.75rem', gap: '0.35rem', whiteSpace: 'nowrap' }}
                >
                  {registeringPasskey ? (
                    <>
                      <Loader2 size={14} className="animate-spin" />
                      <span>Adding…</span>
                    </>
                  ) : (
                    <>
                      <Plus size={14} />
                      <span>Add Passkey</span>
                    </>
                  )}
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Card 3: Google Sheets Live Architecture */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <Database size={20} className="text-cyan" />
            <h3>Google Sheets Live Architecture</h3>
          </div>

          <div className="config-list mono">
            <div className="config-row">
              <span className="config-key">Live Data Engine:</span>
              <span className="config-val text-emerald">Google Sheets REST API (100% Billing-Free)</span>
            </div>
            <div className="config-row">
              <span className="config-key">Target Spreadsheet:</span>
              <span className="config-val">Ziva-finances (Personal Ledger)</span>
            </div>
            <div className="config-row">
              <span className="config-key">Live Tab Mappings:</span>
              <span className="config-val">
                {sheetsConfig
                  ? `${sheetsConfig.accountsTab || 'dim_accounts'}, ${sheetsConfig.transactionsTab || 'fct_transactions'}, ${sheetsConfig.budgetsTab || 'fct_budget_allocations'}, ${sheetsConfig.debtsTab || 'debt_credit_ledger'}`
                  : 'dim_accounts, fct_transactions, fct_budget_allocations, debt_credit_ledger'}
              </span>
            </div>
            <div className="config-row">
              <span className="config-key">Settlement & Writes:</span>
              <span className="config-val text-gold">Direct Append & Patch (Instant)</span>
            </div>
            <div className="config-row">
              <span className="config-key">Receipt Archiving:</span>
              <span className="config-val text-cyan">Google Drive Private Folder / Local Fallback</span>
            </div>
          </div>
        </div>

        {/* Card 4: Offline-First Cache & Storage */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <HardDrive size={20} className="text-emerald" />
            <h3>Offline Cache & Storage</h3>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Private Route Cache Bypass</div>
              <div className="setting-desc">Service worker explicitly excludes sensitive financial APIs from browser cache; in-memory sessions purged on logout</div>
            </div>
            <span className="badge badge-emerald">API CACHE BYPASS ACTIVE</span>
          </div>

          <div className="setting-item">
            <div>
              <div className="setting-title">Network Synchronization</div>
              <div className="setting-desc">Status: {isOnline ? 'Online • Google Sheets Connected' : 'Offline / Sandbox Mode'}</div>
            </div>
            <button type="button" className="btn btn-secondary" onClick={onManualSync}>
              <RefreshCw size={14} />
              <span>Force Re-sync</span>
            </button>
          </div>
        </div>

        {/* Card 5: GitHub Versioning */}
        <div className="glass-panel settings-card">
          <div className="card-header-row">
            <GitBranch size={20} className="text-purple" />
            <h3>Version Control & Branch Status</h3>
          </div>

          <div className="config-list mono">
            <div className="config-row">
              <span className="config-key">Active Branch:</span>
              <span className="config-val text-gold">main</span>
            </div>
            <div className="config-row">
              <span className="config-key">Privacy Update:</span>
              <span className="config-val text-emerald">Complete Owner-Only & Passkeys</span>
            </div>
            <div className="config-row">
              <span className="config-key">Receipt Processing:</span>
              <span className="config-val text-cyan">Tesseract Billing-Free OCR</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
