const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

process.env.NODE_ENV = 'test';
process.env.OWNER_EMAIL = 'owner@ziva.internal';
process.env.SESSION_SECRET = 'test_secret_32_characters_minimum_len!';

const app = require('../src/server');
const authService = require('../services/authService');
const sheetsRepo = require('../services/googleSheetsRepository');

describe('Phase 4 Account & Budget Features Tests', () => {
  let server;
  let baseUrl;
  let testSession;

  before(async () => {
    sheetsRepo.setMockStorage(sheetsRepo.createDefaultMockStorage());
    testSession = authService.setMockOwnerSession('phase4-test-session-token');

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
      'X-CSRF-Token': testSession.csrfToken,
      'Content-Type': 'application/json'
    };
    return fetch(`${baseUrl}${path}`, { ...options, headers });
  };

  it('1. Rejects unauthenticated requests to account and budget mutations', async () => {
    const resAcc = await fetch(`${baseUrl}/api/accounts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ accountName: 'Hacker Account' })
    });
    assert.strictEqual(resAcc.status, 401);

    const resBudget = await fetch(`${baseUrl}/api/budgets/allocate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ categoryId: 'CAT_TEST', allocationMonth: '2026-03', plannedAmount: 100 })
    });
    assert.strictEqual(resBudget.status, 401);
  });

  it('2. POST /api/accounts creates new account with validated fields and 0 synthetic transactions', async () => {
    const res = await authFetch('/api/accounts', {
      method: 'POST',
      body: JSON.stringify({
        accountName: 'Discovery Bank Gold',
        financialInstitution: 'Discovery Bank',
        countryCode: 'ZA',
        primaryCurrency: 'ZAR',
        cashFlowTier: 'DAILY_SPENDING',
        accountType: 'CHECKING',
        accountNumberMasked: '...9988'
      })
    });

    assert.strictEqual(res.status, 201);
    const body = await res.json();
    assert.strictEqual(body.success, true);
    assert.ok(body.accountId);
    assert.strictEqual(body.account.accountName, 'Discovery Bank Gold');
    assert.strictEqual(body.account.nativeBalance, 0); // No fictitious balance injected
    assert.strictEqual(body.account.isActive, true);

    // Verify account is retrievable via GET /api/accounts
    const getRes = await authFetch('/api/accounts');
    assert.strictEqual(getRes.status, 200);
    const accounts = await getRes.json();
    const created = accounts.find((a) => a.accountId === body.accountId);
    assert.ok(created, 'Created account must appear in accounts listing');
    assert.strictEqual(created.accountName, 'Discovery Bank Gold');
  });

  it('3. PATCH /api/accounts/:id updates existing account metadata', async () => {
    // Create an account first
    const createRes = await authFetch('/api/accounts', {
      method: 'POST',
      body: JSON.stringify({
        accountName: 'Pre-Edit Account',
        countryCode: 'ZA',
        primaryCurrency: 'ZAR'
      })
    });
    const { accountId } = await createRes.json();

    // Patch account
    const patchRes = await authFetch(`/api/accounts/${accountId}`, {
      method: 'PATCH',
      body: JSON.stringify({
        accountName: 'Post-Edit Account',
        accountNumberMasked: '...4321'
      })
    });
    assert.strictEqual(patchRes.status, 200);
    const patchBody = await patchRes.json();
    assert.strictEqual(patchBody.success, true);

    // Verify update
    const getRes = await authFetch('/api/accounts');
    const accounts = await getRes.json();
    const updated = accounts.find((a) => a.accountId === accountId);
    assert.ok(updated);
    assert.strictEqual(updated.accountName, 'Post-Edit Account');
  });

  it('4. DELETE /api/accounts/:id soft-archives account without deleting data', async () => {
    // Create an account
    const createRes = await authFetch('/api/accounts', {
      method: 'POST',
      body: JSON.stringify({
        accountName: 'Account To Archive',
        countryCode: 'ZA'
      })
    });
    const { accountId } = await createRes.json();

    // Archive it
    const delRes = await authFetch(`/api/accounts/${accountId}`, {
      method: 'DELETE'
    });
    assert.strictEqual(delRes.status, 200);
    const delBody = await delRes.json();
    assert.strictEqual(delBody.archived, true);

    // Verify it is excluded from active accounts by default
    const activeRes = await authFetch('/api/accounts');
    const activeAccounts = await activeRes.json();
    assert.strictEqual(activeAccounts.some((a) => a.accountId === accountId), false, 'Archived account should not appear in active list');

    // Verify it is marked inactive when includeArchived=true
    const getRes = await authFetch('/api/accounts?includeArchived=true');
    const accounts = await getRes.json();
    const archived = accounts.find((a) => a.accountId === accountId);
    assert.ok(archived, 'Archived account should appear when includeArchived=true');
    assert.strictEqual(archived.isActive, false);
  });

  it('5. POST /api/budgets/allocate creates new monthly envelope allocation', async () => {
    const res = await authFetch('/api/budgets/allocate', {
      method: 'POST',
      body: JSON.stringify({
        categoryId: 'CAT_TEST_HEALTH',
        allocationMonth: '2026-04',
        plannedAmount: 1800,
        targetCurrency: 'ZAR',
        cashFlowTier: 'DAILY_SPENDING',
        notes: 'Monthly gym and medical aid'
      })
    });

    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.action, 'CREATED');
    assert.strictEqual(body.allocation.plannedAmount, 1800);

    // Verify envelope in listing
    const budgetsRes = await authFetch('/api/budgets');
    const budgets = await budgetsRes.json();
    const found = budgets.find((b) => b.categoryId === 'CAT_TEST_HEALTH' && b.allocationMonth === '2026-04');
    assert.ok(found, 'New allocation must appear in envelopes list');
    assert.strictEqual(found.plannedAmountZar, 1800);
  });

  it('6. POST /api/budgets/allocate performs safe upsert without duplicate rows', async () => {
    // Update existing envelope created in test 5
    const res = await authFetch('/api/budgets/allocate', {
      method: 'POST',
      body: JSON.stringify({
        categoryId: 'CAT_TEST_HEALTH',
        allocationMonth: '2026-04',
        plannedAmount: 2500,
        targetCurrency: 'ZAR',
        notes: 'Increased health budget'
      })
    });

    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.action, 'UPDATED');
    assert.strictEqual(body.allocation.plannedAmount, 2500);

    // Verify no duplicates
    const budgetsRes = await authFetch('/api/budgets');
    const budgets = await budgetsRes.json();
    const matches = budgets.filter((b) => b.categoryId === 'CAT_TEST_HEALTH' && b.allocationMonth === '2026-04');
    assert.strictEqual(matches.length, 1, 'Must have exactly 1 allocation row, no duplicates');
    assert.strictEqual(matches[0].plannedAmountZar, 2500);
  });
});
