import React from 'react';
import {
  LayoutDashboard,
  WalletCards,
  ReceiptText,
  Handshake,
  PieChart,
  Landmark,
  Gem,
  LineChart,
  Settings
} from 'lucide-react';

export type NavTab = 'dashboard' | 'accounts' | 'ledger' | 'debts' | 'budgets' | 'tax' | 'wealth' | 'analytics' | 'settings';

interface SidebarProps {
  currentTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ currentTab, onSelectTab }) => {
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

  return (
    <aside className="sidebar">
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
              onClick={() => onSelectTab(item.id)}
              id={`nav-tab-${item.id}`}
            >
              <Icon size={18} className="nav-icon" />
              <span className="nav-label">{item.label}</span>
              {item.highlight && <span className="nav-badge-new">PRO</span>}
            </button>
          );
        })}
      </nav>

      {/* Warehouse Anchor Footer */}
      <div className="sidebar-footer">
        <div className="warehouse-info-card">
          <div className="wh-header">
            <span className="wh-dot pulse-live" />
            <span className="wh-title">BigQuery Data Warehouse</span>
          </div>
          <div className="wh-details mono">
            <div>Project: budget-tracker-507418</div>
            <div>Dataset: personal_finance</div>
            <div>Region: africa-south1</div>
          </div>
        </div>
      </div>
    </aside>
  );
};
