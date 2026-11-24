'use strict';

const common = require('./common.js');
const { applyCors, cappedHttps, enforceRateLimit, getAdmin } = common;
const { streamMediaBody } = require('./stream_media_body');

const RASTER_IMAGE_RE = /^image\/(jpeg|jpg|png|webp|gif|avif|bmp|x-icon|vnd\.microsoft\.icon)(?:;|$)/i;

const proxyAnimeImage = cappedHttps(30, async (req, res) => {
  applyCors(req, res, 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is accepted' });
    return;
  }
  if (enforceRateLimit(req, res, { endpoint: 'proxyAnimeImage', limit: 240, windowMs: 60000 })) return;
  const header = req.get('Authorization') || req.headers.authorization || '';
  const idToken = header ? String(header).replace(/^Bearer\s+/i, '').trim() : '';
  if (idToken) {
    try {
      await getAdmin().auth().verifyIdToken(idToken, true);
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

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  const allowedSuffixes = [
    '.crunchyroll.com',
    '.funimation.com',
  ];
  const isAllowedAnimeImage = (u) =>
    !u.port && allowedSuffixes.some((s) => u.hostname.toLowerCase().endsWith(s));
  if (parsed.protocol !== 'https:' || !isAllowedAnimeImage(parsed)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
      headers: { 'Accept': 'image/*,*/*;q=0.8' },
      signal: AbortSignal.timeout(20000),
      httpsOnly: true,
      isAllowedUrl: isAllowedAnimeImage,
    });
    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }
    const contentType =
      (upstream.headers.get('content-type') || '').trim() || 'image/jpeg';
    if (!RASTER_IMAGE_RE.test(contentType)) {
      if (upstream.body && typeof upstream.body.cancel === 'function') {
        await upstream.body.cancel().catch(() => {});
      }
      res.status(415).json({ error: 'Upstream did not return a supported image' });
      return;
    }
    res.set('Content-Type', contentType);
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', "default-src 'none'; sandbox");
    res.set('Cache-Control', 'public, max-age=600');
    await streamMediaBody(upstream.body, res);
  } catch (e) {
    console.warn(`proxyAnimeImage failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: 'Upstream fetch failed' });
  }
});

module.exports = { proxyAnimeImage };
