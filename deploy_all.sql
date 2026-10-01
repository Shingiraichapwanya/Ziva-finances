-- =============================================================================
-- BigQuery Schema: Personal Budget Tracker - Master Deployment Script
-- File: deploy_all.sql
-- Description: Creates dataset, all dimension and fact tables, analytical views,
--              and populates the complete sample seed dataset in one run.
-- =============================================================================

-- Step 0: Create Dataset (Adjust location if needed, e.g. 'africa-south1', 'US', 'EU')
CREATE SCHEMA IF NOT EXISTS `personal_finance`
OPTIONS(
  location = 'africa-south1',
  description = 'Personal budget tracking data warehouse for Southern African multi-currency cash flows'
);

-- =============================================================================
-- STEP 1: DIMENSIONS
-- =============================================================================

-- 1.1 DIM_CURRENCIES
CREATE OR REPLACE TABLE `personal_finance.dim_currencies` (
  currency_code       STRING NOT NULL OPTIONS(description="ISO code or regional currency identifier, e.g. ZAR, USD, ZiG"),
  currency_name       STRING NOT NULL OPTIONS(description="Full name of the currency"),
  country_code        STRING NOT NULL OPTIONS(description="ISO Alpha-2 country code primarily associated (e.g. ZA, ZW, US)"),
  symbol              STRING NOT NULL OPTIONS(description="Display symbol (e.g. R, $, ZiG)"),
  decimal_places      INT64 NOT NULL OPTIONS(description="Standard decimal places"),
  is_active           BOOL NOT NULL OPTIONS(description="Whether the currency is currently actively transacted"),
  notes               STRING OPTIONS(description="Contextual notes e.g. Zimbabwe Gold introduced April 2024")
)
CLUSTER BY currency_code;

-- 1.2 DIM_ACCOUNTS
CREATE OR REPLACE TABLE `personal_finance.dim_accounts` (
  account_id              STRING NOT NULL OPTIONS(description="Unique identifier for the account"),
  account_name            STRING NOT NULL OPTIONS(description="User-friendly account label"),
  financial_institution   STRING NOT NULL OPTIONS(description="Bank or fintech provider"),
  country_code            STRING NOT NULL OPTIONS(description="Country where account is domiciled: 'ZA' or 'ZW'"),
  primary_currency        STRING NOT NULL OPTIONS(description="Base currency for this account"),
  cash_flow_tier          STRING NOT NULL OPTIONS(description="Cash flow designation: 'DAILY_SPENDING', 'MONTHLY_ALLOCATION', or 'LONG_TERM_VAULT'"),
  account_type            STRING NOT NULL OPTIONS(description="Account category"),
  is_vault_locked         BOOL NOT NULL OPTIONS(description="True if account is in the Long-Term Vault with locked terms"),
  withdrawal_notice_days  INT64 OPTIONS(description="Notice period required for withdrawals"),
  account_number_masked   STRING OPTIONS(description="Last 4 digits or masked identifier"),
  is_active               BOOL NOT NULL OPTIONS(description="Active status of the account"),
  created_at              TIMESTAMP NOT NULL OPTIONS(description="Record creation timestamp in UTC")
)
CLUSTER BY cash_flow_tier, country_code, primary_currency;

-- 1.3 DIM_CATEGORIES
CREATE OR REPLACE TABLE `personal_finance.dim_categories` (
  category_id             STRING NOT NULL OPTIONS(description="Unique category identifier"),
  category_name           STRING NOT NULL OPTIONS(description="Human-readable category name"),
  parent_category_id      STRING OPTIONS(description="Parent category ID for hierarchical aggregation"),
  category_group          STRING NOT NULL OPTIONS(description="High-level category grouping"),
  cash_flow_tier          STRING NOT NULL OPTIONS(description="Target tier"),
  is_essential_need       BOOL NOT NULL OPTIONS(description="True for 50/30/20 'Needs'; False for 'Wants'"),
  is_tax_deductible       BOOL NOT NULL OPTIONS(description="True if expenses qualify for business tax offset or deduction"),
  tax_line_item           STRING OPTIONS(description="Tax return classification e.g. 'PRODUCTIVITY_HARDWARE', 'BUSINESS_SOFTWARE', 'STATUTORY_TAX_PAYMENT', etc."),
  description             STRING OPTIONS(description="Detailed scope of expenses")
)
CLUSTER BY category_group, cash_flow_tier;

-- =============================================================================
-- STEP 2: FACT TABLES
-- =============================================================================

-- 2.1 FCT_EXCHANGE_RATES
CREATE OR REPLACE TABLE `personal_finance.fct_exchange_rates` (
  rate_date           DATE NOT NULL OPTIONS(description="Calendar date of the exchange rate quotation"),
  rate_timestamp      TIMESTAMP NOT NULL OPTIONS(description="Exact timestamp when this rate became effective (UTC)"),
  base_currency       STRING NOT NULL OPTIONS(description="Base currency"),
  quote_currency      STRING NOT NULL OPTIONS(description="Quote currency"),
  rate_type           STRING NOT NULL OPTIONS(description="Rate regime: 'OFFICIAL_INTERBANK', 'MARKET_PARALLEL', etc."),
  exchange_rate       NUMERIC(18, 6) NOT NULL OPTIONS(description="Rate multiplier: quote_amount = base_amount * exchange_rate"),
  inverse_rate        NUMERIC(18, 6) NOT NULL OPTIONS(description="Inverse rate: base_amount = quote_amount * inverse_rate"),
  source_provider     STRING NOT NULL OPTIONS(description="Source of data"),
  notes               STRING OPTIONS(description="Additional context regarding rate adjustments")
)
PARTITION BY rate_date
CLUSTER BY base_currency, quote_currency, rate_type;

-- 2.2 FCT_TRANSACTIONS (External Table linked to Google Sheets)
CREATE OR REPLACE EXTERNAL TABLE `personal_finance.fct_transactions` (
  transaction_id              STRING NOT NULL,
  transaction_timestamp       TIMESTAMP NOT NULL,
  transaction_date            DATE NOT NULL,
  local_timezone              STRING NOT NULL,
  local_timestamp             DATETIME NOT NULL,
  settlement_timestamp        TIMESTAMP,
  account_id                  STRING NOT NULL,
  cash_flow_tier              STRING NOT NULL,
  category_id                 STRING NOT NULL,
  transaction_type            STRING NOT NULL,
  original_amount             NUMERIC(18, 4) NOT NULL,
  original_currency           STRING NOT NULL,
  reporting_amount_usd        NUMERIC(18, 4) NOT NULL,
  reporting_amount_zar        NUMERIC(18, 4) NOT NULL,
  applied_exchange_rate_usd   NUMERIC(18, 6) NOT NULL,
  applied_exchange_rate_zar   NUMERIC(18, 6) NOT NULL,
  rate_type_applied           STRING NOT NULL,
  transfer_counterpart_id     STRING,
  merchant_or_payee           STRING NOT NULL,
  payment_method              STRING NOT NULL,
  statutory_levy_or_fee       NUMERIC(18, 4),
  is_tax_deductible           BOOL NOT NULL,
  tax_deductible_amount_zar   NUMERIC(18, 4),
  tax_deductible_amount_usd   NUMERIC(18, 4),
  tax_invoice_number          STRING,
  notes                       STRING,
  tags                        STRING,
  metadata                    STRING
)
OPTIONS (
  format = 'GOOGLE_SHEETS',
  uris = ['https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms'],
  skip_leading_rows = 1,
  sheet_range = 'fct_transactions!A:AB',
  description = "External table linked directly to Google Sheets for real-time transaction ledger reads."
);

-- 2.3 FCT_BUDGET_ALLOCATIONS
CREATE OR REPLACE TABLE `personal_finance.fct_budget_allocations` (
  allocation_month        DATE NOT NULL,
  category_id             STRING NOT NULL,
  cash_flow_tier          STRING NOT NULL,
  target_currency         STRING NOT NULL,
  planned_amount          NUMERIC(18, 4) NOT NULL,
  planned_amount_usd      NUMERIC(18, 4) NOT NULL,
  planned_amount_zar      NUMERIC(18, 4) NOT NULL,
  rollover_from_prior     NUMERIC(18, 4) DEFAULT 0.0000 NOT NULL,
  is_fixed_obligation     BOOL NOT NULL,
  notes                   STRING
)
PARTITION BY allocation_month
CLUSTER BY cash_flow_tier, category_id;

-- =============================================================================
-- STEP 3: ANALYTICAL REPORTING VIEWS
-- =============================================================================

-- 3.1 Latest Effective Exchange Rates
CREATE OR REPLACE VIEW `personal_finance.v_latest_effective_exchange_rates` AS
WITH ranked_rates AS (
  SELECT
    rate_date,
    rate_timestamp,
    base_currency,
    quote_currency,
    rate_type,
    exchange_rate,
    inverse_rate,
    source_provider,
    ROW_NUMBER() OVER (
      PARTITION BY base_currency, quote_currency, rate_type
      ORDER BY rate_timestamp DESC, rate_date DESC
    ) AS rank_idx
  FROM `personal_finance.fct_exchange_rates`
)
SELECT
  rate_date,
  rate_timestamp,
  base_currency,
  quote_currency,
  rate_type,
  exchange_rate,
  inverse_rate,
  source_provider
FROM ranked_rates
WHERE rank_idx = 1;

-- 3.2 Daily Spending Burn Rate
CREATE OR REPLACE VIEW `personal_finance.v_daily_spending_burn_rate` AS
WITH daily_aggregates AS (
  SELECT
    t.transaction_date,
    t.account_id,
    t.category_id,
    SUM(ABS(t.original_amount)) AS total_spent_original,
    t.original_currency,
    SUM(ABS(t.reporting_amount_usd)) AS total_spent_usd,
    SUM(ABS(t.reporting_amount_zar)) AS total_spent_zar,
    COUNT(1) AS transaction_count
  FROM `personal_finance.fct_transactions` AS t
  WHERE t.cash_flow_tier = 'DAILY_SPENDING'
    AND t.transaction_type IN ('EXPENSE', 'FINANCIAL_FEE')
  GROUP BY
    t.transaction_date,
    t.account_id,
    t.category_id,
    t.original_currency
)
SELECT
  d.transaction_date,
  a.account_name,
  a.financial_institution,
  a.country_code,
  c.category_name,
  c.category_group,
  c.is_essential_need,
  d.total_spent_original,
  d.original_currency,
  d.total_spent_usd,
  d.total_spent_zar,
  d.transaction_count,
  AVG(d.total_spent_zar) OVER (
    PARTITION BY a.country_code
    ORDER BY d.transaction_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_avg_spend_zar,
  AVG(d.total_spent_usd) OVER (
    PARTITION BY a.country_code
    ORDER BY d.transaction_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_avg_spend_usd
FROM daily_aggregates AS d
INNER JOIN `personal_finance.dim_accounts` AS a
  ON d.account_id = a.account_id
INNER JOIN `personal_finance.dim_categories` AS c
  ON d.category_id = c.category_id;

-- 3.3 Monthly Budget vs Actuals
CREATE OR REPLACE VIEW `personal_finance.v_monthly_budget_vs_actual` AS
WITH monthly_actuals AS (
  SELECT
    DATE_TRUNC(t.transaction_date, MONTH) AS budget_month,
    t.category_id,
    t.cash_flow_tier,
    SUM(ABS(t.reporting_amount_usd)) AS actual_spent_usd,
    SUM(ABS(t.reporting_amount_zar)) AS actual_spent_zar,
    COUNT(1) AS actual_transaction_count
  FROM `personal_finance.fct_transactions` AS t
  WHERE t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER', 'FINANCIAL_FEE')
  GROUP BY
    budget_month,
    t.category_id,
    t.cash_flow_tier
)
SELECT
  b.allocation_month,
  b.category_id,
  b.cash_flow_tier,
  c.category_group,
  c.category_name,
  b.is_fixed_obligation,
  b.target_currency,
  b.planned_amount,
  b.rollover_from_prior,
  b.planned_amount_usd,
  b.planned_amount_zar,
  COALESCE(m.actual_spent_usd, 0.0000) AS actual_spent_usd,
  COALESCE(m.actual_spent_zar, 0.0000) AS actual_spent_zar,
  COALESCE(m.actual_transaction_count, 0) AS actual_transaction_count,
  (b.planned_amount_zar + b.rollover_from_prior) - COALESCE(m.actual_spent_zar, 0.0000) AS variance_zar,
  (b.planned_amount_usd + b.rollover_from_prior) - COALESCE(m.actual_spent_usd, 0.0000) AS variance_usd,
  SAFE_DIVIDE(COALESCE(m.actual_spent_zar, 0.0000), (b.planned_amount_zar + b.rollover_from_prior)) * 100.0 AS pct_budget_consumed,
  CASE
    WHEN COALESCE(m.actual_spent_zar, 0.0000) > (b.planned_amount_zar + b.rollover_from_prior) THEN 'OVER_BUDGET'
    WHEN SAFE_DIVIDE(COALESCE(m.actual_spent_zar, 0.0000), (b.planned_amount_zar + b.rollover_from_prior)) >= 0.90 THEN 'NEAR_LIMIT'
    ELSE 'ON_TRACK'
  END AS budget_status
FROM `personal_finance.fct_budget_allocations` AS b
LEFT JOIN monthly_actuals AS m
  ON b.allocation_month = m.budget_month
 AND b.category_id = m.category_id
 AND b.cash_flow_tier = m.cash_flow_tier
INNER JOIN `personal_finance.dim_categories` AS c
  ON b.category_id = c.category_id;

-- 3.4 Vault Holdings & Net Worth
CREATE OR REPLACE VIEW `personal_finance.v_vault_holdings_and_net_worth` AS
WITH vault_ledger AS (
  SELECT
    t.account_id,
    SUM(t.original_amount) AS cumulative_balance_original,
    t.original_currency,
    SUM(t.reporting_amount_usd) AS cumulative_balance_usd,
    SUM(t.reporting_amount_zar) AS cumulative_balance_zar,
    MIN(t.transaction_date) AS first_deposit_date,
    MAX(t.transaction_date) AS last_movement_date,
    COUNT(1) AS total_vault_movements
  FROM `personal_finance.fct_transactions` AS t
  WHERE t.cash_flow_tier = 'LONG_TERM_VAULT'
  GROUP BY
    t.account_id,
    t.original_currency
)
SELECT
  a.account_id,
  a.account_name,
  a.financial_institution,
  a.country_code,
  a.primary_currency,
  a.account_type,
  a.is_vault_locked,
  a.withdrawal_notice_days,
  COALESCE(v.cumulative_balance_original, 0.0000) AS current_balance_original,
  COALESCE(v.cumulative_balance_usd, 0.0000) AS current_balance_usd,
  COALESCE(v.cumulative_balance_zar, 0.0000) AS current_balance_zar,
  v.first_deposit_date,
  v.last_movement_date,
  v.total_vault_movements
FROM `personal_finance.dim_accounts` AS a
LEFT JOIN vault_ledger AS v
  ON a.account_id = v.account_id
WHERE a.cash_flow_tier = 'LONG_TERM_VAULT';

-- 3.5 Quarterly Tax Liability Schedule
CREATE OR REPLACE VIEW `personal_finance.v_quarterly_tax_liability_schedule` AS
WITH quarterly_base AS (
  SELECT
    EXTRACT(YEAR FROM t.transaction_date) AS tax_year,
    CONCAT(CAST(EXTRACT(YEAR FROM t.transaction_date) AS STRING), '-Q', CAST(EXTRACT(QUARTER FROM t.transaction_date) AS STRING)) AS tax_quarter,
    DATE_TRUNC(t.transaction_date, QUARTER) AS quarter_start_date,
    LAST_DAY(t.transaction_date, QUARTER) AS quarter_end_date,

    -- Gross Inflows (Taxable Revenue/Income)
    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_zar ELSE 0 END) AS gross_taxable_inflow_zar,
    SUM(CASE WHEN t.transaction_type = 'INCOME' THEN t.reporting_amount_usd ELSE 0 END) AS gross_taxable_inflow_usd,

    -- Business Productivity Deductions (Hardware, Software, Professional Services)
    SUM(CASE 
      WHEN c.category_group = 'BUSINESS_PRODUCTIVITY' AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_zar, ABS(t.reporting_amount_zar))
      ELSE 0 
    END) AS productivity_expenses_offset_zar,
    SUM(CASE 
      WHEN c.category_group = 'BUSINESS_PRODUCTIVITY' AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_usd, ABS(t.reporting_amount_usd))
      ELSE 0 
    END) AS productivity_expenses_offset_usd,

    -- Total Allowable Tax Deductions (all items flagged is_tax_deductible)
    SUM(CASE 
      WHEN (t.is_tax_deductible OR c.is_tax_deductible) AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_zar, ABS(t.reporting_amount_zar))
      ELSE 0 
    END) AS total_allowable_deductions_zar,
    SUM(CASE 
      WHEN (t.is_tax_deductible OR c.is_tax_deductible) AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER')
      THEN COALESCE(t.tax_deductible_amount_usd, ABS(t.reporting_amount_usd))
      ELSE 0 
    END) AS total_allowable_deductions_usd,

    -- Actual Statutory Tax Payments (Payments made to SARS / ZIMRA)
    SUM(CASE 
      WHEN c.category_id = 'CAT_TAX_STATUTORY_PROVISIONAL' OR c.tax_line_item = 'STATUTORY_TAX_PAYMENT'
      THEN ABS(t.reporting_amount_zar)
      ELSE 0 
    END) AS actual_tax_paid_zar,
    SUM(CASE 
      WHEN c.category_id = 'CAT_TAX_STATUTORY_PROVISIONAL' OR c.tax_line_item = 'STATUTORY_TAX_PAYMENT'
      THEN ABS(t.reporting_amount_usd)
      ELSE 0 
    END) AS actual_tax_paid_usd,

    COUNT(DISTINCT CASE WHEN (t.is_tax_deductible OR c.is_tax_deductible) THEN t.transaction_id END) AS tax_deductible_transaction_count
  FROM `personal_finance.fct_transactions` AS t
  INNER JOIN `personal_finance.dim_categories` AS c
    ON t.category_id = c.category_id
  GROUP BY
    tax_year,
    tax_quarter,
    quarter_start_date,
    quarter_end_date
)
SELECT
  tax_year,
  tax_quarter,
  quarter_start_date,
  quarter_end_date,
  gross_taxable_inflow_zar,
  productivity_expenses_offset_zar,
  total_allowable_deductions_zar,
  GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) AS net_taxable_income_zar,
  0.2700 AS effective_tax_rate,
  ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) AS estimated_tax_liability_zar,
  actual_tax_paid_zar,
  ROUND(ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) - actual_tax_paid_zar, 4) AS net_tax_outstanding_zar,
  CASE
    WHEN actual_tax_paid_zar >= ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) 
         AND ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) > 0 
      THEN 'SETTLED'
    WHEN actual_tax_paid_zar > ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4)
      THEN 'CREDIT_SURPLUS'
    WHEN ROUND(GREATEST(0.0000, gross_taxable_inflow_zar - total_allowable_deductions_zar) * 0.2700, 4) = 0 
      THEN 'NO_TAX_LIABILITY'
    ELSE 'PAYMENT_PENDING'
  END AS tax_settlement_status,
  gross_taxable_inflow_usd,
  productivity_expenses_offset_usd,
  total_allowable_deductions_usd,
  GREATEST(0.0000, gross_taxable_inflow_usd - total_allowable_deductions_usd) AS net_taxable_income_usd,
  ROUND(GREATEST(0.0000, gross_taxable_inflow_usd - total_allowable_deductions_usd) * 0.2700, 4) AS estimated_tax_liability_usd,
  actual_tax_paid_usd,
  ROUND(ROUND(GREATEST(0.0000, gross_taxable_inflow_usd - total_allowable_deductions_usd) * 0.2700, 4) - actual_tax_paid_usd, 4) AS net_tax_outstanding_usd,
  tax_deductible_transaction_count
FROM quarterly_base;

-- 3.6 Tax-Deductible Expenses Audit
CREATE OR REPLACE VIEW `personal_finance.v_tax_deductible_expenses_audit` AS
SELECT
  t.transaction_date,
  t.transaction_id,
  t.merchant_or_payee,
  c.category_id,
  c.category_name,
  c.category_group,
  c.tax_line_item,
  t.original_amount,
  t.original_currency,
  t.reporting_amount_zar,
  t.reporting_amount_usd,
  COALESCE(t.tax_deductible_amount_zar, ABS(t.reporting_amount_zar)) AS tax_deductible_amount_zar,
  COALESCE(t.tax_deductible_amount_usd, ABS(t.reporting_amount_usd)) AS tax_deductible_amount_usd,
  t.tax_invoice_number,
  t.payment_method,
  t.notes,
  t.tags
FROM `personal_finance.fct_transactions` AS t
INNER JOIN `personal_finance.dim_categories` AS c
  ON t.category_id = c.category_id
WHERE (t.is_tax_deductible OR c.is_tax_deductible)
  AND t.transaction_type IN ('EXPENSE', 'ALLOCATION_TRANSFER');

-- =============================================================================
-- STEP 4: SEED SAMPLE DATA
-- =============================================================================

-- 4.1 Currencies
INSERT INTO `personal_finance.dim_currencies` (currency_code, currency_name, country_code, symbol, decimal_places, is_active, notes)
VALUES
  ('ZAR', 'South African Rand', 'ZA', 'R', 2, TRUE, 'Legal tender in South Africa and Common Monetary Area'),
  ('USD', 'United States Dollar', 'US', '$', 2, TRUE, 'Dominant currency for pricing and Nostro FCA accounts in Zimbabwe'),
  ('ZiG', 'Zimbabwe Gold', 'ZW', 'ZiG', 2, TRUE, 'Structured currency backed by gold and foreign reserves introduced April 2024'),
  ('ZWL', 'Zimbabwean Dollar (Historical)', 'ZW', 'ZWL$', 2, FALSE, 'Decommissioned predecessor to ZiG');

-- 4.2 Accounts
INSERT INTO `personal_finance.dim_accounts` (account_id, account_name, financial_institution, country_code, primary_currency, cash_flow_tier, account_type, is_vault_locked, withdrawal_notice_days, account_number_masked, is_active, created_at)
VALUES
  ('ACC_ZA_CAPITEC_DAILY', 'Capitec Primary Cheque', 'Capitec Bank', 'ZA', 'ZAR', 'DAILY_SPENDING', 'CHECKING', FALSE, 0, '...4091', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZA_FNB_MONTHLY', 'FNB Monthly Bills Fusion', 'First National Bank', 'ZA', 'ZAR', 'MONTHLY_ALLOCATION', 'CHECKING', FALSE, 0, '...8812', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZA_DISCOVERY_VAULT', 'Discovery 32-Day Notice Emergency', 'Discovery Bank', 'ZA', 'ZAR', 'LONG_TERM_VAULT', 'SAVINGS', TRUE, 32, '...1940', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZA_EE_EQUITIES_VAULT', 'EasyEquities S&P500 & Top40 TFSA', 'EasyEquities', 'ZA', 'ZAR', 'LONG_TERM_VAULT', 'INVESTMENT_BROKER', TRUE, 999, '...EE77', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_STANBIC_NOSTRO', 'Stanbic Nostro FCA Bills', 'Stanbic Bank Zimbabwe', 'ZW', 'USD', 'MONTHLY_ALLOCATION', 'CHECKING', FALSE, 0, '...5521', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_ECOCASH_USD', 'EcoCash USD Wallet', 'EcoCash', 'ZW', 'USD', 'DAILY_SPENDING', 'MOBILE_MONEY', FALSE, 0, '...0772', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_ECOCASH_ZIG', 'EcoCash ZiG Wallet', 'EcoCash', 'ZW', 'ZiG', 'DAILY_SPENDING', 'MOBILE_MONEY', FALSE, 0, '...0772', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_INNBUCKS_USD', 'InnBucks USD Pocket', 'InnBucks Microfinance', 'ZW', 'USD', 'DAILY_SPENDING', 'MOBILE_MONEY', FALSE, 0, '...4311', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC'),
  ('ACC_ZW_OM_UNITTRUST_VAULT', 'Old Mutual USD Balanced Unit Trust', 'Old Mutual Zimbabwe', 'ZW', 'USD', 'LONG_TERM_VAULT', 'INVESTMENT_BROKER', TRUE, 14, '...OM09', TRUE, TIMESTAMP '2026-01-01 00:00:00 UTC');

-- 4.3 Categories
INSERT INTO `personal_finance.dim_categories` (category_id, category_name, parent_category_id, category_group, cash_flow_tier, is_essential_need, description)
VALUES
  ('CAT_INC_SALARY', 'Consulting & Employment Income', NULL, 'INCOME', 'MONTHLY_ALLOCATION', FALSE, 'Primary monthly consulting retainer and professional earnings'),
  ('CAT_INC_DIVIDENDS', 'Investment Dividends', NULL, 'INCOME', 'LONG_TERM_VAULT', FALSE, 'Quarterly dividends received on ETF holdings'),
  ('CAT_DAILY_GROCERIES', 'Groceries & Household Supplies', NULL, 'LIVING_EXPENSES', 'DAILY_SPENDING', TRUE, 'Supermarket food and household consumables'),
  ('CAT_DAILY_DINING', 'Restaurants, Takeaways & Coffee', NULL, 'DISCRETIONARY', 'DAILY_SPENDING', FALSE, 'Eating out, fast food, and barista coffee'),
  ('CAT_DAILY_FUEL_TRANS', 'Fuel, Uber & Commute', NULL, 'LIVING_EXPENSES', 'DAILY_SPENDING', TRUE, 'Petrol purchases, Uber rides, and local travel'),
  ('CAT_DAILY_AIRTIME', 'Mobile Airtime & Bundles', NULL, 'LIVING_EXPENSES', 'DAILY_SPENDING', TRUE, 'Data bundles and voice airtime'),
  ('CAT_DAILY_INCIDENTAL', 'Micro-Cash & Incidentals', NULL, 'DISCRETIONARY', 'DAILY_SPENDING', FALSE, 'Car guard tips, cash petty expenses, minor purchases'),
  ('CAT_ALLOC_RENT', 'Residential Rent & Levies', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, 'Monthly apartment or home rental payment'),
  ('CAT_ALLOC_MEDICAL', 'Medical Aid Scheme', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, 'Discovery Health / Cimas healthcare contribution'),
  ('CAT_ALLOC_ELECTRICITY', 'Pre-paid Power & Utility Tokens', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, 'Eskom power vouchers and ZESA prepaid electricity tokens'),
  ('CAT_ALLOC_INTERNET', 'High-Speed Home Fibre', NULL, 'LIVING_EXPENSES', 'MONTHLY_ALLOCATION', TRUE, 'Uncapped home fibre broadband connectivity'),
  ('CAT_ALLOC_INSURANCE', 'Short-Term Vehicle & Asset Cover', NULL, 'DEBT_OBLIGATIONS', 'MONTHLY_ALLOCATION', TRUE, 'Car and contents insurance premium'),
  ('CAT_ALLOC_SUBSCRIPTIONS', 'Digital Subscriptions', NULL, 'DISCRETIONARY', 'MONTHLY_ALLOCATION', FALSE, 'Streaming media (Netflix, Spotify)'),
  ('CAT_VAULT_EMERGENCY', 'Liquid Emergency Reserve Fund', NULL, 'VAULT_INVESTMENTS', 'LONG_TERM_VAULT', TRUE, 'Capital held for unforeseen emergencies'),
  ('CAT_VAULT_GLOBAL_ETF', 'Offshore S&P 500 Index Equities', NULL, 'VAULT_INVESTMENTS', 'LONG_TERM_VAULT', FALSE, 'Compounding long-term retirement capital'),
  ('CAT_INTERNAL_SWEEP', 'Cross-Tier Capital Allocation Transfer', NULL, 'INTERNAL_TRANSFERS', 'CROSS_TIER_TRANSFER', FALSE, 'Transfer legs moving money between tiers');

-- 4.4 Exchange Rates
INSERT INTO `personal_finance.fct_exchange_rates` (rate_date, rate_timestamp, base_currency, quote_currency, rate_type, exchange_rate, inverse_rate, source_provider, notes)
VALUES
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZAR', 'OFFICIAL_INTERBANK', 18.250000, 0.054795, 'SARB', 'South African Reserve Bank mid-market rate'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZAR', 'CARD_SETTLEMENT', 18.615000, 0.053720, 'Visa / MasterCard', 'Retail card rate with 2% margin'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZiG', 'OFFICIAL_INTERBANK', 13.850000, 0.072202, 'Reserve Bank of Zimbabwe', 'Official interbank weighted exchange rate'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'USD', 'ZiG', 'MARKET_PARALLEL', 24.500000, 0.040816, 'ZimMarket Index', 'Alternative street cash rate'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'ZAR', 'ZiG', 'OFFICIAL_INTERBANK', 0.758900, 1.317697, 'RBZ Cross Rate', 'Cross rate calculated via official USD mid-point'),
  (DATE '2026-09-01', TIMESTAMP '2026-09-01 07:00:00 UTC', 'ZAR', 'ZiG', 'MARKET_PARALLEL', 1.342466, 0.744900, 'ZimMarket Index', 'Border cash trading rate at Beitbridge');

-- 4.5 Budget Allocations
INSERT INTO `personal_finance.fct_budget_allocations` (allocation_month, category_id, cash_flow_tier, target_currency, planned_amount, planned_amount_usd, planned_amount_zar, rollover_from_prior, is_fixed_obligation, notes)
VALUES
  (DATE '2026-09-01', 'CAT_ALLOC_RENT', 'MONTHLY_ALLOCATION', 'ZAR', 14500.0000, 794.5205, 14500.0000, 0.0000, TRUE, 'Apartment lease debit order'),
  (DATE '2026-09-01', 'CAT_ALLOC_MEDICAL', 'MONTHLY_ALLOCATION', 'ZAR', 3850.0000, 210.9589, 3850.0000, 0.0000, TRUE, 'Discovery Classic Comprehensive Plan'),
  (DATE '2026-09-01', 'CAT_ALLOC_ELECTRICITY', 'MONTHLY_ALLOCATION', 'ZAR', 1800.0000, 98.6301, 1800.0000, 150.0000, TRUE, 'Eskom prepaid electricity envelope'),
  (DATE '2026-09-01', 'CAT_ALLOC_INTERNET', 'MONTHLY_ALLOCATION', 'ZAR', 999.0000, 54.7397, 999.0000, 0.0000, TRUE, 'Openserve 100/50 Fibre debit order'),
  (DATE '2026-09-01', 'CAT_ALLOC_INSURANCE', 'MONTHLY_ALLOCATION', 'ZAR', 1250.0000, 68.4932, 1250.0000, 0.0000, TRUE, 'Outsurance Comprehensive vehicle cover'),
  (DATE '2026-09-01', 'CAT_ALLOC_SUBSCRIPTIONS', 'MONTHLY_ALLOCATION', 'ZAR', 550.0000, 30.1370, 550.0000, 0.0000, FALSE, 'Netflix & Spotify family plans'),
  (DATE '2026-09-01', 'CAT_ALLOC_ELECTRICITY', 'MONTHLY_ALLOCATION', 'USD', 120.0000, 120.0000, 2190.0000, 20.0000, TRUE, 'ZESA token purchase via Nostro card'),
  (DATE '2026-09-01', 'CAT_DAILY_GROCERIES', 'DAILY_SPENDING', 'ZAR', 6500.0000, 356.1644, 6500.0000, 450.0000, FALSE, 'Woolworths / Checkers grocery envelope'),
  (DATE '2026-09-01', 'CAT_DAILY_DINING', 'DAILY_SPENDING', 'ZAR', 2500.0000, 136.9863, 2500.0000, 0.0000, FALSE, 'Social dining and takeaways'),
  (DATE '2026-09-01', 'CAT_DAILY_FUEL_TRANS', 'DAILY_SPENDING', 'ZAR', 3000.0000, 164.3836, 3000.0000, 0.0000, FALSE, 'Petrol allowance'),
  (DATE '2026-09-01', 'CAT_DAILY_AIRTIME', 'DAILY_SPENDING', 'USD', 50.0000, 50.0000, 912.5000, 0.0000, FALSE, 'EcoCash data bundles'),
  (DATE '2026-09-01', 'CAT_VAULT_GLOBAL_ETF', 'LONG_TERM_VAULT', 'ZAR', 8000.0000, 438.3562, 8000.0000, 0.0000, FALSE, 'Target monthly transfer into EasyEquities S&P500'),
  (DATE '2026-09-01', 'CAT_VAULT_EMERGENCY', 'LONG_TERM_VAULT', 'ZAR', 3000.0000, 164.3836, 3000.0000, 0.0000, FALSE, 'Target top-up for 32-day emergency runway');

-- 4.6 Transactions Ledger
INSERT INTO `personal_finance.fct_transactions` (
  transaction_id, transaction_timestamp, transaction_date, local_timezone, local_timestamp, settlement_timestamp,
  account_id, cash_flow_tier, category_id, transaction_type,
  original_amount, original_currency, reporting_amount_usd, reporting_amount_zar,
  applied_exchange_rate_usd, applied_exchange_rate_zar, rate_type_applied,
  transfer_counterpart_id, merchant_or_payee, payment_method, statutory_levy_or_fee, notes, tags, metadata
)
VALUES
  (
    'TX_ZA_20260901_001', TIMESTAMP '2026-09-01 06:15:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 08:15:00', TIMESTAMP '2026-09-01 06:15:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_INC_SALARY', 'INCOME',
    55000.0000, 'ZAR', 3013.6986, 55000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Apex Consulting Client Pty Ltd', 'EFT', NULL, 'Monthly tech consulting retainer fee', ['income', 'salary'], JSON '{"client_ref": "INV-2026-089"}'
  ),
  (
    'TX_ZA_20260901_SWEEP_OUT', TIMESTAMP '2026-09-01 07:00:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:00:00', TIMESTAMP '2026-09-01 07:00:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_INTERNAL_SWEEP', 'INTERNAL_TRANSFER',
    -12000.0000, 'ZAR', -657.5342, -12000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_SWEEP_IN', 'Capitec Daily Account', 'EFT', 2.5000, 'Monthly operational allowance transfer to Daily Checking', ['transfer', 'daily-allowance'], JSON '{"eft_type": "RTC_PAYSHAP"}'
  ),
  (
    'TX_ZA_20260901_SWEEP_IN', TIMESTAMP '2026-09-01 07:01:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:01:00', TIMESTAMP '2026-09-01 07:01:00 UTC',
    'ACC_ZA_CAPITEC_DAILY', 'DAILY_SPENDING', 'CAT_INTERNAL_SWEEP', 'INTERNAL_TRANSFER',
    12000.0000, 'ZAR', 657.5342, 12000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_SWEEP_OUT', 'FNB Monthly Account', 'EFT', NULL, 'Monthly operational allowance received', ['transfer', 'daily-allowance'], JSON '{"received_channel": "PAYSHAP"}'
  ),
  (
    'TX_ZA_20260901_VAULT_OUT', TIMESTAMP '2026-09-01 07:30:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:30:00', TIMESTAMP '2026-09-01 07:30:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_INTERNAL_SWEEP', 'VAULT_CONTRIBUTION',
    -8000.0000, 'ZAR', -438.3562, -8000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_VAULT_IN', 'EasyEquities Brokerage Vault', 'EFT', NULL, 'Vault contribution towards S&P500 ETF', ['vault', 'investments'], JSON '{"beneficiary_ref": "EE-INVEST-77"}'
  ),
  (
    'TX_ZA_20260901_VAULT_IN', TIMESTAMP '2026-09-01 07:35:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 09:35:00', TIMESTAMP '2026-09-01 07:35:00 UTC',
    'ACC_ZA_EE_EQUITIES_VAULT', 'LONG_TERM_VAULT', 'CAT_VAULT_GLOBAL_ETF', 'VAULT_CONTRIBUTION',
    8000.0000, 'ZAR', 438.3562, 8000.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    'TX_ZA_20260901_VAULT_OUT', 'FNB Monthly Transfer', 'EFT', NULL, 'Long-term equity vault deposit: 10x 1nvest S&P500 Info Tech ETF units', ['vault', 'investments'], JSON '{"units_purchased": 10.45}'
  ),
  (
    'TX_ZA_20260901_RENT', TIMESTAMP '2026-09-01 08:00:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 10:00:00', TIMESTAMP '2026-09-01 08:00:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_ALLOC_RENT', 'EXPENSE',
    -14500.0000, 'ZAR', -794.5205, -14500.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Trafalgar Property Management', 'DIRECT_DEBIT', NULL, 'Cape Town Apartment Rental September 2026', ['fixed-bill', 'rent'], JSON '{"unit": "Apt 402"}'
  ),
  (
    'TX_ZA_20260901_MED', TIMESTAMP '2026-09-01 08:05:00 UTC', DATE '2026-09-01', 'Africa/Johannesburg', DATETIME '2026-09-01 10:05:00', TIMESTAMP '2026-09-01 08:05:00 UTC',
    'ACC_ZA_FNB_MONTHLY', 'MONTHLY_ALLOCATION', 'CAT_ALLOC_MEDICAL', 'EXPENSE',
    -3850.0000, 'ZAR', -210.9589, -3850.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Discovery Health Scheme', 'DIRECT_DEBIT', NULL, 'Monthly medical aid premium debit', ['medical', 'fixed-bill'], JSON '{"membership_no": "99281726"}'
  ),
  (
    'TX_ZA_20260902_001', TIMESTAMP '2026-09-02 11:30:00 UTC', DATE '2026-09-02', 'Africa/Johannesburg', DATETIME '2026-09-02 13:30:00', TIMESTAMP '2026-09-02 11:30:00 UTC',
    'ACC_ZA_CAPITEC_DAILY', 'DAILY_SPENDING', 'CAT_DAILY_GROCERIES', 'EXPENSE',
    -845.5000, 'ZAR', -46.3288, -845.5000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Woolworths Food Gardens Centre', 'DEBIT_CARD', NULL, 'Weekly organic groceries and essentials', ['groceries', 'food'], JSON '{"pos_terminal": "W-GARDENS-04"}'
  ),
  (
    'TX_ZA_20260902_002', TIMESTAMP '2026-09-02 13:45:00 UTC', DATE '2026-09-02', 'Africa/Johannesburg', DATETIME '2026-09-02 15:45:00', TIMESTAMP '2026-09-02 13:45:00 UTC',
    'ACC_ZA_CAPITEC_DAILY', 'DAILY_SPENDING', 'CAT_DAILY_DINING', 'EXPENSE',
    -78.0000, 'ZAR', -4.2740, -78.0000, 0.054795, 1.000000, 'OFFICIAL_INTERBANK',
    NULL, 'Vida e Caffe Kloof St', 'DEBIT_CARD', NULL, 'Cappuccino and croissant', ['coffee', 'discretionary'], NULL
  ),
  (
    'TX_ZW_20260902_001', TIMESTAMP '2026-09-02 14:10:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 16:10:00', TIMESTAMP '2026-09-02 14:10:00 UTC',
    'ACC_ZW_ECOCASH_USD', 'DAILY_SPENDING', 'CAT_DAILY_GROCERIES', 'EXPENSE',
    -62.4000, 'USD', -62.4000, -1138.8000, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'OK Mart Chitungwiza Junction', 'MOBILE_MONEY_ECOCASH', 1.2500, 'Bulk pantry groceries in Harare', ['groceries', 'zimbabwe'], JSON '{"ecocash_ref": "MP260902.1610.B91823", "merchant_code": "29100"}'
  ),
  (
    'TX_ZW_20260902_002', TIMESTAMP '2026-09-02 16:20:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 18:20:00', TIMESTAMP '2026-09-02 16:20:00 UTC',
    'ACC_ZW_INNBUCKS_USD', 'DAILY_SPENDING', 'CAT_DAILY_DINING', 'EXPENSE',
    -9.5000, 'USD', -9.5000, -173.3750, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'Simbisa Bakers Inn First St', 'MOBILE_MONEY_INNBUCKS', NULL, 'Family meat pies and juices', ['dining', 'fast-food'], JSON '{"innbucks_qr_auth": "IB-8827-01"}'
  ),
  (
    'TX_ZW_20260902_003', TIMESTAMP '2026-09-02 17:00:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 19:00:00', TIMESTAMP '2026-09-02 17:00:00 UTC',
    'ACC_ZW_ECOCASH_ZIG', 'DAILY_SPENDING', 'CAT_DAILY_AIRTIME', 'EXPENSE',
    -245.0000, 'ZiG', -10.0000, -182.5000, 0.040816, 0.744898, 'MARKET_PARALLEL',
    NULL, 'Econet Wireless Zimbabwe', 'MOBILE_MONEY_ECOCASH', 4.9000, 'Monthly 15GB SmartBiz WhatsApp and data bundle', ['data', 'airtime'], JSON '{"bundle_type": "SmartBiz_Weekly"}'
  ),
  (
    'TX_ZW_20260902_004', TIMESTAMP '2026-09-02 18:00:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 20:00:00', TIMESTAMP '2026-09-02 18:00:00 UTC',
    'ACC_ZW_STANBIC_NOSTRO', 'MONTHLY_ALLOCATION', 'CAT_ALLOC_ELECTRICITY', 'EXPENSE',
    -100.0000, 'USD', -100.0000, -1825.0000, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'ZETDC / ZESA Power Distribution', 'DEBIT_CARD', 2.0000, 'Prepaid power token 350 kWh for Harare residence', ['utilities', 'electricity'], JSON '{"token": "4920-1928-3819-4829-1029", "kwh": 350.2}'
  ),
  (
    'TX_ZW_20260902_005', TIMESTAMP '2026-09-02 18:30:00 UTC', DATE '2026-09-02', 'Africa/Harare', DATETIME '2026-09-02 20:30:00', TIMESTAMP '2026-09-02 18:30:00 UTC',
    'ACC_ZW_OM_UNITTRUST_VAULT', 'LONG_TERM_VAULT', 'CAT_VAULT_GLOBAL_ETF', 'VAULT_CONTRIBUTION',
    250.0000, 'USD', 250.0000, 4562.5000, 1.000000, 18.250000, 'OFFICIAL_INTERBANK',
    NULL, 'Old Mutual Unit Trust Allocation', 'EFT', NULL, 'Offshore balanced fund accumulation deposit', ['vault', 'investments'], JSON '{"nav_per_unit": 1.452, "units_added": 172.17}'
  );
