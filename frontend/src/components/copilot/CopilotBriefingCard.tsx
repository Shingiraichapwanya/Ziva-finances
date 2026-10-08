/**
 * CopilotBriefingCard.tsx - Dashboard Executive Briefing Widget
 * Embedded in the main Command Center view for quick AI visibility and one-click simulator launch.
 */

import React, { useEffect, useState } from 'react';
import { Sparkles, ArrowRight, ShieldAlert, Zap, Layers } from 'lucide-react';
import { MasterCurrency } from '../../types/finance';
import { financeApi, CopilotInsightsResponse } from '../../services/api';

interface CopilotBriefingCardProps {
  onOpenCopilot: () => void;
  masterCurrency: MasterCurrency;
  isLive?: boolean;
}

const DEMO_INSIGHTS: CopilotInsightsResponse = {
  metrics: {
    liquidReserveZar: 201250,
    vaultTotalZar: 1100000,
    averageDailyBurnZar: 1420,
    baselineRunwayDays: 141,
    fixedObligationsRunwayDays: 245,
    survivalDate: '2027-01-23',
    monthlyFixedCommitmentsZar: 24000,
    taxSavingsAtRiskZar: 2430,
    taxDeductibleUnverifiedCount: 2,
    spreadPct: 77,
    burnStatus: 'OPTIMAL'
  },
  insights: [],
  generatedAt: new Date().toISOString()
};

export const CopilotBriefingCard: React.FC<CopilotBriefingCardProps> = ({
  onOpenCopilot,
  masterCurrency,
  isLive = false
}) => {
  const [data, setData] = useState<CopilotInsightsResponse | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  useEffect(() => {
    if (!isLive) {
      // Demo Mode: strictly use demo fixtures, zero live API calls
      setData(DEMO_INSIGHTS);
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    financeApi
      .getCopilotInsights()
      .then((res) => {
        setData(res);
      })
      .catch((err) => {
        console.warn('Briefing card insights error:', err);
        setData(null);
      })
      .finally(() => setIsLoading(false));
  }, [isLive]);

  const runwayDays = data ? data.metrics.baselineRunwayDays : null;
  const taxAtRisk = data ? data.metrics.taxSavingsAtRiskZar : null;
  const spread = data ? data.metrics.spreadPct : null;

  return (
    <div className="glass-panel copilot-briefing-card animate-fade-in">
      <div className="briefing-card-glow" />
      <div className="briefing-card-content">
        <div className="briefing-header">
          <div className="briefing-badge">
            <Sparkles size={14} className="text-gold" />
            <span>{isLive ? 'GEMINI LIVE INTELLIGENCE BRIEFING' : 'DEMO FINANCIAL INTELLIGENCE BRIEFING'}</span>
          </div>
          <span className="mono briefing-date">
            {isLive
              ? `Grounded in Google Sheets Live • ${new Date().toLocaleDateString('en-ZA', { month: 'short', day: 'numeric', year: 'numeric' })}`
              : 'Interactive Demo Environment'}
          </span>
        </div>

        <div className="briefing-grid">
          <div className="briefing-item">
            <div className="briefing-item-icon">
              <Zap size={16} className="text-cyan" />
            </div>
            <div>
              <div className="briefing-item-title mono">
                {isLoading ? 'Calculating...' : runwayDays !== null ? `${runwayDays} Days Liquid Runway` : 'Runway Unavailable'}
              </div>
              <div className="briefing-item-sub">
                {data
                  ? `Burn velocity is ${data.metrics.burnStatus || 'STABLE'}. Projected exhaustion date: ${data.metrics.survivalDate || 'N/A'}.`
                  : 'Connect or ingest transactions to project liquid survival date.'}
              </div>
            </div>
          </div>

          <div className="briefing-item">
            <div className="briefing-item-icon">
              <ShieldAlert size={16} className="text-gold" />
            </div>
            <div>
              <div className="briefing-item-title mono">
                {isLoading ? 'Scanning Invoices...' : taxAtRisk !== null ? `R${taxAtRisk.toLocaleString()} Tax Write-offs at Risk` : 'Tax Deductions Verified'}
              </div>
              <div className="briefing-item-sub">
                {taxAtRisk && taxAtRisk > 0
                  ? 'Unattached vendor invoices pending SARS 27% section 11(a) deduction audit.'
                  : 'All recorded tax-deductible expenses have valid invoices attached.'}
              </div>
            </div>
          </div>

          <div className="briefing-item">
            <div className="briefing-item-icon">
              <Layers size={16} className="text-emerald" />
            </div>
            <div>
              <div className="briefing-item-title mono">
                {isLoading ? 'Checking FX Rates...' : spread !== null ? `+${spread}% Parallel Spread Advantage` : 'Parallel Rates Inactive'}
              </div>
              <div className="briefing-item-sub">
                {spread && spread > 0
                  ? 'Official POS card swipe unlocks statutory retail savings vs holding volatile cash.'
                  : 'Multi-currency interbank and retail rates are currently trading at parity.'}
              </div>
            </div>
          </div>
        </div>

        <div className="briefing-footer">
          <span className="briefing-hint">
            Run real-time scenario modeling or ask custom tax & cross-border questions:
          </span>
          <button
            type="button"
            className="btn btn-primary btn-copilot-launch"
            onClick={onOpenCopilot}
          >
            <Sparkles size={16} />
            <span>Open Copilot Simulator</span>
            <ArrowRight size={14} />
          </button>
        </div>
      </div>
    </div>
  );
};
