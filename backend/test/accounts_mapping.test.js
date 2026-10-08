const test = require('node:test');
const assert = require('node:assert/strict');

// Import mapAccountRow dynamically or require
test('Backend Account Mapping: mapAccountRow does not add ghost opening balances', async () => {
  const { mapAccountRow } = await import('../src/bigquery.js');

  // Case 1: Account with an ID matching a previously hardcoded fixture (ACC_ZA_CAPITEC_DAILY)
  const rawDbRow = {
    accountId: 'ACC_ZA_CAPITEC_DAILY',
    accountName: 'Capitec Primary Cheque',
    financialInstitution: 'Capitec Bank',
    countryCode: 'ZA',
    primaryCurrency: 'ZAR',
    cashFlowTier: 'DAILY_SPENDING',
    accountType: 'CHECKING',
    isVaultLocked: false,
    withdrawalNoticeDays: 0,
    accountNumberMasked: '...4091',
    nativeBalance: 0.0, // Database has 0.0 sum of transactions
    isActive: true
  };

  const mapped = mapAccountRow(rawDbRow);

  // The mapped balance must be exactly 0.0, NOT inflated with ghost 18,450.00
  assert.strictEqual(mapped.nativeBalance, 0.0);
  assert.strictEqual(mapped.accountName, 'Capitec Primary Cheque');
  assert.strictEqual(mapped.isActive, true);

  // Case 2: Account with real transactions in the database
  const activeUserRow = {
    accountId: 'ACC_ZA_CAPITEC_DAILY',
    accountName: 'Capitec Primary Cheque',
    financialInstitution: 'Capitec Bank',
    countryCode: 'ZA',
    primaryCurrency: 'ZAR',
    cashFlowTier: 'DAILY_SPENDING',
    accountType: 'CHECKING',
    isVaultLocked: false,
    withdrawalNoticeDays: 0,
    accountNumberMasked: '...4091',
    nativeBalance: 125.50, // Real user transaction sum
    isActive: true
  };

  const mappedActive = mapAccountRow(activeUserRow);
  assert.strictEqual(mappedActive.nativeBalance, 125.50);
});
