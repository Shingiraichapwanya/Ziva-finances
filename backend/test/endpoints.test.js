const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const app = require('../src/server');
const sheetsRepo = require('../services/googleSheetsRepository');
const authService = require('../services/authService');

test('Express API Endpoints with Owner Authentication & Google Sheets Layer', async (t) => {
  let server;
  let baseUrl;
  let testSession;

  t.beforeEach(() => {
    sheetsRepo.setMockStorage(sheetsRepo.createDefaultMockStorage());
    testSession = authService.setMockOwnerSession('test-owner-session-token');
  });

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

  // Helper for authenticated fetch
  const authFetch = (url, options = {}) => {
    const headers = {
      ...(options.headers || {}),
      Authorization: `Bearer ${testSession.sessionId}`,
      'X-CSRF-Token': testSession.csrfToken
    };
    return fetch(url, { ...options, headers });
  };

  await t.test('1. Public Minimal Health Check (Unauthenticated)', async () => {
    const res = await fetch(`${baseUrl}/api/health`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.status, 'ONLINE');
    assert.strictEqual(data.authRequired, true);
    // Crucial: Must NOT leak spreadsheet ID to unauthenticated callers
    assert.strictEqual(data.spreadsheetId, undefined);
  });

  await t.test('2. Private Endpoints Return 401 for Unauthenticated Callers', async () => {
    const unauthAccounts = await fetch(`${baseUrl}/api/accounts`);
    assert.strictEqual(unauthAccounts.status, 401);

    const unauthTxs = await fetch(`${baseUrl}/api/transactions`);
    assert.strictEqual(unauthTxs.status, 401);

    const unauthDebts = await fetch(`${baseUrl}/api/debts`);
    assert.strictEqual(unauthDebts.status, 401);
  });

  await t.test('3. Authenticated Health Check returns full Sheets diagnostics', async () => {
    const res = await authFetch(`${baseUrl}/api/health`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.status, 'ONLINE');
    assert.strictEqual(data.connected, true);
    assert.strictEqual(data.readMode, 'GOOGLE_SHEETS_API');
    assert.strictEqual(data.writeMode, 'GOOGLE_SHEETS_API');
  });

  await t.test('4. Session Check Endpoint (/api/auth/session)', async () => {
    // Unauthenticated
    const unauthRes = await fetch(`${baseUrl}/api/auth/session`);
    assert.strictEqual(unauthRes.status, 200);
    const unauthData = await unauthRes.json();
    assert.strictEqual(unauthData.authenticated, false);

    // Authenticated
    const authRes = await authFetch(`${baseUrl}/api/auth/session`);
    assert.strictEqual(authRes.status, 200);
    const authData = await authRes.json();
    assert.strictEqual(authData.authenticated, true);
    assert.strictEqual(authData.user.email, authService.OWNER_EMAIL);
  });

  await t.test('5. GET /api/accounts returns accounts for owner', async () => {
    const res = await authFetch(`${baseUrl}/api/accounts`);
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.ok(Array.isArray(data));
    assert.ok(data.length > 0);
  });

  await t.test('6. Transactions CRUD for Owner', async () => {
    const postRes = await authFetch(`${baseUrl}/api/transactions`, {
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
    const delRes = await authFetch(`${baseUrl}/api/transactions/${postData.transactionId}`, {
      method: 'DELETE'
    });
    assert.strictEqual(delRes.status, 200);
  });

  await t.test('7. Debt Ledger: Settle, Idempotent Settle, Reopen & Delete', async () => {
    // 1. Create debt
    const postRes = await authFetch(`${baseUrl}/api/debts`, {
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
    const debtId = postData.debtId;

    // 2. Settle debt
    const settleRes = await authFetch(`${baseUrl}/api/debts/${debtId}/settle`, {
      method: 'PATCH'
    });
    assert.strictEqual(settleRes.status, 200);
    const settleData = await settleRes.json();
    assert.strictEqual(settleData.status, 'Settled');

    // 3. Repeated settle call (Idempotency)
    const settleRes2 = await authFetch(`${baseUrl}/api/debts/${debtId}/settle`, {
      method: 'PATCH'
    });
    assert.strictEqual(settleRes2.status, 200);
    const settleData2 = await settleRes2.json();
    assert.strictEqual(settleData2.alreadySettled, true);

    // 4. Reopen debt
    const reopenRes = await authFetch(`${baseUrl}/api/debts/${debtId}/reopen`, {
      method: 'PATCH'
    });
    assert.strictEqual(reopenRes.status, 200);

    // 5. Delete debt
    const delRes = await authFetch(`${baseUrl}/api/debts/${debtId}`, {
      method: 'DELETE'
    });
    assert.strictEqual(delRes.status, 200);
  });

  await t.test('8. Passkey Authentication Endpoints', async () => {
    // Login options (Public)
    const loginOptionsRes = await fetch(`${baseUrl}/api/auth/passkey/login-options`, {
      method: 'POST'
    });
    assert.strictEqual(loginOptionsRes.status, 200);
    const loginOptions = await loginOptionsRes.json();
    assert.ok(loginOptions.options);
    assert.ok(loginOptions.challengeId);

    // Register options (Protected - owner only)
    const unauthReg = await fetch(`${baseUrl}/api/auth/passkey/register-options`, { method: 'POST' });
    assert.strictEqual(unauthReg.status, 401);

    const authReg = await authFetch(`${baseUrl}/api/auth/passkey/register-options`, { method: 'POST' });
    assert.strictEqual(authReg.status, 200);
    const regOptions = await authReg.json();
    assert.ok(regOptions.challenge);
    assert.strictEqual(regOptions.rp.name, 'Ziva Finance');
  });

  await t.test('9. Receipt Scan, Draft Creation & Confirmation to Sheets', async () => {
    // Unauthenticated upload must be rejected
    const unauthUpload = await fetch(`${baseUrl}/api/receipts/upload`, { method: 'POST' });
    assert.strictEqual(unauthUpload.status, 401);

    // Create receipt draft directly via service (simulating valid uploaded receipt)
    const receiptService = require('../services/receiptService');
    const mockFileBuffer = Buffer.from('WOOLWORTHS FOOD\nTAX INVOICE INV-2026-9901\nDATE: 2026-10-08\nTOTAL: R450.00\nVAT 15%: R58.70\n');
    
    const draft = await receiptService.createReceiptDraft({
      fileBuffer: mockFileBuffer,
      filename: 'woolies_receipt.txt',
      mimeType: 'text/plain',
      userEmail: authService.OWNER_EMAIL
    });

    assert.ok(draft.draftId);
    assert.strictEqual(draft.status, 'AWAITING_REVIEW');
    assert.strictEqual(draft.extractedFields.currency, 'ZAR');
    assert.strictEqual(draft.extractedFields.amount, 450.00);

    // Confirm draft to Google Sheets via authenticated endpoint
    const confirmRes = await authFetch(`${baseUrl}/api/receipts/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        draftId: draft.draftId,
        reviewedData: {
          merchant: 'Woolworths Food Sandton',
          amount: 450.00,
          currency: 'ZAR',
          category: 'CAT_FOOD_DINING',
          isTaxDeductible: true
        }
      })
    });

    assert.strictEqual(confirmRes.status, 200);
    const confirmData = await confirmRes.json();
    assert.strictEqual(confirmData.success, true);
    assert.ok(confirmData.transactionId);

    // Repeated confirmation (Idempotency check)
    const repeatConfirmRes = await authFetch(`${baseUrl}/api/receipts/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ draftId: draft.draftId })
    });
    assert.strictEqual(repeatConfirmRes.status, 200);
    const repeatData = await repeatConfirmRes.json();
    assert.strictEqual(repeatData.alreadyConfirmed, true);
  });

  await t.test('10. Financial Aggregations & Metrics (Protected)', async () => {
    const budgetsRes = await authFetch(`${baseUrl}/api/budgets`);
    assert.strictEqual(budgetsRes.status, 200);

    const taxRes = await authFetch(`${baseUrl}/api/tax-schedule`);
    assert.strictEqual(taxRes.status, 200);

    const burnRes = await authFetch(`${baseUrl}/api/burn-rate`);
    assert.strictEqual(burnRes.status, 200);

    const summaryRes = await authFetch(`${baseUrl}/api/analytics/summary`);
    assert.strictEqual(summaryRes.status, 200);
  });
});
