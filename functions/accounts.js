'use strict';

const crypto = require('node:crypto');
const { promisify } = require('node:util');

const scryptAsync = promisify(crypto.scrypt);

const { getAdmin, clientIp, cappedHttps, applyCors, requireAuth } = require('./common.js');
const {
  normalizeUsername,
  isValidUsername,
  isReservedUsername,
  trustedProfileUsername,
} = require('./auth_core.js');
const { _pcLockoutAttempt } = require('./passcode.js');

const MIN_PASSWORD_LEN = 6;
const MAX_PASSWORD_LEN = 128;
const SCRYPT_KEYLEN = 64;

const _acctAttempts = new Map();
function _acctHit(ip, maxPerMinute = 10) {
  const now = Date.now();
  const recent = (_acctAttempts.get(ip) || []).filter((t) => now - t < 60_000);
  recent.push(now);
  _acctAttempts.delete(ip);
  _acctAttempts.set(ip, recent);
  if (_acctAttempts.size > 400) {
    for (const [k, times] of _acctAttempts) {
      if (times.length === 0 || now - times[times.length - 1] >= 60_000) {
        _acctAttempts.delete(k);
      }
    }
    while (_acctAttempts.size > 400) {
      const oldestKey = _acctAttempts.keys().next().value;
      if (oldestKey === undefined) break;
      _acctAttempts.delete(oldestKey);
    }
  }
  return recent.length > maxPerMinute;
}

function _sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const derived = crypto.scryptSync(String(password), salt, SCRYPT_KEYLEN).toString('hex');
  return { salt, hash: derived };
}

async function hashPasswordAsync(password, salt = crypto.randomBytes(16).toString('hex')) {
  const derived = (await scryptAsync(String(password), salt, SCRYPT_KEYLEN)).toString('hex');
  return { salt, hash: derived };
}

function verifyPassword(password, salt, expectedHash) {
  if (!salt || !expectedHash) return false;
  try {
    const derived = crypto.scryptSync(String(password), String(salt), SCRYPT_KEYLEN);
    const expected = Buffer.from(String(expectedHash), 'hex');
    if (derived.length !== expected.length) return false;
    return crypto.timingSafeEqual(derived, expected);
  } catch {
    return false;
  }
}

async function verifyPasswordAsync(password, salt, expectedHash) {
  if (!salt || !expectedHash) return false;
  try {
    const derived = await scryptAsync(String(password), String(salt), SCRYPT_KEYLEN);
    const expected = Buffer.from(String(expectedHash), 'hex');
    if (derived.length !== expected.length) return false;
    return crypto.timingSafeEqual(derived, expected);
  } catch {
    return false;
  }
}

async function isAccountLocked(ipRef, globalRef) {
  const now = Date.now();
  const [ipSnap, globalSnap] = await Promise.all([ipRef.get(), globalRef.get()]);
  const ipUntil = Number(ipSnap.exists ? ipSnap.data()?.lockedUntil || 0 : 0);
  const globalUntil = Number(globalSnap.exists ? globalSnap.data()?.lockedUntil || 0 : 0);
  return ipUntil > now || globalUntil > now;
}

function serializeAccount(id, data) {
  const toIso = (ts) => {
    if (!ts) return null;
    if (typeof ts.toDate === 'function') return ts.toDate().toISOString();
    if (typeof ts === 'string') return ts;
    return null;
  };
  return {
    id,
    username: String(data.username || id),
    status: String(data.status || 'pending'),
    createdAt: toIso(data.createdAt),
    approvedAt: toIso(data.approvedAt),
    approvedBy: data.approvedBy ? String(data.approvedBy) : null,
  };
}

const registerAccount = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }
  const ip = clientIp(req);
  if (_acctHit(ip, 8)) {
    res.status(429).json({ error: 'Too many attempts — try again in a minute' });
    return;
  }

  const body = req.body || {};
  const username = normalizeUsername(body.username);
  const password = String(body.password || '');
  const confirmPassword = String(body.confirmPassword || '');

  if (!isValidUsername(username)) {
    res.status(400).json({
      error: 'Username must be 3–24 characters using letters, numbers, hyphens, or underscores',
    });
    return;
  }
  if (isReservedUsername(username)) {
    res.status(400).json({ error: 'That username is reserved' });
    return;
  }
  if (password.length < MIN_PASSWORD_LEN || password.length > MAX_PASSWORD_LEN) {
    res.status(400).json({ error: `Password must be between ${MIN_PASSWORD_LEN} and ${MAX_PASSWORD_LEN} characters` });
    return;
  }
  if (password !== confirmPassword) {
    res.status(400).json({ error: 'Passwords do not match' });
    return;
  }

  const key = username.toLowerCase();
  try {
    const db = getAdmin().firestore();
    const ref = db.collection('member_accounts').doc(key);
    const { salt, hash } = await hashPasswordAsync(password);
    const now = getAdmin().firestore.FieldValue.serverTimestamp();

    const accountId = crypto.randomUUID().replace(/-/g, '');
    const authEmail = `member_${accountId}@members.everglow.local`;

    const created = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists) {
        const existing = snap.data() || {};
        if (existing.status !== 'rejected' || existing.uid) {
          return false;
        }
      }
      tx.set(ref, {
        username,
        usernameLower: key,
        accountId,
        authEmail,
        passwordHash: hash,
        passwordSalt: salt,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
        approvedAt: null,
        approvedBy: null,
      });
      return true;
    });

    if (!created) {
      res.status(409).json({ error: 'Username is already taken' });
      return;
    }

    res.status(201).json({ status: 'pending', username });
  } catch (e) {
    console.error('[registerAccount] failed:', e.code || e.message);
    res.status(500).json({ error: 'Could not create account' });
  }
});

const loginAccount = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS', 'Content-Type');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }
  const ip = clientIp(req);
  if (_acctHit(ip, 12)) {
    res.status(429).json({ error: 'Too many attempts — try again in a minute' });
    return;
  }

  const body = req.body || {};
  const username = normalizeUsername(body.username);
  const password = String(body.password || '');

  if (!username || !password) {
    res.status(400).json({ error: 'Username and password are required' });
    return;
  }

  const key = username.toLowerCase();
  try {
    const db = getAdmin().firestore();
    const attempts = db.collection('auth_attempts');
    const ipRef = attempts.doc(`acct_${_sha256Hex(ip)}`);
    const globalRef = attempts.doc('acct_global');
    try {
      if (await isAccountLocked(ipRef, globalRef)) {
        res.status(429).json({ error: 'Too many attempts — try again later' });
        return;
      }
    } catch (e) {
      console.error('[loginAccount] lockout check failed:', e.message);
      res.status(503).json({ error: 'Login temporarily unavailable' });
      return;
    }

    const ref = db.collection('member_accounts').doc(key);
    const snap = await ref.get();
    const data = snap.exists ? snap.data() || {} : null;
    const validPassword = Boolean(data && await verifyPasswordAsync(password, data.passwordSalt, data.passwordHash));

    let lock;
    try {
      lock = await _pcLockoutAttempt(db, ipRef, globalRef, validPassword);
    } catch (e) {
      console.error('[loginAccount] lockout transaction failed:', e.message);
      res.status(503).json({ error: 'Login temporarily unavailable' });
      return;
    }

    if (lock.locked) {
      res.status(429).json({ error: 'Too many attempts — try again later' });
      return;
    }
    if (!validPassword || !data) {
      res.status(401).json({ error: 'Invalid username or password' });
      return;
    }

    if (data.status === 'pending') {
      res.status(403).json({
        status: 'pending',
        error: 'Your account is pending approval. Ask Khent to approve it in the Creator Dashboard.',
      });
      return;
    }
    if (data.status !== 'approved') {
      res.status(403).json({
        status: data.status || 'rejected',
        error: 'This account is not approved to sign in.',
      });
      return;
    }

    const canonicalUsername = String(data.username || username);
    const email = typeof data.authEmail === 'string' && data.authEmail.includes('@')
      ? data.authEmail
      : `${key}@members.everglow.local`;
    let user;
    try {
      user = await getAdmin().auth().getUserByEmail(email);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        user = await getAdmin().auth().createUser({
          email,
          emailVerified: true,
          displayName: canonicalUsername,
        });
      } else {
        throw e;
      }
    }

    const nowTs = getAdmin().firestore.FieldValue.serverTimestamp();
    if (data.uid !== user.uid) {
      await ref.set({ uid: user.uid, updatedAt: nowTs }, { merge: true });
    }
    await db.collection('users').doc(user.uid).set(
      {
        username: canonicalUsername,
        partnerUsername: null,
        updatedAt: nowTs,
      },
      { merge: true },
    );

    const token = await getAdmin().auth().createCustomToken(user.uid, {
      username: canonicalUsername,
      accountType: 'member',
    });

    res.json({ token, username: canonicalUsername, accountType: 'member' });
  } catch (e) {
    console.error('[loginAccount] failed:', e.code || e.message);
    res.status(500).json({ error: 'Sign in failed' });
  }
});

const manageAccounts = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'GET, POST, OPTIONS', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const caller = trustedProfileUsername(decoded);
  if (caller !== 'khentsgdz') {
    res.status(403).json({ error: 'Creator access required' });
    return;
  }

  const db = getAdmin().firestore();
  const col = db.collection('member_accounts');

  if (req.method === 'GET') {
    try {
      const snap = await col.orderBy('createdAt', 'desc').limit(100).get();
      const accounts = snap.docs.map((d) => serializeAccount(d.id, d.data() || {}));
      res.json({ accounts });
    } catch (e) {
      console.error('[manageAccounts] list failed:', e.code || e.message);
      res.status(500).json({ error: 'Could not load accounts' });
    }
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'GET or POST only' });
    return;
  }

  const body = req.body || {};
  const action = String(body.action || '').trim().toLowerCase();
  const username = normalizeUsername(body.username);
  if (!isValidUsername(username) || !['approve', 'reject', 'revoke', 'delete'].includes(action)) {
    res.status(400).json({ error: 'Valid action and username are required' });
    return;
  }

  const key = username.toLowerCase();
  const ref = col.doc(key);
  try {
    const snap = await ref.get();
    if (!snap.exists) {
      res.status(404).json({ error: 'Account not found' });
      return;
    }
    const data = snap.data() || {};
    const now = getAdmin().firestore.FieldValue.serverTimestamp();

    if (action === 'approve') {
      await ref.update({
        status: 'approved',
        approvedAt: now,
        approvedBy: caller,
        updatedAt: now,
      });
      res.json({ ok: true, username: data.username || username, status: 'approved' });
      return;
    }

    if (action === 'reject' || action === 'revoke') {
      const nextStatus = action === 'reject' ? 'rejected' : 'pending';
      await ref.update({
        status: nextStatus,
        updatedAt: now,
      });
      if (data.uid) {
        await db.collection('users').doc(data.uid).delete().catch(() => {});
        await getAdmin().auth().revokeRefreshTokens(data.uid).catch(() => {});
      }
      res.json({ ok: true, username: data.username || username, status: nextStatus });
      return;
    }

    if (action === 'delete') {
      await ref.delete();
      if (data.uid) {
        await db.collection('users').doc(data.uid).delete().catch(() => {});
        await getAdmin().auth().deleteUser(data.uid).catch(() => {});
      }
      res.json({ ok: true, username: data.username || username, status: 'deleted' });
      return;
    }
  } catch (e) {
    console.error('[manageAccounts] update failed:', e.code || e.message);
    res.status(500).json({ error: 'Could not update account' });
  }
});

const communityWatchPartyAccess = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  const caller = trustedProfileUsername(decoded);
  if (!caller) {
    res.status(403).json({ error: 'Account sign-in required' });
    return;
  }

  const body = req.body || {};
  const action = String(body.action || '').trim();
  const db = getAdmin().firestore();
  const now = getAdmin().firestore.FieldValue.serverTimestamp();

  if (action === 'createRoom') {
    const ip = clientIp(req);
    if (_acctHit(ip, 15)) {
      res.status(429).json({ error: 'Too many requests — try again shortly' });
      return;
    }
    const cleanName = String(body.name || '').trim().slice(0, 80) || 'Watch Party';
    const cleanPassword = String(body.password || '').trim();
    if (cleanPassword.length > MAX_PASSWORD_LEN) {
      res.status(400).json({ error: 'Room password is too long' });
      return;
    }
    const hasPassword = cleanPassword.length > 0;
    const m = body.media && typeof body.media === 'object' ? body.media : null;
    const mediaType = m && m.mediaType === 'tv' ? 'tv' : 'movie';
    const tmdbId = m && Number.isFinite(Number(m.tmdbId)) ? Number(m.tmdbId) : 0;

    try {
      const roomRef = db.collection('community_watch_rooms').doc();
      const batch = db.batch();
      const posNum = (v) => (v != null && v !== '' && Number.isFinite(Number(v)) && Number(v) > 0 ? Number(v) : null);
      const malIdVal = m ? posNum(m.malId) : null;
      const seasonVal = m ? posNum(m.season) : null;
      const episodeVal = m ? posNum(m.episode) : null;
      const episodeCountVal = m ? posNum(m.episodeCount) : null;
      const roomDoc = {
        name: cleanName,
        hostUid: decoded.uid,
        hostName: caller,
        mediaType,
        tmdbId,
        ...(malIdVal != null ? { malId: malIdVal } : {}),
        isAnime: Boolean(m && m.isAnime === true),
        ...(seasonVal != null ? { season: seasonVal } : {}),
        ...(episodeVal != null ? { episode: episodeVal } : {}),
        ...(episodeCountVal != null ? { episodeCount: episodeCountVal } : {}),
        title: m ? String(m.title || '').slice(0, 200) : '',
        posterPath: m ? String(m.posterPath || '').slice(0, 400) : '',
        serverType: 'hls',
        serverName: 'Everglow Server',
        serverHost: 'everglow',
        captionsOn: true,
        proxyEnabled: false,
        hasPassword,
        state: 'paused',
        currentTime: 0,
        updatedBy: decoded.uid,
        active: true,
        createdAt: now,
        updatedAt: now,
        positionAt: now,
      };
      batch.set(roomRef, roomDoc);
      batch.set(roomRef.collection('members').doc(decoded.uid), {
        uid: decoded.uid,
        username: caller,
        unlockedAt: now,
      });
      if (hasPassword) {
        const { salt, hash } = await hashPasswordAsync(cleanPassword);
        batch.set(db.collection('community_watch_room_secrets').doc(roomRef.id), {
          passwordSalt: salt,
          passwordHash: hash,
          hostUid: decoded.uid,
          createdAt: now,
        });
      }
      await batch.commit();
      res.status(201).json({ roomId: roomRef.id, hasPassword });
    } catch (e) {
      console.error('[communityWatchPartyAccess] createRoom failed:', e.code || e.message);
      res.status(500).json({ error: 'Could not create watch party room' });
    }
    return;
  }

  if (action === 'unlockRoom') {
    const ip = clientIp(req);
    if (_acctHit(ip, 15)) {
      res.status(429).json({ error: 'Too many attempts — try again shortly' });
      return;
    }
    const roomId = String(body.roomId || '').trim();
    const password = String(body.password || '').trim();
    if (!roomId || roomId.includes('/') || roomId.length > 128) {
      res.status(400).json({ error: 'Invalid room id' });
      return;
    }
    try {
      const roomRef = db.collection('community_watch_rooms').doc(roomId);
      const roomSnap = await roomRef.get();
      if (!roomSnap.exists) {
        res.status(404).json({ error: 'Room not found' });
        return;
      }
      const roomData = roomSnap.data() || {};
      const isBypass =
        !roomData.hasPassword ||
        roomData.hostUid === decoded.uid ||
        caller === 'khentsgdz' ||
        caller === 'clairjassen';
      if (!isBypass) {
        const secretSnap = await db.collection('community_watch_room_secrets').doc(roomId).get();
        const secret = secretSnap.exists ? secretSnap.data() || {} : null;
        if (!secret || !(await verifyPasswordAsync(password, secret.passwordSalt, secret.passwordHash))) {
          res.status(403).json({ error: 'Incorrect room password.' });
          return;
        }
      }
      await roomRef.collection('members').doc(decoded.uid).set(
        {
          uid: decoded.uid,
          username: caller,
          unlockedAt: now,
        },
        { merge: true },
      );
      res.json({ ok: true });
    } catch (e) {
      console.error('[communityWatchPartyAccess] unlockRoom failed:', e.code || e.message);
      res.status(500).json({ error: 'Could not unlock watch party room' });
    }
    return;
  }

  res.status(400).json({ error: 'Unknown action' });
});

module.exports = {
  registerAccount,
  loginAccount,
  manageAccounts,
  communityWatchPartyAccess,
  hashPassword,
  verifyPassword,
  serializeAccount,
};
