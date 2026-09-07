const { execSync } = require('child_process');
const fs = require('fs');

const sqlFile = process.argv[2];
if (!sqlFile) {
  console.error('Usage: node run_bq.cjs <sql-file>');
  process.exit(1);
}

let sql = fs.readFileSync(sqlFile, 'utf8');
if (sql.charCodeAt(0) === 0xFEFF) {
  sql = sql.slice(1);
}

const cmd = 'bq query --use_legacy_sql=false --project_id=budget-tracker-507418 --location=africa-south1 --label datacloud:antigravity';
try {
  const out = execSync(cmd, { input: sql, encoding: 'utf8' });
  console.log(out);
} catch (err) {
  console.error(err.stdout || err.stderr || err.message);
  process.exit(1);
}
