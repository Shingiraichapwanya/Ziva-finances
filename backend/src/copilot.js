/**
 * copilot.js - Gemini AI Financial Copilot Engine
 * Provides predictive runway forecasting, SARS provisional tax optimization,
 * Southern African multi-currency arbitrage advice, and conversational financial reasoning.
 */

import { GoogleGenAI } from '@google/genai';
import sheetsRepo from '../services/googleSheetsRepository.js';
const {
  getAccounts,
  getTransactions,
  getBudgetEnvelopes,
  getTaxSchedule,
  getDailyBurnMetrics,
  getExchangeRates
} = sheetsRepo;

/**
 * Generate comprehensive predictive insights and runway metrics from BigQuery
 */
export async function getCopilotInsights() {
  const [accounts, transactions, envelopes, taxSchedule, burnMetrics, rates] = await Promise.all([
    getAccounts(),
    getTransactions(50),
    getBudgetEnvelopes(),
    getTaxSchedule(),
    getDailyBurnMetrics(),
    getExchangeRates()
  ]);

  // 1. Calculate Liquid Reserves (Tier 1 Daily + Tier 2 Monthly in ZAR)
  let liquidReserveZar = 0;
  let vaultTotalZar = 0;

  accounts.forEach((acc) => {
    let nativeInZar = acc.nativeBalance;
    if (acc.primaryCurrency === 'USD') nativeInZar = acc.nativeBalance * rates.USD_TO_ZAR;
    else if (acc.primaryCurrency === 'ZiG') nativeInZar = acc.nativeBalance / rates.ZAR_TO_ZIG_PARALLEL;

    if (acc.cashFlowTier === 'DAILY_SPENDING' || acc.cashFlowTier === 'MONTHLY_ALLOCATION') {
      liquidReserveZar += nativeInZar;
    } else if (acc.cashFlowTier === 'LONG_TERM_VAULT') {
      vaultTotalZar += nativeInZar;
    }
  });

  // 2. Daily Burn Rate & Velocity
  let avgDailyBurnZar = 650; // default baseline
  if (burnMetrics.length > 0) {
    const totalDaily = burnMetrics.reduce((sum, b) => sum + b.dailySpendZar, 0);
    avgDailyBurnZar = Math.max(100, Math.round(totalDaily / burnMetrics.length));
  }

  const baselineRunwayDays = avgDailyBurnZar > 0 ? Math.max(0, Math.floor(liquidReserveZar / avgDailyBurnZar)) : 999;
  const survivalDate = new Date(Date.now() + baselineRunwayDays * 86400000).toISOString().split('T')[0];

  // Fixed monthly commitments from envelopes
  const fixedCommitmentsZar = envelopes
    .filter((e) => e.isFixedObligation)
    .reduce((sum, e) => sum + e.plannedAmountZar, 0);

  const fixedRunwayDays = fixedCommitmentsZar > 0 ? Math.floor(liquidReserveZar / (fixedCommitmentsZar / 30)) : 999;

  // 3. Proactive Tax Shield & Deduction Insights
  const missingInvoiceTxs = transactions.filter((t) => t.isTaxDeductible && !t.taxInvoiceNumber);
  const totalDeductibleUnverified = missingInvoiceTxs.reduce((sum, t) => sum + Math.abs(t.reportingAmountZar), 0);
  const taxSavingsAtRisk = Math.round(totalDeductibleUnverified * 0.27);

  // 4. Over-Budget Warning Envelopes
  const criticalEnvelopes = envelopes.filter((e) => e.pctConsumed >= 85);

  // 5. Currency Spread (ZiG Parallel vs Official)
  const officialRate = rates.USD_TO_ZIG_OFFICIAL || 13.85;
  const parallelRate = rates.USD_TO_ZIG_PARALLEL || 24.50;
  const spreadPct = Math.round(((parallelRate - officialRate) / officialRate) * 100);

  // 6. Actionable Insights Array
  const insights = [
    {
      id: 'insight-runway',
      type: 'RUNWAY',
      urgency: baselineRunwayDays < 60 ? 'HIGH' : baselineRunwayDays < 90 ? 'MEDIUM' : 'OPTIMAL',
      title: `${baselineRunwayDays} Days of Liquid Runway`,
      summary: `At current 7-day velocity of R${avgDailyBurnZar.toLocaleString()}/day, liquid reserves will reach zero by ${survivalDate}.`,
      action: 'Run scenario simulator to model spending cuts or retainers.',
      metric: `${baselineRunwayDays} days`,
      category: 'Liquidity'
    },
    {
      id: 'insight-tax-audit',
      type: 'TAX',
      urgency: missingInvoiceTxs.length > 0 ? 'HIGH' : 'LOW',
      title: `R${taxSavingsAtRisk.toLocaleString()} Tax Savings at Risk`,
      summary: `${missingInvoiceTxs.length} tax-deductible expenses lack formal tax invoices, risking audit disallowance from SARS.`,
      action: 'Attach vendor invoices (INV-*) to secure 27% write-offs.',
      metric: `R${taxSavingsAtRisk.toLocaleString()} potential write-off`,
      category: 'Tax Shield'
    },
    {
      id: 'insight-currency-arb',
      type: 'CURRENCY',
      urgency: spreadPct > 50 ? 'MEDIUM' : 'LOW',
      title: `+${spreadPct}% ZiG Parallel Premium Alert`,
      summary: `Parallel market rate (ZiG ${parallelRate.toFixed(2)}) is trading at a ${spreadPct}% premium over interbank (ZiG ${officialRate.toFixed(2)}).`,
      action: 'Swipe debit card for local supermarkets/pharmacies at official rates; preserve USD cash reserves for offshore/imports.',
      metric: `${spreadPct}% spread`,
      category: 'Arbitrage'
    }
  ];

  if (criticalEnvelopes.length > 0) {
    const worst = criticalEnvelopes[0];
    insights.push({
      id: 'insight-envelope-alert',
      type: 'BUDGET',
      urgency: 'HIGH',
      title: `${worst.categoryName} at ${Math.round(worst.pctConsumed)}% Capacity`,
      summary: `Spend is R${worst.actualSpentZar.toLocaleString()} vs R${worst.plannedAmountZar.toLocaleString()} planned. Variance: R${worst.varianceZar.toLocaleString()}.`,
      action: `Shift R${Math.abs(worst.varianceZar).toLocaleString()} from discretionary buffer to avoid envelope depletion.`,
      metric: `${Math.round(worst.pctConsumed)}%`,
      category: 'Budget Envelope'
    });
  }

  return {
    metrics: {
      liquidReserveZar: Math.round(liquidReserveZar),
      vaultTotalZar: Math.round(vaultTotalZar),
      averageDailyBurnZar: avgDailyBurnZar,
      baselineRunwayDays: baselineRunwayDays,
      fixedObligationsRunwayDays: fixedRunwayDays,
      survivalDate: survivalDate,
      monthlyFixedCommitmentsZar: Math.round(fixedCommitmentsZar),
      taxSavingsAtRiskZar: taxSavingsAtRisk,
      taxDeductibleUnverifiedCount: missingInvoiceTxs.length,
      spreadPct: spreadPct,
      burnStatus: baselineRunwayDays > 120 ? 'OPTIMAL' : baselineRunwayDays > 60 ? 'STABLE' : 'ACCELERATING'
    },
    insights: insights,
    generatedAt: new Date().toISOString()
  };
}

/**
 * Handle interactive chat with Gemini model or deterministic financial engine
 */
export async function chatWithCopilot({ prompt, apiKey }) {
  const insights = await getCopilotInsights();
  const effectiveKey = apiKey || process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;

  // Mode 1: Live Gemini API via @google/genai
  if (effectiveKey) {
    try {
      const ai = new GoogleGenAI({ apiKey: effectiveKey });
      const systemInstruction = `
You are the Chief AI Financial Strategist for Ziva Finance, a personal financial command center managing Southern African cross-border cash flows (South Africa ZAR and Zimbabwe USD/ZiG).
You have authoritative access to the user's real-time BigQuery data warehouse (project: budget-tracker-507418, dataset: personal_finance).

Current Real-Time Metrics Grounding:
- Liquid Reserves (Tier 1 Daily + Tier 2 Monthly): R${insights.metrics.liquidReserveZar.toLocaleString()} ZAR
- Long-Term Vault Wealth: R${insights.metrics.vaultTotalZar.toLocaleString()} ZAR
- 7-Day Average Daily Burn: R${insights.metrics.averageDailyBurnZar.toLocaleString()} ZAR/day
- Estimated Liquid Runway: ${insights.metrics.baselineRunwayDays} Days (Survival Date: ${insights.metrics.survivalDate})
- Monthly Fixed Commitments: R${insights.metrics.monthlyFixedCommitmentsZar.toLocaleString()} ZAR
- Tax Write-off Savings at Risk (Missing Invoices): R${insights.metrics.taxSavingsAtRiskZar.toLocaleString()} ZAR
- ZiG Parallel vs Official Spread: +${insights.metrics.spreadPct}%

Rules:
1. Provide actionable, concise, quantitative recommendations formatted in Markdown.
2. Directly reference SARS provisional tax principles (27% allowable business productivity write-offs, section 11(a) deductions), ZIMRA IMTT 2% considerations, and multi-tier envelope discipline.
3. Be proactive and supportive, highlighting exact numbers and actionable levers.
`;

      const response = await ai.models.generateContent({
        model: 'gemini-2.5-flash',
        contents: prompt,
        config: {
          systemInstruction: systemInstruction,
          temperature: 0.2
        }
      });

      return {
        reply: response.text,
        model: 'Gemini 2.5 Flash',
        metrics: insights.metrics
      };
    } catch (err) {
      console.warn('Gemini API call failed, falling back to deterministic financial engine:', err.message);
    }
  }

  // Mode 2: Deterministic Domain-Grounded Financial Reasoner
  const p = prompt.toLowerCase();
  let reply = '';

  if (p.includes('runway') || p.includes('survival') || p.includes('how long') || p.includes('burn')) {
    reply = `### 📊 Cash Runway & Burn Velocity Assessment

Based on real-time BigQuery partitions in **\`budget-tracker-507418.personal_finance\`**:

* **Liquid Reserves (Tier 1 & Tier 2)**: **R${insights.metrics.liquidReserveZar.toLocaleString()}**
* **Rolling 7-Day Spend Velocity**: **R${insights.metrics.averageDailyBurnZar.toLocaleString()} / day**
* **Baseline Runway**: **${insights.metrics.baselineRunwayDays} Days** (Cash exhaustion date: **${insights.metrics.survivalDate}**)
* **Fixed Obligation Runway**: **${insights.metrics.fixedObligationsRunwayDays} Days** (Strict survival on contractual rent & utilities)

**Strategic Levers to Extend Runway:**
1. **Reduce Dining & Discretionary Velocity by 30%**: Adds **+${Math.round(insights.metrics.baselineRunwayDays * 0.25)} days** of operational runway.
2. **Accelerate Client Invoicing**: Bringing forward one retainer cycle adds approximately **45 days** of buffer.
3. **Vault Preservation Rule**: Do not break the Discovery 32-day notice deposit or EasyEquities TFSA; maintain strict Tier 3 segregation.`;
  } else if (p.includes('tax') || p.includes('sars') || p.includes('deduct') || p.includes('provisional')) {
    reply = `### 🛡️ SARS Provisional Tax Shield Strategy

* **Current Quarter**: 2026-Q3 (provisional payment window active)
* **Estimated Allowable Productivity Write-Offs**: **R${(insights.metrics.taxSavingsAtRiskZar * 3.7).toLocaleString()}**
* **Tax Relief at 27% Effective Rate**: **R${insights.metrics.taxSavingsAtRiskZar.toLocaleString()}**
* **Audit Risk Alert**: You have **${insights.metrics.taxDeductibleUnverifiedCount} tax-deductible transactions** without attached vendor tax invoices.

**Immediate Optimization Checklist:**
1. **Attach Invoices**: Upload official vendor invoices for software tools (Claude/ChatGPT team), work monitors, and cloud infrastructure.
2. **Hardware Section 11(e) Allowance**: Capital assets under R7,000 (such as standing desks and monitors) qualify for 100% immediate expensing in the year of purchase.
3. **Provisional Tax Payment**: Remit your estimated net liability through SARS eFiling before the quarterly deadline to avoid late payment penalties (10%) and interest.`;
  } else if (p.includes('zig') || p.includes('currency') || p.includes('arbitrage') || p.includes('usd') || p.includes('rate')) {
    reply = `### 💱 Southern African Multi-Currency Hedging Strategy

* **RBZ Official Interbank Rate**: **ZiG 13.85 / USD**
* **Retail Market Parallel Rate**: **ZiG 24.50 / USD**
* **Active Arbitrage Spread**: **+${insights.metrics.spreadPct}% Premium**

**Tactical Recommendations:**
1. **Retail Grocery & Supermarket Spend**: Use local card swipe (EcoCash ZiG or bank POS) pegged to statutory interbank pricing to exploit consumer purchasing power parity.
2. **Hardware & Import Protection**: Settle digital software and international subscriptions strictly via Nostro USD or ZAR credit facilities to bypass domestic exchange control markups.
3. **Emergency Reserves**: Retain emergency buffers in USD Cash or ZAR high-yield notice accounts to insulate against local currency volatility.`;
  } else {
    reply = `### ⚡ Financial Command Center Synthesis

Here is your current financial executive briefing:

1. **Liquidity Health**: You possess **${insights.metrics.baselineRunwayDays} days of liquid runway** (R${insights.metrics.liquidReserveZar.toLocaleString()} across Capitec, FNB, and EcoCash).
2. **Tax Opportunities**: **R${insights.metrics.taxSavingsAtRiskZar.toLocaleString()} in potential tax write-offs** requires invoice attachment before SARS submission.
3. **Vault Compounding**: Your Long-Term Vault holds **R${insights.metrics.vaultTotalZar.toLocaleString()}** safely locked in compounding ETFs and notice funds.
4. **Currency Advantage**: A **+${insights.metrics.spreadPct}% parallel spread** gives you significant pricing power when paying via official POS swipe.

*Tip: Connect your Gemini API Key in Settings or the Copilot drawer for personalized, generative natural language financial advisory.*`;
  }

  return {
    reply: reply,
    model: 'Built-in Financial Reasoner',
    metrics: insights.metrics
  };
}
