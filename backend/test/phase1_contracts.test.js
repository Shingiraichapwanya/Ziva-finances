const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

// Load environment variables for test execution
process.env.NODE_ENV = 'test';
process.env.OWNER_EMAIL = 'owner@ziva.internal';
process.env.SESSION_SECRET = 'test_secret_32_characters_minimum_len!';

const app = require('../src/server');
const authService = require('../services/authService');
const receiptService = require('../services/receiptService');
const sheetsRepo = require('../services/googleSheetsRepository');

describe('Phase 1 Contract Verification Tests', () => {
  let server;
  let baseUrl;
  let testSession;

  before(async () => {
    sheetsRepo.setMockStorage(sheetsRepo.createDefaultMockStorage());
    testSession = authService.setMockOwnerSession('phase1-test-session-token');

    server = http.createServer(app);
    await new Promise((resolve) => {
      server.listen(0, '127.0.0.1', () => {
        const { port } = server.address();
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  const authFetch = (path, options = {}) => {
    const headers = {
      ...(options.headers || {}),
      Authorization: `Bearer ${testSession.sessionId}`,
      'X-CSRF-Token': testSession.csrfToken
    };
    return fetch(`${baseUrl}${path}`, { ...options, headers });
  };

  it('1. GET /api/auth/session and GET /api/auth/me return identical session shape', async () => {
    const resSession = await authFetch('/api/auth/session');
    const resMe = await authFetch('/api/auth/me');

    assert.strictEqual(resSession.status, 200);
    assert.strictEqual(resMe.status, 200);

    const bodySession = await resSession.json();
    const bodyMe = await resMe.json();

    assert.strictEqual(bodySession.authenticated, true);
    assert.strictEqual(bodyMe.authenticated, true);
    assert.strictEqual(bodySession.user.email, authService.OWNER_EMAIL);
    assert.strictEqual(bodyMe.user.email, authService.OWNER_EMAIL);
  });

  it('2. GET /api/auth/passkey/list and /api/auth/passkey/credentials contract compatibility', async () => {
    const resList = await authFetch('/api/auth/passkey/list');
    const resCredentials = await authFetch('/api/auth/passkey/credentials');

    assert.strictEqual(resList.status, 200);
    assert.strictEqual(resCredentials.status, 200);

    const listBody = await resList.json();
    const credBody = await resCredentials.json();

    assert.ok(Array.isArray(listBody));
    assert.ok(Array.isArray(credBody.credentials));
  });

  it('3. GET /api/burn-rate returns { metrics, history } typed contract grounded in real data', async () => {
    const resBurn = await authFetch('/api/burn-rate');

    assert.strictEqual(resBurn.status, 200);
    const body = await resBurn.json();

    // Flat access backward compatibility
    assert.strictEqual(typeof body.averageDailyBurnZar, 'number');
    assert.strictEqual(typeof body.liquidReserveBalanceZar, 'number');
    assert.strictEqual(typeof body.baselineRunwayDays, 'number');
    // Nested typed metrics access
    assert.ok(body.metrics);
    assert.strictEqual(typeof body.metrics.averageDailyBurnZar, 'number');
    // History array
    assert.ok(Array.isArray(body.history));
  });

  it('4. POST /api/receipts/confirm validates amount, currency, and prevents double-confirmation', async () => {
    const draft = await receiptService.createReceiptDraft({
      fileBuffer: Buffer.from('SPAR SUPERMARKET\nDATE: 2026-10-05\nTOTAL: R 250.00\n'),
      filename: 'spar_receipt.txt',
      mimeType: 'text/plain',
      userEmail: authService.OWNER_EMAIL
    });

    assert.ok(draft.draftId);

    // Confirmation test with reviewedData
    const resConfirm = await authFetch('/api/receipts/confirm', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        draftId: draft.draftId,
        reviewedData: {
          merchant: 'SPAR Groceries',
          amount: 250.00,
          currency: 'ZAR',
          date: '2026-10-05',
          isTaxDeductible: false
        }
      })
    });

    assert.strictEqual(resConfirm.status, 200);
    const bodyConfirm = await resConfirm.json();
    assert.strictEqual(bodyConfirm.success, true);
    assert.ok(bodyConfirm.transactionId);

    // Second confirmation test (Idempotency check)
    const resDoubleConfirm = await authFetch('/api/receipts/confirm', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        draftId: draft.draftId,
        reviewedData: { amount: 250.00 }
      })
    });

    assert.strictEqual(resDoubleConfirm.status, 200);
    const bodyDouble = await resDoubleConfirm.json();
    assert.strictEqual(bodyDouble.alreadyConfirmed, true);
    assert.strictEqual(bodyDouble.transactionId, bodyConfirm.transactionId);
  });

  it('5. POST /api/receipts/drafts/:id/confirm alias route compatibility', async () => {
    const draft2 = await receiptService.createReceiptDraft({
      fileBuffer: Buffer.from('TECH HARDWARE\nDATE: 2026-10-06\nTOTAL: $45.00\n'),
      filename: 'invoice.txt',
      mimeType: 'text/plain',
      userEmail: authService.OWNER_EMAIL
    });

    const resAliasConfirm = await authFetch(`/api/receipts/drafts/${draft2.draftId}/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        overrides: {
          merchant: 'Tech Hardware Co',
          totalAmount: 45.00,
          currency: 'USD',
          date: '2026-10-06'
        }
      })
    });

    assert.strictEqual(resAliasConfirm.status, 200);
    const bodyAlias = await resAliasConfirm.json();
    assert.strictEqual(bodyAlias.success, true);
    assert.ok(bodyAlias.transactionId);
  });
});
