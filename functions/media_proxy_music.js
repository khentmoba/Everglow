'use strict';

const { cappedHttps, enforceRateLimit, getAdmin } = require('./common.js');

/**
 * Last.fm artwork CDN hosts. Covers come from the `image` arrays in
 * `proxyLastfm` JSON responses (user.gettoptracks, user.getrecenttracks,
 * track.getinfo album art, ...).
 */
const LASTFM_IMAGE_HOSTS = new Set([
  'lastfm-img.freetls.fastly.net',
  'lastfm.freetls.fastly.net',
]);

/**
 * True when [targetUrl] is an https URL on the Last.fm artwork CDN.
 * Pure so unit tests can pin the allow-list without HTTP mocks.
 */
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

/**
 * Proxies Last.fm album artwork so Flutter Web isn't blocked by CORS.
 * The Last.fm image CDN sends no `Access-Control-Allow-Origin` header,
 * so a direct `Image.network` fetch from the browser fails and every
 * dashboard leaderboard row falls back to the music-note tile. This
 * function fetches the bytes server-side and streams them back with
 * permissive CORS headers.
 *
 * Accepts:
 *   GET /proxyLastfmImage?url=<encoded image url>
 *
 * Mirrors the `proxyMangaImage` pattern: anonymous by design (an
 * `<img>`-style load can't send Authorization headers), restricted to
 * the Last.fm artwork hosts above, with a per-IP rate limit as the
 * abuse backstop. Artwork URLs are content-hashed and immutable, so
 * responses cache for a year.
 */
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
  // Optional token: validated when present, anonymous otherwise.
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
    const contentType =
      upstream.headers.get('content-type') || 'image/jpeg';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyLastfmImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyLastfmImage, isAllowedLastfmImageUrl };
