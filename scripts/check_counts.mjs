import { execSync } from 'child_process';
import fs from 'fs';

const BQ_CONFIG = {
  projectId: 'budget-tracker-507418',
  datasetId: 'personal_finance',
  location: 'africa-south1'
};

function runQuery(sql) {
  const cmd = `bq query --use_legacy_sql=false --format=json --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --label datacloud:antigravity`;
  const output = execSync(cmd, { input: sql, encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
  return JSON.parse(output || '[]');
}

const tables = [
  'debt_credit_ledger',
  'fct_transactions',
  'fct_budget_allocations',
  'dim_accounts',
  'dim_categories',
  'fct_exchange_rates',
  'dim_currencies'
];

console.log('=== CHECKING CURRENT ROW COUNTS VIA SELECT COUNT(*) ===');
for (const t of tables) {
  try {
    const res = runQuery(`SELECT COUNT(1) as cnt FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.${t}\``);
    console.log(`${t}: ${res[0].cnt} rows`);
  } catch (err) {
    console.error(`Error querying ${t}:`, err.message);
  }
}
