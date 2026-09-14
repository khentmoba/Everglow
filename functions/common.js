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
  const idToken = String(header).replace(/^Bearer\s+/i, '').trim();
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

// ─── External API cache (TMDB/weather/books/anime) ───────────
// Deduplicates repeat searches within tool-loop rounds and across rapid
// user messages. TTLs: TMDB 10m, weather 15m, books 30m, anime 10m.
// Size-capped at 200 entries to bound memory. Lives here (not index.js)
// so both index.js and motchi_context.js share one Map.
const _externalCache = new Map();
const _EXTERNAL_CACHE_TTLS = {
  tmdb: 10 * 60 * 1000,
  weather: 15 * 60 * 1000,
  books: 30 * 60 * 1000,
  anime: 10 * 60 * 1000,
  trending: 10 * 60 * 1000,
  web_search: 15 * 60 * 1000,
  web_page: 30 * 60 * 1000,
};
function _getExternalCache(key, ttlMs) {
  const entry = _externalCache.get(key);
  if (!entry) return null;
  if ((Date.now() - entry.ts) > ttlMs) {
    _externalCache.delete(key);
    return null;
  }
  return entry.data;
}
function _setExternalCache(key, data) {
  _externalCache.set(key, { data, ts: Date.now() });
  if (_externalCache.size > 200) {
    const oldest = _externalCache.keys().next().value;
    _externalCache.delete(oldest);
  }
}

// ─── Lightweight in-memory rate limiter ───────────
// Per-instance sliding-window counters. Each Cloud Functions instance
// keeps its own map, so this is not a hard global cap — but it stops
// single-client floods and bot loops cheaply with zero Firestore cost.
// Expensive endpoints (proxyAI, agnesImage) additionally use the
// Firestore-backed daily caps below, which hold across instances.
const _rateBuckets = new Map();
const RATE_LIMIT_MAX_BUCKETS = 2000;
const RATE_LIMIT_PRUNE = 200;

function _pruneRateBuckets() {
  const keys = _rateBuckets.keys();
  for (let i = 0; i < RATE_LIMIT_PRUNE; i++) {
    const k = keys.next().value;
    if (k === undefined) break;
    _rateBuckets.delete(k);
  }
}

/**
 * Record one hit for `key`. Returns true when the key is OVER the limit
 * (i.e. the caller should reject with 429). Window slides from first hit.
 */
function rateLimitHit(key, limit, windowMs, now = Date.now()) {
  let bucket = _rateBuckets.get(key);
  if (!bucket || (now - bucket.start) >= windowMs) {
    bucket = { start: now, count: 0 };
    _rateBuckets.set(key, bucket);
    if (_rateBuckets.size > RATE_LIMIT_MAX_BUCKETS) _pruneRateBuckets();
  }
  bucket.count += 1;
  return bucket.count > limit;
}

/**
 * Best-effort client IP behind Google's frontend. `req.ip` here is the
 * load balancer, not the caller — the first X-Forwarded-For hop is the
 * real client. Authed endpoints key by UID instead, so a spoofed header
 * can only move an anonymous caller between IP buckets, never dodge
 * the UID limits on the expensive endpoints.
 */
function clientIp(req) {
  const fwd = (req.get('X-Forwarded-For') || req.headers['x-forwarded-for'] || '').toString();
  const first = fwd.split(',')[0].trim();
  const ip = ((first || req.ip || 'unknown').toString().trim() || 'unknown').slice(0, 64);
  return ip;
}

/**
 * Enforce a per-minute style limit. Sends 429 + Retry-After and returns
 * true when over the limit. Pass the verified `uid` for authed endpoints
 * so limits follow the user; anonymous-tolerant endpoints fall back to IP.
 */
function enforceRateLimit(req, res, { endpoint, limit, windowMs, uid = '' }) {
  const key = uid ? `${endpoint}:u:${uid}` : `${endpoint}:ip:${clientIp(req)}`;
  if (rateLimitHit(key, limit, windowMs)) {
    res.set('Retry-After', String(Math.max(1, Math.ceil(windowMs / 1000))));
    res.status(429).json({ error: 'Too many requests — please slow down.' });
    return true;
  }
  return false;
}

// ─── Firestore-backed daily usage caps ───────────
// Counters live at api_usage/{uid}/days/{YYYY-MM-DD} (server-only
// collection, see firestore.rules). Atomic increments, so concurrent
// instances can't dodge the cap. Fails OPEN (allows the call) when
// Firestore is unreachable — we never want to break Clair's chat
// because a counter write hiccuped; the miss is logged instead.
function _todayDayKey(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

async function checkDailyCap(uid, endpoint, dailyLimit) {
  const day = _todayDayKey();
  try {
    const ref = getDb().collection('api_usage').doc(uid).collection('days').doc(day);
    await ref.set({
      [endpoint]: getAdmin().firestore.FieldValue.increment(1),
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const snap = await ref.get();
    const count = Number(snap.data()?.[endpoint] || 0);
    return { allowed: count <= dailyLimit, count };
  } catch (e) {
    console.warn('[usage] daily cap check failed (fail-open):', e.message);
    return { allowed: true, count: 0 };
  }
}

module.exports = {
  APP_VERSION,
  getAdmin,
  getDb,
  requireAuth,
  rateLimitHit,
  enforceRateLimit,
  clientIp,
  checkDailyCap,
  _todayDayKey,
  getVerifiedUsername,
  isPrivateIpv4,
  isPrivateIp,
  isPublicDnsHost,
  isAllowedBookTextUrl,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
};
