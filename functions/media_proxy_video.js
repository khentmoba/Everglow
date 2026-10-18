'use strict';

const { streamMediaBody } = require('./stream_media_body');
const { cappedHttps, enforceRateLimit, requireAuth, fetchPublicUrl } = require('./common.js');

/** Streams allowlisted-by-network public watch media through the app origin. */
const proxyWatchStream = cappedHttps(10, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'proxyWatchStream', limit: 60, windowMs: 60000, uid: decoded.uid })) return;

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<stream url> query param' });
    return;
  }

  let target;
  try {
    target = new URL(targetUrl);
  } catch {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }
  if (!['http:', 'https:'].includes(target.protocol) || target.username || target.password) {
    res.status(400).json({ error: 'Only credential-free http(s) urls are allowed' });
    return;
  }

  const headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    Accept: '*/*',
  };
  if (typeof req.query.referer === 'string') {
    let referer;
    try {
      referer = new URL(req.query.referer);
    } catch {
      res.status(400).json({ error: 'Invalid referer' });
      return;
    }
    if (!['http:', 'https:'].includes(referer.protocol) || referer.username || referer.password) {
      res.status(400).json({ error: 'Invalid referer' });
      return;
    }
    headers.Referer = referer.toString();
  }

  try {
    const upstream = await fetchPublicUrl(targetUrl, {
      headers,
      signal: AbortSignal.timeout(30000),
    });
    if (!upstream.ok) {
      await upstream.body?.cancel();
      res.status(upstream.status).json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    res.set('Content-Type', upstream.headers.get('content-type') || 'application/octet-stream');
    res.set('Cache-Control', 'public, max-age=300');
    await streamMediaBody(upstream.body, res);
  } catch (e) {
    console.warn(`proxyWatchStream failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyWatchStream };
