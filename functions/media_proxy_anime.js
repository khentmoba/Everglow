'use strict';

const { cappedHttps, enforceRateLimit, requireAuth } = require('./common.js');

/**
 * Proxies anime episode thumbnail images so Flutter web isn't blocked by
 * CORS. Streaming CDNs (Crunchyroll, Funimation, etc.) typically don't
 * include `Access-Control-Allow-Origin` on their image endpoints, so a
 * direct `Image.network` request from the browser fails. This function
 * fetches the image server-side and streams it back with permissive CORS
 * headers.
 *
 * Accepts:
 *   GET /proxyAnimeImage?url=<encoded image url>
 *
 * Only known anime CDN hosts are allowed — currently:
 *   - *.ak.crunchyroll.com
 *   - *.funimation.com
 */
const proxyAnimeImage = cappedHttps(30, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyAnimeImage', limit: 240, windowMs: 60000, uid: decoded.uid })) return;







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
    '.ak.crunchyroll.com',
    '.funimation.com',
  ];
  const hostAllowed = allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
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
    const contentType =
      upstream.headers.get('content-type') || 'image/jpeg';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyAnimeImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyAnimeImage };
