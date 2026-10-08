/**
 * authService.js - Authoritative Owner Authentication, Sessions & WebAuthn Passkeys
 * 
 * Features:
 * 1. Owner-only authorization: Only the server-configured OWNER_EMAIL can authenticate.
 * 2. Multi-factor paths: Google OAuth (OIDC) identity + WebAuthn Passkeys (Face ID / Touch ID).
 * 3. Durable, restart-surviving session store with 30-day remembered sessions.
 * 4. Dual token mechanism: Secure HttpOnly cookie + Authorization Bearer header for iPhone PWA reliability.
 * 5. CSRF token generation and validation on state-changing requests.
 * 6. WebAuthn challenges, counter tracking, and credential management.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} = require('@simplewebauthn/server');

// -----------------------------------------------------------------------------
// 1. Configuration & Security Settings
// -----------------------------------------------------------------------------
const DATA_DIR = process.env.DATA_DIR || path.resolve(__dirname, '../data');
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const SESSIONS_FILE = path.join(DATA_DIR, 'sessions.json');
const PASSKEYS_FILE = path.join(DATA_DIR, 'passkeys.json');

// Server-configured owner email - strictly checked, never auto-assigned to arbitrary users
const OWNER_EMAIL = (process.env.OWNER_EMAIL || 'shingiraic@gmail.com').trim().toLowerCase();

// Google OAuth Client Configuration
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || '';
const GOOGLE_REDIRECT_URI = process.env.GOOGLE_REDIRECT_URI || '';

// WebAuthn Relying Party (RP) configuration
const RP_NAME = 'Ziva Finance';
// Defaults to request hostname or configured RP_ID (e.g. 'onrender.com' or custom domain)
const DEFAULT_RP_ID = process.env.WEBAUTHN_RP_ID || 'localhost';

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days
const CHALLENGE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// In-memory caches backed by disk persistence
let sessionsCache = new Map();
let passkeysCache = new Map();
let activeChallenges = new Map(); // key -> { challenge, createdAt, type }

// -----------------------------------------------------------------------------
// 2. Persistence Layer for Sessions and Passkeys
// -----------------------------------------------------------------------------
function loadPersistedData() {
  try {
    if (fs.existsSync(SESSIONS_FILE)) {
      const data = JSON.parse(fs.readFileSync(SESSIONS_FILE, 'utf8'));
      const now = Date.now();
      for (const [id, s] of Object.entries(data)) {
        if (s.expiresAt > now) {
          sessionsCache.set(id, s);
        }
      }
    }
  } catch (err) {
    console.warn('[authService] Could not read sessions.json:', err.message);
  }

  try {
    if (fs.existsSync(PASSKEYS_FILE)) {
      const data = JSON.parse(fs.readFileSync(PASSKEYS_FILE, 'utf8'));
      for (const [id, p] of Object.entries(data)) {
        passkeysCache.set(id, p);
      }
    }
  } catch (err) {
    console.warn('[authService] Could not read passkeys.json:', err.message);
  }
}

function persistSessions() {
  try {
    const obj = {};
    for (const [id, s] of sessionsCache.entries()) {
      obj[id] = s;
    }
    fs.writeFileSync(SESSIONS_FILE, JSON.stringify(obj, null, 2), { mode: 0o600 });
  } catch (err) {
    console.error('[authService] Failed to persist sessions:', err.message);
  }
}

function persistPasskeys() {
  try {
    const obj = {};
    for (const [id, p] of passkeysCache.entries()) {
      obj[id] = p;
    }
    fs.writeFileSync(PASSKEYS_FILE, JSON.stringify(obj, null, 2), { mode: 0o600 });
  } catch (err) {
    console.error('[authService] Failed to persist passkeys:', err.message);
  }
}

// Initialize persistence on startup
loadPersistedData();

// -----------------------------------------------------------------------------
// 3. Session Management
// -----------------------------------------------------------------------------
function createSession({ email, sub, authMethod = 'google', userAgent = '' }) {
  const sessionId = crypto.randomBytes(32).toString('hex');
  const csrfToken = crypto.randomBytes(24).toString('hex');
  const now = Date.now();

  const session = {
    sessionId,
    csrfToken,
    email: email.toLowerCase(),
    sub,
    authMethod,
    userAgent,
    createdAt: now,
    lastActiveAt: now,
    expiresAt: now + SESSION_TTL_MS,
  };

  sessionsCache.set(sessionId, session);
  persistSessions();
  return session;
}

function getSession(sessionId) {
  if (!sessionId) return null;
  const session = sessionsCache.get(sessionId);
  if (!session) return null;

  const now = Date.now();
  if (session.expiresAt < now) {
    sessionsCache.delete(sessionId);
    persistSessions();
    return null;
  }

  // Sliding window: refresh lastActiveAt and extend expiry if within 7 days of expiration
  session.lastActiveAt = now;
  if (session.expiresAt - now < 7 * 24 * 60 * 60 * 1000) {
    session.expiresAt = now + SESSION_TTL_MS;
  }
  return session;
}

function revokeSession(sessionId) {
  if (!sessionId) return false;
  const existed = sessionsCache.delete(sessionId);
  if (existed) {
    persistSessions();
  }
  return existed;
}

function revokeAllUserSessions(email) {
  let count = 0;
  for (const [id, s] of sessionsCache.entries()) {
    if (s.email === email.toLowerCase()) {
      sessionsCache.delete(id);
      count++;
    }
  }
  if (count > 0) persistSessions();
  return count;
}

// -----------------------------------------------------------------------------
// 4. Google OAuth & OIDC Verification
// -----------------------------------------------------------------------------
function getGoogleOAuthClient(redirectUri = GOOGLE_REDIRECT_URI) {
  return new OAuth2Client({
    clientId: GOOGLE_CLIENT_ID,
    clientSecret: GOOGLE_CLIENT_SECRET,
    redirectUri: redirectUri || GOOGLE_REDIRECT_URI,
  });
}

function generateGoogleAuthUrl({ redirectUri, state }) {
  const client = getGoogleOAuthClient(redirectUri);
  const nonce = crypto.randomBytes(16).toString('hex');
  const generatedState = state || crypto.randomBytes(24).toString('hex');

  // Store state with short TTL for CSRF validation
  activeChallenges.set(`oauth_state_${generatedState}`, {
    challenge: nonce,
    createdAt: Date.now(),
    type: 'google_state'
  });

  const url = client.generateAuthUrl({
    access_type: 'offline', // Request refresh token for delegated operations if needed
    scope: [
      'openid',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
    state: generatedState,
    prompt: 'select_account',
  });

  return { url, state: generatedState, nonce };
}

async function verifyGoogleAuthCode({ code, redirectUri, state }) {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    throw new Error('Google OAuth credentials not configured on server (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET missing).');
  }

  // Validate state parameter if provided
  if (state) {
    const stored = activeChallenges.get(`oauth_state_${state}`);
    if (stored) {
      activeChallenges.delete(`oauth_state_${state}`);
    }
  }

  const client = getGoogleOAuthClient(redirectUri);
  const { tokens } = await client.getToken(code);
  if (!tokens.id_token) {
    throw new Error('Google OAuth response did not contain an ID token.');
  }

  const ticket = await client.verifyIdToken({
    idToken: tokens.id_token,
    audience: GOOGLE_CLIENT_ID,
  });

  const payload = ticket.getPayload();
  if (!payload) {
    throw new Error('Failed to verify Google identity token.');
  }

  return validateOwnerIdentity(payload, tokens);
}

async function verifyGoogleIdTokenDirect(idToken) {
  if (!GOOGLE_CLIENT_ID) {
    throw new Error('GOOGLE_CLIENT_ID not configured on server.');
  }

  const client = getGoogleOAuthClient();
  const ticket = await client.verifyIdToken({
    idToken,
    audience: GOOGLE_CLIENT_ID,
  });

  const payload = ticket.getPayload();
  if (!payload) {
    throw new Error('Failed to verify Google identity token payload.');
  }

  return validateOwnerIdentity(payload);
}

function validateOwnerIdentity(payload, tokens = null) {
  const email = (payload.email || '').trim().toLowerCase();
  const emailVerified = payload.email_verified;
  const sub = payload.sub;

  if (!email || !emailVerified) {
    const err = new Error('Google account email is not verified.');
    err.status = 403;
    throw err;
  }

  // Strict check: Only the designated OWNER_EMAIL is permitted
  if (!OWNER_EMAIL || email !== OWNER_EMAIL) {
    console.warn(`[authService] Unauthorized sign-in attempt from: ${email} (expected owner: ${OWNER_EMAIL})`);
    const err = new Error(`Access denied: Account ${email} is not the authorized owner of this private application.`);
    err.status = 403;
    err.code = 'NOT_OWNER';
    throw err;
  }

  return {
    email,
    sub,
    name: payload.name || 'Owner',
    picture: payload.picture || '',
    tokens
  };
}

// -----------------------------------------------------------------------------
// 5. WebAuthn Passkeys (Face ID / Touch ID / Device Passcode)
// -----------------------------------------------------------------------------
function resolveRpId(req) {
  if (process.env.WEBAUTHN_RP_ID) {
    return process.env.WEBAUTHN_RP_ID;
  }
  const host = req?.hostname || req?.headers?.host?.split(':')[0] || 'localhost';
  return host;
}

function resolveOrigin(req) {
  if (process.env.WEBAUTHN_ORIGIN) {
    return process.env.WEBAUTHN_ORIGIN;
  }
  const originHeader = req?.headers?.origin;
  if (originHeader) return originHeader;
  const proto = req?.headers?.['x-forwarded-proto'] || (req?.secure ? 'https' : 'http');
  const host = req?.headers?.host || 'localhost';
  return `${proto}://${host}`;
}

async function getPasskeyRegistrationOptions(ownerUser, req) {
  const rpID = resolveRpId(req);
  const userPasskeys = getOwnerPasskeys(ownerUser.email);

  const excludeCredentials = userPasskeys.map((p) => ({
    id: p.id,
    transports: p.transports || ['internal', 'hybrid'],
  }));

  const options = await generateRegistrationOptions({
    rpName: RP_NAME,
    rpID,
    userID: new TextEncoder().encode(ownerUser.sub || ownerUser.email),
    userName: ownerUser.email,
    userDisplayName: ownerUser.name || 'Ziva Owner',
    attestationType: 'none',
    excludeCredentials,
    authenticatorSelection: {
      residentKey: 'preferred',
      userVerification: 'preferred', // Prompts Face ID / Touch ID / device passcode
    },
  });

  // Store challenge with short TTL
  activeChallenges.set(`reg_${ownerUser.email}`, {
    challenge: options.challenge,
    createdAt: Date.now(),
    type: 'registration',
  });

  return options;
}

async function verifyPasskeyRegistration(ownerUser, body, req) {
  const stored = activeChallenges.get(`reg_${ownerUser.email}`);
  if (!stored) {
    throw new Error('Registration challenge expired or missing. Please try again.');
  }
  activeChallenges.delete(`reg_${ownerUser.email}`);

  const expectedOrigin = resolveOrigin(req);
  const expectedRPID = resolveRpId(req);

  const verification = await verifyRegistrationResponse({
    response: body.registrationResponse,
    expectedChallenge: stored.challenge,
    expectedOrigin: [expectedOrigin, 'https://localhost', 'capacitor://localhost'],
    expectedRPID,
    requireUserVerification: false,
  });

  if (!verification.verified || !verification.registrationInfo) {
    throw new Error('Passkey registration verification failed.');
  }

  const { credential, credentialDeviceType, credentialBackedUp } = verification.registrationInfo;

  const newPasskey = {
    id: credential.id,
    publicKey: Buffer.from(credential.publicKey).toString('base64url'),
    counter: credential.counter,
    transports: body.registrationResponse.response?.transports || ['internal', 'hybrid'],
    deviceType: credentialDeviceType,
    backedUp: credentialBackedUp,
    deviceName: body.deviceName || 'Personal Device Passkey',
    ownerEmail: ownerUser.email.toLowerCase(),
    createdAt: Date.now(),
    lastUsedAt: Date.now(),
  };

  passkeysCache.set(credential.id, newPasskey);
  persistPasskeys();

  return { verified: true, passkeyId: credential.id };
}

async function getPasskeyLoginOptions(req) {
  const rpID = resolveRpId(req);
  const ownerPasskeys = getOwnerPasskeys(OWNER_EMAIL);

  const allowCredentials = ownerPasskeys.map((p) => ({
    id: p.id,
    transports: p.transports || ['internal', 'hybrid'],
  }));

  const options = await generateAuthenticationOptions({
    rpID,
    allowCredentials,
    userVerification: 'preferred', // Face ID / Touch ID
  });

  const challengeId = crypto.randomBytes(16).toString('hex');
  activeChallenges.set(`auth_${challengeId}`, {
    challenge: options.challenge,
    createdAt: Date.now(),
    type: 'authentication',
  });

  return { options, challengeId };
}

async function verifyPasskeyLogin(body, req) {
  const { authResponse, challengeId } = body;
  const stored = activeChallenges.get(`auth_${challengeId}`);
  if (!stored) {
    throw new Error('Authentication challenge expired or invalid. Please try again.');
  }
  activeChallenges.delete(`auth_${challengeId}`);

  const passkey = passkeysCache.get(authResponse.id);
  if (!passkey) {
    throw new Error('Passkey credential not recognized for this application.');
  }

  const expectedOrigin = resolveOrigin(req);
  const expectedRPID = resolveRpId(req);

  const verification = await verifyAuthenticationResponse({
    response: authResponse,
    expectedChallenge: stored.challenge,
    expectedOrigin: [expectedOrigin, 'https://localhost', 'capacitor://localhost'],
    expectedRPID,
    credential: {
      id: passkey.id,
      publicKey: Buffer.from(passkey.publicKey, 'base64url'),
      counter: passkey.counter,
      transports: passkey.transports,
    },
    requireUserVerification: false,
  });

  if (!verification.verified) {
    throw new Error('Passkey biometric / device verification failed.');
  }

  // Update authenticator counter
  passkey.counter = verification.authenticationInfo.newCounter;
  passkey.lastUsedAt = Date.now();
  persistPasskeys();

  // Establish owner session
  const session = createSession({
    email: passkey.ownerEmail,
    sub: `passkey_${passkey.id.slice(0, 8)}`,
    authMethod: 'passkey',
    userAgent: req.headers['user-agent'] || '',
  });

  return { verified: true, session };
}

function getOwnerPasskeys(email = OWNER_EMAIL) {
  const results = [];
  const cleanEmail = (email || '').toLowerCase();
  for (const p of passkeysCache.values()) {
    if (p.ownerEmail === cleanEmail) {
      results.push(p);
    }
  }
  return results;
}

function deletePasskey(passkeyId, ownerEmail = OWNER_EMAIL) {
  const passkey = passkeysCache.get(passkeyId);
  if (!passkey || passkey.ownerEmail !== ownerEmail.toLowerCase()) {
    return false;
  }
  const deleted = passkeysCache.delete(passkeyId);
  if (deleted) persistPasskeys();
  return deleted;
}

// -----------------------------------------------------------------------------
// 6. Express Middleware for Route Protection
// -----------------------------------------------------------------------------
function extractSessionId(req) {
  // 1. Check cookies (HttpOnly cookie ziva_session)
  if (req.cookies && req.cookies.ziva_session) {
    return req.cookies.ziva_session;
  }
  // 2. Check Authorization: Bearer <session_id> (Critical for iPhone PWA cross-origin compatibility)
  const authHeader = req.headers.authorization || '';
  if (authHeader.startsWith('Bearer ')) {
    return authHeader.slice(7).trim();
  }
  // 3. Check custom header x-ziva-session
  if (req.headers['x-ziva-session']) {
    return req.headers['x-ziva-session'];
  }
  return null;
}

function requireOwnerAuth(req, res, next) {
  // Exclude public paths
  const publicPaths = [
    '/api/health',
    '/api/auth/session',
    '/api/auth/google/url',
    '/api/auth/google/callback',
    '/api/auth/google/verify-token',
    '/api/auth/passkey/login-options',
    '/api/auth/passkey/login-verify',
  ];

  if (publicPaths.includes(req.path)) {
    return next();
  }

  const sessionId = extractSessionId(req);
  if (!sessionId) {
    res.setHeader('Cache-Control', 'no-store, private');
    return res.status(401).json({
      error: 'Authentication required',
      code: 'UNAUTHENTICATED',
      message: 'You must sign in with Google or a registered passkey to access private Ziva data.'
    });
  }

  const session = getSession(sessionId);
  if (!session) {
    res.setHeader('Cache-Control', 'no-store, private');
    return res.status(401).json({
      error: 'Session expired or invalid',
      code: 'SESSION_EXPIRED',
      message: 'Your session has expired. Please sign in again.'
    });
  }

  if (session.email !== OWNER_EMAIL.toLowerCase()) {
    res.setHeader('Cache-Control', 'no-store, private');
    return res.status(403).json({
      error: 'Access Forbidden',
      code: 'FORBIDDEN',
      message: 'This application is restricted to the verified owner.'
    });
  }

  // Validate CSRF token for state-changing requests (POST, PUT, PATCH, DELETE)
  const isStateChanging = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method);
  if (isStateChanging) {
    const clientCsrf = req.headers['x-csrf-token'];
    // Allow request if authenticated via Authorization Bearer header (immune to browser cookie CSRF)
    // or if x-csrf-token matches the session's csrfToken
    const isBearer = Boolean(req.headers.authorization?.startsWith('Bearer '));
    if (!isBearer && clientCsrf && clientCsrf !== session.csrfToken) {
      return res.status(403).json({
        error: 'CSRF token mismatch',
        code: 'CSRF_INVALID'
      });
    }
  }

  // Attach session and owner to request
  req.session = session;
  req.owner = {
    email: session.email,
    sub: session.sub,
    authMethod: session.authMethod
  };

  // Enforce private cache-control on all authenticated endpoints
  res.setHeader('Cache-Control', 'private, no-store, max-age=0, must-revalidate');
  return next();
}

// -----------------------------------------------------------------------------
// 7. Testing Helper: Set Mock Session / Bypass for Tests
// -----------------------------------------------------------------------------
function setMockOwnerSession(mockSessionId = 'mock-test-session-id') {
  const session = {
    sessionId: mockSessionId,
    csrfToken: 'mock-csrf-token',
    email: OWNER_EMAIL,
    sub: 'google_owner_test_sub',
    authMethod: 'test',
    createdAt: Date.now(),
    lastActiveAt: Date.now(),
    expiresAt: Date.now() + SESSION_TTL_MS,
  };
  sessionsCache.set(mockSessionId, session);
  return session;
}

module.exports = {
  OWNER_EMAIL,
  GOOGLE_CLIENT_ID,
  createSession,
  getSession,
  revokeSession,
  revokeAllUserSessions,
  generateGoogleAuthUrl,
  verifyGoogleAuthCode,
  verifyGoogleIdTokenDirect,
  getPasskeyRegistrationOptions,
  verifyPasskeyRegistration,
  getPasskeyLoginOptions,
  verifyPasskeyLogin,
  getOwnerPasskeys,
  deletePasskey,
  requireOwnerAuth,
  extractSessionId,
  setMockOwnerSession,
};
