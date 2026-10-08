import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  getSessionToken,
  setSessionToken,
  getCsrfToken,
  setCsrfToken
} from './api.ts';

test('Session token persistence and retrieval', () => {
  // Test token save and load
  setSessionToken('mock-session-xyz-123');
  assert.equal(getSessionToken(), 'mock-session-xyz-123');

  // Test token clearing
  setSessionToken(null);
  assert.equal(getSessionToken(), null);
});

test('CSRF token persistence and retrieval', () => {
  setCsrfToken('mock-csrf-abc-789');
  assert.equal(getCsrfToken(), 'mock-csrf-abc-789');

  setCsrfToken(null);
  assert.equal(getCsrfToken(), null);
});
