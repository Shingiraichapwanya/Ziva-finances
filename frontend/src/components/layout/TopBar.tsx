import React from 'react';
import { MasterCurrency, ExchangeRates } from '../../types/finance';
import { Menu, Camera, RefreshCw, Sparkles, ShieldCheck, Lock, Unlock, LogOut } from 'lucide-react';
import { UserSession } from '../../services/api';

interface TopBarProps {
  masterCurrency: MasterCurrency;
  onSelectCurrency: (c: MasterCurrency) => void;
  rates: ExchangeRates;
  isOnline: boolean;
  onOpenReceiptModal: () => void;
  onRefresh?: () => void;
  isRefreshing?: boolean;
  onOpenCopilot: () => void;
  onToggleNav?: () => void;
  isNavOpen?: boolean;
  session?: UserSession;
  onOpenAuthModal?: () => void;
  onToggleLiveMode?: () => void;
}

export const TopBar: React.FC<TopBarProps> = ({
  masterCurrency,
  onSelectCurrency,
  rates,
  isOnline,
  onOpenReceiptModal,
  onRefresh,
  isRefreshing,
  onOpenCopilot,
  onToggleNav,
  isNavOpen = false,
  session,
  onOpenAuthModal,
  onToggleLiveMode
}) => {
  // Dynamic, verified FX spread calculation (guarding against missing or zero values)
  const officialZig = rates?.USD_TO_ZIG_OFFICIAL;
  const parallelZig = rates?.USD_TO_ZIG_PARALLEL;
  const spreadPct =
    officialZig && officialZig > 0 && parallelZig && parallelZig > 0
      ? ((parallelZig - officialZig) / officialZig) * 100
      : null;
  const spreadDisplay = spreadPct !== null ? `${spreadPct >= 0 ? '+' : ''}${spreadPct.toFixed(1)}%` : null;

  const usdZarDisplay = rates?.USD_TO_ZAR && rates.USD_TO_ZAR > 0 ? `R ${rates.USD_TO_ZAR.toFixed(2)}` : 'R —';
  const zigOffDisplay = officialZig && officialZig > 0 ? `ZiG ${officialZig.toFixed(2)}` : 'ZiG —';
  const zigParDisplay = parallelZig && parallelZig > 0 ? `ZiG ${parallelZig.toFixed(2)}` : 'ZiG —';

  return (
    <header className="topbar">
      {/* Brand Identity & Mobile Menu Toggle */}
      <div className="topbar-left">
        {onToggleNav && (
          <button
            type="button"
            className="mobile-nav-toggle"
            id="mobile-nav-toggle-btn"
            onClick={onToggleNav}
            aria-label={isNavOpen ? 'Close navigation menu' : 'Open navigation menu'}
            aria-expanded={isNavOpen}
            aria-controls="mobile-sidebar-drawer"
          >
            <Menu size={20} />
          </button>
        )}
        <div className="topbar-brand">
          <div className="brand-logo-gem">
            <Sparkles size={18} className="text-gold" />
          </div>
          <div>
            <div className="brand-title">ZIVA FINANCE</div>
            <div className="brand-subtitle">Financial Command Center</div>
          </div>
        </div>
      </div>

      {/* Live FX Ticker (SARB Interbank, RBZ Official, Market Parallel) */}
      <div className="fx-ticker-bar">
        <div className="fx-pill" title="South African Reserve Bank Interbank Reference">
          <span className="fx-label">USD/ZAR</span>
          <span className="fx-val mono">{usdZarDisplay}</span>
        </div>
        <div className="fx-pill" title="Reserve Bank of Zimbabwe Official Interbank Rate">
          <span className="fx-label">RBZ Off:</span>
          <span className="fx-val mono">{zigOffDisplay}</span>
        </div>
        <div className="fx-pill fx-pill-alert" title="Domestic Retail Parallel Market Rate">
          <span className="fx-label">Market:</span>
          <span className="fx-val mono">{zigParDisplay}</span>
          {spreadDisplay && <span className="fx-spread-badge">{spreadDisplay}</span>}
        </div>
      </div>

      {/* Actions & Master Currency Toggle */}
      <div className="topbar-actions">
        {/* Master Currency Toggle */}
        <div className="currency-toggle-wrapper">
          <span className="toggle-caption">Master Currency:</span>
          <div className="currency-toggle-group">
            <button
              type="button"
              className={`currency-toggle-btn ${masterCurrency === 'ZAR' ? 'active' : ''}`}
              onClick={() => onSelectCurrency('ZAR')}
              title="South African Rand (Base)"
            >
              🇿🇦 ZAR
            </button>
            <button
              type="button"
              className={`currency-toggle-btn ${masterCurrency === 'USD' ? 'active' : ''}`}
              onClick={() => onSelectCurrency('USD')}
              title="United States Dollar"
            >
              🇺🇸 USD
            </button>
            <button
              type="button"
              className={`currency-toggle-btn ${masterCurrency === 'ZiG' ? 'active' : ''}`}
              onClick={() => onSelectCurrency('ZiG')}
              title="Zimbabwe Gold"
            >
              🇿🇼 ZiG
            </button>
          </div>
        </div>

        {/* Sync Status Badge (Google Sheets Live vs Demo Mode) */}
        <button
          type="button"
          className="sync-status-badge"
          onClick={onToggleLiveMode}
          title={isOnline ? "Switch to Demo Mode" : "Switch to Google Sheets Live"}
          style={{ cursor: 'pointer', background: 'none', border: '1px solid rgba(255, 255, 255, 0.1)' }}
        >
          <span className={`status-dot ${isOnline ? 'online pulse-live' : 'offline'}`} />
          <ShieldCheck size={14} className={isOnline ? "text-emerald" : "text-gold"} />
          <span>{isOnline ? 'Google Sheets Live' : 'Demo Mode'}</span>
        </button>

        {/* Auth / Lock Indicator */}
        {isOnline && !session?.authenticated && onOpenAuthModal && (
          <button
            type="button"
            className="btn btn-secondary"
            onClick={onOpenAuthModal}
            style={{ padding: '0.4rem 0.65rem', fontSize: '0.8rem', gap: '0.35rem' }}
            title="Owner login required for live financial data"
          >
            <Lock size={13} className="text-gold" />
            <span>Owner Sign-In</span>
          </button>
        )}

        {/* Manual Refresh Action */}
        {onRefresh && (
          <button
            type="button"
            className="btn btn-secondary btn-icon-only"
            onClick={onRefresh}
            disabled={isRefreshing}
            title="Refresh live data from Google Sheets"
            style={{ padding: '0.45rem', display: 'flex', alignItems: 'center' }}
          >
            <RefreshCw size={14} className={isRefreshing ? 'animate-spin' : ''} />
          </button>
        )}

        {/* Gemini Copilot Action */}
        <button
          type="button"
          className="btn btn-copilot-toggle"
          onClick={onOpenCopilot}
          id="btn-open-copilot"
          title="Open Gemini AI Financial Copilot"
        >
          <Sparkles size={15} className="text-gold" />
          <span>Gemini Copilot</span>
        </button>

        {/* Scan Receipt Quick Action */}
        <button
          type="button"
          className="btn btn-primary btn-scan"
          onClick={onOpenReceiptModal}
          id="btn-scan-receipt"
        >
          <Camera size={16} />
          <span>Scan Receipt</span>
        </button>
      </div>
    </header>
  );
};
