/**
 * BigQueryClient.js - Google BigQuery Integration Client for Google Apps Script
 * Communicates with BigQuery via the Apps Script Advanced BigQuery Service.
 */

const BQ_CONFIG = {
  projectId: 'budget-tracker-507418',
  datasetId: 'personal_finance',
  location: 'africa-south1',
  defaultTimezone: 'Africa/Johannesburg',
  fallbackRates: {
    USD_TO_ZAR: 18.25,
    ZAR_TO_USD: 0.054795,
    USD_TO_ZIG: 13.85,
    ZIG_TO_USD: 0.072202,
    USD_TO_ZIG_PARALLEL: 24.50,
    ZIG_TO_USD_PARALLEL: 0.040816,
    ZAR_TO_ZIG: 0.7589,
    ZIG_TO_ZAR: 1.317697,
    ZAR_TO_ZIG_PARALLEL: 1.342466,
    ZIG_TO_ZAR_PARALLEL: 0.744900
  }
};

const SHEETS_CONFIG = {
  spreadsheetId: (typeof PropertiesService !== 'undefined' && PropertiesService.getScriptProperties && PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID')) ||
                 (typeof process !== 'undefined' && (process.env.GOOGLE_SHEETS_SPREADSHEET_ID || process.env.SPREADSHEET_ID)) ||
                 '1OjPfL4plcH33vm9KpZv2_Y435Xl10uaA1UC-Nl8kUrE',
  transactionsTab: 'fct_transactions'
};

class BigQueryClient {
  /**
   * Fetch the latest effective exchange rates from BigQuery view.
   * @returns {object} Map of currency rate pairs
   */
  static getLatestExchangeRates() {
    const query = `
      SELECT base_currency, quote_currency, rate_type, exchange_rate, inverse_rate
      FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_latest_effective_exchange_rates\`
    `;

    const rates = { ...BQ_CONFIG.fallbackRates };

    try {
      if (typeof BigQuery !== 'undefined' && BigQuery.Jobs) {
        const request = {
          query: query,
          useLegacySql: false,
          location: BQ_CONFIG.location
        };
        const queryJob = BigQuery.Jobs.query(request, BQ_CONFIG.projectId);
        if (queryJob && queryJob.rows) {
          queryJob.rows.forEach(row => {
            const base = row.f[0].v;
            const quote = row.f[1].v;
            const type = row.f[2].v;
            const rate = parseFloat(row.f[3].v);
            const key = `${base}_TO_${quote}_${type}`;
            rates[key] = rate;
            if (type === 'OFFICIAL_INTERBANK') {
              rates[`${base}_TO_${quote}`] = rate;
            }
          });
        }
      }
    } catch (e) {
      console.warn('Could not query live FX rates from BigQuery, utilizing fallback rates:', e.message);
    }

    return rates;
  }

  /**
   * Convert an amount into normalized USD and ZAR based on active rates.
   * @param {number} amount Original signed amount
   * @param {string} currency 'ZAR', 'USD', or 'ZiG'
   * @param {object} rates FX rates map
   * @returns {object} Converted amounts and applied multipliers
   */
  static convertCurrency(amount, currency, rates) {
    let reportingUsd = 0;
    let reportingZar = 0;
    let rateUsd = 1.0;
    let rateZar = 1.0;
    let rateType = 'OFFICIAL_INTERBANK';

    const usdToZar = rates.USD_TO_ZAR || 18.25;
    const zarToUsd = rates.ZAR_TO_USD || (1 / usdToZar);
    const zigToUsdParallel = rates.ZIG_TO_USD_PARALLEL || 0.040816;
    const zigToZarParallel = rates.ZIG_TO_ZAR_PARALLEL || 0.744900;

    if (currency === 'ZAR') {
      reportingZar = amount;
      rateZar = 1.000000;
      rateUsd = zarToUsd;
      reportingUsd = amount * rateUsd;
      rateType = 'OFFICIAL_INTERBANK';
    } else if (currency === 'USD') {
      reportingUsd = amount;
      rateUsd = 1.000000;
      rateZar = usdToZar;
      reportingZar = amount * rateZar;
      rateType = 'OFFICIAL_INTERBANK';
    } else if (currency === 'ZiG') {
      // ZiG operational spending reflects parallel market purchasing power
      rateType = 'MARKET_PARALLEL';
      rateUsd = zigToUsdParallel;
      rateZar = zigToZarParallel;
      reportingUsd = amount * rateUsd;
      reportingZar = amount * rateZar;
    }

    return {
      reportingAmountUsd: parseFloat(reportingUsd.toFixed(4)),
      reportingAmountZar: parseFloat(reportingZar.toFixed(4)),
      appliedExchangeRateUsd: parseFloat(rateUsd.toFixed(6)),
      appliedExchangeRateZar: parseFloat(rateZar.toFixed(6)),
      rateTypeApplied: rateType
    };
  }

  /**
   * Ingest transaction into fct_transactions in BigQuery.
   * Supports both BigQuery Load Job (Sandbox / Free Tier compatible) and SQL DML.
   * @param {object} txData Parsed transaction data
   * @returns {object} Ingestion result { success, transactionId, error }
   */
  static insertTransaction(txData) {
    const now = new Date();
    const isoString = now.toISOString(); // e.g. 2026-09-02T19:40:00.000Z
    const dateStr = isoString.split('T')[0]; // 2026-09-02
    const timestampStr = isoString.replace('T', ' ').replace('Z', ' UTC');
    const localTimeStr = isoString.replace('Z', '').split('.')[0]; // civil DATETIME

    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const txId = txData.transactionId || `TX_SLACK_${dateStr.replace(/-/g, '')}_${randomSuffix}`;

    const fxRates = this.getLatestExchangeRates();
    const conversions = this.convertCurrency(txData.originalAmount, txData.originalCurrency, fxRates);

    const record = {
      transaction_id: txId,
      transaction_timestamp: timestampStr,
      transaction_date: dateStr,
      local_timezone: BQ_CONFIG.defaultTimezone,
      local_timestamp: localTimeStr,
      settlement_timestamp: timestampStr,
      account_id: txData.accountId,
      cash_flow_tier: txData.cashFlowTier,
      category_id: txData.categoryId,
      transaction_type: txData.transactionType,
      original_amount: txData.originalAmount,
      original_currency: txData.originalCurrency,
      reporting_amount_usd: conversions.reportingAmountUsd,
      reporting_amount_zar: conversions.reportingAmountZar,
      applied_exchange_rate_usd: conversions.appliedExchangeRateUsd,
      applied_exchange_rate_zar: conversions.appliedExchangeRateZar,
      rate_type_applied: conversions.rateTypeApplied,
      transfer_counterpart_id: null,
      merchant_or_payee: txData.merchantOrPayee,
      payment_method: txData.paymentMethod,
      statutory_levy_or_fee: null,
      is_tax_deductible: Boolean(txData.isTaxDeductible),
      tax_deductible_amount_zar: txData.isTaxDeductible ? Math.abs(conversions.reportingAmountZar) : 0.0,
      tax_deductible_amount_usd: txData.isTaxDeductible ? Math.abs(conversions.reportingAmountUsd) : 0.0,
      tax_invoice_number: txData.taxInvoiceNumber || null,
      notes: txData.notes,
      tags: txData.tags,
      metadata: Object.assign({
        source: 'slack_bot',
        raw_prompt: txData.rawInput,
        receipt_name: txData.receiptName || null,
        receipt_url: txData.receiptUrl || null,
        ingested_at: isoString
      }, txData.metadata || {})
    };

    // Write directly to Google Sheets via SpreadsheetApp or Sheets Advanced Service
    // BigQuery treats the linked Google Sheet as an external table for real-time reads
    const rowValues = [
      record.transaction_id,
      record.transaction_timestamp,
      record.transaction_date,
      record.local_timezone,
      record.local_timestamp,
      record.settlement_timestamp,
      record.account_id,
      record.cash_flow_tier,
      record.category_id,
      record.transaction_type,
      record.original_amount,
      record.original_currency,
      record.reporting_amount_usd,
      record.reporting_amount_zar,
      record.applied_exchange_rate_usd,
      record.applied_exchange_rate_zar,
      record.rate_type_applied,
      record.transfer_counterpart_id || '',
      record.merchant_or_payee,
      record.payment_method,
      record.statutory_levy_or_fee || '',
      record.is_tax_deductible,
      record.tax_deductible_amount_zar,
      record.tax_deductible_amount_usd,
      record.tax_invoice_number || '',
      record.notes || '',
      Array.isArray(record.tags) ? record.tags.join(',') : '',
      typeof record.metadata === 'object' ? JSON.stringify(record.metadata) : record.metadata
    ];

    try {
      // Strategy 1: Google Apps Script native SpreadsheetApp
      if (typeof SpreadsheetApp !== 'undefined') {
        const ss = SpreadsheetApp.openById(SHEETS_CONFIG.spreadsheetId);
        const sheet = ss.getSheetByName(SHEETS_CONFIG.transactionsTab) || ss.getSheets()[0];
        sheet.appendRow(rowValues);
        return {
          success: true,
          transactionId: txId,
          destination: 'GOOGLE_SHEETS',
          spreadsheetId: SHEETS_CONFIG.spreadsheetId,
          tabName: SHEETS_CONFIG.transactionsTab,
          record: record,
          conversions: conversions
        };
      }

      // Strategy 2: Google Sheets Advanced Service
      if (typeof Sheets !== 'undefined' && Sheets.Spreadsheets) {
        Sheets.Spreadsheets.Values.append(
          { values: [rowValues] },
          SHEETS_CONFIG.spreadsheetId,
          `${SHEETS_CONFIG.transactionsTab}!A1`,
          { valueInputOption: 'USER_ENTERED', insertDataOption: 'INSERT_ROWS' }
        );
        return {
          success: true,
          transactionId: txId,
          destination: 'GOOGLE_SHEETS',
          spreadsheetId: SHEETS_CONFIG.spreadsheetId,
          tabName: SHEETS_CONFIG.transactionsTab,
          record: record,
          conversions: conversions
        };
      }
    } catch (sheetError) {
      console.error('Google Sheets write failed:', sheetError.message);
      return {
        success: false,
        error: `Google Sheets write failed: ${sheetError.message}`,
        record: record
      };
    }

    // Offline / Mock environment (e.g. testing outside Apps Script container)
    return {
      success: true,
      transactionId: txId,
      destination: 'GOOGLE_SHEETS',
      record: record,
      conversions: conversions,
      isMock: true
    };
  }

  /**
   * Get category budget status for current month.
   * @param {string} categoryId 
   * @returns {object|null} Budget stats
   */
  static getCategoryBudgetStatus(categoryId) {
    const query = `
      SELECT
        category_name,
        target_currency,
        planned_amount_zar,
        actual_spent_zar,
        variance_zar,
        ROUND(pct_budget_consumed, 1) AS pct_consumed,
        budget_status
      FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.v_monthly_budget_vs_actual\`
      WHERE category_id = '${categoryId}'
        AND allocation_month = DATE_TRUNC(CURRENT_DATE(), MONTH)
      LIMIT 1;
    `;

    try {
      if (typeof BigQuery !== 'undefined' && BigQuery.Jobs) {
        const queryJob = BigQuery.Jobs.query({ query: query, useLegacySql: false, location: BQ_CONFIG.location }, BQ_CONFIG.projectId);
        if (queryJob && queryJob.rows && queryJob.rows.length > 0) {
          const cols = queryJob.rows[0].f;
          return {
            categoryName: cols[0].v,
            targetCurrency: cols[1].v,
            plannedAmountZar: parseFloat(cols[2].v),
            actualSpentZar: parseFloat(cols[3].v),
            varianceZar: parseFloat(cols[4].v),
            pctConsumed: parseFloat(cols[5].v),
            budgetStatus: cols[6].v
          };
        }
      }
    } catch (err) {
      console.warn('Could not query budget status:', err.message);
    }

    return null;
  }
}

// CommonJS export for testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { BigQueryClient, BQ_CONFIG, SHEETS_CONFIG };
}
