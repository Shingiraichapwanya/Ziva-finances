-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: 07_external_sheets_tables.sql
-- Description: External Table definitions linking BigQuery to Google Sheets
-- =============================================================================
--
-- Instructions:
-- 1. Replace the spreadsheet URL/ID with your active Google Sheet:
--    'https://docs.google.com/spreadsheets/d/<YOUR_SPREADSHEET_ID>'
-- 2. Ensure your Google Sheet contains two tabs:
--    - 'fct_transactions' (Columns A to AB: 28 columns)
--    - 'debt_credit_ledger' (Columns A to J: 10 columns)
-- 3. Share the Google Sheet with the Service Account email:
--    (e.g., bigquery-client@budget-tracker-507418.iam.gserviceaccount.com)
--    with "Viewer" or "Editor" permissions.
-- 4. Execute this script in BigQuery Console or via `node src/server.js` startup helper.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FCT_TRANSACTIONS EXTERNAL TABLE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE EXTERNAL TABLE `personal_finance.fct_transactions` (
  transaction_id              STRING NOT NULL OPTIONS(description="Unique transaction ID"),
  transaction_timestamp       TIMESTAMP NOT NULL OPTIONS(description="Point-in-time event timestamp in UTC"),
  transaction_date            DATE NOT NULL OPTIONS(description="Calendar date of transaction"),
  local_timezone              STRING NOT NULL OPTIONS(description="Local civil timezone"),
  local_timestamp             DATETIME NOT NULL OPTIONS(description="Local civil timestamp"),
  settlement_timestamp        TIMESTAMP OPTIONS(description="Settlement timestamp in UTC"),
  account_id                  STRING NOT NULL OPTIONS(description="Foreign key to dim_accounts"),
  cash_flow_tier              STRING NOT NULL OPTIONS(description="Cash flow designation"),
  category_id                 STRING NOT NULL OPTIONS(description="Foreign key to dim_categories"),
  transaction_type            STRING NOT NULL OPTIONS(description="Transaction type"),
  original_amount             NUMERIC(18, 4) NOT NULL OPTIONS(description="Amount in account currency"),
  original_currency           STRING NOT NULL OPTIONS(description="Currency code: ZAR, USD, ZiG, etc."),
  reporting_amount_usd        NUMERIC(18, 4) NOT NULL OPTIONS(description="Normalized USD amount"),
  reporting_amount_zar        NUMERIC(18, 4) NOT NULL OPTIONS(description="Normalized ZAR amount"),
  applied_exchange_rate_usd   NUMERIC(18, 6) NOT NULL OPTIONS(description="USD conversion rate"),
  applied_exchange_rate_zar   NUMERIC(18, 6) NOT NULL OPTIONS(description="ZAR conversion rate"),
  rate_type_applied           STRING NOT NULL OPTIONS(description="Conversion rate regime"),
  transfer_counterpart_id     STRING OPTIONS(description="Matching transfer transaction ID"),
  merchant_or_payee           STRING NOT NULL OPTIONS(description="Merchant or payee name"),
  payment_method              STRING NOT NULL OPTIONS(description="Payment channel"),
  statutory_levy_or_fee       NUMERIC(18, 4) OPTIONS(description="Specific transaction levy"),
  is_tax_deductible           BOOL NOT NULL OPTIONS(description="Tax deduction flag"),
  tax_deductible_amount_zar   NUMERIC(18, 4) OPTIONS(description="Tax deductible portion in ZAR"),
  tax_deductible_amount_usd   NUMERIC(18, 4) OPTIONS(description="Tax deductible portion in USD"),
  tax_invoice_number          STRING OPTIONS(description="Tax invoice or receipt reference number"),
  notes                       STRING OPTIONS(description="Personal memo or transaction narrative"),
  tags                        STRING OPTIONS(description="Comma-separated or JSON list of labels"),
  metadata                    STRING OPTIONS(description="Raw provider JSON payload stored as string")
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1OjPfL4plcH33vm9KpZv2_Y435Xl10uaA1UC-Nl8kUrE'],
  skip_leading_rows = 1,
  sheet_range = 'fct_transactions!A:AB',
  description = "External table linking BigQuery fct_transactions directly to Google Sheets for real-time reads."
);

-- -----------------------------------------------------------------------------
-- 2. DEBT_CREDIT_LEDGER EXTERNAL TABLE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE EXTERNAL TABLE `personal_finance.debt_credit_ledger` (
  id                          STRING NOT NULL OPTIONS(description="Debt record ID"),
  person_name                 STRING NOT NULL OPTIONS(description="Counterparty person name"),
  direction                   STRING NOT NULL OPTIONS(description="'owed_by_me' or 'owed_to_me'"),
  amount                      NUMERIC(18, 4) NOT NULL OPTIONS(description="Principal debt amount"),
  currency                    STRING NOT NULL OPTIONS(description="Currency code"),
  date                        DATE NOT NULL OPTIONS(description="Entry date"),
  status                      STRING NOT NULL OPTIONS(description="Status: 'Pending' or 'Settled'"),
  notes                       STRING OPTIONS(description="Description notes"),
  created_at                  TIMESTAMP OPTIONS(description="Creation timestamp"),
  updated_at                  TIMESTAMP OPTIONS(description="Last update timestamp")
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1OjPfL4plcH33vm9KpZv2_Y435Xl10uaA1UC-Nl8kUrE'],
  skip_leading_rows = 1,
  sheet_range = 'debt_credit_ledger!A:J',
  description = "External table linking BigQuery debt_credit_ledger directly to Google Sheets for real-time reads."
);
