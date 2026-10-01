-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker
-- Script: 03_transactions.sql
-- Description: External table linked to Google Sheets for live financial ledger reads.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FCT_TRANSACTIONS (External Table backed by Google Sheets)
-- Unified double-entry / multi-account transaction ledger.
--
-- External Table Strategy:
--  - Ingestion occurs directly to Google Sheets via Google Sheets API v4.
--  - BigQuery reads the linked Google Sheet dynamically at query time.
--  - Real-time updates with zero streaming buffer locks or quota restrictions.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE EXTERNAL TABLE `personal_finance.fct_transactions` (
  transaction_id              STRING NOT NULL OPTIONS(description="Unique transaction ID (UUID or bank statement unique hash)"),
  transaction_timestamp       TIMESTAMP NOT NULL OPTIONS(description="Point-in-time event timestamp in UTC"),
  transaction_date            DATE NOT NULL OPTIONS(description="Calendar date of transaction"),
  local_timezone              STRING NOT NULL OPTIONS(description="Local timezone of the transaction, typically 'Africa/Johannesburg' or 'Africa/Harare' (CAT / UTC+2)"),
  local_timestamp             DATETIME NOT NULL OPTIONS(description="Local civil timestamp when transaction took place"),
  settlement_timestamp        TIMESTAMP OPTIONS(description="Bank clearing or value settlement timestamp in UTC"),
  
  -- Account & Flow Segregation
  account_id                  STRING NOT NULL OPTIONS(description="Foreign key to dim_accounts"),
  cash_flow_tier              STRING NOT NULL OPTIONS(description="Cash flow designation: 'DAILY_SPENDING', 'MONTHLY_ALLOCATION', or 'LONG_TERM_VAULT'"),
  category_id                 STRING NOT NULL OPTIONS(description="Foreign key to dim_categories"),
  transaction_type            STRING NOT NULL OPTIONS(description="Type: 'EXPENSE', 'INCOME', 'INTERNAL_TRANSFER', 'ALLOCATION_TRANSFER', 'VAULT_CONTRIBUTION', 'VAULT_WITHDRAWAL', 'FINANCIAL_FEE'"),
  
  -- Financial Amounts & Currencies
  -- Signed amounts: Positive (+) indicates inflow/credit; Negative (-) indicates outflow/debit.
  original_amount             NUMERIC(18, 4) NOT NULL OPTIONS(description="Exact transaction amount in the account's operational currency"),
  original_currency           STRING NOT NULL OPTIONS(description="Currency code: 'ZAR', 'USD', 'ZiG', etc."),
  
  -- Pre-computed Base Reporting Currencies (Both USD and ZAR to satisfy dual-country reporting)
  reporting_amount_usd        NUMERIC(18, 4) NOT NULL OPTIONS(description="Normalized amount in USD at effective exchange rate"),
  reporting_amount_zar        NUMERIC(18, 4) NOT NULL OPTIONS(description="Normalized amount in ZAR at effective exchange rate"),
  applied_exchange_rate_usd   NUMERIC(18, 6) NOT NULL OPTIONS(description="Exchange rate multiplier applied to calculate USD (1.0 if already USD)"),
  applied_exchange_rate_zar   NUMERIC(18, 6) NOT NULL OPTIONS(description="Exchange rate multiplier applied to calculate ZAR (1.0 if already ZAR)"),
  rate_type_applied           STRING NOT NULL OPTIONS(description="Rate regime used for conversion: 'OFFICIAL_INTERBANK', 'MARKET_PARALLEL', or 'FIXED_BASE'"),
  
  -- Transfer Reconciliation
  transfer_counterpart_id     STRING OPTIONS(description="Matching transaction_id for complementary leg of internal transfer"),
  
  -- Descriptive & Merchant Metadata
  merchant_or_payee           STRING NOT NULL OPTIONS(description="Merchant, vendor, employer, or recipient name"),
  payment_method              STRING NOT NULL OPTIONS(description="Channel: 'DEBIT_CARD', 'EFT', 'MOBILE_MONEY_ECOCASH', 'MOBILE_MONEY_INNBUCKS', 'DIRECT_DEBIT', 'SWIPE_POS', 'CASH'"),
  statutory_levy_or_fee       NUMERIC(18, 4) OPTIONS(description="Specific transaction levy if applicable, e.g. Zimbabwe 2% IMTT tax or SA ATM fee"),
  
  -- Tax Offset & Compliance Attributes
  is_tax_deductible           BOOL NOT NULL OPTIONS(description="Explicit tax deduction flag for the transaction (e.g. business productivity purchases)"),
  tax_deductible_amount_zar   NUMERIC(18, 4) OPTIONS(description="Allowable tax deductible portion in ZAR for business offsets"),
  tax_deductible_amount_usd   NUMERIC(18, 4) OPTIONS(description="Allowable tax deductible portion in USD for business offsets"),
  tax_invoice_number          STRING OPTIONS(description="Tax invoice or receipt reference number for SARS/ZIMRA audit trail"),

  notes                       STRING OPTIONS(description="Personal memo or transaction narrative"),
  tags                        STRING OPTIONS(description="Comma-separated or JSON string list of labels"),
  metadata                    STRING OPTIONS(description="Raw provider JSON payload stored as string from Google Sheets")
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1OjPfL4plcH33vm9KpZv2_Y435Xl10uaA1UC-Nl8kUrE'],
  skip_leading_rows = 1,
  sheet_range = 'fct_transactions!A:AB',
  description = "Granular financial ledger capturing all cash flows across Daily Spending, Monthly Allocations, and Long-Term Vault, read in real-time from linked Google Sheet."
);
