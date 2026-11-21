'use strict';

const net = require('net');
const dns = require('dns').promises;
const { trustedProfileUsername } = require('./auth_core.js');

const APP_VERSION = '6.3.0+1';

let _admin;
function getAdmin() {
  if (!_admin) {
    const { getAdminCompat } = require('./admin_compat.js');
    _admin = getAdminCompat();
  }
  return _admin;
}

function getDb() {
  return getAdmin().firestore();
}

async function requireAuth(req, res) {
  const header = req.get('Authorization') || req.headers.authorization || '';
  const idToken = String(header).replace(/^Bearer\s+/i, '').trim();
  if (!idToken) {
    res.status(401).json({ error: 'Authentication required' });
    return null;
  }
  try {
    const decoded = await getAdmin().auth().verifyIdToken(idToken);
    if (decoded.firebase?.sign_in_provider === 'anonymous') {
      res.status(401).json({ error: 'A signed-in profile is required' });
      return null;
    }
    if (!trustedProfileUsername(decoded)) {
      res.status(403).json({ error: 'An approved profile is required — please log in with your passcode' });
      return null;
    }
    return decoded;
  } catch (e) {
    console.warn('Auth verification failed:', e.message);
    res.status(401).json({ error: 'Invalid or expired auth token' });
    return null;
  }
}

const nonPublicIps = new net.BlockList();
for (const [address, prefix] of [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10],
  ['127.0.0.0', 8], ['169.254.0.0', 16], ['172.16.0.0', 12],
  ['192.0.0.0', 24], ['192.0.2.0', 24], ['192.168.0.0', 16],
  ['198.18.0.0', 15], ['198.51.100.0', 24], ['203.0.113.0', 24],
  ['224.0.0.0', 3],
]) nonPublicIps.addSubnet(address, prefix, 'ipv4');
const publicIpv6 = new net.BlockList();
publicIpv6.addSubnet('2000::', 3, 'ipv6');
for (const [address, prefix] of [
  ['2001::', 23], ['2001:db8::', 32], ['2002::', 16], ['3fff::', 20],
]) nonPublicIps.addSubnet(address, prefix, 'ipv6');

function isPrivateIpv4(ip) {
  return !net.isIPv4(ip) || nonPublicIps.check(ip, 'ipv4');
}

function isPrivateIp(ip) {
  if (net.isIPv4(ip)) return isPrivateIpv4(ip);
  if (!net.isIPv6(ip)) return true;
  return !publicIpv6.check(ip, 'ipv6') || nonPublicIps.check(ip, 'ipv6');
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

async function fetchPublicUrl(target, { headers, signal }) {
  const { Readable } = require('node:stream');
  const reqHeaders = headers ? { ...headers } : {};
  let url = new URL(target);
  for (let hop = 0; hop <= 5; hop++) {
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
      throw new Error('Only credential-free http(s) urls are allowed');
    }
    if (url.hostname === '' || url.port && !/^\d+$/.test(url.port)) {
      throw new Error('Invalid URL');
    }
    const hostname = url.hostname.replace(/^\[|\]$/g, '');
    const records = net.isIP(hostname)
      ? [{ address: hostname, family: net.isIP(hostname) }]
      : await dns.lookup(hostname, { all: true });
    if (!records.length || records.some(({ address }) => isPrivateIp(address))) {
      throw new Error('Host not allowed');
    }
    const transport = require(url.protocol === 'https:' ? 'node:https' : 'node:http');
    const incoming = await new Promise((resolve, reject) => {
      const request = transport.get(url, {
        headers: reqHeaders, signal,
        agent: false,
        lookup: (_host, options, callback) => {
          callback(null, options.all ? [records[0]] : records[0].address, records[0].family);
        },
      }, resolve);
      request.on('error', reject);
    });
    if ([301, 302, 303, 307, 308].includes(incoming.statusCode)) {
      incoming.destroy();
      if (!incoming.headers.location || hop === 5) throw new Error('Invalid or excessive redirects');
      const nextUrl = new URL(incoming.headers.location, url);
      if (nextUrl.origin !== url.origin) {
        for (const key of Object.keys(reqHeaders)) {
          const lower = key.toLowerCase();
          if (lower === 'referer' || lower === 'cookie' || lower === 'authorization') {
            delete reqHeaders[key];
          }
        }
      }
      url = nextUrl;
      continue;
    }
    return {
      ok: incoming.statusCode >= 200 && incoming.statusCode < 300,
      status: incoming.statusCode,
      url: url.toString(),
      headers: new Headers(Object.entries(incoming.headers).map(([key, value]) => [key, String(value)])),
      body: Readable.toWeb(incoming),
    };
  }
}

async function readLimitedText(body, maxBytes = 4 * 1024 * 1024) {
  if (!body) return '';
  if (typeof body.getReader !== 'function') {
    const text = await new Response(body).text();
    if (Buffer.byteLength(text, 'utf8') > maxBytes) {
      throw new Error('Upstream response exceeded size limit');
    }
    return text;
  }
  const reader = body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel().catch(() => {});
        throw new Error('Upstream response exceeded size limit');
      }
      chunks.push(Buffer.from(value));
    }
  } finally {
    try { reader.releaseLock(); } catch (_) {}
  }
  return Buffer.concat(chunks, total).toString('utf8');
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

async function getVerifiedUsername(decoded) {
  return trustedProfileUsername(decoded);
}

const _externalCache = new Map();
const _EXTERNAL_CACHE_TTLS = {
  tmdb: 10 * 60 * 1000,
  lastfm: 5 * 60 * 1000,
  weather: 15 * 60 * 1000,
  books: 30 * 60 * 1000,
  anime: 10 * 60 * 1000,
  trending: 10 * 60 * 1000,
  web_search: 15 * 60 * 1000,
  web_search_long: 60 * 60 * 1000,
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

function clientIp(req) {
  const fwd = String(req.get('X-Forwarded-For') || req.headers['x-forwarded-for'] || '');
  const hops = fwd.split(',').map((hop) => hop.trim());
  const client = hops.length >= 2 ? hops.at(-2) : req.ip;
  if (net.isIP(client || '')) return client;
  return net.isIP(req.ip || '') ? req.ip : 'unknown';
}

function enforceRateLimit(req, res, { endpoint, limit, windowMs, uid = '' }) {
  const key = uid ? `${endpoint}:u:${uid}` : `${endpoint}:ip:${clientIp(req)}`;
  if (rateLimitHit(key, limit, windowMs)) {
    res.set('Retry-After', String(Math.max(1, Math.ceil(windowMs / 1000))));
    res.status(429).json({ error: 'Too many requests — please slow down.' });
    return true;
  }
  return false;
}

function _todayDayKey(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

const _dailyCapCache = new Map();
const DAILY_CAP_CACHE_TTL_MS = 60 * 1000;
const DAILY_CAP_CACHE_MAX = 500;

function _dailyCapCacheGet(key) {
  const entry = _dailyCapCache.get(key);
  if (!entry) return null;
  if ((Date.now() - entry.ts) > DAILY_CAP_CACHE_TTL_MS) {
    _dailyCapCache.delete(key);
    return null;
  }
  return entry.count;
}

function _dailyCapCacheSet(key, count) {
  _dailyCapCache.set(key, { count, ts: Date.now() });
  if (_dailyCapCache.size > DAILY_CAP_CACHE_MAX) {
    const oldest = _dailyCapCache.keys().next().value;
    _dailyCapCache.delete(oldest);
  }
}

async function checkDailyCap(uid, endpoint, dailyLimit) {
  const day = _todayDayKey();
  const key = `${uid}:${endpoint}:${day}`;
  const cached = _dailyCapCacheGet(key);
  if (cached !== null) {
    const count = cached + 1;
    _dailyCapCacheSet(key, count);
    try {
      const ref = getDb().collection('api_usage').doc(uid).collection('days').doc(day);
      ref.set({
        [endpoint]: getAdmin().firestore.FieldValue.increment(1),
        updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
      }, { merge: true }).catch((e) => {
        console.warn('[usage] background daily cap sync failed:', e.message);
      });
    } catch (e) {
      console.warn('[usage] background daily cap sync failed:', e.message);
    }
    return { allowed: count <= dailyLimit, count };
  }
  try {
    const ref = getDb().collection('api_usage').doc(uid).collection('days').doc(day);
    await ref.set({
      [endpoint]: getAdmin().firestore.FieldValue.increment(1),
      updatedAt: getAdmin().firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const snap = await ref.get();
    const count = Number(snap.data()?.[endpoint] || 0);
    _dailyCapCacheSet(key, count);
    return { allowed: count <= dailyLimit, count };
  } catch (e) {
    console.warn('[usage] daily cap check failed (fail-open):', e.message);
    return { allowed: true, count: 0 };
  }
}

function allowedCorsOrigin(req) {
  const origin = String(req?.get?.('Origin') || req?.headers?.origin || '').trim();
  if (!origin) return 'https://everglow-1c6db.web.app';
  if (
    origin === 'https://everglow-1c6db.web.app' ||
    origin === 'https://everglow-1c6db.firebaseapp.com' ||
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)
  ) {
    return origin;
  }
  return 'https://everglow-1c6db.web.app';
}

function applyCors(req, res, methods, headers = 'Content-Type, Authorization') {
  res.set('Access-Control-Allow-Origin', allowedCorsOrigin(req));
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Methods', methods);
  res.set('Access-Control-Allow-Headers', headers);
}

function cappedHttps(maxInstances, handler, opts = {}) {
  const functions = require('firebase-functions/v1');
  return functions.runWith({ maxInstances, ...opts }).https.onRequest(handler);
}

module.exports = {
  APP_VERSION,
  getAdmin,
  getDb,
  cappedHttps,
  allowedCorsOrigin,
  applyCors,
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
  fetchPublicUrl,
  readLimitedText,
  isAllowedBookTextUrl,
  _getExternalCache,
  _setExternalCache,
  _EXTERNAL_CACHE_TTLS,
};
