/**
 * services/financeService.js
 * 
 * Production-Ready BigQuery Financial Analytics & Projections Engine for Ziva Finance
 * Grounded in Google Cloud Project: budget-tracker-507418, Dataset: personal_finance
 * 
 * Provides:
 *  - Native SDK Ingestion (table.insert / insertRows) replacing CLI 'bq' calls
 *  - Daily & Monthly Burn Rate Calculations
 *  - Cash Runway Forecasting & Survival Date Projections
 *  - Monthly Spending Trends by Category & Month-over-Month Variance
 *  - Inflow / Revenue Metrics & Cashflow Tracking
 *  - SARS Provisional Tax Liability & Deductions Scheduling
 */

const { BigQuery } = require('@google-cloud/bigquery');
const fs = require('fs');
const path = require('path');

// 1. Authoritative BigQuery Configuration
const BQ_CONFIG = {
  projectId: process.env.GCP_PROJECT_ID || process.env.BIGQUERY_PROJECT_ID || 'budget-tracker-507418',
  datasetId: process.env.BIGQUERY_DATASET || 'personal_finance',
  location: process.env.BIGQUERY_LOCATION || 'africa-south1',
};

// Opening balances dictionary for baseline cash reserves (aligned with dim_accounts)
const OPENING_BALANCES = {
  ACC_ZA_DISCOVERY_CHECKING: 34500.00,
  ACC_ZA_SAVINGS_POCKET: 12000.00,
  ACC_ZA_DISCOVERY_CREDIT: -8500.00,
  ACC_ZA_DISCOVERY_VAULT: 150000.00,
  ACC_ZA_EE_EQUITIES_VAULT: 680000.00,
  ACC_ZW_ECOCASH_USD: 1250.00,
  ACC_ZW_ECOCASH_ZIG: 4500.00,
  ACC_ZW_INNBUCKS_USD: 200.00,
  ACC_ZW_OM_BALANCED_VAULT: 15000.00,
  ACC_ZW_STANBIC_NOSTRO_MONTHLY: 2400.00,
};

// 2. Self-Contained Multi-Tier BigQuery Client Initialization
let bigqueryInstance = null;

function getBigQueryClient() {
  if (bigqueryInstance) {
    return bigqueryInstance;
  }

  // Tier 1: GOOGLE_CREDENTIALS environment variable (Render production deployment)
  if (process.env.GOOGLE_CREDENTIALS) {
    try {
      const credentials = typeof process.env.GOOGLE_CREDENTIALS === 'string'
        ? JSON.parse(process.env.GOOGLE_CREDENTIALS)
        : process.env.GOOGLE_CREDENTIALS;

      bigqueryInstance = new BigQuery({
        projectId: credentials.project_id || BQ_CONFIG.projectId,
        location: BQ_CONFIG.location,
        credentials: {
          client_email: credentials.client_email,
          private_key: credentials.private_key,
        },
      });
      return bigqueryInstance;
    } catch (err) {
      console.warn('[financeService] Failed to parse GOOGLE_CREDENTIALS env var:', err.message);
    }
  }

  // Tier 2: Standard GOOGLE_APPLICATION_CREDENTIALS file path
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
    bigqueryInstance = new BigQuery({
      projectId: BQ_CONFIG.projectId,
      location: BQ_CONFIG.location,
      keyFilename: process.env.GOOGLE_APPLICATION_CREDENTIALS,
    });
    return bigqueryInstance;
  }

  // Tier 3: Local candidate service account files
  const candidateKeyPaths = [
    path.resolve(__dirname, '../service-account.json'),
    path.resolve(__dirname, '../../service-account.json'),
    path.resolve(__dirname, './service-account.json'),
    path.resolve(__dirname, '../../mobile/assets/credentials/mobile-bigquery-client.json'),
  ];

  for (const keyPath of candidateKeyPaths) {
    if (fs.existsSync(keyPath)) {
      try {
        const content = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
        if (content.private_key) {
          bigqueryInstance = new BigQuery({
            projectId: content.project_id || BQ_CONFIG.projectId,
            location: BQ_CONFIG.location,
            keyFilename: keyPath,
          });
          return bigqueryInstance;
        }
      } catch (_) {}
    }
  }

  // Tier 4: Application Default Credentials (ADC) fallback
  bigqueryInstance = new BigQuery({
    projectId: BQ_CONFIG.projectId,
    location: BQ_CONFIG.location,
  });
  return bigqueryInstance;
}

/**
 * Execute BigQuery SQL query with resource attribution labels
 */
async function runQuery(sql, params = {}) {
  const client = getBigQueryClient();
  const options = {
    query: sql,
    location: BQ_CONFIG.location,
    params,
    labels: { datacloud: 'antigravity' },
  };

  const [job] = await client.createQueryJob(options);
  const [rows] = await job.getQueryResults({ timeoutMs: 30000 });
  return rows || [];
}

/**
 * Inserts one or more rows directly into a BigQuery table using streaming insert.
 * Replaces any calls that previously shelled out to `bq insert` or `bq load`.
 *
 * @param {string} tableName - e.g. 'fct_transactions'
 * @param {Object|Object[]} rows - Single row object or array of row objects
 * @param {Object} [options] - Optional BigQuery insert options (e.g. raw, ignoreUnknownValues)
 */
async function insertRows(tableName, rows, options = {}) {
  const client = getBigQueryClient();
  const dataset = client.dataset(BQ_CONFIG.datasetId);
  const table = dataset.table(tableName);

  const payload = Array.isArray(rows) ? rows : [rows];
  if (payload.length === 0) return { inserted: 0 };

  try {
    const defaultOptions = {
      raw: false,
      ignoreUnknownValues: true,
      skipInvalidRows: false,
      ...options,
    };

    const [apiResponse] = await table.insert(payload, defaultOptions);
    return {
      success: true,
      insertedCount: payload.length,
      response: apiResponse,
    };
  } catch (err) {
    // BigQuery partial failure details are populated in err.errors
    if (err.name === 'PartialFailureError' && err.errors) {
      console.error(
        `[financeService] Partial failure inserting into ${tableName}:`,
        JSON.stringify(err.errors, null, 2)
      );
      throw new Error(
        `BigQuery streaming insert failed for ${err.errors.length} rows: ${err.errors[0]?.errors[0]?.message || err.message}`
      );
    }
    console.error(`[financeService] Error inserting rows into ${tableName}:`, err);
    throw err;
  }
}

/**
 * Insert a single transaction record into fct_transactions
 */
async function recordTransaction(transactionData) {
  return insertRows('fct_transactions', transactionData);
}

/**
 * 1. Calculate Daily Spending Burn Rate Metrics
 */
async function getDailyBurnMetrics(days = 14) {
  try {
    const sql = `
      SELECT 
        CAST(transaction_date AS STRING) AS transactionDate,
        CAST(SUM(total_spent_zar) AS FLOAT64) AS dailySpendZar,
        CAST(AVG(rolling_7d_avg_spend_zar) AS FLOAT64) AS rolling7dAvgSpendZar,
        CAST(SUM(total_spent_usd) AS FLOAT64) AS dailySpendUsd,
        CAST(AVG(rolling_7d_avg_spend_usd) AS FLOAT64) AS rolling7dAvgSpendUsd
      FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_daily_spending_burn_rate\`
      GROUP BY transaction_date
      ORDER BY transaction_date DESC
      LIMIT ${parseInt(days, 10) || 14}
    `;
    const rows = await runQuery(sql);

    if (rows && rows.length > 0) {
      return rows.map((r) => {
        const dailySpend = parseFloat(r.dailySpendZar || 0);
        const rollingAvg = parseFloat(r.rolling7dAvgSpendZar || 0);
        const velocity = rollingAvg > 0 ? parseFloat((dailySpend / rollingAvg).toFixed(2)) : 1.0;

        return {
          transactionDate: r.transactionDate,
          dailySpendZar: dailySpend,
          rolling7dAvgSpendZar: rollingAvg,
          dailySpendUsd: parseFloat(r.dailySpendUsd || 0),
          rolling7dAvgSpendUsd: parseFloat(r.rolling7dAvgSpendUsd || 0),
          burnVelocityRatio: velocity,
          burnAlertStatus: (rollingAvg > 0 && velocity > 1.3) ? 'ELEVATED' : 'NORMAL',
        };
      });
    }
  } catch (err) {
    console.warn('[financeService] v_daily_spending_burn_rate fallback to fct_transactions:', err.message);
  }

  // Resilient fallback: Aggregate directly from fct_transactions
  const fallbackSql = `
    SELECT 
      CAST(transaction_date AS STRING) AS transactionDate,
      ROUND(SUM(ABS(reporting_amount_zar)), 2) AS dailySpendZar,
      ROUND(SUM(ABS(reporting_amount_usd)), 2) AS dailySpendUsd
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\`
    WHERE reporting_amount_zar < 0
    GROUP BY transaction_date
    ORDER BY transaction_date DESC
    LIMIT ${parseInt(days, 10) || 14}
  `;
  const rawRows = await runQuery(fallbackSql);

  return rawRows.map((r, i, arr) => {
    const dailySpend = parseFloat(r.dailySpendZar || 0);
    const windowSlice = arr.slice(Math.max(0, i - 6), i + 1);
    const rollingSum = windowSlice.reduce((acc, curr) => acc + parseFloat(curr.dailySpendZar || 0), 0);
    const rollingAvg = parseFloat((rollingSum / windowSlice.length).toFixed(2));
    const velocity = rollingAvg > 0 ? parseFloat((dailySpend / rollingAvg).toFixed(2)) : 1.0;

    return {
      transactionDate: r.transactionDate,
      dailySpendZar: dailySpend,
      rolling7dAvgSpendZar: rollingAvg,
      dailySpendUsd: parseFloat(r.dailySpendUsd || 0),
      rolling7dAvgSpendUsd: parseFloat((dailySpend / 18.5).toFixed(2)),
      burnVelocityRatio: velocity,
      burnAlertStatus: (rollingAvg > 0 && velocity > 1.3) ? 'ELEVATED' : 'NORMAL',
    };
  });
}

/**
 * 2. Calculate Current Monthly Burn Rate and Historical Monthly Burn
 */
async function getMonthlyBurnMetrics(months = 6) {
  const sql = `
    SELECT 
      FORMAT_DATE('%Y-%m', transaction_date) AS month,
      ROUND(SUM(ABS(reporting_amount_zar)), 2) AS monthlyBurnZar,
      ROUND(SUM(ABS(reporting_amount_usd)), 2) AS monthlyBurnUsd,
      COUNT(1) AS transactionCount,
      ROUND(AVG(ABS(reporting_amount_zar)), 2) AS avgSpendPerTxZar,
      ROUND(MAX(ABS(reporting_amount_zar)), 2) AS peakSingleSpendZar
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\`
    WHERE reporting_amount_zar < 0
    GROUP BY month
    ORDER BY month DESC
    LIMIT ${parseInt(months, 10) || 6}
  `;

  const rows = await runQuery(sql);

  if (!rows || rows.length === 0) {
    return {
      currentMonth: new Date().toISOString().slice(0, 7),
      currentMonthBurnZar: 0,
      currentMonthBurnUsd: 0,
      averageMonthlyBurnZar: 0,
      averageDailyBurnZar: 0,
      burnGrowthMoMPct: 0,
      burnTrend: 'STABLE',
      historicalMonthlyBurn: [],
    };
  }

  const formattedRows = rows.map((r) => ({
    month: r.month,
    monthlyBurnZar: parseFloat(r.monthlyBurnZar || 0),
    monthlyBurnUsd: parseFloat(r.monthlyBurnUsd || 0),
    transactionCount: parseInt(r.transactionCount || 0, 10),
    avgSpendPerTxZar: parseFloat(r.avgSpendPerTxZar || 0),
    peakSingleSpendZar: parseFloat(r.peakSingleSpendZar || 0),
  }));

  const currentMonth = formattedRows[0];
  const previousMonth = formattedRows[1];

  const totalHistoricalBurnZar = formattedRows.reduce((sum, r) => sum + r.monthlyBurnZar, 0);
  const averageMonthlyBurnZar = Math.round(totalHistoricalBurnZar / formattedRows.length);
  const averageDailyBurnZar = Math.max(100, Math.round(averageMonthlyBurnZar / 30));

  let burnGrowthMoMPct = 0;
  if (previousMonth && previousMonth.monthlyBurnZar > 0) {
    burnGrowthMoMPct = parseFloat(
      (((currentMonth.monthlyBurnZar - previousMonth.monthlyBurnZar) / previousMonth.monthlyBurnZar) * 100).toFixed(1)
    );
  }

  const burnTrend = burnGrowthMoMPct > 5 ? 'ACCELERATING' : burnGrowthMoMPct < -5 ? 'DECELERATING' : 'STABLE';

  return {
    currentMonth: currentMonth.month,
    currentMonthBurnZar: currentMonth.monthlyBurnZar,
    currentMonthBurnUsd: currentMonth.monthlyBurnUsd,
    averageMonthlyBurnZar,
    averageDailyBurnZar,
    burnGrowthMoMPct,
    burnTrend,
    historicalMonthlyBurn: formattedRows,
  };
}

/**
 * 3. Create Cash Runway Projections
 */
async function getRunwayProjection() {
  const accountsSql = `
    SELECT 
      a.account_id AS accountId,
      a.account_name AS accountName,
      a.financial_institution AS financialInstitution,
      a.cash_flow_tier AS cashFlowTier,
      a.primary_currency AS primaryCurrency,
      ROUND(COALESCE(SUM(t.reporting_amount_zar), 0.0), 2) AS txNetZar,
      ROUND(COALESCE(SUM(t.reporting_amount_usd), 0.0), 2) AS txNetUsd
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.dim_accounts\` a
    LEFT JOIN \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` t
      ON a.account_id = t.account_id
    WHERE a.is_active = TRUE
    GROUP BY 1, 2, 3, 4, 5
  `;

  const [accountRows, monthlyMetrics, dailyMetrics] = await Promise.all([
    runQuery(accountsSql),
    getMonthlyBurnMetrics(3),
    getDailyBurnMetrics(14),
  ]);

  let liquidReserveZar = 0;
  let vaultTotalZar = 0;
  let creditObligationsZar = 0;

  accountRows.forEach((acc) => {
    const opening = OPENING_BALANCES[acc.accountId] || 0.0;
    const currentBalanceZar = opening + parseFloat(acc.txNetZar || 0);

    if (acc.cashFlowTier === 'DAILY_SPENDING' || acc.cashFlowTier === 'MONTHLY_ALLOCATION') {
      liquidReserveZar += Math.max(0, currentBalanceZar);
      if (currentBalanceZar < 0) {
        creditObligationsZar += Math.abs(currentBalanceZar);
      }
    } else if (acc.cashFlowTier === 'LONG_TERM_VAULT') {
      vaultTotalZar += Math.max(0, currentBalanceZar);
    }
  });

  let avgDailyBurnZar = monthlyMetrics.averageDailyBurnZar || 650;
  if (dailyMetrics && dailyMetrics.length > 0) {
    const recentAvg = dailyMetrics.reduce((sum, d) => sum + d.dailySpendZar, 0) / dailyMetrics.length;
    if (recentAvg > 0) {
      avgDailyBurnZar = Math.round(recentAvg);
    }
  }

  const avgMonthlyBurnZar = avgDailyBurnZar * 30;

  const baselineRunwayDays = avgDailyBurnZar > 0 ? Math.max(0, Math.floor(liquidReserveZar / avgDailyBurnZar)) : 999;
  const baselineRunwayMonths = avgMonthlyBurnZar > 0 ? parseFloat((liquidReserveZar / avgMonthlyBurnZar).toFixed(1)) : 99;
  const survivalDate = new Date(Date.now() + baselineRunwayDays * 86400000).toISOString().split('T')[0];

  const totalReserveZar = liquidReserveZar + vaultTotalZar;
  const totalRunwayDays = avgDailyBurnZar > 0 ? Math.max(0, Math.floor(totalReserveZar / avgDailyBurnZar)) : 999;
  const totalRunwayMonths = avgMonthlyBurnZar > 0 ? parseFloat((totalReserveZar / avgMonthlyBurnZar).toFixed(1)) : 99;
  const extendedSurvivalDate = new Date(Date.now() + totalRunwayDays * 86400000).toISOString().split('T')[0];

  const stressedDailyBurnZar = Math.round(avgDailyBurnZar * 1.25);
  const stressedRunwayDays = stressedDailyBurnZar > 0 ? Math.max(0, Math.floor(liquidReserveZar / stressedDailyBurnZar)) : 999;

  const runwayStatus = baselineRunwayDays < 60 ? 'CRITICAL' : baselineRunwayDays < 90 ? 'WARNING' : 'HEALTHY';

  return {
    liquidReserveZar: parseFloat(liquidReserveZar.toFixed(2)),
    vaultTotalZar: parseFloat(vaultTotalZar.toFixed(2)),
    totalReserveZar: parseFloat(totalReserveZar.toFixed(2)),
    creditObligationsZar: parseFloat(creditObligationsZar.toFixed(2)),
    averageDailyBurnZar: avgDailyBurnZar,
    averageMonthlyBurnZar: avgMonthlyBurnZar,
    baselineRunwayDays,
    baselineRunwayMonths,
    survivalDate,
    totalRunwayDays,
    totalRunwayMonths,
    extendedSurvivalDate,
    stressedDailyBurnZar,
    stressedRunwayDays,
    runwayStatus,
    generatedAt: new Date().toISOString(),
  };
}

/**
 * 4. Monthly Category Spending Trends
 */
async function getMonthlySpendingTrends(months = 6) {
  const sql = `
    SELECT 
      FORMAT_DATE('%Y-%m', t.transaction_date) AS month,
      COALESCE(c.category_name, t.category_id, 'Uncategorized') AS categoryName,
      ROUND(SUM(ABS(t.reporting_amount_zar)), 2) AS totalSpentZar,
      ROUND(SUM(ABS(t.reporting_amount_usd)), 2) AS totalSpentUsd,
      COUNT(1) AS transactionCount
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` t
    LEFT JOIN \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.dim_categories\` c
      ON t.category_id = c.category_id
    WHERE t.reporting_amount_zar < 0
      AND t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL ${parseInt(months, 10) || 6} MONTH)
    GROUP BY month, categoryName
    ORDER BY month DESC, totalSpentZar DESC
  `;

  const rows = await runQuery(sql);

  const trendsByMonth = {};
  rows.forEach((r) => {
    if (!trendsByMonth[r.month]) {
      trendsByMonth[r.month] = {
        month: r.month,
        totalSpendZar: 0,
        totalSpendUsd: 0,
        categories: [],
      };
    }
    const spentZar = parseFloat(r.totalSpentZar || 0);
    const spentUsd = parseFloat(r.totalSpentUsd || 0);

    trendsByMonth[r.month].totalSpendZar += spentZar;
    trendsByMonth[r.month].totalSpendUsd += spentUsd;
    trendsByMonth[r.month].categories.push({
      categoryName: r.categoryName,
      spentZar,
      spentUsd,
      transactionCount: parseInt(r.transactionCount || 0, 10),
    });
  });

  return Object.values(trendsByMonth).map((m) => ({
    month: m.month,
    totalSpendZar: parseFloat(m.totalSpendZar.toFixed(2)),
    totalSpendUsd: parseFloat(m.totalSpendUsd.toFixed(2)),
    topCategory: m.categories[0]?.categoryName || 'None',
    topCategorySpendZar: m.categories[0]?.spentZar || 0,
    categories: m.categories,
  }));
}

/**
 * 5. Monthly Revenue and Income Inflow Metrics
 */
async function getRevenueMetrics(months = 6) {
  const sql = `
    SELECT 
      FORMAT_DATE('%Y-%m', transaction_date) AS month,
      ROUND(SUM(reporting_amount_zar), 2) AS totalRevenueZar,
      ROUND(SUM(reporting_amount_usd), 2) AS totalRevenueUsd,
      COUNT(1) AS transactionCount,
      ROUND(AVG(reporting_amount_zar), 2) AS avgRevenuePerEventZar
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\`
    WHERE reporting_amount_zar > 0
    GROUP BY month
    ORDER BY month DESC
    LIMIT ${parseInt(months, 10) || 6}
  `;

  const rows = await runQuery(sql);

  const formattedRows = rows.map((r) => ({
    month: r.month,
    totalRevenueZar: parseFloat(r.totalRevenueZar || 0),
    totalRevenueUsd: parseFloat(r.totalRevenueUsd || 0),
    transactionCount: parseInt(r.transactionCount || 0, 10),
    avgRevenuePerEventZar: parseFloat(r.avgRevenuePerEventZar || 0),
  }));

  const currentMonth = formattedRows[0] || { totalRevenueZar: 0, totalRevenueUsd: 0 };
  const totalRevenue = formattedRows.reduce((sum, r) => sum + r.totalRevenueZar, 0);
  const averageMonthlyRevenueZar = formattedRows.length > 0 ? Math.round(totalRevenue / formattedRows.length) : 0;

  return {
    currentMonthRevenueZar: currentMonth.totalRevenueZar,
    currentMonthRevenueUsd: currentMonth.totalRevenueUsd,
    averageMonthlyRevenueZar,
    historicalMonthlyRevenue: formattedRows,
  };
}

/**
 * 6. Quarterly Tax Schedule & Deduction Metrics
 */
async function getTaxSchedule() {
  try {
    const sql = `
      SELECT 
        tax_year AS taxYear,
        tax_quarter AS taxQuarter,
        CAST(gross_taxable_inflow_zar AS FLOAT64) AS grossTaxableInflowZar,
        CAST(gross_taxable_inflow_usd AS FLOAT64) AS grossTaxableInflowUsd,
        CAST(productivity_expenses_offset_zar AS FLOAT64) AS productivityExpensesOffsetZar,
        CAST(total_allowable_deductions_zar AS FLOAT64) AS totalAllowableDeductionsZar,
        CAST(total_allowable_deductions_usd AS FLOAT64) AS totalAllowableDeductionsUsd,
        CAST(net_taxable_income_zar AS FLOAT64) AS netTaxableIncomeZar,
        CAST(net_taxable_income_usd AS FLOAT64) AS netTaxableIncomeUsd,
        CAST(effective_tax_rate AS FLOAT64) AS effectiveTaxRate,
        CAST(estimated_tax_liability_zar AS FLOAT64) AS estimatedTaxLiabilityZar,
        CAST(actual_tax_paid_zar AS FLOAT64) AS actualTaxPaidZar,
        CAST(net_tax_outstanding_zar AS FLOAT64) AS netTaxOutstandingZar,
        tax_settlement_status AS taxSettlementStatus,
        tax_deductible_transaction_count AS taxDeductibleCount
      FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_quarterly_tax_liability_schedule\`
      ORDER BY tax_quarter DESC
      LIMIT 1
    `;
    const rows = await runQuery(sql);

    if (rows && rows.length > 0) {
      const r = rows[0];
      return {
        taxYear: parseInt(r.taxYear || 2026, 10),
        taxQuarter: r.taxQuarter || '2026-Q1',
        grossTaxableInflowZar: parseFloat(r.grossTaxableInflowZar || 0),
        grossTaxableInflowUsd: parseFloat(r.grossTaxableInflowUsd || 0),
        productivityExpensesOffsetZar: parseFloat(r.productivityExpensesOffsetZar || 0),
        totalAllowableDeductionsZar: parseFloat(r.totalAllowableDeductionsZar || 0),
        totalAllowableDeductionsUsd: parseFloat(r.totalAllowableDeductionsUsd || 0),
        netTaxableIncomeZar: parseFloat(r.netTaxableIncomeZar || 0),
        netTaxableIncomeUsd: parseFloat(r.netTaxableIncomeUsd || 0),
        effectiveTaxRate: parseFloat(r.effectiveTaxRate || 0.27),
        estimatedTaxLiabilityZar: parseFloat(r.estimatedTaxLiabilityZar || 0),
        actualTaxPaidZar: parseFloat(r.actualTaxPaidZar || 0),
        netTaxOutstandingZar: parseFloat(r.netTaxOutstandingZar || 0),
        taxSettlementStatus: r.taxSettlementStatus || 'PAYMENT_PENDING',
        taxDeductibleCount: parseInt(r.taxDeductibleCount || 0, 10),
      };
    }
  } catch (err) {
    console.warn('[financeService] v_quarterly_tax_liability_schedule fallback:', err.message);
  }

  // Fallback estimation directly from fct_transactions
  const taxFallbackSql = `
    SELECT 
      ROUND(SUM(CASE WHEN reporting_amount_zar > 0 THEN reporting_amount_zar ELSE 0 END), 2) AS grossInflowZar,
      ROUND(SUM(CASE WHEN is_tax_deductible = TRUE THEN ABS(reporting_amount_zar) ELSE 0 END), 2) AS totalDeductionsZar,
      COUNT(CASE WHEN is_tax_deductible = TRUE THEN 1 END) AS deductibleCount
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\`
  `;
  const [res] = await runQuery(taxFallbackSql);
  const grossInflow = parseFloat(res?.grossInflowZar || 0);
  const deductions = parseFloat(res?.totalDeductionsZar || 0);
  const netTaxable = Math.max(0, grossInflow - deductions);
  const estimatedTax = parseFloat((netTaxable * 0.27).toFixed(2));

  return {
    taxYear: new Date().getFullYear(),
    taxQuarter: `${new Date().getFullYear()}-Q1`,
    grossTaxableInflowZar: grossInflow,
    grossTaxableInflowUsd: parseFloat((grossInflow / 18.5).toFixed(2)),
    productivityExpensesOffsetZar: deductions,
    totalAllowableDeductionsZar: deductions,
    totalAllowableDeductionsUsd: parseFloat((deductions / 18.5).toFixed(2)),
    netTaxableIncomeZar: netTaxable,
    netTaxableIncomeUsd: parseFloat((netTaxable / 18.5).toFixed(2)),
    effectiveTaxRate: 0.27,
    estimatedTaxLiabilityZar: estimatedTax,
    actualTaxPaidZar: 0,
    netTaxOutstandingZar: estimatedTax,
    taxSettlementStatus: 'ESTIMATED',
    taxDeductibleCount: parseInt(res?.deductibleCount || 0, 10),
  };
}

// 7. Harmonized Exports
const financeService = {
  getBigQueryClient,
  runQuery,
  insertRows,
  recordTransaction,
  getDailyBurnMetrics,
  getMonthlyBurnMetrics,
  getRunwayProjection,
  getMonthlySpendingTrends,
  getRevenueMetrics,
  getTaxSchedule,
  BQ_CONFIG,
  OPENING_BALANCES,
};

module.exports = {
  ...financeService,
  financeService,
  default: financeService,
};
