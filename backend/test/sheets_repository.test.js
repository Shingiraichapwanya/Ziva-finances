const test = require('node:test');
const assert = require('node:assert/strict');
const sheetsRepo = require('../services/googleSheetsRepository');

test('Google Sheets Repository: Full CRUD, Aggregations, Idempotency & Mutex', async (t) => {
  t.beforeEach(() => {
    sheetsRepo.setMockStorage(sheetsRepo.createDefaultMockStorage());
  });

  await t.test('1. Verify Connectivity Probe in Mock Mode', async () => {
    const health = await sheetsRepo.verifySheetsConnectivity({ forceCheck: true });
    assert.strictEqual(health.status, 'ONLINE');
    assert.strictEqual(health.connected, true);
    assert.strictEqual(health.readMode, 'GOOGLE_SHEETS_API');
    assert.strictEqual(health.writeMode, 'GOOGLE_SHEETS_API');
    assert.ok(health.tabs.includes('fct_transactions'));
    assert.ok(health.tabs.includes('debt_credit_ledger'));
  });

  await t.test('2. Transactions CRUD & Read-After-Write', async () => {
    const initialTxs = await sheetsRepo.getTransactions();
    assert.ok(Array.isArray(initialTxs));
    const initialCount = initialTxs.length;

    // Create new transaction
    const newTxPayload = {
      description: 'Fiber Internet Sub',
      amount: 899.00,
      currency: 'ZAR',
      transactionType: 'EXPENSE',
      category: 'CAT_HOUSING_BILLS',
      accountId: 'ACC_ZA_CAPITEC_DAILY',
      merchantOrPayee: 'Octotel ISP',
      isTaxDeductible: true,
      taxInvoiceNumber: 'INV-2026-OCTO-01'
    };

    const createResult = await sheetsRepo.insertTransaction(newTxPayload);
    assert.strictEqual(createResult.success, true);
    assert.ok(createResult.transactionId);
    assert.strictEqual(createResult.record.reportingAmountZar, -899.00);

    // Read back and verify persistence in mock store
    const updatedTxs = await sheetsRepo.getTransactions();
    assert.strictEqual(updatedTxs.length, initialCount + 1);
    const found = updatedTxs.find((t) => t.id === createResult.transactionId);
    assert.ok(found);
    assert.strictEqual(found.merchantOrPayee, 'Octotel ISP');
    assert.strictEqual(found.isTaxDeductible, true);
    assert.strictEqual(found.taxInvoiceNumber, 'INV-2026-OCTO-01');

    // Delete transaction
    const deleteResult = await sheetsRepo.deleteTransaction(createResult.transactionId);
    assert.strictEqual(deleteResult.success, true);

    const postDeleteTxs = await sheetsRepo.getTransactions();
    assert.strictEqual(postDeleteTxs.length, initialCount);
    assert.strictEqual(postDeleteTxs.find((t) => t.id === createResult.transactionId), undefined);
  });

  await t.test('3. Debt Ledger CRUD, Settle, Reopen & Idempotency', async () => {
    const initialDebts = await sheetsRepo.getDebts();
    const initialCount = initialDebts.length;

    // Insert new debt record
    const debtPayload = {
      personName: 'Tinashe Chikwanha',
      direction: 'owed_to_me',
      amount: 1500.00,
      currency: 'ZAR',
      notes: 'Freelance design deposit'
    };

    const insertResult = await sheetsRepo.insertDebt(debtPayload);
    assert.strictEqual(insertResult.success, true);
    assert.ok(insertResult.debtId);
    assert.strictEqual(insertResult.record.status, 'Pending');

    // Verify retrieval
    const pendingDebts = await sheetsRepo.getDebts('Pending');
    const createdDebt = pendingDebts.find((d) => d.id === insertResult.debtId);
    assert.ok(createdDebt);
    assert.strictEqual(createdDebt.personName, 'Tinashe Chikwanha');
    assert.strictEqual(createdDebt.amount, 1500.00);

    // Settle debt
    const settleResult = await sheetsRepo.settleDebt(insertResult.debtId);
    assert.strictEqual(settleResult.success, true);
    assert.strictEqual(settleResult.status, 'Settled');

    // Settle again (Idempotency check - must succeed gracefully)
    const idempotentSettleResult = await sheetsRepo.settleDebt(insertResult.debtId);
    assert.strictEqual(idempotentSettleResult.success, true);
    assert.strictEqual(idempotentSettleResult.status, 'Settled');
    assert.strictEqual(idempotentSettleResult.alreadySettled, true);

    // Check filtered queries
    const settledDebts = await sheetsRepo.getDebts('Settled');
    assert.ok(settledDebts.some((d) => d.id === insertResult.debtId));

    // Reopen debt
    const reopenResult = await sheetsRepo.reopenDebt(insertResult.debtId);
    assert.strictEqual(reopenResult.success, true);
    assert.strictEqual(reopenResult.status, 'Pending');

    // Delete debt
    const deleteResult = await sheetsRepo.deleteDebt(insertResult.debtId);
    assert.strictEqual(deleteResult.success, true);

    const postDeleteDebts = await sheetsRepo.getDebts();
    assert.strictEqual(postDeleteDebts.length, initialCount);
  });

  await t.test('4. Net Debt Balances Aggregation', async () => {
    // Add two opposing debts for the same counterparty
    const d1 = await sheetsRepo.insertDebt({
      personName: 'Audit Test Person',
      direction: 'owed_to_me',
      amount: 1000.00,
      currency: 'ZAR'
    });
    const d2 = await sheetsRepo.insertDebt({
      personName: 'Audit Test Person',
      direction: 'owed_by_me',
      amount: 400.00,
      currency: 'ZAR'
    });

    const balances = await sheetsRepo.getDebtBalances('Audit Test Person');
    assert.ok(balances.length >= 1);
    const personBalance = balances.find((b) => b.personName === 'Audit Test Person');
    assert.ok(personBalance);
    assert.strictEqual(personBalance.owedToMe, 1000.00);
    assert.strictEqual(personBalance.owedByMe, 400.00);
    assert.strictEqual(personBalance.netBalance, 600.00); // 1000 - 400

    // Cleanup
    await sheetsRepo.deleteDebt(d1.debtId);
    await sheetsRepo.deleteDebt(d2.debtId);
  });

  await t.test('5. Pure Node.js Analytical Aggregations', async () => {
    // Accounts & Live balances
    const accounts = await sheetsRepo.getAccounts();
    assert.ok(Array.isArray(accounts));
    assert.ok(accounts.length > 0);
    // Verify each account has required schema fields
    accounts.forEach((acc) => {
      assert.ok(acc.accountId);
      assert.ok(acc.accountName);
      assert.strictEqual(typeof acc.nativeBalance, 'number');
    });

    // Budget Envelopes
    const envelopes = await sheetsRepo.getBudgetEnvelopes();
    assert.ok(Array.isArray(envelopes));
    assert.ok(envelopes.length > 0);
    envelopes.forEach((env) => {
      assert.ok(env.categoryId);
      assert.strictEqual(typeof env.plannedAmountZar, 'number');
      assert.strictEqual(typeof env.actualSpentZar, 'number');
    });

    // Tax Schedule
    const taxSchedule = await sheetsRepo.getTaxSchedule();
    assert.ok(taxSchedule);
    assert.strictEqual(typeof taxSchedule.grossTaxableInflowZar, 'number');
    assert.strictEqual(typeof taxSchedule.estimatedTaxLiabilityZar, 'number');
    assert.strictEqual(taxSchedule.effectiveTaxRate, 0.27);

    // Daily Burn Metrics
    const burn = await sheetsRepo.getDailyBurnMetrics(7);
    assert.ok(Array.isArray(burn));
    assert.ok(burn.length >= 1);

    // Vault Holdings
    const vault = await sheetsRepo.getVaultHoldings();
    assert.ok(Array.isArray(vault));

    // Performance Summary
    const summary = await sheetsRepo.getPerformanceSummary();
    assert.ok(summary);
    assert.ok(summary.kpis);
    assert.strictEqual(typeof summary.kpis.netWorthZar, 'number');
  });

  await t.test('6. AsyncMutex Serialized Concurrency Test', async () => {
    const mutex = new sheetsRepo.AsyncMutex();
    const executionOrder = [];

    // Launch 5 concurrent tasks through the mutex
    const tasks = [1, 2, 3, 4, 5].map((id) =>
      mutex.runExclusive(async () => {
        executionOrder.push(`start-${id}`);
        // Small delay to test exclusion
        await new Promise((resolve) => setTimeout(resolve, 10));
        executionOrder.push(`end-${id}`);
        return id;
      })
    );

    const results = await Promise.all(tasks);
    assert.deepStrictEqual(results, [1, 2, 3, 4, 5]);

    // Ensure every start is immediately followed by its own end before the next start
    for (let i = 0; i < 5; i++) {
      const startIdx = executionOrder.indexOf(`start-${i + 1}`);
      const endIdx = executionOrder.indexOf(`end-${i + 1}`);
      assert.strictEqual(endIdx, startIdx + 1, `Task ${i + 1} was interrupted concurrently`);
    }
  });

  await t.test('7. Error Handling for Non-Existent Records', async () => {
    await assert.rejects(
      async () => sheetsRepo.settleDebt('non-existent-uuid-99999'),
      /Debt record with ID 'non-existent-uuid-99999' not found/
    );

    await assert.rejects(
      async () => sheetsRepo.deleteDebt('non-existent-uuid-99999'),
      /Debt record with ID 'non-existent-uuid-99999' not found/
    );
  });
});
