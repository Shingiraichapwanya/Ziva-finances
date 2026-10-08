/**
 * GeminiCopilotDrawer.tsx - Interactive AI Financial Copilot
 * Features predictive burn-rate simulation, SARS provisional tax shield alerts,
 * Southern African multi-currency hedging, and conversational financial reasoning.
 */

import React, { useState, useEffect, useRef } from 'react';
import {
  Sparkles,
  X,
  Send,
  Sliders,
  ShieldCheck,
  TrendingDown,
  AlertTriangle,
  ArrowRight,
  Key,
  Flame,
  CheckCircle2
} from 'lucide-react';
import { MasterCurrency, ExchangeRates } from '../../types/finance';
import { convertCurrency } from '../../services/currency';
import {
  financeApi,
  CopilotInsightsResponse,
  CopilotInsightItem
} from '../../services/api';

interface GeminiCopilotDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  masterCurrency: MasterCurrency;
  rates: ExchangeRates;
  isLive?: boolean;
}

interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  model?: string;
  timestamp: string;
}

const QUICK_PROMPTS = [
  'How many days of liquid runway do I have?',
  'How can I lower my SARS provisional tax liability?',
  'Should I pay for groceries in USD cash or ZiG card swipe?',
  'Which budget envelope is burning velocity fastest?'
];

const DEMO_DRAWER_INSIGHTS: CopilotInsightsResponse = {
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

export const GeminiCopilotDrawer: React.FC<GeminiCopilotDrawerProps> = ({
  isOpen,
  onClose,
  masterCurrency,
  rates,
  isLive = false
}) => {
  const [data, setData] = useState<CopilotInsightsResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputPrompt, setInputPrompt] = useState('');
  const [sending, setSending] = useState(false);

  // Gemini API Key config (persisted in localStorage)
  const [showKeyInput, setShowKeyInput] = useState(false);
  const [apiKey, setApiKey] = useState(() => localStorage.getItem('gemini_api_key') || '');

  // Runway Simulation Sliders
  const [discretionaryCutPct, setDiscretionaryCutPct] = useState(0); // 0% to 50%
  const [incomeDelayDays, setIncomeDelayDays] = useState(0); // 0 to 60 days

  const chatEndRef = useRef<HTMLDivElement>(null);

  // Fetch insights when opened
  useEffect(() => {
    if (isOpen) {
      if (!isLive) {
        // Demo Mode: strictly use demo fixtures, zero live API calls
        setData(DEMO_DRAWER_INSIGHTS);
        if (messages.length === 0) {
          setMessages([
            {
              id: 'welcome-demo',
              role: 'assistant',
              text: `👋 **Hello! I am your Gemini Financial Copilot (Demo Mode).**\n\nI am analyzing your demo accounts and budget allocations. In this simulated environment, you have **141 days of liquid runway** and **R2,430** in potential SARS tax write-offs.\n\nAsk me about scenarios, multi-currency strategies, or budget envelopes!`,
              model: 'Interactive Demo Reasoner',
              timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
            }
          ]);
        }
        setLoading(false);
        return;
      }

      setLoading(true);
      financeApi
        .getCopilotInsights()
        .then((res) => {
          setData(res);
          if (messages.length === 0) {
            setMessages([
              {
                id: 'welcome-1',
                role: 'assistant',
                text: `👋 **Hello! I am your Gemini Financial Copilot.**\n\nI am continuously analyzing your live Google Sheets records and budgets. You currently have **${res.metrics.baselineRunwayDays} days of liquid runway** and **R${res.metrics.taxSavingsAtRiskZar.toLocaleString()}** in potential SARS tax write-offs requiring verified invoices.\n\nHow can I help optimize your cash flow or tax strategy today?`,
                model: apiKey ? 'Gemini 2.5 Flash' : 'Built-in Financial Reasoner',
                timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
              }
            ]);
          }
        })
        .catch((err) => {
          console.warn('Could not load Copilot insights:', err);
        })
        .finally(() => setLoading(false));
    }
  }, [isOpen, isLive]);

  // Scroll chat to bottom
  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, sending]);

  const handleSaveApiKey = (key: string) => {
    setApiKey(key);
    localStorage.setItem('gemini_api_key', key.trim());
    setShowKeyInput(false);
  };

  const handleSendPrompt = async (promptText?: string) => {
    const textToSend = promptText || inputPrompt;
    if (!textToSend.trim() || sending) return;

    const userMsg: ChatMessage = {
      id: `user-${Date.now()}`,
      role: 'user',
      text: textToSend,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages((prev) => [...prev, userMsg]);
    setInputPrompt('');
    setSending(true);

    try {
      const res = await financeApi.askCopilot(textToSend, apiKey);
      const assistantMsg: ChatMessage = {
        id: `assistant-${Date.now()}`,
        role: 'assistant',
        text: res.reply,
        model: res.model,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setMessages((prev) => [...prev, assistantMsg]);
    } catch (err: any) {
      const errorMsg: ChatMessage = {
        id: `err-${Date.now()}`,
        role: 'assistant',
        text: `⚠️ **Error querying Copilot:** ${err.message || 'Please check your connection and try again.'}`,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setMessages((prev) => [...prev, errorMsg]);
    } finally {
      setSending(false);
    }
  };

  if (!isOpen) return null;

  // Real-time Runway Simulation calculations
  const baselineRunway = data?.metrics.baselineRunwayDays || 45;
  const avgBurn = data?.metrics.averageDailyBurnZar || 650;
  const liquidReserves = data?.metrics.liquidReserveZar || 35000;

  // Assume discretionary spend is ~40% of daily burn
  const discretionaryDaily = avgBurn * 0.4;
  const fixedDaily = avgBurn * 0.6;
  const simulatedDiscretionary = discretionaryDaily * (1 - discretionaryCutPct / 100);
  const simulatedDailyBurn = Math.max(150, Math.round(fixedDaily + simulatedDiscretionary));
  const simulatedRunwayDays = Math.max(0, Math.floor(liquidReserves / simulatedDailyBurn) - incomeDelayDays);
  const runwayDiff = simulatedRunwayDays - baselineRunway;

  return (
    <div className="copilot-backdrop" onClick={onClose}>
      <aside className="copilot-drawer glass-panel" onClick={(e) => e.stopPropagation()}>
        {/* Drawer Header */}
        <div className="copilot-header">
          <div className="copilot-title-group">
            <div className="brand-logo-gem">
              <Sparkles size={18} className="text-gold" />
            </div>
            <div>
              <div className="copilot-heading">
                <span>GEMINI FINANCIAL COPILOT</span>
                <span className="badge badge-gold" style={{ fontSize: '0.65rem', marginLeft: '0.5rem' }}>
                  {apiKey ? 'GEMINI 2.5 FLASH' : 'LOCAL REASONER'}
                </span>
              </div>
              <div className="copilot-subheading">Live Financial Intelligence</div>
            </div>
          </div>

          <div className="copilot-header-actions">
            <button
              type="button"
              className={`btn btn-secondary btn-icon-only ${apiKey ? 'active-key' : ''}`}
              onClick={() => setShowKeyInput(!showKeyInput)}
              title={apiKey ? 'Gemini API Key configured' : 'Configure Gemini API Key'}
            >
              <Key size={14} className={apiKey ? 'text-gold' : ''} />
            </button>
            <button type="button" className="btn btn-secondary btn-icon-only" onClick={onClose}>
              <X size={16} />
            </button>
          </div>
        </div>

        {/* API Key Modal Banner (collapsible) */}
        {showKeyInput && (
          <div className="api-key-banner animate-fade-in">
            <div className="api-key-header">
              <Key size={14} className="text-gold" />
              <span>Connect Google Gemini API Key</span>
            </div>
            <p className="api-key-desc">
              Provide your personal Gemini API key to enable live generative reasoning with Gemini 2.5 Flash. Stored securely in your browser's localStorage.
            </p>
            <div className="api-key-input-row">
              <input
                type="password"
                className="input-field"
                placeholder="AIzaSy..."
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
              />
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => handleSaveApiKey(apiKey)}
              >
                Save
              </button>
            </div>
          </div>
        )}

        {/* Drawer Body Scroll Area */}
        <div className="copilot-body">
          {/* 1. Predictive Runway Simulator Card */}
          <div className="copilot-card simulator-card">
            <div className="copilot-card-header">
              <Sliders size={16} className="text-cyan" />
              <span>Predictive Runway Simulator</span>
              <span className="mono status-badge" style={{ marginLeft: 'auto' }}>
                {simulatedRunwayDays} Days
              </span>
            </div>

            <div className="runway-meter-container">
              <div className="runway-meta-row">
                <span className="meta-label">Simulated Survival Runway:</span>
                <span className={`meta-value mono ${runwayDiff >= 0 ? 'text-emerald' : 'text-crimson'}`}>
                  {simulatedRunwayDays} Days ({runwayDiff >= 0 ? `+${runwayDiff}` : runwayDiff} days)
                </span>
              </div>
              <div className="progress-bar-track">
                <div
                  className={`progress-bar-fill ${
                    simulatedRunwayDays > 90 ? 'fill-emerald' : simulatedRunwayDays > 45 ? 'fill-gold' : 'fill-crimson'
                  }`}
                  style={{ width: `${Math.min(100, (simulatedRunwayDays / 180) * 100)}%` }}
                />
              </div>
            </div>

            {/* Simulation Sliders */}
            <div className="simulator-controls">
              <div className="slider-group">
                <div className="slider-label-row">
                  <span>Cut Discretionary Spend:</span>
                  <span className="mono text-gold">-{discretionaryCutPct}%</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="50"
                  step="5"
                  value={discretionaryCutPct}
                  onChange={(e) => setDiscretionaryCutPct(Number(e.target.value))}
                  className="copilot-slider"
                />
              </div>

              <div className="slider-group">
                <div className="slider-label-row">
                  <span>Client Retainer Delay:</span>
                  <span className="mono text-crimson">+{incomeDelayDays} days</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="60"
                  step="5"
                  value={incomeDelayDays}
                  onChange={(e) => setIncomeDelayDays(Number(e.target.value))}
                  className="copilot-slider"
                />
              </div>
            </div>
          </div>

          {/* 2. Proactive Insights Feed */}
          {data && data.insights.length > 0 && (
            <div className="copilot-insights-section">
              <div className="section-subtitle">
                <Flame size={14} className="text-gold" />
                <span>ACTIVE LIVE FINANCIAL ALERTS</span>
              </div>
              <div className="copilot-insights-list">
                {data.insights.map((ins: CopilotInsightItem) => (
                  <div key={ins.id} className={`insight-card insight-${ins.urgency.toLowerCase()}`}>
                    <div className="insight-card-top">
                      <span className={`badge badge-${ins.urgency === 'HIGH' ? 'crimson' : ins.urgency === 'MEDIUM' ? 'gold' : 'emerald'}`}>
                        {ins.category}
                      </span>
                      <span className="insight-metric mono">{ins.metric}</span>
                    </div>
                    <div className="insight-title">{ins.title}</div>
                    <p className="insight-summary">{ins.summary}</p>
                    <div className="insight-action">
                      <ArrowRight size={12} className="text-gold" />
                      <span>{ins.action}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 3. Conversational Financial Q&A */}
          <div className="copilot-chat-section">
            <div className="section-subtitle">
              <Sparkles size={14} className="text-gold" />
              <span>INTERACTIVE FINANCIAL STRATEGIST</span>
            </div>

            <div className="chat-messages-container">
              {messages.map((m) => (
                <div key={m.id} className={`chat-bubble chat-bubble-${m.role}`}>
                  <div className="chat-bubble-header">
                    <span className="chat-role">{m.role === 'user' ? 'You' : 'Gemini Copilot'}</span>
                    {m.model && <span className="chat-model-tag mono">{m.model}</span>}
                    <span className="chat-time">{m.timestamp}</span>
                  </div>
                  <div className="chat-text" style={{ whiteSpace: 'pre-line' }}>
                    {m.text}
                  </div>
                </div>
              ))}

              {sending && (
                <div className="chat-bubble chat-bubble-assistant loading-bubble">
                  <Sparkles size={14} className="animate-spin text-gold" />
                  <span>Gemini is synthesizing live ledger data...</span>
                </div>
              )}
              <div ref={chatEndRef} />
            </div>

            {/* Quick Prompt Suggestions */}
            <div className="quick-prompts-bar">
              {QUICK_PROMPTS.map((p, idx) => (
                <button
                  key={idx}
                  type="button"
                  className="quick-prompt-btn"
                  onClick={() => handleSendPrompt(p)}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Drawer Footer Input Bar */}
        <div className="copilot-footer">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleSendPrompt();
            }}
            className="copilot-input-form"
          >
            <input
              type="text"
              className="copilot-input"
              placeholder="Ask Gemini about runway, SARS tax, or ZiG arbitrage..."
              value={inputPrompt}
              onChange={(e) => setInputPrompt(e.target.value)}
              disabled={sending}
            />
            <button
              type="submit"
              className="btn btn-primary btn-copilot-send"
              disabled={sending || !inputPrompt.trim()}
            >
              <Send size={16} />
            </button>
          </form>
        </div>
      </aside>
    </div>
  );
};
