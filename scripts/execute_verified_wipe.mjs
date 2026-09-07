import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const BQ_CONFIG = {
  projectId: 'budget-tracker-507418',
  datasetId: 'personal_finance',
  location: 'africa-south1'
};

const tables = [
  'debt_credit_ledger',
  'fct_transactions',
  'fct_budget_allocations',
  'dim_accounts',
  'dim_categories',
  'fct_exchange_rates',
  'dim_currencies'
];

function runQuery(sql) {
  const cmd = `bq query --use_legacy_sql=false --format=json --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --label datacloud:antigravity`;
  const output = execSync(cmd, { input: sql, encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
  return JSON.parse(output || '[]');
}

function getCount(tableName) {
  const res = runQuery(`SELECT COUNT(1) as cnt FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.${tableName}\``);
  return parseInt(res[0].cnt, 10);
}

function wipeTable(tableName) {
  const tableRef = `${BQ_CONFIG.projectId}:${BQ_CONFIG.datasetId}.${tableName}`;
  // 1. Fetch metadata & schema
  const metaJson = execSync(`bq show --format=prettyjson ${tableRef}`, { encoding: 'utf8' });
  const meta = JSON.parse(metaJson);
  const tempSchema = path.join(__dirname, `temp_${tableName}_schema.json`);
  fs.writeFileSync(tempSchema, JSON.stringify(meta.schema.fields, null, 2), 'utf8');

  // 2. Remove table
  execSync(`bq rm -f -t ${tableRef}`, { encoding: 'utf8' });

  // 3. Recreate table empty with identical schema, partition, and clustering
  let mkCmd = `bq mk --table --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location}`;
  if (meta.timePartitioning) {
    mkCmd += ` --time_partitioning_type=${meta.timePartitioning.type || 'DAY'}`;
    if (meta.timePartitioning.field) mkCmd += ` --time_partitioning_field=${meta.timePartitioning.field}`;
    if (meta.timePartitioning.expirationMs) mkCmd += ` --time_partitioning_expiration=${Math.round(parseInt(meta.timePartitioning.expirationMs, 10) / 1000)}`;
  }
  if (meta.clustering && meta.clustering.fields && meta.clustering.fields.length > 0) {
    mkCmd += ` --clustering_fields=${meta.clustering.fields.join(',')}`;
  }
  mkCmd += ` ${tableRef} "${tempSchema}"`;
  execSync(mkCmd, { encoding: 'utf8' });

  if (fs.existsSync(tempSchema)) fs.unlinkSync(tempSchema);
}

async function main() {
  const results = {
    environment: "PRODUCTION",
    tables_checked: [],
    overall_wipe_status: "SUCCESS"
  };

  for (const tableName of tables) {
    let rowsBefore = null;
    let rowsAfter = null;
    let status = "FAILED";

    try {
      rowsBefore = getCount(tableName);
      if (rowsBefore > 0) {
        wipeTable(tableName);
      }
      rowsAfter = getCount(tableName);
      status = rowsAfter === 0 ? "SUCCESS" : "FAILED";
    } catch (err) {
      console.error(`Error wiping ${tableName}:`, err.message);
      status = "FAILED";
    }

    if (status === "FAILED") {
      results.overall_wipe_status = "FAILED";
    }

    results.tables_checked.push({
      table_name: tableName,
      rows_before: rowsBefore,
      rows_after: rowsAfter,
      wipe_status: status
    });
  }

  console.log('\n--- FINAL WIPE JSON OUTPUT ---');
  console.log(JSON.stringify(results, null, 2));
}

main().catch(err => {
  console.error("Fatal error during wipe execution:", err);
  process.exit(1);
});
