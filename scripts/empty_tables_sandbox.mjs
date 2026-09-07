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
  'fct_transactions',
  'fct_budget_allocations',
  'dim_accounts',
  'dim_categories',
  'fct_exchange_rates',
  'dim_currencies'
];

const schemaDir = path.join(__dirname, '../scratch/schemas');
if (!fs.existsSync(schemaDir)) {
  fs.mkdirSync(schemaDir, { recursive: true });
}

console.log('=== SAFELY RESETTING PRODUCTION TABLES IN BIGQUERY SANDBOX ===\n');

for (const tableName of tables) {
  const tableRef = `${BQ_CONFIG.projectId}:${BQ_CONFIG.datasetId}.${tableName}`;
  console.log(`Processing table: ${tableRef}...`);

  // 1. Fetch metadata
  const metaJson = execSync(`bq show --format=prettyjson ${tableRef}`, { encoding: 'utf8' });
  const meta = JSON.parse(metaJson);
  const rowCountBefore = parseInt(meta.numRows || '0', 10);
  console.log(`  - Existing row count: ${rowCountBefore}`);

  // 2. Save schema JSON
  const schemaPath = path.join(schemaDir, `${tableName}.schema.json`);
  fs.writeFileSync(schemaPath, JSON.stringify(meta.schema.fields, null, 2), 'utf8');

  // 3. Drop table
  console.log(`  - Removing table ${tableName}...`);
  execSync(`bq rm -f -t ${tableRef}`, { encoding: 'utf8' });

  // 4. Recreate table with exact schema, partitioning, and clustering
  console.log(`  - Recreating table ${tableName} with identical schema & configurations...`);
  let mkCmd = `bq mk --table --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location}`;

  if (meta.timePartitioning) {
    mkCmd += ` --time_partitioning_type=${meta.timePartitioning.type || 'DAY'}`;
    if (meta.timePartitioning.field) {
      mkCmd += ` --time_partitioning_field=${meta.timePartitioning.field}`;
    }
    if (meta.timePartitioning.expirationMs) {
      mkCmd += ` --time_partitioning_expiration=${Math.round(parseInt(meta.timePartitioning.expirationMs, 10) / 1000)}`;
    }
  }

  if (meta.clustering && meta.clustering.fields && meta.clustering.fields.length > 0) {
    mkCmd += ` --clustering_fields=${meta.clustering.fields.join(',')}`;
  }

  mkCmd += ` ${tableRef} "${schemaPath}"`;
  execSync(mkCmd, { encoding: 'utf8' });

  // 5. Verify row count is 0
  const verifyJson = execSync(`bq show --format=prettyjson ${tableRef}`, { encoding: 'utf8' });
  const verifyMeta = JSON.parse(verifyJson);
  const rowCountAfter = parseInt(verifyMeta.numRows || '0', 10);
  console.log(`  - Verified row count: ${rowCountAfter} (Schema preserved, rows reset to 0)\n`);
}

console.log('=== ALL 6 PRODUCTION TABLES RESET TO ZERO ROWS SUCCESSFULLY ===');
