'use strict';

const { randomBytes } = require('node:crypto');
const { streamMediaBody } = require('./stream_media_body');
const { cappedHttps, enforceRateLimit, requireAuth, fetchPublicUrl, getDb } = require('./common.js');
const { STREAM_LIFETIME_MS, mediaUrl, signedStreamUrl, validStreamSignature, rewritePlaylist } = require('./watch_stream_access');

// One server-only key per approved account, shared across devices and function instances.
async function streamSecret(uid, create = false) {
  const db = getDb();
  const ref = db.collection('watch_stream_keys').doc(uid);
  if (!create) return (await ref.get()).data()?.secret;
  return db.runTransaction(async (tx) => {
    const saved = await tx.get(ref);
    if (saved.exists) return saved.data().secret;
    const secret = randomBytes(32).toString('hex');
    tx.set(ref, { secret });
    return secret;
  });
}

const proxyWatchStream = cappedHttps(10, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
  res.set('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length');
  res.set('Cache-Control', 'private, no-store');
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
    if (enforceRateLimit(req, res, { endpoint: issue ? 'watchStreamAccess' : 'proxyWatchStream',
      limit: issue ? 10 : 240, windowMs: 60000, uid: access.uid })) return;
    if (typeof input.url !== 'string') { res.status(400).json({ error: 'Stream url required' }); return; }
    const targetUrl = mediaUrl(input.url);
    access.referer = typeof input.referer === 'string' && input.referer ? mediaUrl(input.referer) : '';
    access.secret = await streamSecret(access.uid, issue || !input.signature);
    if (!access.secret || (!issue && input.signature &&
        !validStreamSignature(targetUrl, access, input.signature))) {
      res.status(401).json({ error: 'Invalid or expired stream access' }); return;
    }
    if (issue) { res.json({ url: signedStreamUrl(targetUrl, access) }); return; }

    const headers = { 'User-Agent': 'Mozilla/5.0', Accept: '*/*' };
    if (access.referer) headers.Referer = access.referer;
    const range = req.get('Range');
    if (range && /^bytes=\d*-\d*$/.test(range)) headers.Range = range;
    const upstream = await fetchPublicUrl(targetUrl, { headers, signal: AbortSignal.timeout(30000) });
    if (!upstream.ok) {
      await upstream.body?.cancel();
      res.status(upstream.status).json({ error: `Upstream returned ${upstream.status}` }); return;
    }
    const contentType = upstream.headers.get('content-type') || 'application/octet-stream';
    const finalUrl = upstream.url || targetUrl;
    if (/mpegurl/i.test(contentType) || new URL(finalUrl).pathname.toLowerCase().endsWith('.m3u8')) {
      const reader = upstream.body.getReader();
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
      } finally { await reader.cancel(); }
      res.set('Content-Type', 'application/vnd.apple.mpegurl');
      res.status(200).send(rewritePlaylist(Buffer.concat(chunks).toString('utf8'), finalUrl, access));
      return;
    }
    res.set('Content-Type', contentType);
    for (const name of ['Content-Range', 'Accept-Ranges', 'Content-Length']) {
      const value = upstream.headers.get(name);
      if (value) res.set(name, value);
    }
    res.status(upstream.status);
    await streamMediaBody(upstream.body, res);
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
