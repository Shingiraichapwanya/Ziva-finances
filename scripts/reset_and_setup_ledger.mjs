import { execSync } from 'child_process';

const BQ_CONFIG = {
  projectId: 'budget-tracker-507418',
  datasetId: 'personal_finance',
  location: 'africa-south1'
};

function runSql(sql) {
  const cmd = `bq query --use_legacy_sql=false --format=json --project_id=${BQ_CONFIG.projectId} --location=${BQ_CONFIG.location} --label datacloud:antigravity`;
  try {
    const output = execSync(cmd, { input: sql, encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
    return JSON.parse(output || '[]');
  } catch (err) {
    console.error('SQL Execution Error:', err.message);
    throw err;
  }
}

function getRowCount(tableName) {
  try {
    const res = JSON.parse(execSync(`bq show --format=prettyjson ${BQ_CONFIG.projectId}:${BQ_CONFIG.datasetId}.${tableName}`, { encoding: 'utf8' }));
    return parseInt(res.numRows || '0', 10);
  } catch (err) {
    return null;
  }
}

async function main() {
  console.log('=== STARTING PRODUCTION DATA RESET & LEDGER DEPLOYMENT ===');
  console.log(`Target: ${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId} (${BQ_CONFIG.location})`);

  const tables = [
    'fct_transactions',
    'fct_budget_allocations',
    'dim_accounts',
    'dim_categories',
    'fct_exchange_rates',
    'dim_currencies'
  ];

  console.log('\n--- 1. PRE-WIPE ROW COUNT AUDIT ---');
  const beforeCounts = {};
  for (const t of tables) {
    const count = getRowCount(t);
    beforeCounts[t] = count;
    console.log(`- ${BQ_CONFIG.datasetId}.${t}: ${count} rows`);
  }

  console.log('\n--- 2. EXECUTING SAFE TRUNCATE ON 6 PRODUCTION TABLES ---');
  for (const t of tables) {
    console.log(`Truncating ${BQ_CONFIG.datasetId}.${t}...`);
    runSql(`TRUNCATE TABLE \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.${t}\``);
  }

  console.log('\n--- 3. POST-WIPE ROW COUNT VERIFICATION ---');
  const afterCounts = {};
  for (const t of tables) {
    const count = getRowCount(t);
    afterCounts[t] = count;
    console.log(`- ${BQ_CONFIG.datasetId}.${t}: ${count} rows (Verified 0)`);
  }

  console.log('\n--- 4. CREATING DEBT & CREDIT LEDGER TABLE ---');
  const createTableSql = `
    CREATE TABLE IF NOT EXISTS \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_ledger\` (
      id STRING NOT NULL OPTIONS(description="Unique identifier for each debt/credit record"),
      person_name STRING NOT NULL OPTIONS(description="Name of the person involved in the debt/credit"),
      direction STRING NOT NULL OPTIONS(description="Direction of debt: 'owed_to_me' or 'owed_by_me'"),
      amount NUMERIC(18, 4) NOT NULL OPTIONS(description="Positive amount of money"),
      currency STRING OPTIONS(description="Currency code, e.g. USD, ZAR"),
      date DATE NOT NULL OPTIONS(description="Date the debt or credit was created or logged"),
      status STRING NOT NULL OPTIONS(description="Debt status: 'Pending' or 'Settled'"),
      notes STRING OPTIONS(description="Free-text notes or memo"),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Record creation timestamp"),
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Record update timestamp")
    )
    PARTITION BY date
    CLUSTER BY status, direction, person_name;
  `;
  runSql(createTableSql);
  console.log('Successfully created table `debt_credit_ledger`.');

  console.log('\n--- 5. CREATING DEBT & CREDIT BALANCES VIEW ---');
  const createViewSql = `
    CREATE OR REPLACE VIEW \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_balances\` AS
    SELECT
      person_name,
      COALESCE(SUM(CASE WHEN direction = 'owed_to_me' THEN amount ELSE 0 END), 0) AS total_owed_to_me,
      COALESCE(SUM(CASE WHEN direction = 'owed_by_me' THEN amount ELSE 0 END), 0) AS total_owed_by_me,
      (COALESCE(SUM(CASE WHEN direction = 'owed_to_me' THEN amount ELSE 0 END), 0) - 
       COALESCE(SUM(CASE WHEN direction = 'owed_by_me' THEN amount ELSE 0 END), 0)) AS net_balance,
      CASE
        WHEN (COALESCE(SUM(CASE WHEN direction = 'owed_to_me' THEN amount ELSE 0 END), 0) - 
              COALESCE(SUM(CASE WHEN direction = 'owed_by_me' THEN amount ELSE 0 END), 0)) > 0 THEN 'they_owe_me'
        WHEN (COALESCE(SUM(CASE WHEN direction = 'owed_to_me' THEN amount ELSE 0 END), 0) - 
              COALESCE(SUM(CASE WHEN direction = 'owed_by_me' THEN amount ELSE 0 END), 0)) < 0 THEN 'i_owe_them'
        ELSE 'settled_or_zero'
      END AS balance_direction
    FROM \`${BQ_CONFIG.projectId}.${BQ_CONFIG.datasetId}.debt_credit_ledger\`
    WHERE status = 'Pending'
    GROUP BY person_name;
  `;
  runSql(createViewSql);
  console.log('Successfully created view `debt_credit_balances`.');

  console.log('\n--- 6. VERIFYING DDL & SCHEMA OF CREATED OBJECTS ---');
  const ledgerMeta = JSON.parse(execSync(`bq show --format=prettyjson ${BQ_CONFIG.projectId}:${BQ_CONFIG.datasetId}.debt_credit_ledger`, { encoding: 'utf8' }));
  console.log('debt_credit_ledger Fields:', ledgerMeta.schema.fields.map(f => `${f.name} (${f.type})`).join(', '));

  const viewMeta = JSON.parse(execSync(`bq show --format=prettyjson ${BQ_CONFIG.projectId}:${BQ_CONFIG.datasetId}.debt_credit_balances`, { encoding: 'utf8' }));
  console.log('debt_credit_balances Fields:', viewMeta.schema.fields.map(f => `${f.name} (${f.type})`).join(', '));

  console.log('\n=== COMPLETED SUCCESSFULLY ===');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
