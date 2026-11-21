'use strict';

const { cappedHttps, enforceRateLimit, getAdmin } = require('./common.js');
const { streamMediaBody } = require('./stream_media_body');

const LASTFM_IMAGE_HOSTS = new Set([
  'lastfm-img.freetls.fastly.net',
  'lastfm.freetls.fastly.net',
]);

function isAllowedLastfmImageUrl(targetUrl) {
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) return false;
  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    return false;
  }
  return (
    parsed.protocol === 'https:' &&
    LASTFM_IMAGE_HOSTS.has(parsed.hostname.toLowerCase())
  );
}

const proxyLastfmImage = cappedHttps(30, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyLastfmImage', limit: 240, windowMs: 60000 })) return;
  const header = req.get('Authorization') || req.headers.authorization || '';
  const idToken = header ? String(header).replace(/^Bearer\s+/i, '') : '';
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken);
    } catch (e) {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  if (!isAllowedLastfmImageUrl(targetUrl)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      signal: AbortSignal.timeout(20000),
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const rawCt = (upstream.headers.get('content-type') || 'image/jpeg').split(';')[0].trim().toLowerCase();
    if (!/^image\/(jpeg|jpg|png|webp|gif|avif|bmp|x-icon|vnd\.microsoft\.icon)$/.test(rawCt)) {
      await upstream.body?.cancel();
      res.status(415).json({ error: 'Upstream did not return a raster image' });
      return;
    }
    res.set('Content-Type', rawCt);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', "default-src 'none'; sandbox");
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
    await streamMediaBody(upstream.body, res);
  } catch (e) {
    console.warn(`proxyLastfmImage failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyLastfmImage, isAllowedLastfmImageUrl };
