/**
 * bigquery.js - BigQuery Service Layer for Ziva Finance
 * Grounded in Google Cloud Project: budget-tracker-507418, dataset: personal_finance
 * Enforces mandatory resource attribution labels ('datacloud: antigravity')
 * Relies strictly on the official @google-cloud/bigquery Node.js SDK without CLI or shell commands.
 */

import { BigQuery } from '@google-cloud/bigquery';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const BQ_CONFIG = {
  projectId: process.env.GCP_PROJECT_ID || process.env.BIGQUERY_PROJECT_ID || 'budget-tracker-507418',
  datasetId: process.env.BIGQUERY_DATASET || 'personal_finance',
  location: process.env.BIGQUERY_LOCATION || 'africa-south1',
  defaultTimezone: 'Africa/Johannesburg'
};

let activeClientInstance = null;
let activeAuthMode = 'UNKNOWN';
let lastTokenRefresh = 0;
let cachedConnectionState = null;

/**
 * Diagnostic guidance generator based on exact Google Cloud errors
 */
export function getTroubleshootingGuidance(err) {
  const msg = (err?.message || '').toLowerCase();
  const code = err?.code;

  if (msg.includes('could not load the default credentials') || msg.includes('no credentialed accounts') || msg.includes('invalid_grant')) {
    return "Google Cloud Application Default Credentials (ADC) missing or expired. Set the GOOGLE_APPLICATION_CREDENTIALS environment variable to the path of your service account key JSON file, or provide service account credentials via GOOGLE_CREDENTIALS in your environment.";
  }
  if (msg.includes('access denied') || msg.includes('permission') || code === 403) {
    return `Google Cloud IAM permission denied. Ensure the active service account has 'roles/bigquery.dataEditor' and 'roles/bigquery.jobUser' on project '${BQ_CONFIG.projectId}'.`;
  }
  if (msg.includes('not found: dataset') || (msg.includes('dataset') && msg.includes('not found')) || code === 404) {
    return `BigQuery dataset '${BQ_CONFIG.datasetId}' was not found in project '${BQ_CONFIG.projectId}' (location '${BQ_CONFIG.location}'). Verify the dataset exists in that region.`;
  }
  if (msg.includes('econnrefused') || msg.includes('enotfound') || msg.includes('timeout') || msg.includes('fetch failed')) {
    return "Network connectivity failure reaching Google Cloud BigQuery API (bigquery.googleapis.com). Check internet connection and outbound access.";
  }
  return `Review the exact error details in Google Cloud Console / Render logs for project ${BQ_CONFIG.projectId}.`;
}

/**
 * Multi-tier credential resolver (Node.js native, no shell commands)
 */
export function resolveAuthDetails() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
    return { mode: 'GOOGLE_APPLICATION_CREDENTIALS', keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS };
  }

  // Support JSON credentials string passed in environment variables (e.g. on Render)
  const envCredentialsRaw = process.env.GOOGLE_CREDENTIALS || process.env.GCP_CREDENTIALS || process.env.BIGQUERY_CREDENTIALS;
  if (envCredentialsRaw) {
    try {
      const parsed = typeof envCredentialsRaw === 'string' ? JSON.parse(envCredentialsRaw) : envCredentialsRaw;
      if (parsed.client_email && parsed.private_key) {
        return { mode: 'CREDENTIALS_OBJECT', credentials: parsed };
      }
    } catch (_) {}
  }

  const candidateKeyPaths = [
    path.resolve(__dirname, '../service-account.json'),
    path.resolve(__dirname, '../../service-account.json'),
    path.resolve(__dirname, '../../mobile/assets/credentials/mobile-bigquery-client.json'),
    path.resolve(__dirname, '../../mobile/assets/credentials/service-account.json')
  ];

  for (const p of candidateKeyPaths) {
    if (fs.existsSync(p)) {
      try {
        const content = JSON.parse(fs.readFileSync(p, 'utf8'));
        if (content.private_key) {
          return { mode: 'SERVICE_ACCOUNT_KEY_FILE', keyFile: p };
        }
      } catch (_) {}
    }
  }

  return { mode: 'APPLICATION_DEFAULT_CREDENTIALS' };
}

/**
 * Returns or instantiates the authoritative BigQuery client
 */
export function getBigQueryClient(forceRefresh = false) {
  const now = Date.now();
  if (activeClientInstance && !forceRefresh && (now - lastTokenRefresh < 45 * 60 * 1000)) {
    return { client: activeClientInstance, mode: activeAuthMode };
  }

  const authDetails = resolveAuthDetails();
  activeAuthMode = authDetails.mode;

  if (authDetails.mode === 'SERVICE_ACCOUNT_KEY_FILE' || authDetails.mode === 'GOOGLE_APPLICATION_CREDENTIALS') {
    activeClientInstance = new BigQuery({
      projectId: BQ_CONFIG.projectId,
      location: BQ_CONFIG.location,
      keyFilename: authDetails.keyFile
    });
  } else if (authDetails.mode === 'CREDENTIALS_OBJECT') {
    activeClientInstance = new BigQuery({
      projectId: authDetails.credentials.project_id || BQ_CONFIG.projectId,
      location: BQ_CONFIG.location,
      credentials: {
        client_email: authDetails.credentials.client_email,
        private_key: authDetails.credentials.private_key
      }
    });
  } else {
    activeClientInstance = new BigQuery({
      projectId: BQ_CONFIG.projectId,
      location: BQ_CONFIG.location
    });
  }

  lastTokenRefresh = now;
  return { client: activeClientInstance, mode: activeAuthMode };
}

/**
 * Retry helper with exponential backoff for transient BigQuery failures
 */
export async function withRetry(operation, maxRetries = 3, baseDelayMs = 400) {
  let attempt = 0;
  while (true) {
    attempt++;
    try {
      return await operation();
    } catch (err) {
      const isRetryable =
        err.code === 429 ||
        err.code === 500 ||
        err.code === 502 ||
        err.code === 503 ||
        err.code === 504 ||
        err.message?.includes('rateLimitExceeded') ||
        err.message?.includes('backendError') ||
        err.message?.includes('ECONNRESET') ||
        err.message?.includes('ETIMEDOUT') ||
        err.message?.includes('socket hang up');

      if (attempt >= maxRetries || !isRetryable) {
        throw err;
      }

      const delay = baseDelayMs * Math.pow(2, attempt - 1) + Math.floor(Math.random() * 200);
      console.warn(`[BigQuery Retry] Attempt ${attempt} failed: ${err.message}. Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

/**
 * Execute a query with datacloud:antigravity attribution label strictly via SDK.
 */
export async function runQuery(sql, options = {}) {
  return withRetry(async () => {
    try {
      const { client } = getBigQueryClient();
      const queryOptions = {
        query: sql,
        location: BQ_CONFIG.location,
        labels: { datacloud: 'antigravity' },
        ...options
      };
      const [rows] = await client.query(queryOptions);
      return rows;
    } catch (sdkErr) {
      if (sdkErr.message?.includes('invalid_grant') || sdkErr.message?.includes('credentials') || sdkErr.code === 401) {
        try {
          const { client: refreshedClient } = getBigQueryClient(true);
          const [rows] = await refreshedClient.query({
            query: sql,
            location: BQ_CONFIG.location,
            labels: { datacloud: 'antigravity' },
            ...options
          });
          return rows;
        } catch (refreshErr) {
          console.error('[BigQuery] Retry with refreshed client failed:', refreshErr.message);
        }
      }

      console.error('[BigQuery] Query execution failed via Node.js SDK:');
      console.error('SDK Error Code:', sdkErr.code || 'UNKNOWN');
      console.error('SDK Error Message:', sdkErr.message);
      if (sdkErr.errors) {
        console.error('SDK Error Details:', JSON.stringify(sdkErr.errors));
      }

      const enhancedError = new Error(`BigQuery Query Failed: ${sdkErr.message}`);
      enhancedError.code = sdkErr.code || 'QUERY_FAILED';
      enhancedError.errors = sdkErr.errors || [sdkErr.message];
      enhancedError.troubleshooting = getTroubleshootingGuidance(sdkErr);
      throw enhancedError;
    }
  });
}

/**
 * Explicit connection verification probe
 */
export async function verifyBigQueryConnectivity({ forceCheck = false } = {}) {
  const now = Date.now();
  if (!forceCheck && cachedConnectionState && (now - new Date(cachedConnectionState.lastVerifiedAt).getTime() < 30000)) {
    return cachedConnectionState;
  }

  const startTime = Date.now();
  try {
    const { client, mode } = getBigQueryClient(forceCheck);
    
    // Test dataset metadata access
    const dataset = client.dataset(BQ_CONFIG.datasetId);
    const [metadata] = await dataset.getMetadata();

    // Probe basic row count
    const probeSql = `
      SELECT CURRENT_TIMESTAMP() AS server_time, COUNT(1) AS total_records
      FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\`
    `;
    const rows = await runQuery(probeSql);
    const latencyMs = Date.now() - startTime;

    cachedConnectionState = {
      status: 'ONLINE',
      connected: true,
      project: BQ_CONFIG.projectId,
      dataset: BQ_CONFIG.datasetId,
      location: BQ_CONFIG.location,
      authMode: mode,
      latencyMs,
      datasetDetails: {
        id: metadata.id,
        location: metadata.location,
        totalRecords: rows[0]?.total_records || 0,
        serverTime: rows[0]?.server_time?.value || new Date().toISOString()
      },
      lastVerifiedAt: new Date().toISOString()
    };

    console.log('================================================================');
    console.log(' [BigQuery Connection] Verification SUCCESSFUL');
    console.log(` Project:   ${BQ_CONFIG.projectId} (Dataset: ${BQ_CONFIG.datasetId})`);
    console.log(` Location:  ${BQ_CONFIG.location}`);
    console.log(` Auth Mode: ${mode}`);
    console.log(` Latency:   ${latencyMs}ms`);
    console.log('================================================================');

    return cachedConnectionState;
  } catch (err) {
    const latencyMs = Date.now() - startTime;
    const troubleshooting = getTroubleshootingGuidance(err);
    
    cachedConnectionState = {
      status: 'OFFLINE',
      connected: false,
      project: BQ_CONFIG.projectId,
      dataset: BQ_CONFIG.datasetId,
      location: BQ_CONFIG.location,
      latencyMs,
      lastVerifiedAt: new Date().toISOString(),
      error: {
        code: err.code || 'CONNECTION_FAILED',
        message: err.message,
        details: err.errors || err.stack,
        troubleshooting
      }
    };

    console.error('================================================================');
    console.error(' [BigQuery Connection] Verification FAILED!');
    console.error(` Project:         ${BQ_CONFIG.projectId}`);
    console.error(` Error Message:   ${err.message}`);
    console.error(` Error Code:      ${err.code || 'UNKNOWN'}`);
    console.error(` Troubleshooting: ${troubleshooting}`);
    console.error('================================================================');

    return cachedConnectionState;
  }
}

/**
 * Fetch latest effective exchange rates
 */
export async function getExchangeRates() {
  const sql = `
    SELECT base_currency, quote_currency, rate_type, exchange_rate, inverse_rate
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_latest_effective_exchange_rates\`
  `;
  const rows = await runQuery(sql);
  
  const rates = {
    USD_TO_ZAR: 18.25,
    ZAR_TO_USD: 0.054795,
    USD_TO_ZIG_OFFICIAL: 13.85,
    ZIG_TO_USD_OFFICIAL: 0.072202,
    USD_TO_ZIG_PARALLEL: 24.50,
    ZIG_TO_USD_PARALLEL: 0.040816,
    ZAR_TO_ZIG_OFFICIAL: 0.7589,
    ZAR_TO_ZIG_PARALLEL: 1.342466,
    lastUpdated: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) + ' SAST'
  };

  rows.forEach(r => {
    const base = r.base_currency;
    const quote = r.quote_currency;
    const type = r.rate_type;
    const rate = parseFloat(r.exchange_rate);
    const inv = parseFloat(r.inverse_rate);

    if (base === 'USD' && quote === 'ZAR') {
      rates.USD_TO_ZAR = rate;
      rates.ZAR_TO_USD = inv;
    } else if (base === 'USD' && quote === 'ZiG') {
      if (type === 'OFFICIAL_INTERBANK') {
        rates.USD_TO_ZIG_OFFICIAL = rate;
        rates.ZIG_TO_USD_OFFICIAL = inv;
      } else if (type === 'MARKET_PARALLEL') {
        rates.USD_TO_ZIG_PARALLEL = rate;
        rates.ZIG_TO_USD_PARALLEL = inv;
      }
    } else if (base === 'ZAR' && quote === 'ZiG') {
      if (type === 'OFFICIAL_INTERBANK') {
        rates.ZAR_TO_ZIG_OFFICIAL = rate;
      } else if (type === 'MARKET_PARALLEL') {
        rates.ZAR_TO_ZIG_PARALLEL = rate;
      }
    }
  });

  return rates;
}

export const OPENING_BALANCES = {
  ACC_ZA_CAPITEC_DAILY: 18450.00,
  ACC_ZA_FNB_MONTHLY: 32800.00,
  ACC_ZA_DISCOVERY_VAULT: 150000.00,
  ACC_ZA_EE_EQUITIES_VAULT: 680000.00,
  ACC_ZW_ECOCASH_USD: 1250.00,
  ACC_ZW_ECOCASH_ZIG: 4500.00,
  ACC_ZW_INNBUCKS_USD: 200.00,
  ACC_ZW_OM_BALANCED_VAULT: 15000.00,
  ACC_ZW_STANBIC_NOSTRO_MONTHLY: 2400.00
};

/**
 * Fetch accounts with calculated balances
 */
export async function getAccounts() {
  const sql = `
    SELECT 
      a.account_id AS accountId,
      a.account_name AS accountName,
      a.financial_institution AS financialInstitution,
      a.country_code AS countryCode,
      a.primary_currency AS primaryCurrency,
      a.cash_flow_tier AS cashFlowTier,
      a.account_type AS accountType,
      a.is_vault_locked AS isVaultLocked,
      a.withdrawal_notice_days AS withdrawalNoticeDays,
      a.account_number_masked AS accountNumberMasked,
      ROUND(COALESCE(SUM(t.original_amount), 0.0), 2) AS nativeBalance,
      a.is_active AS isActive
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.dim_accounts\` a
    LEFT JOIN \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` t
      ON a.account_id = t.account_id
    WHERE a.is_active = TRUE
    GROUP BY 1,2,3,4,5,6,7,8,9,10,12
    ORDER BY a.cash_flow_tier, a.account_name
  `;
  const rows = await runQuery(sql);
  return rows.map(r => {
    const txNet = parseFloat(r.nativeBalance || 0);
    const opening = OPENING_BALANCES[r.accountId] || 0.0;
    return {
      ...r,
      nativeBalance: parseFloat((opening + txNet).toFixed(2)),
      withdrawalNoticeDays: parseInt(r.withdrawalNoticeDays || 0, 10),
      isVaultLocked: Boolean(r.isVaultLocked),
      isActive: Boolean(r.isActive)
    };
  });
}

/**
 * Fetch transactions with category details
 */
export async function getTransactions(limit = 100) {
  const sql = `
    SELECT 
      t.transaction_id AS transactionId,
      CAST(t.transaction_timestamp AS STRING) AS transactionTimestamp,
      CAST(t.transaction_date AS STRING) AS transactionDate,
      t.local_timezone AS localTimezone,
      t.account_id AS accountId,
      t.cash_flow_tier AS cashFlowTier,
      t.category_id AS categoryId,
      COALESCE(c.category_name, t.category_id) AS categoryName,
      t.transaction_type AS transactionType,
      CAST(t.original_amount AS FLOAT64) AS originalAmount,
      t.original_currency AS originalCurrency,
      t.original_currency AS currencyCode,
      CAST(t.reporting_amount_usd AS FLOAT64) AS reportingAmountUsd,
      CAST(t.reporting_amount_zar AS FLOAT64) AS reportingAmountZar,
      CAST(t.applied_exchange_rate_usd AS FLOAT64) AS appliedExchangeRateUsd,
      CAST(t.applied_exchange_rate_zar AS FLOAT64) AS appliedExchangeRateZar,
      t.rate_type_applied AS rateTypeApplied,
      t.merchant_or_payee AS merchantOrPayee,
      t.payment_method AS paymentMethod,
      t.is_tax_deductible AS isTaxDeductible,
      CAST(t.tax_deductible_amount_zar AS FLOAT64) AS taxDeductibleAmountZar,
      CAST(t.tax_deductible_amount_usd AS FLOAT64) AS taxDeductibleAmountUsd,
      t.tax_invoice_number AS taxInvoiceNumber,
      t.notes,
      t.tags,
      JSON_VALUE(t.metadata, '$.receipt_storage_url') AS receiptStorageUrl,
      JSON_VALUE(t.metadata, '$.receipt_file_type') AS receiptFileType,
      TRUE AS isSynced
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` t
    LEFT JOIN \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.dim_categories\` c
      ON t.category_id = c.category_id
    ORDER BY t.transaction_date DESC, t.transaction_timestamp DESC
    LIMIT ${limit}
  `;
  const rows = await runQuery(sql);
  return rows.map(r => ({
    ...r,
    originalAmount: parseFloat(r.originalAmount || 0),
    originalCurrency: r.originalCurrency || 'ZAR',
    currencyCode: r.currencyCode || r.originalCurrency || 'ZAR',
    reportingAmountUsd: parseFloat(r.reportingAmountUsd || 0),
    reportingAmountZar: parseFloat(r.reportingAmountZar || 0),
    appliedExchangeRateUsd: parseFloat(r.appliedExchangeRateUsd || 1),
    appliedExchangeRateZar: parseFloat(r.appliedExchangeRateZar || 1),
    taxDeductibleAmountZar: parseFloat(r.taxDeductibleAmountZar || 0),
    taxDeductibleAmountUsd: parseFloat(r.taxDeductibleAmountUsd || 0),
    isTaxDeductible: Boolean(r.isTaxDeductible),
    receiptStorageUrl: r.receiptStorageUrl || null,
    receiptFileType: r.receiptFileType || null,
    tags: Array.isArray(r.tags) ? r.tags : []
  }));
}

/**
 * Fetch budget envelopes vs actuals
 */
export async function getBudgetEnvelopes() {
  const sql = `
    SELECT 
      CAST(allocation_month AS STRING) AS allocationMonth,
      category_id AS categoryId,
      category_name AS categoryName,
      category_group AS categoryGroup,
      cash_flow_tier AS cashFlowTier,
      target_currency AS targetCurrency,
      CAST(planned_amount AS FLOAT64) AS plannedAmount,
      CAST(planned_amount_zar AS FLOAT64) AS plannedAmountZar,
      CAST(planned_amount_usd AS FLOAT64) AS plannedAmountUsd,
      CAST(actual_spent_zar AS FLOAT64) AS actualSpentZar,
      CAST(actual_spent_usd AS FLOAT64) AS actualSpentUsd,
      CAST(variance_zar AS FLOAT64) AS varianceZar,
      CAST(variance_usd AS FLOAT64) AS varianceUsd,
      CAST(pct_budget_consumed AS FLOAT64) AS pctConsumed,
      budget_status AS budgetStatus,
      is_fixed_obligation AS isFixedObligation
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_monthly_budget_vs_actual\`
    ORDER BY pct_budget_consumed DESC
  `;
  const rows = await runQuery(sql);
  return rows.map(r => ({
    ...r,
    plannedAmount: parseFloat(r.plannedAmount || 0),
    plannedAmountZar: parseFloat(r.plannedAmountZar || 0),
    plannedAmountUsd: parseFloat(r.plannedAmountUsd || 0),
    actualSpentZar: parseFloat(r.actualSpentZar || 0),
    actualSpentUsd: parseFloat(r.actualSpentUsd || 0),
    varianceZar: parseFloat(r.varianceZar || 0),
    varianceUsd: parseFloat(r.varianceUsd || 0),
    pctConsumed: parseFloat(r.pctConsumed || 0),
    isFixedObligation: Boolean(r.isFixedObligation)
  }));
}

/**
 * Fetch quarterly tax liability schedule
 */
export async function getTaxSchedule() {
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
    WHERE tax_year = 2026
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
      taxDeductibleCount: parseInt(r.taxDeductibleCount || 0, 10)
    };
  }
  return null;
}

/**
 * Fetch daily burn rate metrics
 */
export async function getDailyBurnMetrics() {
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
    LIMIT 14
  `;
  const rows = await runQuery(sql);
  return rows.map(r => ({
    transactionDate: r.transactionDate,
    dailySpendZar: parseFloat(r.dailySpendZar || 0),
    rolling7dAvgSpendZar: parseFloat(r.rolling7dAvgSpendZar || 0),
    dailySpendUsd: parseFloat(r.dailySpendUsd || 0),
    rolling7dAvgSpendUsd: parseFloat(r.rolling7dAvgSpendUsd || 0),
    burnVelocityRatio: r.rolling7dAvgSpendZar > 0 ? parseFloat((r.dailySpendZar / r.rolling7dAvgSpendZar).toFixed(2)) : 1.0,
    burnAlertStatus: (r.rolling7dAvgSpendZar > 0 && (r.dailySpendZar / r.rolling7dAvgSpendZar) > 1.3) ? 'ELEVATED' : 'NORMAL'
  }));
}

/**
 * Fetch vault net worth and asset breakdown
 */
export async function getVaultHoldings() {
  const sql = `
    SELECT 
      account_id AS accountId,
      account_name AS accountName,
      financial_institution AS financialInstitution,
      country_code AS countryCode,
      primary_currency AS primaryCurrency,
      account_type AS accountType,
      is_vault_locked AS isVaultLocked,
      withdrawal_notice_days AS withdrawalNoticeDays,
      CAST(current_balance_original AS FLOAT64) AS nativeBalance,
      CAST(current_balance_zar AS FLOAT64) AS valuationZar,
      CAST(current_balance_usd AS FLOAT64) AS valuationUsd,
      first_deposit_date AS firstDepositDate,
      last_movement_date AS lastMovementDate,
      total_vault_movements AS totalVaultMovements
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_vault_holdings_and_net_worth\`
    ORDER BY current_balance_zar DESC
  `;
  const rows = await runQuery(sql);
  return rows.map(r => ({
    ...r,
    nativeBalance: parseFloat(r.nativeBalance || 0),
    valuationZar: parseFloat(r.valuationZar || 0),
    valuationUsd: parseFloat(r.valuationUsd || 0),
    withdrawalNoticeDays: parseInt(r.withdrawalNoticeDays || 0, 10),
    isVaultLocked: Boolean(r.isVaultLocked)
  }));
}

/**
 * Insert a transaction record into BigQuery fct_transactions via Node.js SDK
 */
export async function insertTransaction(txData) {
  const now = new Date();
  const isoString = now.toISOString();
  const dateStr = txData.transactionDate || isoString.split('T')[0];
  const timestampStr = isoString.replace('T', ' ').replace('Z', ' UTC');
  const localTimeStr = isoString.replace('Z', '').split('.')[0];
  const randomSuffix = Math.floor(1000 + Math.random() * 9000);
  const txId = txData.transactionId || `TX_WEB_${dateStr.replace(/-/g, '')}_${randomSuffix}`;

  const rates = await getExchangeRates();
  
  // Calculate conversions
  let reportingUsd = 0;
  let reportingZar = 0;
  let rateUsd = 1.0;
  let rateZar = 1.0;
  let rateType = 'OFFICIAL_INTERBANK';

  const rawAmount = parseFloat(txData.originalAmount ?? txData.amount ?? 0);
  const rawCurrency = (txData.currencyCode || txData.currency_code || txData.originalCurrency || txData.original_currency || 'ZAR').toString().trim().toUpperCase();
  const currency = rawCurrency === 'ZIG' ? 'ZWG' : rawCurrency;

  if (currency === 'ZAR') {
    reportingZar = rawAmount;
    rateZar = 1.0;
    rateUsd = rates.ZAR_TO_USD || (1 / (rates.USD_TO_ZAR || 18.25));
    reportingUsd = rawAmount * rateUsd;
    rateType = 'FIXED_BASE';
  } else if (currency === 'USD') {
    reportingUsd = rawAmount;
    rateUsd = 1.0;
    rateZar = rates.USD_TO_ZAR || 18.25;
    reportingZar = rawAmount * rateZar;
    rateType = 'OFFICIAL_INTERBANK';
  } else if (currency === 'ZWG' || currency === 'ZIG') {
    rateType = 'OFFICIAL_INTERBANK';
    rateUsd = 1 / 26.50;
    rateZar = (rates.USD_TO_ZAR || 18.25) / 26.50;
    reportingUsd = rawAmount * rateUsd;
    reportingZar = rawAmount * rateZar;
  } else {
    reportingZar = rawAmount;
    rateZar = 1.0;
    rateUsd = 1 / 18.25;
    reportingUsd = rawAmount * rateUsd;
  }

  const record = {
    transaction_id: txId,
    transaction_timestamp: timestampStr,
    transaction_date: dateStr,
    local_timezone: BQ_CONFIG.defaultTimezone,
    local_timestamp: localTimeStr,
    settlement_timestamp: timestampStr,
    account_id: txData.accountId || 'ACC_CHECKING',
    cash_flow_tier: txData.cashFlowTier || 'DAILY_SPENDING',
    category_id: txData.categoryId || 'CAT_GENERAL',
    transaction_type: txData.transactionType || (rawAmount < 0 ? 'EXPENSE' : 'INCOME'),
    original_amount: rawAmount,
    original_currency: currency,
    reporting_amount_usd: parseFloat(reportingUsd.toFixed(4)),
    reporting_amount_zar: parseFloat(reportingZar.toFixed(4)),
    applied_exchange_rate_usd: parseFloat(rateUsd.toFixed(6)),
    applied_exchange_rate_zar: parseFloat(rateZar.toFixed(6)),
    rate_type_applied: rateType,
    transfer_counterpart_id: null,
    merchant_or_payee: txData.merchantOrPayee || 'Direct Entry',
    payment_method: txData.paymentMethod || 'EFT/Card',
    statutory_levy_or_fee: null,
    is_tax_deductible: Boolean(txData.isTaxDeductible),
    tax_deductible_amount_zar: txData.isTaxDeductible ? Math.abs(parseFloat(reportingZar.toFixed(4))) : 0.0,
    tax_deductible_amount_usd: txData.isTaxDeductible ? Math.abs(parseFloat(reportingUsd.toFixed(4))) : 0.0,
    tax_invoice_number: txData.taxInvoiceNumber || null,
    notes: txData.notes || '',
    tags: Array.isArray(txData.tags) ? txData.tags : ['web_dashboard'],
    metadata: {
      source: 'web_command_center',
      currency_code: currency,
      receipt_storage_url: txData.receiptStorageUrl || txData.receipt_storage_url || txData.receiptUrl || null,
      receipt_file_type: txData.receiptFileType || txData.receipt_file_type || null,
      ingested_at: isoString
    }
  };

  const { client } = getBigQueryClient();

  // Try SQL DML INSERT first via BigQuery query engine (avoids streaming buffer mutation lock)
  const dmlSql = `
    INSERT INTO \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` (
      transaction_id, transaction_timestamp, transaction_date, local_timezone, local_timestamp,
      settlement_timestamp, account_id, cash_flow_tier, category_id, transaction_type,
      original_amount, original_currency, reporting_amount_usd, reporting_amount_zar,
      applied_exchange_rate_usd, applied_exchange_rate_zar, rate_type_applied,
      transfer_counterpart_id, merchant_or_payee, payment_method, statutory_levy_or_fee,
      is_tax_deductible, tax_deductible_amount_zar, tax_deductible_amount_usd,
      tax_invoice_number, notes, tags, metadata
    ) VALUES (
      @transaction_id,
      TIMESTAMP(@transaction_timestamp),
      DATE(@transaction_date),
      @local_timezone,
      DATETIME(@local_timestamp),
      TIMESTAMP(@settlement_timestamp),
      @account_id,
      @cash_flow_tier,
      @category_id,
      @transaction_type,
      @original_amount,
      @original_currency,
      @reporting_amount_usd,
      @reporting_amount_zar,
      @applied_exchange_rate_usd,
      @applied_exchange_rate_zar,
      @rate_type_applied,
      @transfer_counterpart_id,
      @merchant_or_payee,
      @payment_method,
      @statutory_levy_or_fee,
      @is_tax_deductible,
      @tax_deductible_amount_zar,
      @tax_deductible_amount_usd,
      @tax_invoice_number,
      @notes,
      @tags,
      PARSE_JSON(@metadata_json)
    )
  `;

  const queryParams = {
    transaction_id: record.transaction_id,
    transaction_timestamp: timestampStr,
    transaction_date: dateStr,
    local_timezone: record.local_timezone,
    local_timestamp: localTimeStr,
    settlement_timestamp: timestampStr,
    account_id: record.account_id,
    cash_flow_tier: record.cash_flow_tier,
    category_id: record.category_id,
    transaction_type: record.transaction_type,
    original_amount: record.original_amount,
    original_currency: record.original_currency,
    reporting_amount_usd: record.reporting_amount_usd,
    reporting_amount_zar: record.reporting_amount_zar,
    applied_exchange_rate_usd: record.applied_exchange_rate_usd,
    applied_exchange_rate_zar: record.applied_exchange_rate_zar,
    rate_type_applied: record.rate_type_applied,
    transfer_counterpart_id: record.transfer_counterpart_id,
    merchant_or_payee: record.merchant_or_payee,
    payment_method: record.payment_method,
    statutory_levy_or_fee: record.statutory_levy_or_fee,
    is_tax_deductible: record.is_tax_deductible,
    tax_deductible_amount_zar: record.tax_deductible_amount_zar,
    tax_deductible_amount_usd: record.tax_deductible_amount_usd,
    tax_invoice_number: record.tax_invoice_number,
    notes: record.notes,
    tags: record.tags,
    metadata_json: JSON.stringify(record.metadata)
  };

  try {
    await runQuery(dmlSql, { params: queryParams });
    return {
      success: true,
      transactionId: txId,
      record: record
    };
  } catch (dmlErr) {
    // If DML fails (e.g. streaming buffer conflict or billing sandbox limitation), attempt SDK streaming insert
    console.warn('[BigQuery] DML INSERT failed, attempting SDK table.insert fallback:', dmlErr.message);
    try {
      const table = client.dataset(BQ_CONFIG.datasetId).table('fct_transactions');
      await table.insert([record]);
      return {
        success: true,
        transactionId: txId,
        record: record
      };
    } catch (insertErr) {
      console.error('[BigQuery] Transaction insertion failed on both DML and table.insert via SDK:');
      console.error('DML Error:', dmlErr.message);
      console.error('Insert Error:', insertErr.message);
      if (insertErr.errors) {
        console.error('Insert Error Details:', JSON.stringify(insertErr.errors));
      }
      const enhancedError = new Error(`BigQuery Ingest Failed: ${dmlErr.message || insertErr.message}`);
      enhancedError.code = dmlErr.code || insertErr.code || 'INGEST_FAILED';
      enhancedError.troubleshooting = getTroubleshootingGuidance(dmlErr || insertErr);
      throw enhancedError;
    }
  }
}

/**
 * Delete a transaction record from BigQuery fct_transactions
 * @param {string} transactionId
 * @returns {Promise<{success: boolean, transactionId: string, timestamp: string}>}
 */
export async function deleteTransaction(transactionId) {
  if (!transactionId || typeof transactionId !== 'string') {
    throw new Error('Invalid or missing transaction ID');
  }
  const cleanId = transactionId.replace(/[^a-zA-Z0-9_-]/g, '');
  const sql = `DELETE FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` WHERE transaction_id = @transactionId`;
  
  try {
    await runQuery(sql, { params: { transactionId: cleanId } });
  } catch (err) {
    console.error(`[BigQuery] Failed to delete transaction ${cleanId}:`, err.message);
    throw err;
  }

  return {
    success: true,
    transactionId: cleanId,
    timestamp: new Date().toISOString()
  };
}

/**
 * Fetch structured Income Statements (monthly or quarterly)
 */
export async function getIncomeStatements(periodType = null) {
  const whereClause = periodType ? `WHERE period_type = @periodType` : '';
  const sql = `
    SELECT
      period_type,
      statement_period,
      CAST(period_start_date AS STRING) AS period_start_date,
      CAST(period_end_date AS STRING) AS period_end_date,
      gross_operating_revenue_zar,
      operating_expenses_zar,
      net_operating_income_zar,
      operating_margin_pct,
      living_essentials_zar,
      discretionary_expenses_zar,
      statutory_and_debt_zar,
      total_comprehensive_outflows_zar,
      net_cash_surplus_zar,
      savings_rate_pct,
      vault_contributions_zar,
      gross_operating_revenue_usd,
      operating_expenses_usd,
      net_operating_income_usd,
      living_essentials_usd,
      discretionary_expenses_usd,
      statutory_and_debt_usd,
      net_cash_surplus_usd,
      vault_contributions_usd
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_income_statement_monthly_quarterly\`
    ${whereClause}
    ORDER BY period_start_date DESC
  `;
  const options = periodType ? { params: { periodType: periodType.toUpperCase() } } : {};
  const rows = await runQuery(sql, options);
  return rows.map(r => ({
    periodType: r.period_type,
    statementPeriod: r.statement_period,
    periodStartDate: r.period_start_date,
    periodEndDate: r.period_end_date,
    grossOperatingRevenueZar: parseFloat(r.gross_operating_revenue_zar || 0),
    operatingExpensesZar: parseFloat(r.operating_expenses_zar || 0),
    netOperatingIncomeZar: parseFloat(r.net_operating_income_zar || 0),
    operatingMarginPct: parseFloat(r.operating_margin_pct || 0),
    livingEssentialsZar: parseFloat(r.living_essentials_zar || 0),
    discretionaryExpensesZar: parseFloat(r.discretionary_expenses_zar || 0),
    statutoryAndDebtZar: parseFloat(r.statutory_and_debt_zar || 0),
    totalComprehensiveOutflowsZar: parseFloat(r.total_comprehensive_outflows_zar || 0),
    netCashSurplusZar: parseFloat(r.net_cash_surplus_zar || 0),
    savingsRatePct: parseFloat(r.savings_rate_pct || 0),
    vaultContributionsZar: parseFloat(r.vault_contributions_zar || 0),
    grossOperatingRevenueUsd: parseFloat(r.gross_operating_revenue_usd || 0),
    operatingExpensesUsd: parseFloat(r.operating_expenses_usd || 0),
    netOperatingIncomeUsd: parseFloat(r.net_operating_income_usd || 0),
    livingEssentialsUsd: parseFloat(r.living_essentials_usd || 0),
    discretionaryExpensesUsd: parseFloat(r.discretionary_expenses_usd || 0),
    statutoryAndDebtUsd: parseFloat(r.statutory_and_debt_usd || 0),
    netCashSurplusUsd: parseFloat(r.net_cash_surplus_usd || 0),
    vaultContributionsUsd: parseFloat(r.vault_contributions_usd || 0)
  }));
}

/**
 * Fetch non-operating gains and asset yields
 */
export async function getNonOperatingGains() {
  const sql = `
    SELECT
      account_id,
      account_name,
      financial_institution,
      country_code,
      primary_currency,
      account_type,
      withdrawal_notice_days,
      current_vault_balance_native,
      current_vault_balance_zar,
      current_vault_balance_usd,
      gain_classification,
      annualized_yield_pct,
      monthly_projected_gain_zar,
      monthly_projected_gain_usd
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_non_operating_gains_and_yields\`
    ORDER BY current_vault_balance_zar DESC
  `;
  const rows = await runQuery(sql);
  return rows.map(r => ({
    accountId: r.account_id,
    accountName: r.account_name,
    financialInstitution: r.financial_institution,
    countryCode: r.country_code,
    primaryCurrency: r.primary_currency,
    accountType: r.account_type,
    withdrawalNoticeDays: parseInt(r.withdrawal_notice_days || 0, 10),
    currentVaultBalanceNative: parseFloat(r.current_vault_balance_native || 0),
    currentVaultBalanceZar: parseFloat(r.current_vault_balance_zar || 0),
    currentVaultBalanceUsd: parseFloat(r.current_vault_balance_usd || 0),
    gainClassification: r.gain_classification,
    annualizedYieldPct: parseFloat(r.annualized_yield_pct || 0),
    monthlyProjectedGainZar: parseFloat(r.monthly_projected_gain_zar || 0),
    monthlyProjectedGainUsd: parseFloat(r.monthly_projected_gain_usd || 0)
  }));
}

/**
 * Fetch consolidated analytics summary including KPIs, spend habit distributions, and trends
 */
export async function getPerformanceSummary() {
  const [statements, burnMetrics, nonOpGains, spendHabits] = await Promise.all([
    getIncomeStatements('MONTH'),
    getDailyBurnMetrics(),
    getNonOperatingGains(),
    runQuery(`
      SELECT
        c.category_group AS categoryGroup,
        c.category_name AS categoryName,
        COUNT(1) AS transactionCount,
        ROUND(SUM(ABS(t.reporting_amount_zar)), 2) AS totalSpentZar,
        ROUND(SUM(ABS(t.reporting_amount_usd)), 2) AS totalSpentUsd
      FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.fct_transactions\` t
      JOIN \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.dim_categories\` c
        ON t.category_id = c.category_id
      WHERE t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      GROUP BY 1, 2
      ORDER BY totalSpentZar DESC
    `)
  ]);

  const latestStatement = statements[0] || {
    grossOperatingRevenueZar: 0,
    grossOperatingRevenueUsd: 0,
    netOperatingIncomeZar: 0,
    operatingMarginPct: 0,
    savingsRatePct: 0,
    netCashSurplusZar: 0,
    netCashSurplusUsd: 0,
    totalComprehensiveOutflowsZar: 0
  };

  const latestBurn = burnMetrics[0] || {
    dailySpendZar: 0,
    rolling7dAvgSpendZar: 0,
    dailySpendUsd: 0,
    rolling7dAvgSpendUsd: 0,
    burnVelocityRatio: 1.0,
    burnAlertStatus: 'NORMAL'
  };

  const totalMonthlyGainZar = nonOpGains.reduce((sum, g) => sum + g.monthlyProjectedGainZar, 0);
  const totalMonthlyGainUsd = nonOpGains.reduce((sum, g) => sum + g.monthlyProjectedGainUsd, 0);

  const totalSpentAllZar = spendHabits.reduce((acc, c) => acc + parseFloat(c.totalSpentZar || 0), 0);
  const formattedHabits = spendHabits.map(h => ({
    categoryGroup: h.categoryGroup,
    categoryName: h.categoryName,
    iconName: h.iconName || 'tag',
    transactionCount: parseInt(h.transactionCount || 0, 10),
    totalSpentZar: parseFloat(h.totalSpentZar || 0),
    totalSpentUsd: parseFloat(h.totalSpentUsd || 0),
    pctOfTotalSpend: totalSpentAllZar > 0 ? parseFloat(((parseFloat(h.totalSpentZar || 0) / totalSpentAllZar) * 100).toFixed(1)) : 0
  }));

  const monthlyTrends = [...statements].reverse().map(s => ({
    statementPeriod: s.statementPeriod,
    periodStartDate: s.periodStartDate,
    operatingRevenueZar: s.grossOperatingRevenueZar,
    operatingRevenueUsd: s.grossOperatingRevenueUsd,
    totalOutflowsZar: s.totalComprehensiveOutflowsZar,
    netSurplusZar: s.netCashSurplusZar,
    netSurplusUsd: s.netCashSurplusUsd,
    savingsRatePct: s.savingsRatePct,
    operatingMarginPct: s.operatingMarginPct
  }));

  return {
    kpis: {
      savingsRatePct: latestStatement.savingsRatePct,
      operatingMarginPct: latestStatement.operatingMarginPct,
      rolling7dAvgSpendZar: latestBurn.rolling7dAvgSpendZar,
      rolling7dAvgSpendUsd: latestBurn.rolling7dAvgSpendUsd,
      latestDailySpendZar: latestBurn.dailySpendZar,
      burnAlertStatus: latestBurn.burnAlertStatus,
      burnVelocityRatio: latestBurn.burnVelocityRatio,
      netCashSurplusZar: latestStatement.netCashSurplusZar,
      netCashSurplusUsd: latestStatement.netCashSurplusUsd,
      grossOperatingRevenueZar: latestStatement.grossOperatingRevenueZar,
      grossOperatingRevenueUsd: latestStatement.grossOperatingRevenueUsd,
      monthlyProjectedGainZar: parseFloat(totalMonthlyGainZar.toFixed(2)),
      monthlyProjectedGainUsd: parseFloat(totalMonthlyGainUsd.toFixed(2))
    },
    spendHabits: formattedHabits,
    monthlyTrends,
    statements,
    nonOperatingGains: nonOpGains
  };
}

/**
 * Get all debts from debt_credit_ledger
 */
export async function getDebts(statusFilter = null) {
  let sql = `
    SELECT 
      id,
      person_name,
      direction,
      amount,
      currency,
      CAST(date AS STRING) as date,
      status,
      notes,
      created_at,
      updated_at
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_ledger\`
  `;
  const options = {};
  if (statusFilter) {
    sql += ` WHERE status = @statusFilter`;
    options.params = { statusFilter };
  }
  sql += ` ORDER BY date DESC, created_at DESC`;
  
  const rows = await runQuery(sql, options);
  return rows.map(r => ({
    id: r.id,
    personName: r.person_name,
    direction: r.direction,
    amount: parseFloat(r.amount || 0),
    currency: r.currency || 'USD',
    date: r.date,
    status: r.status,
    notes: r.notes || '',
    createdAt: r.created_at,
    updatedAt: r.updated_at
  }));
}

/**
 * Get aggregated balances per person from debt_credit_balances view
 */
export async function getDebtBalances(personName = null) {
  let sql = `
    SELECT 
      person_name,
      total_owed_to_me,
      total_owed_by_me,
      net_balance,
      balance_direction
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_balances\`
  `;
  const options = {};
  if (personName) {
    sql += ` WHERE person_name = @personName`;
    options.params = { personName };
  }
  sql += ` ORDER BY ABS(net_balance) DESC`;

  const rows = await runQuery(sql, options);
  return rows.map(r => ({
    personName: r.person_name,
    totalOwedToMe: parseFloat(r.total_owed_to_me || 0),
    totalOwedByMe: parseFloat(r.total_owed_by_me || 0),
    netBalance: parseFloat(r.net_balance || 0),
    balanceDirection: r.balance_direction
  }));
}

/**
 * Insert a new debt or credit entry into debt_credit_ledger via SDK
 */
export async function insertDebt(debtData) {
  const debtId = debtData.id || `debt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const now = new Date().toISOString();
  const dateStr = debtData.date || now.split('T')[0];

  const rawCurrency = (debtData.currency || debtData.currencyCode || debtData.currency_code || 'USD').toString().trim().toUpperCase();
  const currency = rawCurrency === 'ZIG' ? 'ZWG' : rawCurrency;

  const record = {
    id: debtId,
    person_name: debtData.personName || debtData.person_name || 'Counterparty',
    direction: (debtData.direction === 'owed_by_me' || debtData.direction === 'owedByMe') ? 'owed_by_me' : 'owed_to_me',
    amount: parseFloat(Number(debtData.amount ?? debtData.originalPrincipalZar ?? 0).toFixed(4)),
    currency: currency,
    date: dateStr,
    status: debtData.status || 'Pending',
    notes: debtData.notes || '',
    created_at: now,
    updated_at: now
  };

  const { client } = getBigQueryClient();

  // Try SQL DML INSERT first via BigQuery SDK
  const dmlSql = `
    INSERT INTO \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_ledger\` (
      id, person_name, direction, amount, currency, date, status, notes, created_at, updated_at
    ) VALUES (
      @id, @person_name, @direction, @amount, @currency, DATE(@date), @status, @notes,
      TIMESTAMP(@created_at), TIMESTAMP(@updated_at)
    )
  `;

  const queryParams = {
    id: record.id,
    person_name: record.person_name,
    direction: record.direction,
    amount: record.amount,
    currency: record.currency,
    date: record.date,
    status: record.status,
    notes: record.notes,
    created_at: record.created_at,
    updated_at: record.updated_at
  };

  try {
    await runQuery(dmlSql, { params: queryParams });
    return {
      success: true,
      debtId: debtId,
      record: record
    };
  } catch (dmlErr) {
    console.warn('[BigQuery] DML INSERT for debt failed, attempting SDK table.insert fallback:', dmlErr.message);
    try {
      const table = client.dataset(BQ_CONFIG.datasetId).table('debt_credit_ledger');
      await table.insert([record]);
      return {
        success: true,
        debtId: debtId,
        record: record
      };
    } catch (insertErr) {
      console.error('[BigQuery] Debt insertion failed on both DML and table.insert via SDK:');
      console.error('DML Error:', dmlErr.message);
      console.error('Insert Error:', insertErr.message);
      if (insertErr.errors) {
        console.error('Insert Error Details:', JSON.stringify(insertErr.errors));
      }
      const enhancedError = new Error(`BigQuery Insert Debt Failed: ${dmlErr.message || insertErr.message}`);
      enhancedError.code = dmlErr.code || insertErr.code || 'INSERT_DEBT_FAILED';
      enhancedError.troubleshooting = getTroubleshootingGuidance(dmlErr || insertErr);
      throw enhancedError;
    }
  }
}

/**
 * Mark a debt entry as 'Settled' via SDK DML UPDATE
 */
export async function settleDebt(debtId) {
  if (!debtId || typeof debtId !== 'string') {
    throw new Error('Invalid or missing debt ID');
  }
  const cleanId = debtId.replace(/[^a-zA-Z0-9_-]/g, '');
  
  const updateSql = `
    UPDATE \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_ledger\`
    SET status = 'Settled', updated_at = CURRENT_TIMESTAMP()
    WHERE id = @debtId
  `;
  try {
    await runQuery(updateSql, { params: { debtId: cleanId } });
  } catch (err) {
    console.error(`[BigQuery] Failed to settle debt ${cleanId}:`, err.message);
    throw err;
  }

  return {
    success: true,
    debtId: cleanId,
    status: 'Settled',
    updatedAt: new Date().toISOString()
  };
}

/**
 * Delete a debt entry from debt_credit_ledger via SDK DML DELETE
 */
export async function deleteDebt(debtId) {
  if (!debtId || typeof debtId !== 'string') {
    throw new Error('Invalid or missing debt ID');
  }
  const cleanId = debtId.replace(/[^a-zA-Z0-9_-]/g, '');

  const deleteSql = `
    DELETE FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_ledger\`
    WHERE id = @debtId
  `;
  try {
    await runQuery(deleteSql, { params: { debtId: cleanId } });
  } catch (err) {
    console.error(`[BigQuery] Failed to delete debt ${cleanId}:`, err.message);
    throw err;
  }

  return {
    success: true,
    debtId: cleanId
  };
}
