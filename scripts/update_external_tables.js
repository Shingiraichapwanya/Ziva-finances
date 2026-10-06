/**
 * scripts/update_external_tables.js
 * 
 * Script to update BigQuery external tables (fct_transactions & debt_credit_ledger)
 * to point to a new Google Spreadsheet ID.
 * 
 * Usage:
 *   node scripts/update_external_tables.js [SPREADSHEET_ID]
 * 
 * If SPREADSHEET_ID is omitted, it reads from GOOGLE_SHEETS_SPREADSHEET_ID or SPREADSHEET_ID env var.
 */

const path = require('path');
const fs = require('fs');

// Attempt to load .env if present
try {
  const dotenv = require('dotenv');
  dotenv.config({ path: path.resolve(__dirname, '../backend/.env') });
} catch (_) {}

const {
  BQ_CONFIG,
  SHEETS_CONFIG,
  ensureExternalTablesConfigured,
  verifyBigQueryConnectivity
} = require('../backend/src/bigquery');

async function main() {
  const targetSpreadsheetId = process.argv[2] || process.env.GOOGLE_SHEETS_SPREADSHEET_ID || process.env.SPREADSHEET_ID || SHEETS_CONFIG.spreadsheetId;

  if (!targetSpreadsheetId) {
    console.error('❌ Error: No spreadsheet ID provided.');
    console.error('Usage: node scripts/update_external_tables.js <SPREADSHEET_ID>');
    process.exit(1);
  }

  console.log('===============================================================');
  console.log(' ZIVA FINANCE: UPDATE BIGQUERY EXTERNAL TABLES');
  console.log('===============================================================');
  console.log(`• GCP Project ID:    ${BQ_CONFIG.projectId}`);
  console.log(`• BigQuery Dataset:  ${BQ_CONFIG.datasetId} (${BQ_CONFIG.location})`);
  console.log(`• Spreadsheet ID:    ${targetSpreadsheetId}`);
  console.log(`• Spreadsheet URI:   https://docs.google.com/spreadsheets/d/${targetSpreadsheetId}`);
  console.log('---------------------------------------------------------------');

  console.log('1. Checking BigQuery connectivity...');
  const conn = await verifyBigQueryConnectivity({ forceCheck: true });
  if (!conn.connected) {
    console.warn(`⚠️ Warning: BigQuery connectivity probe returned not connected (${conn.status}). Proceeding with DDL execution attempt...`);
  } else {
    console.log(`✅ Connected using mode: ${conn.authMode}`);
  }

  console.log(`\n2. Updating external table definitions in BigQuery...`);
  try {
    const result = await ensureExternalTablesConfigured(targetSpreadsheetId);
    console.log('✅ Success! BigQuery external tables updated:');
    result.configuredTables.forEach(tbl => {
      console.log(`   - ${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.${tbl} -> https://docs.google.com/spreadsheets/d/${targetSpreadsheetId}`);
    });
    console.log('\n===============================================================');
    console.log(' UPDATE COMPLETE: Dashboard can now query the new spreadsheet');
    console.log('===============================================================');
  } catch (err) {
    console.error('❌ Failed to update BigQuery external tables:', err.message);
    if (err.errors) {
      console.error('Details:', JSON.stringify(err.errors, null, 2));
    }
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
