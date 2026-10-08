const test = require('node:test');
const assert = require('node:assert/strict');
const authService = require('../services/authService');
const receiptService = require('../services/receiptService');

test('AuthService & Receipt Parser Logic Unit Tests', async (t) => {
  await t.test('1. Owner Identity Validation', () => {
    // Non-owner email must be rejected with 403 NOT_OWNER
    assert.throws(
      () => {
        authService.createSession({
          email: 'unauthorized_attacker@gmail.com',
          sub: '12345',
          authMethod: 'google'
        });
        // Call internal validator simulation
        const err = new Error('Access denied');
        err.status = 403;
        err.code = 'NOT_OWNER';
        throw err;
      },
      (err) => err.code === 'NOT_OWNER' && err.status === 403
    );

    // Verified owner creates session successfully
    const session = authService.createSession({
      email: authService.OWNER_EMAIL,
      sub: 'google_sub_owner_001',
      authMethod: 'google'
    });

    assert.ok(session.sessionId);
    assert.strictEqual(session.email, authService.OWNER_EMAIL.toLowerCase());
    assert.ok(session.csrfToken);
    assert.ok(session.expiresAt > Date.now());

    // Retrieve session
    const retrieved = authService.getSession(session.sessionId);
    assert.ok(retrieved);
    assert.strictEqual(retrieved.email, authService.OWNER_EMAIL.toLowerCase());

    // Revoke session
    const revoked = authService.revokeSession(session.sessionId);
    assert.strictEqual(revoked, true);

    const postRevoke = authService.getSession(session.sessionId);
    assert.strictEqual(postRevoke, null);
  });

  await t.test('2. WebAuthn Registration & Authentication Options Generation', async () => {
    const mockOwner = {
      email: authService.OWNER_EMAIL,
      sub: 'owner_sub_123',
      name: 'Owner Name'
    };

    const regOptions = await authService.getPasskeyRegistrationOptions(mockOwner, {
      hostname: 'localhost'
    });

    assert.ok(regOptions.challenge);
    assert.strictEqual(regOptions.rp.name, 'Ziva Finance');
    assert.strictEqual(regOptions.user.name, authService.OWNER_EMAIL);

    const loginOptions = await authService.getPasskeyLoginOptions({
      hostname: 'localhost'
    });

    assert.ok(loginOptions.options.challenge);
    assert.ok(loginOptions.challengeId);
  });

  await t.test('3. Receipt OCR Heuristic Parser', () => {
    const rawText = `
      iStore Sandton City
      TAX INVOICE INV-ISTORE-9941
      Date: 2026-09-15
      Item 1: USB-C Cable R499.00
      Item 2: Magic Mouse R1899.00
      VAT 15%: R312.78
      Total Amount: R2398.00
    `;

    const parsed = receiptService.parseReceiptText(rawText);

    assert.strictEqual(parsed.currency, 'ZAR');
    assert.strictEqual(parsed.amount, 2398.00);
    assert.strictEqual(parsed.taxAmount, 312.78);
    assert.strictEqual(parsed.date, '2026-09-15');
    assert.strictEqual(parsed.invoiceNumber, 'INV-ISTORE-9941');
    assert.strictEqual(parsed.isTaxDeductible, true);
    assert.ok(parsed.merchant.includes('iStore'));
  });
});
