/**
 * bigquery.js - Backward Compatibility Façade & Google Sheets Data Bridge
 * 
 * NOTE: Live BigQuery queries, external tables, and billing dependencies have been 
 * COMPLETELY DEPRECATED and removed in favor of direct Google Sheets API v4 access via
 * googleSheetsRepository.js. This avoids any Google Cloud billing requirements (such as
 * the 403 billing error experienced on Render).
 *
 * All operations now route directly to Google Sheets with zero BigQuery billing dependency.
 */

const sheetsRepo = require('../services/googleSheetsRepository');

const SHEETS_CONFIG = sheetsRepo.SHEETS_CONFIG;
const BQ_CONFIG = {
  projectId: process.env.GCP_PROJECT_ID || process.env.BIGQUERY_PROJECT_ID || 'budget-tracker-507418',
  datasetId: process.env.BIGQUERY_DATASET || 'personal_finance',
  location: process.env.BIGQUERY_LOCATION || 'africa-south1',
  defaultTimezone: 'Africa/Johannesburg',
  deprecated: true,
  notice: 'BigQuery queries disabled. Google Sheets is the active live persistence and read layer.'
};

const getTroubleshootingGuidance = sheetsRepo.getTroubleshootingGuidance;
const resolveAuthDetails = sheetsRepo.resolveGoogleCredentials;
const mapAccountRow = (row) => ({
  ...row,
  nativeBalance: Number(row.nativeBalance || 0)
});

// Deprecated runQuery stub that safely returns empty array without throwing billing errors
async function runQuery(sql, params = {}) {
  console.warn('[BigQuery Bridge] runQuery called but BigQuery is disabled. Use Google Sheets repository instead.');
  return [];
}

// Connectivity verification routes to Google Sheets connectivity check
async function verifyBigQueryConnectivity(options = {}) {
  const result = await sheetsRepo.verifySheetsConnectivity(options);
  return {
    ...result,
    source: 'GOOGLE_SHEETS_LIVE',
    bigqueryBillingBypassed: true
  };
}

// External table configuration stub (no-op since Google Sheets is read directly)
async function ensureExternalTablesConfigured(spreadsheetId) {
  return {
    success: true,
    spreadsheetId: spreadsheetId || sheetsRepo.SHEETS_CONFIG.spreadsheetId,
    configuredTables: ['fct_transactions', 'debt_credit_ledger'],
    notice: 'Google Sheets is the authoritative live data layer. BigQuery external tables bypassed.'
  };
}

// Re-export all live business data functions mapped to Google Sheets
const getExchangeRates = sheetsRepo.getExchangeRates;
const getAccounts = sheetsRepo.getAccounts;
const getTransactions = sheetsRepo.getTransactions;
const insertTransaction = sheetsRepo.insertTransaction;
const deleteTransaction = sheetsRepo.deleteTransaction;
const getDebts = sheetsRepo.getDebts;
const getDebtBalances = sheetsRepo.getDebtBalances;
const insertDebt = sheetsRepo.insertDebt;
const settleDebt = sheetsRepo.settleDebt;
const reopenDebt = sheetsRepo.reopenDebt;
const deleteDebt = sheetsRepo.deleteDebt;
const getBudgetEnvelopes = sheetsRepo.getBudgetEnvelopes;
const getTaxSchedule = sheetsRepo.getTaxSchedule;
const getVaultHoldings = sheetsRepo.getVaultHoldings;
const getDailyBurnMetrics = sheetsRepo.getDailyBurnMetrics;
const getIncomeStatements = sheetsRepo.getIncomeStatements;
const getNonOperatingGains = sheetsRepo.getNonOperatingGains;
const getPerformanceSummary = sheetsRepo.getPerformanceSummary;

module.exports = {
  SHEETS_CONFIG,
  BQ_CONFIG,
  getTroubleshootingGuidance,
  resolveAuthDetails,
  mapAccountRow,
  runQuery,
  verifyBigQueryConnectivity,
  ensureExternalTablesConfigured,
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
  getPerformanceSummary
};
