'use strict';

const { cappedHttps, enforceRateLimit, getAdmin } = require('./common.js');

/**
 * Proxies manga chapter page images so Flutter web isn't blocked by
 * CORS or hotlink protection. The MangaDex at-home image server
 * doesn't send CORS headers, so a direct Image.network request from
 * the browser fails. This function fetches the image server-side and
 * streams it back to the client with permissive CORS headers.
 *
 * Accepts:
 *   GET /proxyMangaImage?url=<encoded image url>
 *
 * Mirrors the `proxyBookText` pattern: optional Firebase Auth token in
 * the Authorization header, validated if present.
 */
const proxyMangaImage = cappedHttps(30, async (req, res) => {
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
  // Image chapters burst ~20-50 requests on open; 240/min per IP covers
  // humans while cutting off bots. Anonymous by design for <img> tags.
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaImage', limit: 240, windowMs: 60000 })) return;
  // Image proxies allow anonymous access for <img> tags that cannot send
  // Authorization headers. If a token is provided in the header,
  // validate it; otherwise allow based on host allowlist alone.
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
  const allowedHosts = new Set([
    'uploads.mangadex.org',
  ]);
  const allowedSuffixes = ['.mangadex.network', '.mangadex.org'];
  const hostAllowed =
    allowedHosts.has(parsed.hostname) ||
    allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
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
    console.warn(`proxyMangaImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies MangaKakalot chapter page images so Flutter web isn't blocked
 * by CORS or hotlink protection.
 *
 * Accepts:
 *   GET /proxyMangaKakalotImage?url=<encoded image url>
 */
const proxyMangaKakalotImage = cappedHttps(30, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaKakalotImage', limit: 240, windowMs: 60000 })) return;
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

  const allowedSuffixes = [
    '.mangakakalot.com',
    '.mkklcdnv6temp.com',
  ];
  const hostAllowed = allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8', 'Referer': 'https://mangakakalot.com/' },
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
    console.warn(`proxyMangaKakalotImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies MangaKatana chapter page images so Flutter web isn't blocked
 * by CORS or hotlink protection.
 *
 * Accepts:
 *   GET /proxyMangaKatana?url=<encoded image url>
 */
const proxyMangaKatana = cappedHttps(30, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaKatana', limit: 240, windowMs: 60000 })) return;
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

  const allowedSuffixes = [
    '.mangakatana.com',
    '.mangakakalot.com',
    '.mkklcdnv6temp.com',
    '.catmanga.org',
  ];
  const hostAllowed =
    parsed.hostname === 'mangakatana.com' ||
    allowedSuffixes.some((s) => parsed.hostname.endsWith(s));
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: { 'Accept': 'image/*,*/*;q=0.8', 'Referer': 'https://mangakatana.com/' },
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
    console.warn(`proxyMangaKatana failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies Comick catalog API requests so Flutter web isn't blocked by CORS.
 * Same pattern as `proxyMangaDex` — forwards to api.comick.dev with
 * permissive CORS headers.
 */
const proxyComick = cappedHttps(30, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyComick', limit: 240, windowMs: 60000 })) return;
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







  const pathParam = req.query.path;
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    res.status(400).json({ error: 'Missing ?path=<api path> query param' });
    return;
  }

  const safePath = pathParam.replace(/^\/+/, '').replace(/\.\.+/g, '');
  if (safePath.length === 0) {
    res.status(400).json({ error: 'Empty path' });
    return;
  }
  const targetUrl = `https://api.comick.dev/${safePath}`;

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(20000),
    });
    const body = await upstream.text();
    res.status(upstream.status);
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'application/json',
    );
    res.set('Cache-Control', 'public, max-age=60');
    res.send(body);
  } catch (e) {
    console.warn(`proxyComick failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies MangaDex catalog API requests so Flutter web isn't blocked
 * by CORS. The MangaDex API at api.mangadex.org doesn't send an
 * `Access-Control-Allow-Origin` header on its responses, so the
 * browser drops the body and the client sees an empty `data` array
 * (which is what causes the "Nothing here yet." placeholders in the
 * manga library). This function forwards the request server-side and
 * returns the body with permissive CORS headers.
 *
 * Accepts:
 *   GET /proxyMangaDex?path=<encoded api path with query,
 *                            e.g. "manga?limit=20&includes%5B%5D=cover_art">
 *
 * Only the api.mangadex.org host is allowed — the path is sanitized
 * to prevent abuse. Mirrors the `proxyMangaImage` pattern: optional
 * Firebase Auth token in the Authorization header, validated if
 * present.
 */

const proxyMangaDex = cappedHttps(30, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyMangaDex', limit: 240, windowMs: 60000 })) return;
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







  const pathParam = req.query.path;
  if (typeof pathParam !== 'string' || pathParam.length === 0) {
    res.status(400).json({ error: 'Missing ?path=<api path> query param' });
    return;
  }

  const safePath = pathParam.replace(/^\/+/, '').replace(/\.\.+/g, '');
  if (safePath.length === 0) {
    res.status(400).json({ error: 'Empty path' });
    return;
  }
  const targetUrl = `https://api.mangadex.org/${safePath}`;

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(20000),
    });
    const body = await upstream.text();
    res.status(upstream.status);
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'application/json',
    );
    res.set('Cache-Control', 'public, max-age=60');
    res.send(body);
  } catch (e) {
    console.warn(`proxyMangaDex failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

module.exports = { proxyMangaImage, proxyMangaKakalotImage, proxyMangaKatana, proxyComick, proxyMangaDex };
