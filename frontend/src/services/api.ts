const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { BigQuery } = require('@google-cloud/bigquery');

// Finance and metrics imports
const {
  getTaxSchedule,
  getDailyBurnMetrics,
  getMonthlyBurnMetrics,
  getRunwayProjection,
  getRevenueMetrics,
} = require('../services/financeService');

// BigQuery helper & database service imports
const {
  BQ_CONFIG,
  runQuery,
  getExchangeRates,
  getAccounts,
  getTransactions,
  insertTransaction,
  deleteTransaction,
  getDebts,
  getDebtBalances,
  insertDebt,
  settleDebt,
  deleteDebt,
  getBudgetEnvelopes,
  getVaultHoldings,
  getIncomeStatements,
  getNonOperatingGains,
  getPerformanceSummary,
  verifyBigQueryConnectivity,
  getTroubleshootingGuidance,
} = require('./bigquery');

// AI Copilot service imports
const {
  getCopilotInsights,
  chatWithCopilot,
} = require('./copilot');

// BigQuery initialization from GOOGLE_CREDENTIALS env var
const googleCredentials = process.env.GOOGLE_CREDENTIALS
  ? JSON.parse(process.env.GOOGLE_CREDENTIALS)
  : {};

const bigquery = new BigQuery({
  projectId: googleCredentials.project_id,
  credentials: {
    client_email: googleCredentials.client_email,
    private_key: googleCredentials.private_key,
  },
});

async function verifyBigQuery() {
  try {
    const [datasets] = await bigquery.getDatasets();
    console.log('BigQuery connected. Dataset count:', datasets.length);
  } catch (err) {
    console.error('Error verifying BigQuery:', err);
  }
}

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(bodyParser.json());
app.use(express.json());

// Health & Status endpoint with rich BigQuery connectivity diagnostics
app.get('/api/health', async (req, res) => {
  try {
    const forceCheck = req.query.force === 'true';
    const state = await verifyBigQueryConnectivity({ forceCheck });
    res.json(state);
  } catch (error) {
    res.status(500).json({
      status: 'OFFLINE',
      connected: false,
      error: {
        message: error.message,
        troubleshooting: getTroubleshootingGuidance(error)
      }
    });
  }
});

// Explicit connection test route - forces live probe to BigQuery
app.all('/api/connection-test', async (req, res) => {
  try {
    const state = await verifyBigQueryConnectivity({ forceCheck: true });
    if (state.connected) {
      res.json(state);
    } else {
      res.status(503).json(state);
    }
  } catch (error) {
    res.status(503).json({
      status: 'OFFLINE',
      connected: false,
      error: {
        message: error.message,
        troubleshooting: getTroubleshootingGuidance(error)
      }
    });
  }
});

// Live BigQuery test query execution endpoint
app.get('/api/test-query', async (req, res) => {
  try {
    const sql = `SELECT 
      CURRENT_TIMESTAMP() as query_time,
      COUNT(1) as total_transactions,
      ROUND(SUM(reporting_amount_zar), 2) as total_volume_zar
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\``;
    const rows = await runQuery(sql);
    res.json({
      status: 'SUCCESS',
      project: BQ_CONFIG.projectId,
      dataset: BQ_CONFIG.datasetId,
      location: BQ_CONFIG.location,
      result: rows[0] || rows,
      rowCount: rows.length,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error running BigQuery test query:', error);
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

// Delete transaction (Hard delete from BigQuery warehouse)
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

app.listen(PORT, async () => {
  console.log(`=======================================================`);
  console.log(` Ziva Finance BigQuery API Server running on port ${PORT}`);
  console.log(` Connected to GCP Project: ${BQ_CONFIG.projectId}`);
  console.log(` Dataset: ${BQ_CONFIG.datasetId} (${BQ_CONFIG.location})`);
  console.log(`=======================================================`);

  // Explicit startup connectivity test
  console.log('[Startup Check] Verifying BigQuery warehouse connectivity...');
  await verifyBigQueryConnectivity({ forceCheck: true });
  await verifyBigQuery();
});

module.exports = app;
