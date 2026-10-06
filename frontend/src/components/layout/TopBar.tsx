import React from 'react';
import { MasterCurrency, ExchangeRates } from '../../types/finance';
import { Menu, Camera, RefreshCw, Sparkles, ShieldCheck } from 'lucide-react';

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
  isNavOpen = false
}) => {
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

      {/* Live FX Ticker (SARB, RBZ Official, Market Parallel) */}
      <div className="fx-ticker-bar">
        <div className="fx-pill">
          <span className="fx-label">USD/ZAR</span>
          <span className="fx-val mono">R {rates.USD_TO_ZAR.toFixed(2)}</span>
        </div>
        <div className="fx-pill">
          <span className="fx-label">RBZ Off:</span>
          <span className="fx-val mono">ZiG {rates.USD_TO_ZIG_OFFICIAL.toFixed(2)}</span>
        </div>
        <div className="fx-pill fx-pill-alert">
          <span className="fx-label">Market:</span>
          <span className="fx-val mono">ZiG {rates.USD_TO_ZIG_PARALLEL.toFixed(2)}</span>
          <span className="fx-spread-badge">+76.9%</span>
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

        {/* Sync Status Badge */}
        <div className="sync-status-badge" title="BigQuery Project: budget-tracker-507418, Region: africa-south1">
          <span className={`status-dot ${isOnline ? 'online pulse-live' : 'offline'}`} />
          <ShieldCheck size={14} className={isOnline ? "text-emerald" : "text-gold"} />
          <span>{isOnline ? 'BigQuery Live' : 'Demo Mode'}</span>
        </div>

        {/* Manual Refresh Action */}
        {onRefresh && (
          <button
            type="button"
            className="btn btn-secondary btn-icon-only"
            onClick={onRefresh}
            disabled={isRefreshing}
            title="Refresh live data from BigQuery"
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
