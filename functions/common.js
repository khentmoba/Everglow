'use strict';

const net = require('net');
const dns = require('dns').promises;

/** Mirrors `pubspec.yaml` / `lib/core/system/app_version.dart`. */
const APP_VERSION = '6.0.0+1';

/** Lazy require+init so Firebase deploy analysis doesn't time out.
 *  admin_compat restores the legacy namespace API (admin.auth(),
 *  admin.firestore(), ...) that firebase-admin v14 removed from its
 *  default export — see functions/admin_compat.js. */
let _admin;
function getAdmin() {
  if (!_admin) {
    const { getAdminCompat } = require('./admin_compat.js');
    _admin = getAdminCompat();
  }
  return _admin;
}

/** Firestore handle from the shared admin app. */
function getDb() {
  return getAdmin().firestore();
}

/**
 * Requires a valid Firebase ID token on a request. Returns the decoded
 * token, or writes a 401 and returns null.
 */
async function requireAuth(req, res) {
  const header = req.get('Authorization') || req.headers.authorization || '';
  let idToken = String(header).replace(/^Bearer\s+/i, '').trim();
  if (!idToken) {
    // Fallback to query-string token for clients that sign URLs via ?__auth=
    // (e.g. MusicSyncService). Header takes precedence; query is checked only
    // when the header is absent so logs do not contain credentials.
    const qp = req.query || {};
    const qToken = qp.__auth || qp.token || qp.auth || '';
    idToken = String(qToken).trim();
  }
  if (!idToken) {
    res.status(401).json({ error: 'Authentication required' });
    return null;
  }
  try {
    return await getAdmin().auth().verifyIdToken(idToken);
  } catch (e) {
    console.warn('Auth verification failed:', e.message);
    res.status(401).json({ error: 'Invalid or expired auth token' });
    return null;
  }
}

function isPrivateIpv4(ip) {
  const parts = ip.split('.').map(Number);
  if (parts.length !== 4 || parts.some((p) => Number.isNaN(p))) return true;
  const [a, b] = parts;
  if (a === 0 || a === 10 || a === 127 || a >= 224) return true;
  if (a === 169 && b === 254) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  return false;
}

function isPrivateIp(ip) {
  if (net.isIPv4(ip)) return isPrivateIpv4(ip);
  if (!net.isIPv6(ip)) return true;
  const lower = ip.toLowerCase();
  if (lower === '::1' || lower === '::') return true;
  if (lower.startsWith('fc') || lower.startsWith('fd') || lower.startsWith('fe80')) {
    return true;
  }
  if (lower.startsWith('::ffff:')) {
    return isPrivateIpv4(lower.slice('::ffff:'.length));
  }
  return false;
}

async function isPublicDnsHost(hostname) {
  try {
    const records = await dns.lookup(hostname, { all: true });
    return records.length > 0 && records.every((r) => !isPrivateIp(r.address));
  } catch (e) {
    console.warn('DNS lookup failed for', hostname, e.message);
    return false;
  }
}

function isAllowedBookTextUrl(url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.protocol !== 'https:') return false;
  const host = parsed.hostname.toLowerCase();
  const allowed =
    host === 'gutenberg.org' ||
    host.endsWith('.gutenberg.org') ||
    host === 'archive.org' ||
    host.endsWith('.archive.org');
  return allowed;
}

/** Verified caller cache — maps Firebase UID -> {username, ts} (5m TTL). */
const _verifiedCallerCache = new Map();
const VERIFIED_CALLER_TTL_MS = 5 * 60 * 1000;

/**
 * Resolve the trusted username for a verified Firebase Auth token.
 * Uses `users/{uid}.username` (written by AuthService._syncUserDoc) and
 * caches for 5 minutes. Returns null if not found or on error.
 */
async function getVerifiedUsername(decoded) {
  if (!decoded || !decoded.uid) return null;
  const cached = _verifiedCallerCache.get(decoded.uid);
  if (cached && (Date.now() - cached.ts) < VERIFIED_CALLER_TTL_MS) {
    return cached.username;
  }
  try {
    const snap = await getAdmin().firestore().collection('users').doc(decoded.uid).get();
    if (snap.exists) {
      const username = (snap.data()?.username || '').toString().trim().toLowerCase();
      if (username) {
        _verifiedCallerCache.set(decoded.uid, { username, ts: Date.now() });
        return username;
      }
    }
  } catch (e) {
    console.warn('[auth] getVerifiedUsername lookup failed:', e.message);
  }
  return null;
}

module.exports = {
  APP_VERSION,
  getAdmin,
  getDb,
  requireAuth,
  getVerifiedUsername,
  isPrivateIpv4,
  isPrivateIp,
  isPublicDnsHost,
  isAllowedBookTextUrl,
};
