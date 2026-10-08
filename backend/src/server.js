const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * Startup function: Ensure Google credentials provided as a JSON string
 * in GOOGLE_APPLICATION_CREDENTIALS or GOOGLE_CREDENTIALS are written to a temporary physical file
 * before any Google SDK client initializes.
 */
function setupGoogleCredentials() {
  const rawCreds = process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.GOOGLE_CREDENTIALS;
  if (!rawCreds) {
    return;
  }

  const trimmed = rawCreds.trim();
  // Check if credentials are provided as a JSON string rather than a file path
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      JSON.parse(trimmed);
      const tempDir = fs.existsSync('/tmp') ? '/tmp' : os.tmpdir();
      const tempFilePath = path.join(tempDir, 'google-creds.json');

      fs.writeFileSync(tempFilePath, trimmed, { mode: 0o600, encoding: 'utf8' });
      process.env.GOOGLE_APPLICATION_CREDENTIALS = tempFilePath;
      console.log(`[Startup] Google credentials JSON string written to temporary file: ${tempFilePath}`);
    } catch (err) {
      console.error('[Startup] Failed to parse and write GOOGLE_APPLICATION_CREDENTIALS JSON string:', err.message);
    }
  }
}

// Execute immediately at the very beginning of server startup
setupGoogleCredentials();

const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

// Google Sheets Live Data Repository (Zero BigQuery billing dependency)
const sheetsRepo = require('../services/googleSheetsRepository');
const {
  REPO_CONFIG,
  SHEETS_CONFIG,
  getExchangeRates,
  getAccounts,
  getTransactions,
  insertTransaction,
  deleteTransaction,
  getDebts,
  getDebtBalances,
  insertDebt,
  settleDebt,
  reopenDebt,
  deleteDebt,
  getBudgetEnvelopes,
  getTaxSchedule,
  getVaultHoldings,
  getDailyBurnMetrics,
  getIncomeStatements,
  getNonOperatingGains,
  getPerformanceSummary,
  verifySheetsConnectivity,
  getTroubleshootingGuidance,
} = sheetsRepo;

// AI Copilot service imports
const {
  getCopilotInsights,
  chatWithCopilot,
} = require('./copilot');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(bodyParser.json());
app.use(express.json());

// Health & Status endpoint with Google Sheets connectivity diagnostics
app.get('/api/health', async (req, res) => {
  try {
    const forceCheck = req.query.force === 'true';
    const state = await verifySheetsConnectivity({ forceCheck });
    res.json(state);
  } catch (error) {
    res.status(500).json({
      status: 'OFFLINE',
      connected: false,
      liveDataLayer: 'GOOGLE_SHEETS_API',
      error: {
        message: error.message,
        troubleshooting: getTroubleshootingGuidance(error)
      }
    });
  }
});

// Explicit connection test route - forces live probe to Google Sheets
app.all('/api/connection-test', async (req, res) => {
  try {
    const state = await verifySheetsConnectivity({ forceCheck: true });
    if (state.connected) {
      res.json(state);
    } else {
      res.status(503).json(state);
    }
  } catch (error) {
    res.status(503).json({
      status: 'OFFLINE',
      connected: false,
      liveDataLayer: 'GOOGLE_SHEETS_API',
      error: {
        message: error.message,
        troubleshooting: getTroubleshootingGuidance(error)
      }
    });
  }
});

// Live data test read endpoint (replaced BigQuery test-query with Sheets read)
app.get('/api/test-query', async (req, res) => {
  try {
    const txs = await getTransactions(50);
    const totalVolumeZar = txs.reduce((sum, t) => sum + (Number(t.reportingAmountZar) || 0), 0);
    res.json({
      status: 'SUCCESS',
      source: 'GOOGLE_SHEETS_LIVE',
      spreadsheetId: REPO_CONFIG.spreadsheetId,
      result: {
        query_time: new Date().toISOString(),
        total_transactions: txs.length,
        total_volume_zar: parseFloat(totalVolumeZar.toFixed(2))
      },
      rowCount: txs.length,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error running test read from Google Sheets:', error);
    res.status(500).json({ error: error.message });
  }
});

// Live FX rates
app.get('/api/rates', async (req, res) => {
  try {
    const rates = await getExchangeRates();
    res.json(rates);
  } catch (error) {
    console.error('Error fetching FX rates:', error);
    res.status(500).json({ error: error.message });
  }
});

// Accounts & Live balances
app.get('/api/accounts', async (req, res) => {
  try {
    const accounts = await getAccounts();
    res.json(accounts);
  } catch (error) {
    console.error('Error fetching accounts:', error);
    res.status(500).json({ error: error.message });
  }
});

// Ledger Transactions
app.get('/api/transactions', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || '100', 10);
    const transactions = await getTransactions(limit);
    res.json(transactions);
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({ error: error.message });
  }
});

// Insert new transaction (Manual entry or receipt scan)
app.post('/api/transactions', async (req, res) => {
  try {
    const result = await insertTransaction(req.body);
    res.json(result);
  } catch (error) {
    console.error('Error inserting transaction:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete transaction
app.delete('/api/transactions/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await deleteTransaction(id);
    res.json(result);
  } catch (error) {
    console.error(`Error deleting transaction ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Debt & Credit Ledger endpoints
app.get('/api/debts', async (req, res) => {
  try {
    const { status } = req.query;
    const debts = await getDebts(status);
    res.json(debts);
  } catch (error) {
    console.error('Error fetching debts:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/debts/balances', async (req, res) => {
  try {
    const { person } = req.query;
    const balances = await getDebtBalances(person);
    res.json(balances);
  } catch (error) {
    console.error('Error fetching debt balances:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/debts', async (req, res) => {
  try {
    const result = await insertDebt(req.body);
    res.json(result);
  } catch (error) {
    console.error('Error creating debt record:', error);
    res.status(500).json({ error: error.message });
  }
});

// Settle Debt - updates status in Google Sheets debt_credit_ledger directly
app.patch('/api/debts/:id/settle', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await settleDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error settling debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Reopen / Undo Settle Debt
app.patch('/api/debts/:id/reopen', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await reopenDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error reopening debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/debts/:id/reopen', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await reopenDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error reopening debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Delete Debt
app.delete('/api/debts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await deleteDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error deleting debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Google Sheets Ingestion & Architecture endpoints
app.get('/api/sheets/config', (req, res) => {
  res.json({
    spreadsheetId: REPO_CONFIG.spreadsheetId,
    transactionsTab: REPO_CONFIG.transactionsTab,
    debtsTab: REPO_CONFIG.debtsTab,
    accountsTab: REPO_CONFIG.accountsTab,
    categoriesTab: REPO_CONFIG.categoriesTab,
    budgetsTab: REPO_CONFIG.budgetsTab,
    ratesTab: REPO_CONFIG.ratesTab,
    readMode: 'GOOGLE_SHEETS_API',
    writeMode: 'GOOGLE_SHEETS_API',
    bigqueryBillingRequired: false
  });
});

app.post('/api/sheets/configure-external-tables', async (req, res) => {
  res.json({
    success: true,
    spreadsheetId: REPO_CONFIG.spreadsheetId,
    message: 'Google Sheets is the authoritative live data layer. BigQuery external tables bypassed.'
  });
});

// Budget Envelopes vs Actual
app.get('/api/budgets', async (req, res) => {
  try {
    const envelopes = await getBudgetEnvelopes();
    res.json(envelopes);
  } catch (error) {
    console.error('Error fetching budgets:', error);
    res.status(500).json({ error: error.message });
  }
});

// Tax Schedule
app.get('/api/tax-schedule', async (req, res) => {
  try {
    const schedule = await getTaxSchedule();
    res.json(schedule);
  } catch (error) {
    console.error('Error fetching tax schedule:', error);
    res.status(500).json({ error: error.message });
  }
});

// Vault holdings & Net Worth
app.get('/api/vault', async (req, res) => {
  try {
    const vault = await getVaultHoldings();
    res.json(vault);
  } catch (error) {
    console.error('Error fetching vault holdings:', error);
    res.status(500).json({ error: error.message });
  }
});

// Daily Burn Metrics
app.get('/api/burn-rate', async (req, res) => {
  try {
    const burn = await getDailyBurnMetrics();
    res.json(burn);
  } catch (error) {
    console.error('Error fetching burn metrics:', error);
    res.status(500).json({ error: error.message });
  }
});

// Gemini AI Copilot Insights & Runway Forecasting
app.get('/api/copilot/insights', async (req, res) => {
  try {
    const insights = await getCopilotInsights();
    res.json(insights);
  } catch (error) {
    console.error('Error generating Copilot insights:', error);
    res.status(500).json({ error: error.message });
  }
});

// Gemini AI Copilot Chat & Interactive Reasoning
app.post('/api/copilot/chat', async (req, res) => {
  try {
    const { prompt, apiKey } = req.body;
    const response = await chatWithCopilot({ prompt, apiKey });
    res.json(response);
  } catch (error) {
    console.error('Error in Copilot chat:', error);
    res.status(500).json({ error: error.message });
  }
});

// Performance & Analytics: Structured Income Statements (Monthly / Quarterly)
app.get('/api/analytics/income-statement', async (req, res) => {
  try {
    const periodType = req.query.periodType || null;
    const statements = await getIncomeStatements(periodType);
    res.json(statements);
  } catch (error) {
    console.error('Error fetching income statements:', error);
    res.status(500).json({ error: error.message });
  }
});

// Performance & Analytics: Non-Operating Gains & Asset Yields
app.get('/api/analytics/non-operating-gains', async (req, res) => {
  try {
    const gains = await getNonOperatingGains();
    res.json(gains);
  } catch (error) {
    console.error('Error fetching non-operating gains:', error);
    res.status(500).json({ error: error.message });
  }
});

// Performance & Analytics: Consolidated Performance Summary (KPIs, Habits, Trends)
app.get('/api/analytics/summary', async (req, res) => {
  try {
    const summary = await getPerformanceSummary();
    res.json(summary);
  } catch (error) {
    console.error('Error fetching analytics summary:', error);
    res.status(500).json({ error: error.message });
  }
});

if (require.main === module) {
  app.listen(PORT, async () => {
    console.log(`=======================================================`);
    console.log(` Ziva Finance Google Sheets API Server running on port ${PORT}`);
    console.log(` Spreadsheet ID: ${REPO_CONFIG.spreadsheetId}`);
    console.log(` Live Architecture: Google Sheets API v4 (Zero BigQuery billing)`);
    console.log(`=======================================================`);

    // Verify Google Sheets connectivity on boot
    try {
      console.log('[Startup Check] Verifying Google Sheets connectivity...');
      const connState = await verifySheetsConnectivity({ forceCheck: true });
      if (connState.connected) {
        console.log(`[Startup Check] Google Sheets connected successfully (Spreadsheet: ${connState.spreadsheetId})`);
      } else {
        console.warn(`[Startup Check] Google Sheets connectivity warning: ${connState.error?.message || 'Check credentials'}`);
      }
    } catch (err) {
      console.warn('[Startup Check] Note on Google Sheets check:', err.message);
    }
  });
}

module.exports = app;
