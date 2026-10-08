import React, { useState, useEffect, useRef } from 'react';
import {
  LayoutDashboard,
  WalletCards,
  ReceiptText,
  Handshake,
  PieChart,
  Landmark,
  Gem,
  LineChart,
  Settings,
  X,
  Sparkles
} from 'lucide-react';

export type NavTab = 'dashboard' | 'accounts' | 'ledger' | 'debts' | 'budgets' | 'tax' | 'wealth' | 'analytics' | 'settings';

interface SidebarProps {
  currentTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
  isOpen?: boolean;
  onClose?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onSelectTab,
  isOpen = false,
  onClose
}) => {
  const closeBtnRef = useRef<HTMLButtonElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  // Close on Escape key press
  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose?.();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  // Lock background scroll, focus close button on open, and restore focus to menu button on close
  useEffect(() => {
    if (isOpen) {
      const active = document.activeElement;
      previousFocusRef.current = (active && active !== document.body ? (active as HTMLElement) : null) || document.getElementById('mobile-nav-toggle-btn');
      const originalOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';

      const timer = setTimeout(() => {
        closeBtnRef.current?.focus();
      }, 50);

      return () => {
        clearTimeout(timer);
        document.body.style.overflow = originalOverflow;
        setTimeout(() => {
          const trigger = (previousFocusRef.current && previousFocusRef.current !== document.body)
            ? previousFocusRef.current
            : document.getElementById('mobile-nav-toggle-btn');
          if (trigger && typeof trigger.focus === 'function') {
            trigger.focus();
          }
        }, 10);
      };
    }
  }, [isOpen]);

  // Ensure breakpoint changes (resizing to desktop) do not leave backdrop or scroll lock behind
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth > 1024) {
        if (isOpen) {
          onClose?.();
        }
        document.body.style.overflow = '';
      }
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [isOpen, onClose]);

  const navItems = [
    { id: 'dashboard' as NavTab, label: 'Dashboard', icon: LayoutDashboard },
    { id: 'accounts' as NavTab, label: 'Accounts & Tiers', icon: WalletCards },
    { id: 'ledger' as NavTab, label: 'Transactions', icon: ReceiptText },
    { id: 'debts' as NavTab, label: 'Debt & Credit Ledger', icon: Handshake },
    { id: 'budgets' as NavTab, label: 'Zero-Based Budgets', icon: PieChart },
    { id: 'tax' as NavTab, label: 'Tax & Compliance', icon: Landmark },
    { id: 'wealth' as NavTab, label: 'Wealth Suite', icon: Gem, highlight: true },
    { id: 'analytics' as NavTab, label: 'Performance & Analytics', icon: LineChart },
    { id: 'settings' as NavTab, label: 'Settings & Cloud', icon: Settings }
  ];

  const [isMobile, setIsMobile] = useState(() =>
    typeof window !== 'undefined' ? window.innerWidth <= 1024 : false
  );

  useEffect(() => {
    const mql = window.matchMedia('(max-width: 1024px)');
    const onChange = (e: MediaQueryListEvent) => {
      setIsMobile(e.matches);
    };
    mql.addEventListener('change', onChange);
    setIsMobile(mql.matches);
    return () => mql.removeEventListener('change', onChange);
  }, []);

  return (
    <>
      {/* Mobile Drawer Backdrop */}
      {isOpen && (
        <div
          className="sidebar-backdrop"
          onClick={onClose}
          aria-hidden="true"
        />
      )}

      <aside
        id="mobile-sidebar-drawer"
        className={`sidebar ${isOpen ? 'mobile-open' : ''}`}
        role={isMobile ? (isOpen ? 'dialog' : undefined) : undefined}
        aria-modal={isMobile && isOpen ? 'true' : undefined}
        aria-label="Navigation drawer"
        aria-hidden={isMobile && !isOpen ? 'true' : undefined}
        inert={isMobile && !isOpen ? true : undefined}
      >
        {/* Mobile Drawer Header with Close Button */}
        <div className="mobile-drawer-header">
          <div className="drawer-brand">
            <div className="brand-logo-gem">
              <Sparkles size={16} className="text-gold" />
            </div>
            <span className="brand-title">ZIVA FINANCE</span>
          </div>
          <button
            type="button"
            className="drawer-close-btn"
            onClick={onClose}
            ref={closeBtnRef}
            aria-label="Close navigation"
          >
            <X size={18} />
          </button>
        </div>

        <nav className="sidebar-nav">
          <div className="nav-group-title">COMMAND CENTER</div>
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentTab === item.id;
            return (
              <button
                key={item.id}
                type="button"
                className={`nav-item ${isActive ? 'active' : ''} ${item.highlight ? 'nav-item-highlight' : ''}`}
                onClick={() => {
                  onSelectTab(item.id);
                  onClose?.();
                }}
                id={`nav-tab-${item.id}`}
              >
                <Icon size={18} className="nav-icon" />
                <span className="nav-label">{item.label}</span>
                {item.highlight && <span className="nav-badge-new">PRO</span>}
              </button>
            );
          })}
        </nav>

        {/* Live Engine Anchor Footer */}
        <div className="sidebar-footer">
          <div className="warehouse-info-card">
            <div className="wh-header">
              <span className="wh-dot pulse-live" />
              <span className="wh-title">Google Sheets Live</span>
            </div>
            <div className="wh-details mono">
              <div>Engine: Sheets REST API</div>
              <div>Billing: 100% Free Sandbox</div>
              <div>Status: Live Sync Active</div>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
};
