'use strict';

const { randomBytes } = require('node:crypto');
const { streamMediaBody } = require('./stream_media_body');
const { applyCors, cappedHttps, enforceRateLimit, requireAuth, fetchPublicUrl, getDb } = require('./common.js');
const { STREAM_LIFETIME_MS, mediaUrl, signedStreamUrl, validStreamSignature, rewritePlaylist } = require('./watch_stream_access');

const _STREAM_SECRET_TTL_MS = 10 * 60 * 1000;
const _STREAM_SECRET_MAX = 200;
const _streamSecretCache = new Map();

function _getCachedStreamSecret(uid) {
  const entry = _streamSecretCache.get(uid);
  if (!entry) return null;
  if (Date.now() - entry.ts > _STREAM_SECRET_TTL_MS) {
    _streamSecretCache.delete(uid);
    return null;
  }
  return entry.secret;
}

function _setCachedStreamSecret(uid, secret) {
  if (!secret) return;
  _streamSecretCache.delete(uid);
  _streamSecretCache.set(uid, { secret, ts: Date.now() });
  if (_streamSecretCache.size > _STREAM_SECRET_MAX) {
    const oldest = _streamSecretCache.keys().next().value;
    if (oldest !== undefined) _streamSecretCache.delete(oldest);
  }
}

async function streamSecret(uid, create = false) {
  const cached = _getCachedStreamSecret(uid);
  if (cached) return cached;
  const db = getDb();
  const ref = db.collection('watch_stream_keys').doc(uid);
  if (!create) {
    const secret = (await ref.get()).data()?.secret;
    if (secret) _setCachedStreamSecret(uid, secret);
    return secret;
  }
  const secret = await db.runTransaction(async (tx) => {
    const saved = await tx.get(ref);
    if (saved.exists) return saved.data().secret;
    const next = randomBytes(32).toString('hex');
    tx.set(ref, { secret: next });
    return next;
  });
  _setCachedStreamSecret(uid, secret);
  return secret;
}

const proxyWatchStream = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
  res.set('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length');
  res.set('Cache-Control', 'private, no-store');
  res.set('Vary', 'Origin, Authorization');
  res.set('Referrer-Policy', 'no-referrer');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (!['GET', 'POST'].includes(req.method)) { res.status(405).json({ error: 'GET or POST only' }); return; }

  if (enforceRateLimit(req, res, { endpoint: 'watchStreamIp', limit: 480, windowMs: 60000 })) return;
  try {
    const issue = req.method === 'POST';
    const input = issue ? req.body || {} : req.query;
    let access;
    if (issue || !input.signature) {
      const decoded = await requireAuth(req, res);
      if (!decoded) return;
      access = { uid: decoded.uid, expires: Date.now() + STREAM_LIFETIME_MS };
    } else {
      if (!/^[a-zA-Z0-9_-]{1,128}$/.test(input.uid || '')) {
        res.status(401).json({ error: 'Invalid stream access' }); return;
      }
      access = { uid: input.uid, expires: Number(input.expires) };
    }
    if (typeof input.url !== 'string') { res.status(400).json({ error: 'Stream url required' }); return; }
    let targetUrl;
    try {
      targetUrl = mediaUrl(input.url);
      access.referer = typeof input.referer === 'string' && input.referer ? mediaUrl(input.referer) : '';
    } catch {
      res.status(400).json({ error: 'Invalid stream url' }); return;
    }
    access.secret = await streamSecret(access.uid, issue || !input.signature);
    if (!access.secret || (!issue && input.signature &&
        !validStreamSignature(targetUrl, access, input.signature))) {
      res.status(401).json({ error: 'Invalid or expired stream access' }); return;
    }
    if (enforceRateLimit(req, res, { endpoint: issue ? 'watchStreamAccess' : 'proxyWatchStream',
      limit: issue ? 10 : 240, windowMs: 60000, uid: access.uid })) return;
    if (issue) { res.json({ url: signedStreamUrl(targetUrl, access) }); return; }

    const headers = { 'User-Agent': 'Mozilla/5.0', Accept: '*/*' };
    if (access.referer) headers.Referer = access.referer;
    const range = req.get('Range');
    if (range && /^bytes=\d*-\d*$/.test(range)) headers.Range = range;
    const controller = new AbortController();
    const ttfbTimer = setTimeout(() => controller.abort(new Error('Upstream timeout')), 30000);
    const onClientClose = () => {
      if (!res.writableEnded) controller.abort(new Error('Client disconnected'));
    };
    if (typeof res.on === 'function') res.on('close', onClientClose);
    try {
      let upstream;
      try {
        upstream = await fetchPublicUrl(targetUrl, { headers, signal: controller.signal });
      } finally {
        clearTimeout(ttfbTimer);
      }
      if (!upstream.ok) {
        await upstream.body?.cancel().catch(() => {});
        res.status(upstream.status).json({ error: `Upstream returned ${upstream.status}` }); return;
      }
      const contentType = upstream.headers.get('content-type') || 'application/octet-stream';
      const baseCt = contentType.split(';')[0].trim().toLowerCase();
      const finalUrl = upstream.url || targetUrl;
      if (/mpegurl/i.test(contentType) || new URL(finalUrl).pathname.toLowerCase().endsWith('.m3u8')) {
        if (!upstream.body || typeof upstream.body.getReader !== 'function') {
          res.status(502).json({ error: 'Stream unavailable — please reload the player' });
          return;
        }
        const reader = upstream.body.getReader();
        const bodyTimer = setTimeout(() => controller.abort(new Error('Playlist body timeout')), 15000);
        const chunks = [];
        let size = 0;
        try {
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            size += value.length;
            if (size > 1024 * 1024) throw new Error('Playlist exceeds 1 MB');
            chunks.push(Buffer.from(value));
          }
        } finally {
          clearTimeout(bodyTimer);
          await reader.cancel().catch(() => {});
        }
        res.set('Content-Type', 'application/vnd.apple.mpegurl');
        res.set('X-Content-Type-Options', 'nosniff');
        res.set('Content-Security-Policy', "default-src 'none'; sandbox");
        res.status(200).send(rewritePlaylist(Buffer.concat(chunks).toString('utf8'), finalUrl, access));
        return;
      }
      if (
        baseCt === 'text/html' ||
        baseCt === 'application/xhtml+xml' ||
        baseCt === 'image/svg+xml' ||
        baseCt === 'text/xml' ||
        baseCt === 'application/xml' ||
        baseCt === 'text/javascript' ||
        baseCt === 'application/javascript' ||
        baseCt === 'text/ecmascript' ||
        baseCt === 'application/ecmascript'
      ) {
        await upstream.body?.cancel().catch(() => {});
        res.status(415).json({ error: 'Unsupported media content type' });
        return;
      }
      res.set('Content-Type', baseCt || 'application/octet-stream');
      res.set('X-Content-Type-Options', 'nosniff');
      res.set('Content-Security-Policy', "default-src 'none'; sandbox");
      for (const name of ['Content-Range', 'Accept-Ranges', 'Content-Length']) {
        const value = upstream.headers.get(name);
        if (value) res.set(name, value);
      }
      res.status(upstream.status);
      await streamMediaBody(upstream.body, res);
    } finally {
      if (typeof res.off === 'function') res.off('close', onClientClose);
    }
  } catch (e) {
    console.warn('proxyWatchStream failed:', e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: 'Stream unavailable — please reload the player' });
  }
});

module.exports = { proxyWatchStream };
