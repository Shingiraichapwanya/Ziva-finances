const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const app = require('../src/server');
const sheetsRepo = require('../services/googleSheetsRepository');

test('Express API Endpoints with Google Sheets Live Data Layer', async (t) => {
  t.beforeEach(() => {
    sheetsRepo.setMockStorage(sheetsRepo.createDefaultMockStorage());
  });

  let server;
  let baseUrl;

  // Start temporary server on dynamic port
  await new Promise((resolve) => {
    server = http.createServer(app);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      baseUrl = `http://127.0.0.1:${port}`;
      resolve();
    });
  });

  t.after(() => {
    if (server) server.close();
  });

  await t.test('GET /api/health returns CONNECTED with GOOGLE_SHEETS_API layer', async () => {
    const res = await fetch(`${baseUrl}/api/health`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.status, 'ONLINE');
    assert.strictEqual(data.connected, true);
    assert.strictEqual(data.readMode, 'GOOGLE_SHEETS_API');
    assert.strictEqual(data.writeMode, 'GOOGLE_SHEETS_API');
  });

  await t.test('GET /api/sheets/config returns sheets configuration without BigQuery requirement', async () => {
    const res = await fetch(`${baseUrl}/api/sheets/config`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.readMode, 'GOOGLE_SHEETS_API');
    assert.strictEqual(data.writeMode, 'GOOGLE_SHEETS_API');
    assert.strictEqual(data.bigqueryBillingRequired, false);
    assert.ok(data.spreadsheetId);
  });

  await t.test('GET /api/test-query returns test transactions from Google Sheets', async () => {
    const res = await fetch(`${baseUrl}/api/test-query`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.status, 'SUCCESS');
    assert.strictEqual(data.source, 'GOOGLE_SHEETS_LIVE');
    assert.ok(data.result);
  });

  await t.test('GET /api/rates returns exchange rates', async () => {
    const res = await fetch(`${baseUrl}/api/rates`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(data.USD_TO_ZAR > 0);
  });

  await t.test('GET /api/accounts returns accounts array', async () => {
    const res = await fetch(`${baseUrl}/api/accounts`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data));
    assert.ok(data.length > 0);
  });

  await t.test('GET /api/transactions returns transactions', async () => {
    const res = await fetch(`${baseUrl}/api/transactions?limit=10`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data));
  });

  await t.test('POST /api/transactions creates transaction and DELETE removes it', async () => {
    const postRes = await fetch(`${baseUrl}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        description: 'Endpoint Integration Coffee',
        amount: 45.00,
        currency: 'ZAR',
        transactionType: 'EXPENSE',
        category: 'CAT_FOOD_DINING',
        accountId: 'ACC_ZA_CAPITEC_DAILY'
      })
    });
    assert.strictEqual(postRes.status, 200);
    const postData = await postRes.json();
    assert.strictEqual(postData.success, true);
    assert.ok(postData.transactionId);

    // Delete it
    const delRes = await fetch(`${baseUrl}/api/transactions/${postData.transactionId}`, {
      method: 'DELETE'
    });
    assert.strictEqual(delRes.status, 200);
    const delData = await delRes.json();
    assert.strictEqual(delData.success, true);
  });

  await t.test('Debt Ledger Endpoints: GET, POST, PATCH /settle, PATCH /reopen, DELETE', async () => {
    // 1. Create debt
    const postRes = await fetch(`${baseUrl}/api/debts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        personName: 'Rudo Mpofu',
        direction: 'owed_by_me',
        amount: 500.00,
        currency: 'ZAR',
        notes: 'Lunch reimbursement'
      })
    });
    assert.strictEqual(postRes.status, 200);
    const postData = await postRes.json();
    assert.strictEqual(postData.success, true);
    const debtId = postData.debtId;

    // 2. Fetch debts list
    const getRes = await fetch(`${baseUrl}/api/debts`);
    assert.strictEqual(getRes.status, 200);
    const debts = await getRes.json();
    assert.ok(debts.some((d) => d.id === debtId));

    // 3. Settle debt (the route that was failing with HTTP 500 on Render due to BQ 403)
    const settleRes = await fetch(`${baseUrl}/api/debts/${debtId}/settle`, {
      method: 'PATCH'
    });
    assert.strictEqual(settleRes.status, 200);
    const settleData = await settleRes.json();
    assert.strictEqual(settleData.success, true);
    assert.strictEqual(settleData.status, 'Settled');

    // 4. Repeated settle call (Idempotency check)
    const settleRes2 = await fetch(`${baseUrl}/api/debts/${debtId}/settle`, {
      method: 'PATCH'
    });
    assert.strictEqual(settleRes2.status, 200);
    const settleData2 = await settleRes2.json();
    assert.strictEqual(settleData2.success, true);
    assert.strictEqual(settleData2.alreadySettled, true);

    // 5. Reopen debt
    const reopenRes = await fetch(`${baseUrl}/api/debts/${debtId}/reopen`, {
      method: 'PATCH'
    });
    assert.strictEqual(reopenRes.status, 200);
    const reopenData = await reopenRes.json();
    assert.strictEqual(reopenData.success, true);
    assert.strictEqual(reopenData.status, 'Pending');

    // 6. Delete debt
    const delRes = await fetch(`${baseUrl}/api/debts/${debtId}`, {
      method: 'DELETE'
    });
    assert.strictEqual(delRes.status, 200);
    const delData = await delRes.json();
    assert.strictEqual(delData.success, true);
  });

  await t.test('GET /api/budgets returns budget envelopes', async () => {
    const res = await fetch(`${baseUrl}/api/budgets`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data));
  });

  await t.test('GET /api/tax-schedule returns SARS tax schedule', async () => {
    const res = await fetch(`${baseUrl}/api/tax-schedule`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(data.taxYear);
    assert.strictEqual(data.effectiveTaxRate, 0.27);
  });

  await t.test('GET /api/vault returns vault holdings', async () => {
    const res = await fetch(`${baseUrl}/api/vault`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data));
  });

  await t.test('GET /api/burn-rate returns burn metrics', async () => {
    const res = await fetch(`${baseUrl}/api/burn-rate`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data));
  });

  await t.test('GET /api/analytics/income-statement returns statements', async () => {
    const res = await fetch(`${baseUrl}/api/analytics/income-statement`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data));
  });

  await t.test('GET /api/analytics/summary returns KPI performance summary', async () => {
    const res = await fetch(`${baseUrl}/api/analytics/summary`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(data.kpis);
  });
});
