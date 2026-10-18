'use strict';

const { cappedHttps, enforceRateLimit, getAdmin } = require('./common.js');
const { resolveKatanaServerCookie } = require('./media_proxy_core.js');
const { streamMediaBody } = require('./stream_media_body');

/**
 * Proxies scanlation-site chapter page images so Flutter web isn't
 * blocked by CORS or hotlink protection. Scanlation groups host images
 * on their own domains or common CDNs (Blogspot, WordPress, etc.).
 *
 * Accepts:
 *   GET /proxyScanlation?url=<encoded image url>
 *
 * The host is validated against a whitelist of known scanlation
 * domains. Mirrors the `proxyMangaKakalotImage` pattern.
 */
const proxyScanlation = cappedHttps(30, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyScanlation', limit: 240, windowMs: 60000 })) return;
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

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  // ── Whitelisted scanlation domains & common image CDNs ─────
  const allowedSuffixes = [
    // Scanlation group domains
    '.asurascans.com',
    '.asuracomic.net',
    '.reaperscans.com',
    '.reapercomics.com',
    '.arcanescans.com',
    '.flamescans.org',
    '.flamecomics.com',
    '.luminousscans.com',
    '.void-scans.com',
    '.rizzcomic.com',
    '.comick.io',
    // Bato.to image CDN
    '.bato.to',
    '.img.bato.to',
    // MangaSee123 image CDN
    '.mangasee123.com',
    '.scans-hot.xyz',
    // MangaKatana image CDN
    '.mangakatana.com',
    '.mangakatana.net',
    // Common image CDNs used by scanlation sites
    '.blogspot.com',
    '.bp.blogspot.com',
    '.googleusercontent.com',
    '.wp.com',
    '.wordpress.com',
  ];
  const hostAllowed = allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'Accept': 'image/*,*/*;q=0.8',
        'Referer': parsed.origin + '/',
      },
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
    await streamMediaBody(upstream.body, res);
  } catch (e) {
    console.warn(`proxyScanlation failed (${targetUrl}):`, e.message);
    if (res.headersSent || res.destroyed) {
      if (!res.destroyed) res.destroy(e);
      return;
    }
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies HTML scraping requests for manga services that scrape
 * external sites (MangaKakalot, MangaKatana, Bato.to, MangaSee123,
 * and scanlation group sites). These sites don't send CORS headers,
 * so direct browser fetches are blocked on Flutter Web.
 *
 * Accepts:
 *   GET /proxyFetchHtml?url=<encoded target URL>[&cookie=<server cookie>]
 *
 * The optional `cookie` param exists for MangaKatana's image-server
 * switch: the site picks Server 2/3 from a `s_r` cookie, the `?sv=`
 * query alone is ignored. Only the exact values `s_r=sv2` and
 * `s_r=sv3` are forwarded, and only to mangakatana.com hosts —
 * anything else is dropped.
 *
 * The function:
 *   1. Validates the URL against a whitelist of manga/scraping domains
 *   2. Fetches the HTML page server-side (with spoofed Referer)
 *   3. Returns the raw HTML with permissive CORS headers
 *
 * This follows the same pattern as proxyScanlation (image proxy) but
 * returns text/html instead of binary image data.
 */
const proxyFetchHtml = cappedHttps(20, async (req, res) => {
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
  // HTML scraping is heavier than images, so the anonymous cap is lower.
  if (enforceRateLimit(req, res, { endpoint: 'proxyFetchHtml', limit: 60, windowMs: 60000 })) return;
  // Allow anonymous for manga scraping (host allowlist restricts to public sites).
  // If a token is provided, validate it.
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
    res.status(400).json({ error: 'Missing ?url=<page url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  // ── Whitelisted manga scraping domains ─────────────────────
  const allowedSuffixes = [
    // MangaKakalot
    '.mangakakalot.com',
    // MangaKatana
    '.mangakatana.com',
    // Bato.to
    '.bato.to',
    // MangaSee123
    '.mangasee123.com',
    // Anime embed probe (animex watch page): third-party anime embeds
    // serve no CORS headers, so the app's dead-server probe can't read
    // their error pages directly from Flutter Web. Same goes for our
    // own player pages (Firebase Hosting sends no CORS headers, while
    // the functions host is covered by direct CORS — belt and braces).
    // Public pages, same guard as the rest.
    '.vidlink.pro',
    '.megaplay.buzz',
    '.anixo.buzz',
    '.megavid.buzz',
    'everglow-1c6db.web.app',
    'us-central1-everglow-1c6db.cloudfunctions.net',
    // Scanlation group sites
    '.asurascans.com',
    '.asuracomic.net',
    '.reaperscans.com',
    '.reapercomics.com',
    '.arcanescans.com',
    '.flamescans.org',
    '.flamecomics.com',
    '.luminousscans.com',
    '.void-scans.com',
    '.rizzcomic.com',
  ];
  const hostAllowed = allowedSuffixes.some(
    (s) => parsed.hostname === s.slice(1) || parsed.hostname.endsWith(s),
  );
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  // MangaKatana picks its image server from a `s_r` cookie (Server 1 =
  // no cookie, Server 2 = `s_r=sv2`, Server 3 = `s_r=sv3`). Without the
  // cookie, Server 2/3 requests silently return Server 1's page URLs,
  // so the app's server switch did nothing.
  const serverCookie = resolveKatanaServerCookie(
    parsed.hostname,
    req.query.cookie,
  );

  try {
    // MangaKatana's bot protection answers rapid concurrent requests
    // with 200 + an EMPTY body, which used to get cached and served
    // to the app ("chapters never load"). Retry empty bodies and
    // never cache them.
    let body = '';
    let status = 502;
    for (let attempt = 0; attempt < 3; attempt++) {
      const upstream = await fetch(targetUrl, {
        method: 'GET',
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          Referer: parsed.origin + '/',
          ...(serverCookie ? { Cookie: serverCookie } : {}),
        },
        signal: AbortSignal.timeout(20000),
      });
      body = await upstream.text();
      status = upstream.status;
      if (status !== 200 || body.length > 0) break;
      await new Promise((r) => setTimeout(r, 350));
    }
    res.status(status);
    res.set(
      'Content-Type',
      'text/html; charset=utf-8',
    );
    res.set('Cache-Control', body.length > 0 ? 'public, max-age=60' : 'no-store');
    res.send(body);
  } catch (e) {
    console.warn(`proxyFetchHtml failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyScanlation, proxyFetchHtml };
