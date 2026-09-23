'use strict';

const crypto = require('node:crypto');

const {
  getAdmin,
  clientIp,
  cappedHttps,
  requireAppCheck,
  requireAuth,
} = require('./common.js');
const {
  isValidPasscodeFormat,
  normalizePasscode,
  advanceAttemptBudget,
} = require('./auth_core.js');

const COUPLE_USERNAMES = new Set(['khentsgdz', 'clairjassen']);
const _pcAttempts = new Map();
const _PC_WINDOW_MS = 15 * 60 * 1000;
const _PC_LOCK_MS = 30 * 60 * 1000;
const _PC_IP_MAX_FAILS = 10;
const _PC_GLOBAL_MAX_FAILS = 30;

function _pcHit(ip) {
  const now = Date.now();
  const attempts = (_pcAttempts.get(ip) || []).filter(
    (timestamp) => now - timestamp < 60_000,
  );
  attempts.push(now);
  _pcAttempts.set(ip, attempts);
  if (_pcAttempts.size > 400) _pcAttempts.clear();
  return attempts.length > 8;
}

function _sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function _passcodeMatches(code, expected) {
  if (!expected) return false;
  const actualHash = crypto.createHash('sha256').update(String(code)).digest();
  const expectedHash = crypto
    .createHash('sha256')
    .update(String(expected))
    .digest();
  return crypto.timingSafeEqual(actualHash, expectedHash);
}

function _cors(req, res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Firebase-AppCheck',
  );
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }
  return false;
}

async function _recordGatewayAttempt(ipHash, failed) {
  const db = getAdmin().firestore();
  const ipRef = db.collection('auth_attempts').doc(`gateway-ip-${ipHash}`);
  const globalRef = db.collection('auth_attempts').doc('gateway-global');

  return db.runTransaction(async (tx) => {
    const now = Date.now();
    const [ipSnapshot, globalSnapshot] = await Promise.all([
      tx.get(ipRef),
      tx.get(globalRef),
    ]);
    const ipBudget = advanceAttemptBudget(
      ipSnapshot.data(),
      {
        now,
        maxFails: _PC_IP_MAX_FAILS,
        windowMs: _PC_WINDOW_MS,
        lockMs: _PC_LOCK_MS,
      },
      failed,
    );
    const globalBudget = advanceAttemptBudget(
      globalSnapshot.data(),
      {
        now,
        maxFails: _PC_GLOBAL_MAX_FAILS,
        windowMs: _PC_WINDOW_MS,
        lockMs: _PC_LOCK_MS,
      },
      failed,
    );
    const lockedUntil = Math.max(ipBudget.lockedUntil, globalBudget.lockedUntil);
    if (lockedUntil > now) {
      return { locked: true, lockedUntil };
    }

    if (failed) {
      tx.set(
        ipRef,
        {
          fails: ipBudget.fails,
          firstFailAt: ipBudget.firstFailAt,
          lockedUntil: ipBudget.lockedUntil,
          updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        globalRef,
        {
          fails: globalBudget.fails,
          firstFailAt: globalBudget.firstFailAt,
          lockedUntil: globalBudget.lockedUntil,
          updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else {
      tx.set(
        ipRef,
        {
          fails: 0,
          firstFailAt: now,
          lockedUntil: 0,
          updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    return { locked: false, lockedUntil: 0 };
  });
}

function _identityForEmail(email) {
  const normalized = String(email || '').trim().toLowerCase();
  if (!normalized) return null;
  const configured = [
    ['clairjassen', process.env.CLAIR_EMAIL, 'couple'],
    ['khentsgdz', process.env.KHENT_EMAIL, 'couple'],
    ['breyan', process.env.BREYAN_EMAIL, 'cinema'],
    ['octagram', process.env.OCTAGRAM_EMAIL, 'cinema'],
  ];
  for (const [username, configuredEmail, role] of configured) {
    if (String(configuredEmail || '').trim().toLowerCase() === normalized) {
      return { username, role };
    }
  }
  return null;
}

async function _setIdentityClaims(user, username, role) {
  await getAdmin()
    .auth()
    .setCustomUserClaims(user.uid, {
      ...(user.customClaims || {}),
      role,
      username,
    });
  const partnerUsername = COUPLE_USERNAMES.has(username)
    ? username === 'khentsgdz'
      ? 'clairjassen'
      : 'khentsgdz'
    : null;
  const db = getAdmin().firestore();
  await db.collection('users').doc(user.uid).set(
    {
      username,
      role,
      partnerUsername,
      updatedAt: db.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  // Remove the pre-multi-device singleton. Admin is required because the
  // legacy document has no uid field and new Firestore rules deny deletes.
  await db.collection('fcm_tokens').doc(username).delete();
}

async function _coupleUser(username) {
  const email = String(
    username === 'clairjassen'
      ? process.env.CLAIR_EMAIL
      : process.env.KHENT_EMAIL,
  ).trim();
  if (!email) throw new Error('Server not configured');
  const auth = getAdmin().auth();
  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    console.log(`verifyPasscode: creating configured account ${username}`);
    return auth.createUser({
      email,
      emailVerified: true,
      displayName: username,
    });
  }
}

const verifyPasscode = cappedHttps(10, async (req, res) => {
  if (_cors(req, res)) return;
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }
  if (!(await requireAppCheck(req, res, { consume: true }))) return;

  const ip = clientIp(req);
  if (_pcHit(ip)) {
    res.status(429).json({ error: 'Too many attempts' });
    return;
  }

  const code = normalizePasscode(req.body?.passcode);
  const clair = normalizePasscode(process.env.CLAIR_PASSCODE);
  const khent = normalizePasscode(process.env.KHENT_PASSCODE);
  if (
    !isValidPasscodeFormat(clair) ||
    !isValidPasscodeFormat(khent) ||
    !isValidPasscodeFormat(code)
  ) {
    res.status(400).json({ error: 'A valid 16+ character passphrase is required' });
    return;
  }

  let username = '';
  if (_passcodeMatches(code, clair)) username = 'clairjassen';
  else if (_passcodeMatches(code, khent)) username = 'khentsgdz';

  let budget;
  try {
    budget = await _recordGatewayAttempt(_sha256Hex(ip), !username);
  } catch (error) {
    console.error('[verifyPasscode] attempt budget failed closed:', error);
    res.status(503).json({ error: 'Login is temporarily unavailable' });
    return;
  }
  if (budget.locked) {
    res.set('Retry-After', String(Math.ceil((budget.lockedUntil - Date.now()) / 1000)));
    res.status(429).json({ error: 'Too many attempts — try again later' });
    return;
  }
  if (!username) {
    res.status(401).json({ error: 'Invalid passphrase' });
    return;
  }

  try {
    const user = await _coupleUser(username);
    await _setIdentityClaims(user, username, 'couple');
    const token = await getAdmin()
      .auth()
      .createCustomToken(user.uid, { role: 'couple', username });
    res.json({ token, username });
  } catch (error) {
    console.error('verifyPasscode', error.code || error.message, error.stack || '');
    res.status(500).json({ error: 'Auth failed' });
  }
});

const bootstrapProfile = cappedHttps(10, async (req, res) => {
  if (_cors(req, res)) return;
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }
  if (!(await requireAppCheck(req, res))) return;
  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const identity = _identityForEmail(decoded.email);
  if (!identity) {
    res.status(403).json({ error: 'Account is not provisioned' });
    return;
  }

  try {
    const user = await getAdmin().auth().getUser(decoded.uid);
    await _setIdentityClaims(user, identity.username, identity.role);
    res.json(identity);
  } catch (error) {
    console.error('[bootstrapProfile]', error);
    res.status(500).json({ error: 'Profile bootstrap failed' });
  }
});

module.exports = { verifyPasscode, bootstrapProfile };
