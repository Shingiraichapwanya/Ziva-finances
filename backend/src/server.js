const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * Startup function: Ensure Google credentials provided as a JSON string
 * in GOOGLE_APPLICATION_CREDENTIALS or GOOGLE_CREDENTIALS are written to a temporary physical file
 * before any Google SDK client initializes.
 */
function setupGoogleCredentials() {
  const rawCreds = process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.GOOGLE_CREDENTIALS;
  if (!rawCreds) {
    return;
  }

  const trimmed = rawCreds.trim();
  // Check if credentials are provided as a JSON string rather than a file path
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      JSON.parse(trimmed);
      const tempDir = fs.existsSync('/tmp') ? '/tmp' : os.tmpdir();
      const tempFilePath = path.join(tempDir, 'google-creds.json');

      fs.writeFileSync(tempFilePath, trimmed, { mode: 0o600, encoding: 'utf8' });
      process.env.GOOGLE_APPLICATION_CREDENTIALS = tempFilePath;
      console.log(`[Startup] Google credentials JSON string written to temporary file: ${tempFilePath}`);
    } catch (err) {
      console.error('[Startup] Failed to parse and write GOOGLE_APPLICATION_CREDENTIALS JSON string:', err.message);
    }
  }
}

// Execute immediately at the very beginning of server startup
setupGoogleCredentials();

const express = require('express');
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const cors = require('cors');
const multer = require('multer');

// Services
const authService = require('../services/authService');
const receiptService = require('../services/receiptService');
const sheetsRepo = require('../services/googleSheetsRepository');

const {
  REPO_CONFIG,
  getExchangeRates,
  getAccounts,
  createAccount,
  updateAccount,
  archiveAccount,
  getTransactions,
  insertTransaction,
  deleteTransaction,
  getDebts,
  getDebtBalances,
  insertDebt,
  settleDebt,
  reopenDebt,
  deleteDebt,
  getBudgetEnvelopes,
  upsertBudgetAllocation,
  getTaxSchedule,
  getVaultHoldings,
  getDailyBurnMetrics,
  getBurnRateSummary,
  getIncomeStatements,
  getNonOperatingGains,
  getPerformanceSummary,
  verifySheetsConnectivity,
  getTroubleshootingGuidance,
} = sheetsRepo;

// AI Copilot service imports
const {
  getCopilotInsights,
  chatWithCopilot,
} = require('./copilot');

const app = express();
const PORT = process.env.PORT || 3001;

// Multer storage for receipt upload (memory storage for immediate OCR & Drive streaming)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'];
    if (allowed.includes(file.mimetype.toLowerCase())) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only JPEG, PNG, WebP, and PDF receipt files are supported.'));
    }
  }
});

// Configure CORS with allowed origins & credential support
const allowedOrigins = [
  'http://localhost:5173',
  'http://localhost:3000',
  'https://shingiraichapwanya.github.io',
  'capacitor://localhost',
  'https://localhost',
  process.env.FRONTEND_URL
].filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (e.g. mobile apps, curl, same-origin)
    if (!origin || allowedOrigins.includes(origin) || origin.endsWith('.github.io')) {
      return callback(null, true);
    }
    return callback(null, true); // Permissive for PWA access, authentication middleware enforces access
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token', 'X-Ziva-Session']
}));

app.use(cookieParser());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(express.json({ limit: '10mb' }));

// Helper: Set Secure HttpOnly session cookie
function setSessionCookie(res, sessionId) {
  const isProd = process.env.NODE_ENV === 'production';
  res.cookie('ziva_session', sessionId, {
    httpOnly: true,
    secure: isProd,
    sameSite: isProd ? 'none' : 'lax', // 'none' allows cross-domain cookies if HTTPS; bearer token provides fallback
    maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
    path: '/'
  });
}

// -----------------------------------------------------------------------------
// 1. PUBLIC AUTHENTICATION & HEALTH ENDPOINTS
// -----------------------------------------------------------------------------

// Minimal, non-sensitive health endpoint
app.get('/api/health', async (req, res) => {
  const sessionId = authService.extractSessionId(req);
  const session = sessionId ? authService.getSession(sessionId) : null;

  // Unauthenticated callers receive minimal status without leaking sensitive spreadsheet or project details
  if (!session) {
    return res.json({
      status: 'ONLINE',
      authRequired: true,
      time: new Date().toISOString()
    });
  }

  // Authenticated owner receives full health diagnostics
  try {
    const forceCheck = req.query.force === 'true';
    const state = await verifySheetsConnectivity({ forceCheck });
    res.json(state);
  } catch (error) {
    res.status(500).json({
      status: 'OFFLINE',
      connected: false,
      liveDataLayer: 'GOOGLE_SHEETS_API',
      error: {
        message: error.message,
        troubleshooting: getTroubleshootingGuidance(error)
      }
    });
  }
});

const handleSessionCheck = (req, res) => {
  const sessionId = authService.extractSessionId(req);
  const session = sessionId ? authService.getSession(sessionId) : null;

  if (!session) {
    return res.json({
      authenticated: false,
      ownerEmail: authService.OWNER_EMAIL,
    });
  }

  return res.json({
    authenticated: true,
    user: {
      email: session.email,
      sub: session.sub,
      authMethod: session.authMethod,
      expiresAt: session.expiresAt
    },
    csrfToken: session.csrfToken
  });
};

// Check current session status
app.get('/api/auth/session', handleSessionCheck);
app.get('/api/auth/me', handleSessionCheck);

// Google OAuth URL generator
app.get('/api/auth/google/url', (req, res) => {
  try {
    const redirectUri = req.query.redirectUri || process.env.GOOGLE_REDIRECT_URI;
    const authDetails = authService.generateGoogleAuthUrl({ redirectUri });
    res.json(authDetails);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Google OAuth Authorization Code exchange
app.post('/api/auth/google/callback', async (req, res) => {
  try {
    const { code, redirectUri, state } = req.body;
    if (!code) {
      return res.status(400).json({ error: 'Authorization code is required' });
    }

    const ownerUser = await authService.verifyGoogleAuthCode({ code, redirectUri, state });
    const session = authService.createSession({
      email: ownerUser.email,
      sub: ownerUser.sub,
      authMethod: 'google',
      userAgent: req.headers['user-agent']
    });

    setSessionCookie(res, session.sessionId);

    res.json({
      success: true,
      sessionToken: session.sessionId,
      csrfToken: session.csrfToken,
      user: {
        email: ownerUser.email,
        name: ownerUser.name,
        picture: ownerUser.picture
      }
    });
  } catch (error) {
    const status = error.status || 401;
    res.status(status).json({
      error: error.message,
      code: error.code || 'AUTH_FAILED'
    });
  }
});

// Direct ID Token verification (for Google One Tap / Sign In with Google button)
app.post('/api/auth/google/verify-token', async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required' });
    }

    const ownerUser = await authService.verifyGoogleIdTokenDirect(idToken);
    const session = authService.createSession({
      email: ownerUser.email,
      sub: ownerUser.sub,
      authMethod: 'google_id_token',
      userAgent: req.headers['user-agent']
    });

    setSessionCookie(res, session.sessionId);

    res.json({
      success: true,
      sessionToken: session.sessionId,
      csrfToken: session.csrfToken,
      user: {
        email: ownerUser.email,
        name: ownerUser.name,
        picture: ownerUser.picture
      }
    });
  } catch (error) {
    const status = error.status || 401;
    res.status(status).json({
      error: error.message,
      code: error.code || 'AUTH_FAILED'
    });
  }
});

// Logout: Revoke session server-side & clear cookies
app.post('/api/auth/logout', (req, res) => {
  const sessionId = authService.extractSessionId(req);
  if (sessionId) {
    authService.revokeSession(sessionId);
  }
  res.clearCookie('ziva_session', { path: '/' });
  res.json({ success: true, message: 'Session logged out and revoked.' });
});

// Passkey Authentication Challenges (Public endpoints)
app.post('/api/auth/passkey/login-options', async (req, res) => {
  try {
    const result = await authService.getPasskeyLoginOptions(req);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/passkey/login-verify', async (req, res) => {
  try {
    const result = await authService.verifyPasskeyLogin(req.body, req);
    if (result.verified && result.session) {
      setSessionCookie(res, result.session.sessionId);
      res.json({
        success: true,
        sessionToken: result.session.sessionId,
        csrfToken: result.session.csrfToken,
        user: {
          email: result.session.email,
          authMethod: 'passkey'
        }
      });
    } else {
      res.status(401).json({ error: 'Passkey verification failed' });
    }
  } catch (error) {
    res.status(401).json({ error: error.message });
  }
});

// -----------------------------------------------------------------------------
// 2. PROTECTED AUTHENTICATION MANAGEMENT (PASSKEY REGISTRATION)
// -----------------------------------------------------------------------------

// WebAuthn Passkey Registration Options (Owner session required)
app.post('/api/auth/passkey/register-options', authService.requireOwnerAuth, async (req, res) => {
  try {
    const options = await authService.getPasskeyRegistrationOptions(req.owner, req);
    res.json(options);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// WebAuthn Passkey Registration Verification (Owner session required)
app.post('/api/auth/passkey/register-verify', authService.requireOwnerAuth, async (req, res) => {
  try {
    const result = await authService.verifyPasskeyRegistration(req.owner, req.body, req);
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// List owner passkeys
const handlePasskeyList = (req, res) => {
  const passkeys = authService.getOwnerPasskeys(req.owner.email).map((p) => ({
    id: p.id,
    deviceName: p.deviceName,
    deviceType: p.deviceType,
    createdAt: p.createdAt,
    lastUsedAt: p.lastUsedAt
  }));
  res.json(passkeys);
};

app.get('/api/auth/passkey/list', authService.requireOwnerAuth, handlePasskeyList);
app.get('/api/auth/passkey/credentials', authService.requireOwnerAuth, (req, res) => {
  const passkeys = authService.getOwnerPasskeys(req.owner.email).map((p) => ({
    id: p.id,
    name: p.deviceName,
    createdAt: p.createdAt,
    counter: p.counter || 0,
    lastUsedAt: p.lastUsedAt
  }));
  res.json({ credentials: passkeys });
});

// Delete owner passkey
const handlePasskeyDelete = (req, res) => {
  const success = authService.deletePasskey(req.params.id, req.owner.email);
  if (success) {
    res.json({ success: true, message: 'Passkey removed.' });
  } else {
    res.status(404).json({ error: 'Passkey not found' });
  }
};

app.delete('/api/auth/passkey/:id', authService.requireOwnerAuth, handlePasskeyDelete);
app.delete('/api/auth/passkey/credentials/:id', authService.requireOwnerAuth, handlePasskeyDelete);

// -----------------------------------------------------------------------------
// 3. PROTECTED RECEIPT SCANNING, OCR & CONFIRMATION
// -----------------------------------------------------------------------------

// Upload receipt photo/PDF -> Private Drive archive -> Billing-free OCR draft
app.post('/api/receipts/upload', authService.requireOwnerAuth, upload.single('receipt'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Receipt file is required' });
    }

    const draft = await receiptService.createReceiptDraft({
      fileBuffer: req.file.buffer,
      filename: req.file.originalname,
      mimeType: req.file.mimetype,
      userEmail: req.owner.email
    });

    res.json({
      success: true,
      draft
    });
  } catch (error) {
    console.error('Error processing receipt upload:', error);
    res.status(500).json({ error: error.message });
  }
});

// List awaiting review drafts
app.get('/api/receipts/drafts', authService.requireOwnerAuth, (req, res) => {
  const drafts = receiptService.listUserDrafts(req.owner.email);
  res.json(drafts);
});

// Get draft details
app.get('/api/receipts/drafts/:id', authService.requireOwnerAuth, (req, res) => {
  const draft = receiptService.getDraft(req.params.id);
  if (!draft || draft.userEmail !== req.owner.email) {
    return res.status(404).json({ error: 'Draft not found' });
  }
  res.json(draft);
});

// Cancel draft
app.delete('/api/receipts/drafts/:id', authService.requireOwnerAuth, (req, res) => {
  const success = receiptService.cancelDraft(req.params.id, req.owner.email);
  if (success) {
    res.json({ success: true, message: 'Draft cancelled.' });
  } else {
    res.status(404).json({ error: 'Draft not found' });
  }
});

// Explicit confirmation: user reviews fields and explicitly posts to Google Sheets
const handleReceiptConfirm = async (req, res) => {
  try {
    const draftId = req.body?.draftId || req.params?.id;
    const reviewedData = req.body?.reviewedData || req.body?.overrides || {};
    if (!draftId) {
      return res.status(400).json({ error: 'draftId is required' });
    }

    const result = await receiptService.confirmDraftToSheets({
      draftId,
      reviewedData,
      userEmail: req.owner.email
    });

    res.json(result);
  } catch (error) {
    console.error('Error confirming receipt draft:', error);
    res.status(500).json({ error: error.message });
  }
};

app.post('/api/receipts/confirm', authService.requireOwnerAuth, handleReceiptConfirm);
app.post('/api/receipts/drafts/:id/confirm', authService.requireOwnerAuth, handleReceiptConfirm);

// -----------------------------------------------------------------------------
// 4. PROTECTED LIVE FINANCIAL DATA ROUTES (OWNER-ONLY)
// -----------------------------------------------------------------------------

// Apply requireOwnerAuth middleware to ALL financial endpoints below
app.use('/api', authService.requireOwnerAuth);

// Explicit connection test route
app.all('/api/connection-test', async (req, res) => {
  try {
    const state = await verifySheetsConnectivity({ forceCheck: true });
    if (state.connected) {
      res.json(state);
    } else {
      res.status(503).json(state);
    }
  } catch (error) {
    res.status(503).json({
      status: 'OFFLINE',
      connected: false,
      liveDataLayer: 'GOOGLE_SHEETS_API',
      error: {
        message: error.message,
        troubleshooting: getTroubleshootingGuidance(error)
      }
    });
  }
});

// Live data test read endpoint
app.get('/api/test-query', async (req, res) => {
  try {
    const txs = await getTransactions(50);
    const totalVolumeZar = txs.reduce((sum, t) => sum + (Number(t.reportingAmountZar) || 0), 0);
    res.json({
      status: 'SUCCESS',
      source: 'GOOGLE_SHEETS_LIVE',
      spreadsheetId: REPO_CONFIG.spreadsheetId,
      result: {
        query_time: new Date().toISOString(),
        total_transactions: txs.length,
        total_volume_zar: parseFloat(totalVolumeZar.toFixed(2))
      },
      rowCount: txs.length,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error running test read from Google Sheets:', error);
    res.status(500).json({ error: error.message });
  }
});

// Live FX rates
app.get('/api/rates', async (req, res) => {
  try {
    const rates = await getExchangeRates();
    res.json(rates);
  } catch (error) {
    console.error('Error fetching FX rates:', error);
    res.status(500).json({ error: error.message });
  }
});

// Accounts & Live balances
app.get('/api/accounts', async (req, res) => {
  try {
    const includeArchived = req.query.includeArchived === 'true';
    const accounts = await getAccounts({ includeArchived });
    res.json(accounts);
  } catch (error) {
    console.error('Error fetching accounts:', error);
    res.status(500).json({ error: error.message });
  }
});

// Create new account
app.post('/api/accounts', async (req, res) => {
  try {
    const {
      accountName,
      financialInstitution,
      countryCode,
      primaryCurrency,
      cashFlowTier,
      accountType,
      isVaultLocked,
      withdrawalNoticeDays,
      accountNumberMasked
    } = req.body;

    if (!accountName || typeof accountName !== 'string' || !accountName.trim()) {
      return res.status(400).json({ error: 'Account name is required' });
    }

    const result = await createAccount({
      accountName: accountName.trim(),
      financialInstitution,
      countryCode,
      primaryCurrency,
      cashFlowTier,
      accountType,
      isVaultLocked,
      withdrawalNoticeDays,
      accountNumberMasked
    });
    res.status(201).json(result);
  } catch (error) {
    console.error('Error creating account:', error);
    res.status(400).json({ error: error.message });
  }
});

// Update account
app.patch('/api/accounts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await updateAccount(id, req.body);
    res.json(result);
  } catch (error) {
    console.error(`Error updating account ${req.params.id}:`, error);
    res.status(400).json({ error: error.message });
  }
});

// Archive account (soft-archive preserves linked transactions)
app.delete('/api/accounts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await archiveAccount(id);
    res.json(result);
  } catch (error) {
    console.error(`Error archiving account ${req.params.id}:`, error);
    res.status(400).json({ error: error.message });
  }
});

// Ledger Transactions
app.get('/api/transactions', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || '100', 10);
    const transactions = await getTransactions(limit);
    res.json(transactions);
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({ error: error.message });
  }
});

// Insert new transaction
app.post('/api/transactions', async (req, res) => {
  try {
    const result = await insertTransaction(req.body);
    res.json(result);
  } catch (error) {
    console.error('Error inserting transaction:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete transaction
app.delete('/api/transactions/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await deleteTransaction(id);
    res.json(result);
  } catch (error) {
    console.error(`Error deleting transaction ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Debt & Credit Ledger endpoints
app.get('/api/debts', async (req, res) => {
  try {
    const { status } = req.query;
    const debts = await getDebts(status);
    res.json(debts);
  } catch (error) {
    console.error('Error fetching debts:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/debts/balances', async (req, res) => {
  try {
    const { person } = req.query;
    const balances = await getDebtBalances(person);
    res.json(balances);
  } catch (error) {
    console.error('Error fetching debt balances:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/debts', async (req, res) => {
  try {
    const result = await insertDebt(req.body);
    res.json(result);
  } catch (error) {
    console.error('Error creating debt record:', error);
    res.status(500).json({ error: error.message });
  }
});

// Settle Debt
app.patch('/api/debts/:id/settle', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await settleDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error settling debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Reopen / Undo Settle Debt
app.patch('/api/debts/:id/reopen', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await reopenDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error reopening debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/debts/:id/reopen', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await reopenDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error reopening debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Delete Debt
app.delete('/api/debts/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await deleteDebt(id);
    res.json(result);
  } catch (error) {
    console.error(`Error deleting debt ${req.params.id}:`, error);
    res.status(500).json({ error: error.message });
  }
});

// Google Sheets Configuration endpoint
app.get('/api/sheets/config', (req, res) => {
  res.json({
    spreadsheetId: REPO_CONFIG.spreadsheetId,
    transactionsTab: REPO_CONFIG.transactionsTab,
    debtsTab: REPO_CONFIG.debtsTab,
    accountsTab: REPO_CONFIG.accountsTab,
    categoriesTab: REPO_CONFIG.categoriesTab,
    budgetsTab: REPO_CONFIG.budgetsTab,
    ratesTab: REPO_CONFIG.ratesTab,
    readMode: 'GOOGLE_SHEETS_API',
    writeMode: 'GOOGLE_SHEETS_API',
    bigqueryBillingRequired: false
  });
});

app.post('/api/sheets/configure-external-tables', async (req, res) => {
  res.json({
    success: true,
    spreadsheetId: REPO_CONFIG.spreadsheetId,
    message: 'Google Sheets is the authoritative live data layer. BigQuery external tables bypassed.'
  });
});

// Budget Envelopes vs Actual
app.get('/api/budgets', async (req, res) => {
  try {
    const envelopes = await getBudgetEnvelopes();
    res.json(envelopes);
  } catch (error) {
    console.error('Error fetching budgets:', error);
    res.status(500).json({ error: error.message });
  }
});

// Upsert budget envelope allocation
const handleUpsertBudget = async (req, res) => {
  try {
    const {
      categoryId,
      allocationMonth,
      plannedAmount,
      targetCurrency,
      cashFlowTier,
      isFixedObligation,
      notes
    } = req.body;

    if (!categoryId || !allocationMonth) {
      return res.status(400).json({ error: 'categoryId and allocationMonth are required' });
    }

    const result = await upsertBudgetAllocation({
      categoryId,
      allocationMonth,
      plannedAmount,
      targetCurrency,
      cashFlowTier,
      isFixedObligation,
      notes
    });
    res.json(result);
  } catch (error) {
    console.error('Error upserting budget allocation:', error);
    res.status(400).json({ error: error.message });
  }
};

app.post('/api/budgets', handleUpsertBudget);
app.post('/api/budgets/allocate', handleUpsertBudget);

// Tax Schedule
app.get('/api/tax-schedule', async (req, res) => {
  try {
    const schedule = await getTaxSchedule();
    res.json(schedule);
  } catch (error) {
    console.error('Error fetching tax schedule:', error);
    res.status(500).json({ error: error.message });
  }
});

// Vault holdings & Net Worth
app.get('/api/vault', async (req, res) => {
  try {
    const vault = await getVaultHoldings();
    res.json(vault);
  } catch (error) {
    console.error('Error fetching vault holdings:', error);
    res.status(500).json({ error: error.message });
  }
});

// Daily Burn Metrics & Runway Summary
app.get('/api/burn-rate', async (req, res) => {
  try {
    const burn = await getBurnRateSummary();
    res.json(burn);
  } catch (error) {
    console.error('Error fetching burn metrics:', error);
    res.status(500).json({ error: error.message });
  }
});

// Gemini AI Copilot Insights
app.get('/api/copilot/insights', async (req, res) => {
  try {
    const insights = await getCopilotInsights();
    res.json(insights);
  } catch (error) {
    console.error('Error generating Copilot insights:', error);
    res.status(500).json({ error: error.message });
  }
});

// Gemini AI Copilot Chat
app.post('/api/copilot/chat', async (req, res) => {
  try {
    const { prompt, apiKey } = req.body;
    const response = await chatWithCopilot({ prompt, apiKey });
    res.json(response);
  } catch (error) {
    console.error('Error in Copilot chat:', error);
    res.status(500).json({ error: error.message });
  }
});

// Analytics: Structured Income Statements
app.get('/api/analytics/income-statement', async (req, res) => {
  try {
    const periodType = req.query.periodType || null;
    const statements = await getIncomeStatements(periodType);
    res.json(statements);
  } catch (error) {
    console.error('Error fetching income statements:', error);
    res.status(500).json({ error: error.message });
  }
});

// Analytics: Non-Operating Gains
app.get('/api/analytics/non-operating-gains', async (req, res) => {
  try {
    const gains = await getNonOperatingGains();
    res.json(gains);
  } catch (error) {
    console.error('Error fetching non-operating gains:', error);
    res.status(500).json({ error: error.message });
  }
});

// Analytics: Consolidated Performance Summary
app.get('/api/analytics/summary', async (req, res) => {
  try {
    const summary = await getPerformanceSummary();
    res.json(summary);
  } catch (error) {
    console.error('Error fetching analytics summary:', error);
    res.status(500).json({ error: error.message });
  }
});

if (require.main === module) {
  app.listen(PORT, async () => {
    console.log(`=======================================================`);
    console.log(` Ziva Finance Server running on port ${PORT}`);
    console.log(` Owner Email: ${authService.OWNER_EMAIL}`);
    console.log(` Live Architecture: Google Sheets API v4`);
    console.log(` Authentication: Owner-only Google OAuth & WebAuthn Passkeys`);
    console.log(`=======================================================`);

    // Verify Google Sheets connectivity on boot
    try {
      console.log('[Startup Check] Verifying Google Sheets connectivity...');
      const connState = await verifySheetsConnectivity({ forceCheck: true });
      if (connState.connected) {
        console.log(`[Startup Check] Google Sheets connected successfully (Spreadsheet: ${connState.spreadsheetId})`);
      } else {
        console.warn(`[Startup Check] Google Sheets connectivity warning: ${connState.error?.message || 'Check credentials'}`);
      }
    } catch (err) {
      console.warn('[Startup Check] Note on Google Sheets check:', err.message);
    }
  });
}

module.exports = app;
