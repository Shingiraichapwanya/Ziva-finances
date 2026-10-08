/**
 * services/financeService.js
 * 
 * Financial Analytics & Projections Engine for Ziva Finance
 * Routes through Google Sheets Repository (Zero BigQuery billing dependency).
 */

const sheetsRepo = require('./googleSheetsRepository');

const OPENING_BALANCES = {};

async function getDailyBurnMetrics(days = 14) {
  return sheetsRepo.getDailyBurnMetrics(days);
}

async function getMonthlyBurnMetrics(months = 6) {
  const statements = await sheetsRepo.getIncomeStatements('MONTH');
  return statements.slice(-months).map((s) => ({
    month: s.period,
    totalExpensesZar: s.totalOutflowZar,
    netBurnZar: Math.max(0, s.totalOutflowZar - s.totalInflowZar),
    savingsRate: s.savingsRatePct
  }));
}

async function getBurnRateSummary(days = 14) {
  return sheetsRepo.getBurnRateSummary(days);
}

async function getRunwayProjection() {
  const summary = await sheetsRepo.getBurnRateSummary(14);
  return {
    liquidReserveZar: summary.metrics.liquidReserveBalanceZar,
    avgDailyBurnZar: summary.metrics.averageDailyBurnZar,
    baselineRunwayDays: summary.metrics.baselineRunwayDays,
    survivalDate: summary.metrics.survivalDate
  };
}

async function getMonthlySpendingTrends(months = 6) {
  const txs = await sheetsRepo.getTransactions(500);
  const categoryTrends = {};

  txs.forEach((t) => {
    if (t.transactionType === 'EXPENSE' || t.transactionType === 'DEBIT') {
      const month = (t.transactionDate || '').slice(0, 7);
      const cat = t.categoryId || 'UNCATEGORIZED';
      if (!categoryTrends[cat]) categoryTrends[cat] = {};
      categoryTrends[cat][month] = (categoryTrends[cat][month] || 0) + Math.abs(Number(t.reportingAmountZar || 0));
    }
  });

  return categoryTrends;
}

async function getRevenueMetrics() {
  const statements = await sheetsRepo.getIncomeStatements('MONTH');
  const currentMonth = statements[statements.length - 1] || {};
  return {
    currentMonthInflowZar: currentMonth.totalInflowZar || 0,
    currentMonthInflowUsd: currentMonth.totalInflowUsd || 0,
    netSavingsZar: currentMonth.netSavingsZar || 0
  };
}

async function getTaxSchedule() {
  return sheetsRepo.getTaxSchedule();
}

async function insertRows(rows, tab = 'fct_transactions') {
  if (tab === 'debt_credit_ledger') {
    return Promise.all(rows.map((r) => sheetsRepo.insertDebt(r)));
  }
  return Promise.all(rows.map((r) => sheetsRepo.insertTransaction(r)));
}

async function recordTransaction(txData) {
  return sheetsRepo.insertTransaction(txData);
}

// Deprecated BigQuery stubs for compatibility
function getBigQueryClient() {
  console.warn('[financeService] getBigQueryClient is deprecated. System uses Google Sheets repository.');
  return null;
}

async function runQuery(sql, params = {}) {
  console.warn('[financeService] runQuery is deprecated. System uses Google Sheets repository.');
  return [];
}

const financeService = {
  getDailyBurnMetrics,
  getBurnRateSummary,
  getMonthlyBurnMetrics,
  getRunwayProjection,
  getMonthlySpendingTrends,
  getRevenueMetrics,
  getTaxSchedule,
  insertRows,
  recordTransaction,
  getBigQueryClient,
  runQuery,
  BQ_CONFIG: sheetsRepo.REPO_CONFIG,
  OPENING_BALANCES
};

module.exports = {
  ...financeService,
  financeService,
  default: financeService
};
