'use strict';

const functions = require('firebase-functions/v1');
const net = require('net');
const dns = require('dns').promises;

const {
  getAdmin,
  requireAuth,
  getVerifiedUsername,
  isPrivateIpv4,
  isPrivateIp,
  isPublicDnsHost,
  isAllowedBookTextUrl,
} = require('./common.js');

const proxyBookText = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) return;

  const { urls } = req.body;
  if (!Array.isArray(urls) || urls.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty urls array' });
    return;
  }

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    if (typeof url !== 'string' || !isAllowedBookTextUrl(url)) {
      console.warn(`proxyBookText rejected URL ${url}`);
      continue;
    }
    if (!(await isPublicDnsHost(new URL(url).hostname))) {
      console.warn(`proxyBookText rejected non-public host ${url}`);
      continue;
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: { 'Accept': 'text/plain' },
        redirect: 'follow',
        signal: controller.signal,
      });
      const contentType = response.headers.get('content-type') || '';
      const isPlainText = contentType.toLowerCase().includes('text/plain');
      if (response.ok) {
        const text = await response.text();
        const looksLikeHtml =
          text.trimLeft().toLowerCase().startsWith('<!doctype') ||
          text.trimLeft().toLowerCase().startsWith('<html') ||
          (text.trimLeft().startsWith('<') && text.trim().length < 4096);
        if (text.trim().length > 0 && isPlainText && !looksLikeHtml) {
          res.json({ text, usedUrl: url, attempted: urls.slice(0, i + 1) });
          return;
        }
      }
    } catch (e) {
      console.warn(`proxyBookText attempt ${i} failed (${url}):`, e.message);
    } finally {
      clearTimeout(timer);
    }
  }

  res.json({
    text: '',
    usedUrl: '',
    attempted: urls,
    error: `Tried ${urls.length} source(s); none responded with readable text.`,
  });
});

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
const proxyMangaImage = functions.https.onRequest(async (req, res) => {
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
  // Image proxies allow anonymous access for <img> tags that cannot send
  // Authorization headers. If a token is provided (header or ?token=),
  // validate it; otherwise allow based on host allowlist alone.
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
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
const proxyMangaKakalotImage = functions.https.onRequest(async (req, res) => {
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
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
const proxyMangaKatana = functions.https.onRequest(async (req, res) => {
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
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
/**
 * Proxies Comick catalog API requests so Flutter web isn't blocked by CORS.
 * Same pattern as `proxyMangaDex` — forwards to api.comick.dev with
 * permissive CORS headers.
 */
const proxyComick = functions.https.onRequest(async (req, res) => {
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
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
const proxyAnimeImage = functions.https.onRequest(async (req, res) => {
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

/**
 * Proxies gallery images from Firebase Storage so Flutter web isn't
 * blocked by any CORS or auth issues with direct Storage download URLs.
 *
 * Accepts:
 *   GET /proxyGalleryImage?url=<encoded Storage download URL>
 *
 * Validates that the URL belongs to the project's Storage bucket,
 * then fetches and streams it back with permissive CORS headers.
 *
 * NOTE: Does NOT require Firebase Auth via Authorization header because
 * Flutter Web Image.network cannot send custom headers. The upstream
 * Storage URL already contains a per-file download token, and we
 * restrict to our own bucket to prevent open-proxy abuse.
 */
const proxyGalleryImage = functions.https.onRequest(async (req, res) => {
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

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  // Only allow URLs from the project's own Storage bucket
  if (!targetUrl.includes('firebasestorage.googleapis.com') ||
      !targetUrl.includes('everglow-1c6db')) {
    res.status(403).json({ error: 'URL must be from the project Storage bucket' });
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
    res.set('Cache-Control', 'public, max-age=3600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyGalleryImage failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Cleans up orphaned gallery data: deletes all Firestore docs in
 * the gallery collection AND their Storage files.
 *
 * Accepts:
 *   POST /cleanupGallery  { confirm: true }
 *
 * Auth required (only khentsgdz can call this).
 */
const cleanupGallery = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Only POST is accepted' });
    return;
  }

  // Verify auth
  const idToken = req.headers.authorization?.replace('Bearer ', '');
  if (!idToken) {
    res.status(401).json({ error: 'Auth required' });
    return;
  }
  const admin = getAdmin();
  const decoded = await admin.auth().verifyIdToken(idToken);
  if (decoded.uid !== 'Khentsgdz') {
    // Fall back to the user document so recreated accounts keep working.
    const userDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
    if (!userDoc.exists || userDoc.data()?.username !== 'khentsgdz') {
      res.status(403).json({ error: 'Only khentsgdz can run cleanup' });
      return;
    }
  }

  if (req.body?.confirm !== true) {
    res.status(400).json({ error: 'Send { confirm: true } to actually delete' });
    return;
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  const snap = await db.collection('gallery').limit(2000).get();
  let deleted = 0;

  // Bounded concurrency keeps this from exhausting memory/CPU when the
  // gallery grows; each worker handles storage + Firestore deletion.
  const workerCount = 20;
  let cursor = 0;
  async function worker() {
    while (cursor < snap.docs.length) {
      const doc = snap.docs[cursor++];
      const d = doc.data();
      // Delete Storage file
      if (d.imageUrl && d.imageUrl.includes('firebasestorage.googleapis.com')) {
        try {
          const path = decodeURIComponent(d.imageUrl.split('/o/')[1]?.split('?')[0] || '');
          if (path) await bucket.file(path).delete();
        } catch (_) { /* best effort */ }
      }
      // Delete Firestore doc
      await doc.ref.delete();
      deleted++;
    }
  }
  await Promise.all(Array.from({ length: workerCount }, () => worker()));

  res.json({ deleted });
});

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
const proxyScanlation = functions.https.onRequest(async (req, res) => {
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
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
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyScanlation failed (${targetUrl}):`, e.message);
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
 *   GET /proxyFetchHtml?url=<encoded target URL>
 *
 * The function:
 *   1. Validates the URL against a whitelist of manga/scraping domains
 *   2. Fetches the HTML page server-side (with spoofed Referer)
 *   3. Returns the raw HTML with permissive CORS headers
 *
 * This follows the same pattern as proxyScanlation (image proxy) but
 * returns text/html instead of binary image data.
 */
const proxyFetchHtml = functions.https.onRequest(async (req, res) => {
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
  // Allow anonymous for manga scraping (host allowlist restricts to public sites).
  // If a token is provided, validate it.
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
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

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        Referer: parsed.origin + '/',
      },
      signal: AbortSignal.timeout(20000),
    });
    const body = await upstream.text();
    res.status(upstream.status);
    res.set(
      'Content-Type',
      upstream.headers.get('content-type') || 'text/html; charset=utf-8',
    );
    res.set('Cache-Control', 'public, max-age=60');
    res.send(body);
  } catch (e) {
    console.warn(`proxyFetchHtml failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

/**
 * Proxies video embed pages (Videasy, VidFast, VidLink, etc.) through
 * our Cloud Function to strip ad scripts before the browser renders
 * the embed. This is the server-side equivalent of FluxTV's approach
 * — the iframe loads cleaned HTML from our domain instead of the
 * provider's domain, so ad networks can't fire.
 *
 * Accepts:
 *   GET /proxyEmbed?url=<encoded embed URL>
 *
 * The function:
 *   1. Validates the URL against an allowlist of known embed hosts
 *   2. Fetches the embed HTML server-side (with spoofed Referer)
 *   3. Strips ad-related <script>, <iframe>, and <div> elements
 *   4. Rewrites relative URLs to absolute (so CSS/JS/images load)
 *   5. Injects a lightweight ad-block script (popup blocker + MutationObserver)
 *   6. Returns the cleaned HTML with permissive CORS headers
 */
const proxyEmbed = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<embed url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  // Allowlist of embed provider hosts
  const allowedHosts = new Set([
    'player.videasy.net',
    'vidfast.pro',
    'vidlink.pro',
    'multiembed.mov',
    'www.2embed.cc',
    'vsembed.ru',
    'vidrock.ru',
    '111movies.com',
    'vidsrc.to',
  ]);
  if (parsed.protocol !== 'https:' || !allowedHosts.has(parsed.hostname)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  // Derive the base origin for rewriting relative URLs
  const baseOrigin = `${parsed.protocol}//${parsed.host}`;

  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Referer': `${baseOrigin}/`,
        'Accept-Language': 'en-US,en;q=0.9',
      },
      signal: AbortSignal.timeout(15000),
    });

    if (!upstream.ok) {
      res.status(upstream.status).json({ error: `Upstream returned ${upstream.status}` });
      return;
    }

    let html = await upstream.text();

    // ── Step 1: Strip ad-related <script> tags ──
    // Remove scripts that load known ad networks or trackers
    const adScriptPatterns = [
      /<script[^>]*\ssrc=["'][^"']*(?:googletag|doubleclick|adsense|google-analytics|googlesyndication)[^"']*["'][^>]*>\s*<\/script>/gi,
      /<script[^>]*\ssrc=["'][^"']*(?:adskeeper|juicyads|popads|popcash|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola)[^"']*["'][^>]*>\s*<\/script>/gi,
      /<script[^>]*\ssrc=["'][^"']*(?:pagead|adsbygoogle|adservice|adserver|adblock|antiadblock)[^"']*["'][^>]*>\s*<\/script>/gi,
      // Inline scripts that set up ad-related globals or push ad frames
      /<script[^>]*>\s*(?:var\s+_0x|window\['[^']*'\]\s*=|document\.write\(\s*['"]<iframe|adsbygoogle|googletag)/gi,
    ];
    for (const pattern of adScriptPatterns) {
      html = html.replace(pattern, '<!-- ad script stripped -->');
    }

    // ── Step 2: Strip ad-related <iframe> tags ──
    html = html.replace(
      /<iframe[^>]*\ssrc=["'][^"']*(?:ad|sponsor|banner|promo|click|track|pixel|beacon)[^"']*["'][^>]*>[\s\S]*?<\/iframe>/gi,
      '<!-- ad iframe stripped -->'
    );

    // ── Step 3: Strip ad-related <div> containers ──
    html = html.replace(
      /<div[^>]*\s(?:class|id)=["'][^"']*(?:ad-container|adsbox|banner-ad|sponsor|ad-wrapper|ad-overlay|popup-ad)[^"']*["'][^>]*>[\s\S]*?<\/div>/gi,
      '<!-- ad div stripped -->'
    );

    // ── Step 4: Rewrite relative URLs to absolute ──
    // src="/assets/foo.js" → src="https://player.videasy.net/assets/foo.js"
    html = html.replace(
      /(<(?:script|link|img|video|source|iframe)[^>]*\s(?:src|href)=["'])((?!https?:\/\/|\/\/|data:|blob:|#)([^"']+))(["'])/gi,
      `$1${baseOrigin}/$2$4`
    );
    // Also fix CSS url() references
    html = html.replace(
      /(url\(['"]?)((?!https?:\/\/|\/\/|data:|blob:|#)([^'")\s]+))(['"]?\))/gi,
      `$1${baseOrigin}/$2$4`
    );

    // ── Step 5: Inject ad-block script ──
    // A lightweight script that:
    //   - Overrides window.open to block popups
    //   - Sets up a MutationObserver to auto-remove dynamically injected ad elements
    const adBlockScript = `
<script>
(function() {
  var _origOpen = window.open;
  window.open = function(url) {
    if (url && /ad|sponsor|promo|click|track|popup|banner|traffic|pop|redirect/i.test(url)) return null;
    return _origOpen.apply(this, arguments);
  };
  var _origFetch = window.fetch;
  window.fetch = function(url, opts) {
    var u = (typeof url === 'string') ? url : (url && url.url) || '';
    if (/googlesyndication|doubleclick|adservice|adserver|adskeeper|juicyads|popads|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola|pagead|google-analytics|adsbygoogle|googleads|adnxs|pubmatic|rubiconproject|openx|criteo|smartadserver|yieldmo|smaato/i.test(u)) {
      return Promise.resolve(new Response('', {status: 204}));
    }
    return _origFetch.apply(this, arguments);
  };
  var _origXHR = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (/googlesyndication|doubleclick|adservice|adserver|adskeeper|juicyads|popads|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola|pagead|google-analytics|adsbygoogle/i.test(url)) {
      return;
    }
    return _origXHR.apply(this, arguments);
  };
  function isAd(node) {
    if (!node || node.nodeType !== 1) return false;
    var tag = node.tagName;
    var src = (node.src || node.getAttribute('src') || node.getAttribute('data-src') || '').toLowerCase();
    var cls = ((node.className || '') + ' ' + (node.id || '')).toLowerCase();
    var style = (node.getAttribute('style') || '').toLowerCase();
    if (tag === 'IFRAME') {
      if (/ad|sponsor|promo|click|track|pixel|beacon|popup|banner|traffic/i.test(src + ' ' + cls)) return true;
      if (/z-index:\s*[89]\d{3,}/.test(style)) return true;
      if (/display:\s*none|visibility:\s*hidden|width:\s*0|height:\s*0/.test(style) && /track|pixel|beacon/i.test(src + ' ' + cls)) return true;
    }
    if (tag === 'SCRIPT') {
      if (/googlesyndication|doubleclick|adservice|adserver|adskeeper|juicyads|popads|exoclick|trafficjunky|hilltopads|propellerads|adsterra|clickadu|mgid|outbrain|taboola|pagead|google-analytics|adsbygoogle|googleads|popunder|onclick/i.test(src)) return true;
    }
    if (tag === 'DIV' || tag === 'SECTION' || tag === 'ASIDE' || tag === 'INS') {
      if (/ad[-_]|ads[-_]|advert|sponsor|banner|promo|popup|overlay|taboola|outbrain|adsense|adsbygoogle|google_ads|ezoic|mediavine|adthrive/i.test(cls)) return true;
      if (tag === 'INS' && /adsbygoogle/i.test(cls)) return true;
    }
    return false;
  }
  function removeAds(root) {
    try {
      var candidates = root.querySelectorAll('iframe, script[src], div, section, aside, ins');
      candidates.forEach(function(el) { if (isAd(el)) el.remove(); });
    } catch(e) {}
  }
  if (document.body) removeAds(document.body);
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (isAd(node)) { node.remove(); return; }
        if (node.querySelectorAll) {
          try {
            node.querySelectorAll('iframe, script[src], div, section, aside, ins').forEach(function(child) {
              if (isAd(child)) child.remove();
            });
          } catch(e) {}
        }
      });
    });
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
  window.alert = function(){};
  window.confirm = function(){ return false; };
  window.prompt = function(){ return null; };
  window.adsbygoogle = window.adsbygoogle || { push: function(){} };
  window.googletag = window.googletag || { cmd: { push: function(fn){ fn(); } }, pubads: function(){ return { enableSingleRequest: function(){}, setTargeting: function(){} }; }, enableServices: function(){} };
  // ── Forward wheel events to parent for scroll-through ──
  // Without this, the iframe captures all wheel events and the
  // parent page can't scroll on desktop.
  document.addEventListener('wheel', function(e) {
    try {
      window.parent.postMessage({ type: 'proxyEmbed_scroll', deltaY: e.deltaY }, '*');
    } catch(ex) {}
  }, { passive: true });

  setInterval(function() { if (document.body) removeAds(document.body); }, 1000);
})();
</script>
`

    // Inject before </body>
    html = html.replace(/<\/body>(?![\s\S]*<\/body>)/i, adBlockScript + '\n</body>');

    // ── Step 6: Remove X-Frame-Options / CSP headers from upstream ──
    // (We're serving from our domain, so these don't apply)
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.set('Cache-Control', 'public, max-age=300');
    res.status(200).send(html);

  } catch (e) {
    console.warn(`proxyEmbed failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});

const proxyMangaDex = functions.https.onRequest(async (req, res) => {
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
  const header = req.get('Authorization') || req.headers.authorization || '';
  const tokenFromQuery = req.query.token ? String(req.query.token) : '';
  const idToken = (header ? String(header).replace(/^Bearer\s+/i, '') : '') || tokenFromQuery;
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

/**
 * Fetches the direct video stream URL from VidLink server-side so Flutter
 * can play it in a controllable <video> element on the same origin.
 *
 * Accepts: POST /proxyVideoStream  { type, id, season?, episode? }
 * Returns: { url: string|null, debug: {...} }
 */
const proxyVideoStream = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'POST only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;







  const { type, id, season, episode } = req.body || {};
  if (!type || !id) { res.status(400).json({ error: 'type and id required' }); return; }

  try {
    // Get the encoded ID via VidLink's WASM module
    const encodedId = await getEncodedId(id.toString());
    console.log(`proxyVideoStream: tmdbId=${id} → encoded=${encodedId}`);

    if (!encodedId) {
      res.json({ url: null, error: 'Could not encode ID' });
      return;
    }

    // Call VidLink's internal API with the encoded ID
    const apiPath = type === 'tv'
      ? `/api/b/tv/${encodedId}/${season||1}/${episode||1}?multiLang=1`
      : `/api/b/movie/${encodedId}?multiLang=1`;
    const apiResp = await fetch(`https://vidlink.pro${apiPath}`, {
      headers: {
        'Referer': 'https://vidlink.pro/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
    });

    if (!apiResp.ok) {
      res.json({ url: null, error: `API returned ${apiResp.status}`, encodedId });
      return;
    }

    const data = await apiResp.json();
    const s = JSON.stringify(data);
    const m3u8 = s.match(/(https?:\/\/[^"'\s]*\.m3u8[^"'\s]*)/i);
    const mp4 = s.match(/(https?:\/\/[^"'\s]*\.mp4[^"'\s]*)/i);
    const url = m3u8 ? m3u8[1] : (mp4 ? mp4[1] : null);

    res.json({
      url,
      encodedId,
      streamData: JSON.stringify(data).substring(0, 2000),
    });
  } catch (e) {
    res.status(502).json({ error: e.message });
  }
});

// ─── WASM-based ID encoding ──────────────────────────────────────────

/**
 * Proxies self-hosted watch-party streams (HLS playlists, segments, and
 * subtitles) so Flutter web can load them without CORS or hotlink
 * blocks. This mirrors AniChan's `/api/watch/m3u8` + `/api/watch/vtt`
 * pattern: the client passes a normalized upstream URL and this
 * function streams it back with permissive CORS headers.
 *
 * Accepts:
 *   GET /proxyWatchStream?url=<encoded upstream url>[&referer=<encoded>]
 */
const proxyWatchStream = functions.https.onRequest(async (req, res) => {
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







  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<stream url> query param' });
    return;
  }

  let parsed;
  try {
    parsed = new URL(targetUrl);
  } catch (_) {
    res.status(400).json({ error: 'Invalid url' });
    return;
  }

  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    res.status(400).json({ error: 'Only http(s) urls are allowed' });
    return;
  }
  const hostname = parsed.hostname.toLowerCase();
  const blocked = [
    'localhost',
    '127.0.0.1',
    '::1',
    '169.254.169.254',
    'metadata.google.internal',
    'metadata',
  ];
  if (blocked.includes(hostname)) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  const referer = req.query.referer;
  try {
    const upstream = await fetch(targetUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
        ...(referer ? { 'Referer': String(referer) } : {}),
      },
      redirect: 'follow',
      signal: AbortSignal.timeout(30000),
    });
    if (!upstream.ok) {
      res
        .status(upstream.status)
        .json({ error: `Upstream returned ${upstream.status}` });
      return;
    }

    const contentType = upstream.headers.get('content-type') || 'application/octet-stream';
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=300');

    // Stream large segment files instead of buffering them fully.
    if (upstream.body && typeof upstream.body.getReader === 'function') {
      const reader = upstream.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(Buffer.from(value));
      }
      res.end();
      return;
    }

    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.status(200).send(buffer);
  } catch (e) {
    console.warn(`proxyWatchStream failed (${targetUrl}):`, e.message);
    res.status(502).json({ error: `Upstream fetch failed: ${e.message}` });
  }
});


let _wasmReady = null;
let _wasmGetAdv = null;

async function getEncodedId(tmdbId) {
  if (!_wasmReady) {
    _wasmReady = initWasm();
  }
  try {
    const getAdv = await _wasmReady;
    if (!getAdv) return null;
    return getAdv(tmdbId);
  } catch (e) {
    console.error('getEncodedId error:', e.message);
    return null;
  }
}

async function initWasm() {
  const sodium = require('libsodium-wrappers-sumo');
  await sodium.ready;
  globalThis.sodium = sodium;

  // Download fu.wasm
  console.log('Downloading fu.wasm...');
  const wasmResp = await fetch('https://vidlink.pro/fu.wasm', {
    headers: { 'Referer': 'https://vidlink.pro/', 'User-Agent': 'Mozilla/5.0' },
  });
  const wasmBytes = await wasmResp.arrayBuffer();
  console.log(`fu.wasm loaded: ${wasmBytes.byteLength} bytes`);

  // Polyfills needed by script.js (Node.js adaptation)
  const enosys = () => { const e = new Error('not implemented'); e.code = 'ENOSYS'; return e; };
  if (!globalThis.fs) {
    let outputBuf = '';
    globalThis.fs = {
      constants: { O_WRONLY: -1, O_RDWR: -1, O_CREAT: -1, O_TRUNC: -1, O_APPEND: -1, O_EXCL: -1 },
      writeSync(fd, buf) {
        outputBuf += new TextDecoder('utf-8').decode(buf);
        return buf.length;
      },
      write(fd, buf, offset, length, position, callback) {
        const n = globalThis.fs.writeSync(fd, buf);
        callback(null, n);
      },
      chmod(p, m, cb) { cb(enosys()); },
      chown(p, u, g, cb) { cb(enosys()); },
      close(fd, cb) { cb(enosys()); },
      fchmod(fd, m, cb) { cb(enosys()); },
      fchown(fd, u, g, cb) { cb(enosys()); },
      fstat(fd, cb) { cb(enosys()); },
      fsync(fd, cb) { cb(null); },
      ftruncate(fd, l, cb) { cb(enosys()); },
      lchown(p, u, g, cb) { cb(enosys()); },
      link(p, l, cb) { cb(enosys()); },
      lstat(p, cb) { cb(enosys()); },
      mkdir(p, pm, cb) { cb(enosys()); },
      open(p, f, m, cb) { cb(enosys()); },
      read(fd, buf, o, l, p, cb) { cb(enosys()); },
      readdir(p, cb) { cb(enosys()); },
      readlink(p, cb) { cb(enosys()); },
      rename(f, t, cb) { cb(enosys()); },
      rmdir(p, cb) { cb(enosys()); },
      stat(p, cb) { cb(enosys()); },
      symlink(p, l, cb) { cb(enosys()); },
      truncate(p, l, cb) { cb(enosys()); },
      unlink(p, cb) { cb(enosys()); },
      utimes(p, a, m, cb) { cb(enosys()); },
    };
  }

  if (!globalThis.process) {
    globalThis.process = {
      getuid() { return -1; }, getgid() { return -1; },
      geteuid() { return -1; }, getegid() { return -1; },
      getgroups() { throw enosys(); },
      pid: -1, ppid: -1,
      umask() { throw enosys(); },
      cwd() { throw enosys(); },
      chdir() { throw enosys(); },
    };
  }

  if (!globalThis.performance) {
    globalThis.performance = require('perf_hooks').performance;
  }

  // Provide crypto.getRandomValues for Node (not in globalThis automatically)
  if (!globalThis.crypto || !globalThis.crypto.getRandomValues) {
    const nodeCrypto = require('crypto');
    globalThis.crypto = globalThis.crypto || {};
    globalThis.crypto.getRandomValues = (arr) => {
      const buf = nodeCrypto.randomBytes(arr.length);
      for (let i = 0; i < arr.length; i++) arr[i] = buf[i];
      return arr;
    };
  }

  // Provide browser-like globals the Go WASM might need
  if (!globalThis.window) globalThis.window = globalThis;
  if (!globalThis.document) globalThis.document = { cookie: '', querySelector: () => null, body: { appendChild: () => {} } };
  if (!globalThis.location) globalThis.location = { href: 'https://vidlink.pro/', origin: 'https://vidlink.pro', protocol: 'https:', host: 'vidlink.pro', pathname: '/' };
  if (!globalThis.navigator) globalThis.navigator = { userAgent: 'Mozilla/5.0', platform: 'Linux' };
  if (!globalThis.localStorage) globalThis.localStorage = { _data: {}, getItem: (k) => globalThis.localStorage._data[k] || null, setItem: (k, v) => { globalThis.localStorage._data[k] = v; }, removeItem: (k) => { delete globalThis.localStorage._data[k]; } };
  if (!globalThis.fetch) globalThis.fetch = fetch;

  // ── Dm class – exact copy of VidLink's script.js runtime ──
  const encoder = new TextEncoder('utf-8');

  class Dm {
    constructor() {
      this.argv = ['js'];
      this.env = {};
      this.exit = (code) => { if (code !== 0) console.warn('exit code:', code); };
      this._exitPromise = new Promise((resolve) => { this._resolveExitPromise = resolve; });
      this._pendingEvent = null;
      this._scheduledTimeouts = new Map();
      this._nextCallbackTimeoutID = 1;

      const setInt64 = (addr, v) => {
        this.mem.setUint32(addr + 0, v, true);
        this.mem.setUint32(addr + 4, Math.floor(v / 4294967296), true);
      };

      const getInt64 = (addr) => {
        const low = this.mem.getUint32(addr + 0, true);
        const high = this.mem.getInt32(addr + 4, true);
        return low + high * 4294967296;
      };

      const loadValue = (addr) => {
        const f = this.mem.getFloat64(addr, true);
        if (f === 0) return undefined;
        if (!isNaN(f)) return f;
        const id = this.mem.getUint32(addr, true);
        return this._values[id];
      };

      const storeValue = (addr, v) => {
        const nanHead = 0x7ff80000;
        if (typeof v === 'number' && v !== 0) {
          if (isNaN(v)) { this.mem.setUint32(addr + 4, nanHead, true); this.mem.setUint32(addr, 0, true); return; }
          this.mem.setFloat64(addr, v, true); return;
        }
        if (v === undefined) { this.mem.setFloat64(addr, 0, true); return; }
        let id = this._ids.get(v);
        if (id === undefined) { id = this._idPool.pop(); if (id === undefined) id = this._values.length; this._values[id] = v; this._goRefCounts[id] = 0; this._ids.set(v, id); }
        this._goRefCounts[id]++;
        let typeFlag = 0;
        switch (typeof v) {
          case 'object': if (v !== null) typeFlag = 1; break;
          case 'string': typeFlag = 2; break;
          case 'symbol': typeFlag = 3; break;
          case 'function': typeFlag = 4; break;
        }
        this.mem.setUint32(addr + 4, nanHead | typeFlag, true);
        this.mem.setUint32(addr, id, true);
      };

      const loadSlice = (addr) => {
        const array = getInt64(addr + 0);
        const len = getInt64(addr + 8);
        return new Uint8Array(this._inst.exports.mem.buffer, array, len);
      };

      const loadSliceOfValues = (addr) => {
        const array = getInt64(addr + 0);
        const len = getInt64(addr + 8);
        const a = new Array(len);
        for (let i = 0; i < len; i++) a[i] = loadValue(array + i * 8);
        return a;
      };

      const loadString = (addr) => {
        const saddr = getInt64(addr + 0);
        const len = getInt64(addr + 8);
        return new TextDecoder('utf-8').decode(new DataView(this._inst.exports.mem.buffer, saddr, len));
      };

      const timeOrigin = Date.now() - performance.now();
      this.importObject = {
        gojs: {
          'runtime.wasmExit': (sp) => {
            sp >>>= 0;
            const code = this.mem.getInt32(sp + 8, true);
            this.exited = true;
            delete this._inst; delete this._values; delete this._goRefCounts; delete this._ids; delete this._idPool;
            this.exit(code);
          },
          'runtime.wasmWrite': (sp) => {
            sp >>>= 0;
            const fd = getInt64(sp + 8);
            const p = getInt64(sp + 16);
            const n = this.mem.getInt32(sp + 24, true);
            globalThis.fs.writeSync(fd, new Uint8Array(this._inst.exports.mem.buffer, p, n));
          },
          'runtime.resetMemoryDataView': (sp) => { sp >>>= 0; this.mem = new DataView(this._inst.exports.mem.buffer); },
          'runtime.nanotime1': (sp) => { sp >>>= 0; setInt64(sp + 8, (timeOrigin + performance.now()) * 1000000); },
          'runtime.walltime': (sp) => {
            sp >>>= 0;
            const msec = new Date().getTime();
            setInt64(sp + 8, msec / 1000);
            this.mem.setInt32(sp + 16, (msec % 1000) * 1000000, true);
          },
          'runtime.scheduleTimeoutEvent': (sp) => {
            sp >>>= 0;
            const id = this._nextCallbackTimeoutID;
            this._nextCallbackTimeoutID++;
            this._scheduledTimeouts.set(id, setTimeout(() => { this._resume(); while (this._scheduledTimeouts.has(id)) { console.warn('scheduleTimeoutEvent: missed'); this._resume(); } }, getInt64(sp + 8)));
            this.mem.setInt32(sp + 16, id, true);
          },
          'runtime.clearTimeoutEvent': (sp) => { sp >>>= 0; const id = this.mem.getInt32(sp + 8, true); clearTimeout(this._scheduledTimeouts.get(id)); this._scheduledTimeouts.delete(id); },
          'runtime.getRandomData': (sp) => { sp >>>= 0; globalThis.crypto.getRandomValues(loadSlice(sp + 8)); },
          'syscall/js.finalizeRef': (sp) => { sp >>>= 0; const id = this.mem.getUint32(sp + 8, true); this._goRefCounts[id]--; if (this._goRefCounts[id] === 0) { const v = this._values[id]; this._values[id] = null; this._ids.delete(v); this._idPool.push(id); } },
          'syscall/js.stringVal': (sp) => { sp >>>= 0; storeValue(sp + 24, loadString(sp + 8)); },
          'syscall/js.valueGet': (sp) => { sp >>>= 0; const result = Reflect.get(loadValue(sp + 8), loadString(sp + 16)); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 32, result); },
          'syscall/js.valueSet': (sp) => { sp >>>= 0; Reflect.set(loadValue(sp + 8), loadString(sp + 16), loadValue(sp + 32)); },
          'syscall/js.valueDelete': (sp) => { sp >>>= 0; Reflect.deleteProperty(loadValue(sp + 8), loadString(sp + 16)); },
          'syscall/js.valueIndex': (sp) => { sp >>>= 0; storeValue(sp + 24, Reflect.get(loadValue(sp + 8), getInt64(sp + 16))); },
          'syscall/js.valueSetIndex': (sp) => { sp >>>= 0; Reflect.set(loadValue(sp + 8), getInt64(sp + 16), loadValue(sp + 24)); },
          'syscall/js.valueCall': (sp) => {
            sp >>>= 0;
            try { const v = loadValue(sp + 8); const m = Reflect.get(v, loadString(sp + 16)); const args = loadSliceOfValues(sp + 32); const result = Reflect.apply(m, v, args); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 56, result); this.mem.setUint8(sp + 64, 1); }
            catch (err) { sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 56, err); this.mem.setUint8(sp + 64, 0); }
          },
          'syscall/js.valueInvoke': (sp) => {
            sp >>>= 0;
            try { const v = loadValue(sp + 8); const args = loadSliceOfValues(sp + 16); const result = Reflect.apply(v, undefined, args); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, result); this.mem.setUint8(sp + 48, 1); }
            catch (err) { sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, err); this.mem.setUint8(sp + 48, 0); }
          },
          'syscall/js.valueNew': (sp) => {
            sp >>>= 0;
            try { const v = loadValue(sp + 8); const args = loadSliceOfValues(sp + 16); const result = Reflect.construct(v, args); sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, result); this.mem.setUint8(sp + 48, 1); }
            catch (err) { sp = this._inst.exports.getsp() >>> 0; storeValue(sp + 40, err); this.mem.setUint8(sp + 48, 0); }
          },
          'syscall/js.valueLength': (sp) => { sp >>>= 0; setInt64(sp + 16, parseInt(loadValue(sp + 8).length)); },
          'syscall/js.valuePrepareString': (sp) => { sp >>>= 0; const str = encoder.encode(String(loadValue(sp + 8))); storeValue(sp + 16, str); setInt64(sp + 24, str.length); },
          'syscall/js.valueLoadString': (sp) => { sp >>>= 0; const str = loadValue(sp + 8); loadSlice(sp + 16).set(str); },
          'syscall/js.valueInstanceOf': (sp) => { sp >>>= 0; this.mem.setUint8(sp + 24, loadValue(sp + 8) instanceof loadValue(sp + 16) ? 1 : 0); },
          'syscall/js.copyBytesToGo': (sp) => {
            sp >>>= 0;
            const dst = loadSlice(sp + 8);
            const src = loadValue(sp + 32);
            if (!(src instanceof Uint8Array || src instanceof Uint8ClampedArray)) { this.mem.setUint8(sp + 48, 0); return; }
            const toCopy = src.subarray(0, dst.length); dst.set(toCopy); setInt64(sp + 40, toCopy.length); this.mem.setUint8(sp + 48, 1);
          },
          'syscall/js.copyBytesToJS': (sp) => {
            sp >>>= 0;
            const dst = loadValue(sp + 8);
            const src = loadSlice(sp + 16);
            if (!(dst instanceof Uint8Array || dst instanceof Uint8ClampedArray)) { this.mem.setUint8(sp + 48, 0); return; }
            const toCopy = src.subarray(0, dst.length); dst.set(toCopy); setInt64(sp + 40, toCopy.length); this.mem.setUint8(sp + 48, 1);
          },
          'debug': (value) => { console.log(value); },
        },
      };
    }

    async run(instance) {
      if (!(instance instanceof WebAssembly.Instance)) throw new Error('Instance expected');
      this._inst = instance;
      this.mem = new DataView(this._inst.exports.mem.buffer);
      this._values = [NaN, 0, null, true, false, globalThis, this];
      this._goRefCounts = new Array(this._values.length).fill(Infinity);
      this._ids = new Map([[0,1],[null,2],[true,3],[false,4],[globalThis,5],[this,6]]);
      this._idPool = [];
      this.exited = false;
      let offset = 4096;

      const strPtr = (str) => {
        const ptr = offset;
        const bytes = encoder.encode(str + '\0');
        new Uint8Array(this.mem.buffer, offset, bytes.length).set(bytes);
        offset += bytes.length;
        if (offset % 8 !== 0) offset += 8 - (offset % 8);
        return ptr;
      };

      const argc = this.argv.length;
      const argvPtrs = this.argv.map(strPtr);
      argvPtrs.push(0);
      const keys = Object.keys(this.env).sort();
      keys.forEach((key) => argvPtrs.push(strPtr(key + '=' + this.env[key])));
      argvPtrs.push(0);

      const argv = offset;
      argvPtrs.forEach((ptr) => { this.mem.setUint32(offset, ptr, true); this.mem.setUint32(offset + 4, 0, true); offset += 8; });

      this._inst.exports.run(argc, argv);
      if (this.exited) this._resolveExitPromise();
      await this._exitPromise;
    }

    _resume() {
      if (this.exited) throw new Error('program has already exited');
      this._inst.exports.resume();
      if (this.exited) this._resolveExitPromise();
    }
  }

  console.log('Instantiating WASM...');
  const dm = new Dm();
  const wasmModule = await WebAssembly.instantiate(wasmBytes, dm.importObject);
  await dm.run(wasmModule.instance);
  console.log('WASM initialized, getAdv available:', typeof globalThis.getAdv);

  return globalThis.getAdv || null;
}

module.exports = {
  proxyBookText,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyGalleryImage,
  cleanupGallery,
  proxyScanlation,
  proxyFetchHtml,
  proxyEmbed,
  proxyMangaDex,
  proxyVideoStream,
  proxyWatchStream,
  initWasm,
};

