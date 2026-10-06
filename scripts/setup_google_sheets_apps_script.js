/**
 * =============================================================================
 * ZIVA FINANCE: GOOGLE SPREADSHEET SETUP SCRIPT (Google Apps Script)
 * =============================================================================
 *
 * Description:
 * Automatically creates all schema-aligned tabs and sets up frozen, formatted
 * header rows matching the Ziva Finance backend ingestion layer and BigQuery
 * external table definitions.
 *
 * Ingestion Tabs (Matches backend/services/googleSheetsService.js):
 *  1. fct_transactions      (28 columns: A to AB) - Primary ledger
 *  2. debt_credit_ledger     (10 columns: A to J)  - Debt/credit ledger
 *
 * Dimension & Budgeting Tabs (Master schema definitions):
 *  3. dim_accounts           (12 columns) - Bank & fintech accounts
 *  4. dim_categories         (9 columns)  - Expense & income taxonomy
 *  5. dim_currencies         (7 columns)  - Supported multi-currency units
 *  6. fct_budget_allocations (10 columns) - Monthly envelopes & zero-based budget
 *  7. fct_exchange_rates     (9 columns)  - Currency conversion rates
 *
 * Installation & Usage:
 * 1. Open your target Google Spreadsheet in a browser.
 * 2. Click "Extensions" > "Apps Script".
 * 3. Delete any default code in Code.gs, paste this entire file, and click "Save" (💾).
 * 4. Choose "setupZivaSpreadsheet" in the function dropdown at the top and click "Run" (▶).
 *    (Grant standard spreadsheet permissions if prompted).
 * 5. Alternatively, reload your spreadsheet and use the newly added "Ziva Finance" top menu.
 * =============================================================================
 */

// -----------------------------------------------------------------------------
// 1. Authoritative Schema & Header Definitions
// -----------------------------------------------------------------------------
const ZIVA_SCHEMAS = {
  // Primary Ingestion Tab (28 columns, matches range fct_transactions!A:AB)
  fct_transactions: {
    sheetName: 'fct_transactions',
    color: '#0F172A', // Slate 900
    headers: [
      'transaction_id',
      'transaction_timestamp',
      'transaction_date',
      'local_timezone',
      'local_timestamp',
      'settlement_timestamp',
      'account_id',
      'cash_flow_tier',
      'category_id',
      'transaction_type',
      'original_amount',
      'original_currency',
      'reporting_amount_usd',
      'reporting_amount_zar',
      'applied_exchange_rate_usd',
      'applied_exchange_rate_zar',
      'rate_type_applied',
      'transfer_counterpart_id',
      'merchant_or_payee',
      'payment_method',
      'statutory_levy_or_fee',
      'is_tax_deductible',
      'tax_deductible_amount_zar',
      'tax_deductible_amount_usd',
      'tax_invoice_number',
      'notes',
      'tags',
      'metadata'
    ],
    validations: {
      cash_flow_tier: ['DAILY_SPENDING', 'MONTHLY_ALLOCATION', 'LONG_TERM_VAULT'],
      transaction_type: ['EXPENSE', 'INCOME', 'TRANSFER', 'CAPITAL_INVESTMENT']
    }
  },

  // Debt & Credit Ingestion Tab (10 columns, matches range debt_credit_ledger!A:J)
  debt_credit_ledger: {
    sheetName: 'debt_credit_ledger',
    color: '#1E293B', // Slate 800
    headers: [
      'id',
      'person_name',
      'direction',
      'amount',
      'currency',
      'date',
      'status',
      'notes',
      'created_at',
      'updated_at'
    ],
    validations: {
      direction: ['owed_by_me', 'owed_to_me'],
      status: ['Pending', 'Settled']
    }
  },

  // Dimension: Accounts Register
  dim_accounts: {
    sheetName: 'dim_accounts',
    color: '#334155', // Slate 700
    headers: [
      'account_id',
      'account_name',
      'financial_institution',
      'country_code',
      'primary_currency',
      'cash_flow_tier',
      'account_type',
      'is_vault_locked',
      'withdrawal_notice_days',
      'account_number_masked',
      'is_active',
      'created_at'
    ]
  },

  // Dimension: Category Taxonomy
  dim_categories: {
    sheetName: 'dim_categories',
    color: '#334155',
    headers: [
      'category_id',
      'category_name',
      'parent_category_id',
      'category_group',
      'cash_flow_tier',
      'is_essential_need',
      'is_tax_deductible',
      'tax_line_item',
      'description'
    ]
  },

  // Dimension: Supported Currencies
  dim_currencies: {
    sheetName: 'dim_currencies',
    color: '#475569',
    headers: [
      'currency_code',
      'currency_name',
      'country_code',
      'symbol',
      'decimal_places',
      'is_active',
      'notes'
    ]
  },

  // Fact: Monthly Budget Allocations (Envelopes)
  fct_budget_allocations: {
    sheetName: 'fct_budget_allocations',
    color: '#475569',
    headers: [
      'allocation_month',
      'category_id',
      'cash_flow_tier',
      'target_currency',
      'planned_amount',
      'planned_amount_usd',
      'planned_amount_zar',
      'rollover_from_prior',
      'is_fixed_obligation',
      'notes'
    ]
  },

  // Fact: Historical / Daily Exchange Rates
  fct_exchange_rates: {
    sheetName: 'fct_exchange_rates',
    color: '#475569',
    headers: [
      'rate_date',
      'rate_timestamp',
      'base_currency',
      'quote_currency',
      'rate_type',
      'exchange_rate',
      'inverse_rate',
      'source_provider',
      'notes'
    ]
  }
};

// -----------------------------------------------------------------------------
// 2. Custom Spreadsheet UI Menu
// -----------------------------------------------------------------------------
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('🚀 Ziva Finance')
    .addItem('Initialize All Tabs & Headers (Full Setup)', 'setupZivaSpreadsheet')
    .addItem('Initialize Ingestion Tabs Only (fct_transactions & debt_credit_ledger)', 'setupCoreIngestionTabsOnly')
    .addSeparator()
    .addItem('Remove Default Empty Sheet (Sheet1)', 'cleanupDefaultSheet')
    .addToUi();
}

// -----------------------------------------------------------------------------
// 3. Main Setup Functions
// -----------------------------------------------------------------------------

/**
 * Initializes all 7 schema tabs (Ingestion + Dimensions + Budgeting)
 */
function setupZivaSpreadsheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const summary = [];

  for (const [key, schema] of Object.entries(ZIVA_SCHEMAS)) {
    const status = createOrUpdateTab(ss, schema);
    summary.push(`${schema.sheetName} (${status})`);
  }

  cleanupDefaultSheet();

  const msg = `Ziva Finance Setup Complete!\n\nInitialized tabs:\n• ` + summary.join('\n• ');
  Logger.log(msg);
  try {
    SpreadsheetApp.getUi().alert('Ziva Finance Setup', msg, SpreadsheetApp.getUi().ButtonSet.OK);
  } catch (_) {
    // Alert might not be available in headless or triggered execution
  }
}

/**
 * Initializes only the 2 core ingestion tabs expected by the backend service:
 *  - fct_transactions
 *  - debt_credit_ledger
 */
function setupCoreIngestionTabsOnly() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const summary = [];

  const coreKeys = ['fct_transactions', 'debt_credit_ledger'];
  for (const key of coreKeys) {
    const schema = ZIVA_SCHEMAS[key];
    const status = createOrUpdateTab(ss, schema);
    summary.push(`${schema.sheetName} (${status})`);
  }

  cleanupDefaultSheet();

  const msg = `Core Ingestion Tabs Ready!\n\n• ` + summary.join('\n• ');
  Logger.log(msg);
  try {
    SpreadsheetApp.getUi().alert('Ziva Finance Ingestion Setup', msg, SpreadsheetApp.getUi().ButtonSet.OK);
  } catch (_) {}
}

// -----------------------------------------------------------------------------
// 4. Tab Creation & Formatting Helper
// -----------------------------------------------------------------------------
function createOrUpdateTab(ss, schema) {
  let sheet = ss.getSheetByName(schema.sheetName);
  let status = 'updated';

  if (!sheet) {
    sheet = ss.insertSheet(schema.sheetName);
    status = 'created';
  }

  // Ensure enough columns exist for the header
  const requiredCols = schema.headers.length;
  const currentCols = sheet.getMaxColumns();
  if (currentCols < requiredCols) {
    sheet.insertColumnsAfter(currentCols, requiredCols - currentCols);
  }

  // Check existing row 1 values
  const existingHeaders = sheet.getRange(1, 1, 1, requiredCols).getValues()[0];
  const isRow1Empty = existingHeaders.every(cell => cell === '' || cell === null);

  // Set header row values
  const headerRange = sheet.getRange(1, 1, 1, requiredCols);
  headerRange.setValues([schema.headers]);

  // Style Header Row (Row 1)
  headerRange
    .setBackground(schema.color || '#0F172A')
    .setFontColor('#FFFFFF')
    .setFontWeight('bold')
    .setFontFamily('Roboto')
    .setFontSize(10)
    .setHorizontalAlignment('center')
    .setVerticalAlignment('middle')
    .setWrap(false);

  // Freeze Header Row
  sheet.setFrozenRows(1);
  sheet.setRowHeight(1, 34);

  // Apply Data Validation dropdowns if defined
  if (schema.validations) {
    for (const [colName, allowedValues] of Object.entries(schema.validations)) {
      const colIndex = schema.headers.indexOf(colName) + 1;
      if (colIndex > 0) {
        const rule = SpreadsheetApp.newDataValidation()
          .requireValueInList(allowedValues, true)
          .setAllowInvalid(true)
          .build();
        // Apply from row 2 to row 1000
        sheet.getRange(2, colIndex, 999, 1).setDataValidation(rule);
      }
    }
  }

  // Auto-fit column widths up to first 10 columns for pleasant visibility
  for (let c = 1; c <= Math.min(requiredCols, 15); c++) {
    sheet.autoResizeColumn(c);
    // Keep minimum column width of 110px
    if (sheet.getColumnWidth(c) < 110) {
      sheet.setColumnWidth(c, 120);
    }
  }

  return status;
}

/**
 * Removes the default 'Sheet1' if it exists and has no data
 */
function cleanupDefaultSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet1 = ss.getSheetByName('Sheet1') || ss.getSheetByName('Sheet 1');

  if (sheet1 && ss.getSheets().length > 1) {
    const lastRow = sheet1.getLastRow();
    const lastCol = sheet1.getLastColumn();
    // Only delete if it is completely empty
    if (lastRow === 0 && lastCol === 0) {
      try {
        ss.deleteSheet(sheet1);
        Logger.log('Removed empty default Sheet1');
      } catch (e) {
        Logger.log('Could not remove Sheet1: ' + e.message);
      }
    }
  }
}
