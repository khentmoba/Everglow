const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Proxies book text requests so Flutter web isn't blocked by CORS.
 *
 * Accepts:
 *   POST /proxyBookText  { urls: string[] }
 *
 * Tries each URL server-side in order and returns the body of the
 * first one that responds with a 2xx and non-empty body.
 *
 * If the caller provides a Firebase ID token in the Authorization
 * header, we verify it (optional — useful in dev without a token).
 */
exports.proxyBookText = functions.https.onRequest(async (req, res) => {
  // CORS headers so the Flutter web app can call us
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

  // Optional: verify Firebase Auth token
  const idToken = req.get('Authorization')?.replace('Bearer ', '');
  if (idToken) {
    try {
      await admin.auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }

  const { urls } = req.body;
  if (!Array.isArray(urls) || urls.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty urls array' });
    return;
  }

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: { 'Accept': 'text/plain, text/html' },
        timeout: 15000,
      });
      if (response.ok) {
        const text = await response.text();
        if (text.trim().length > 0) {
          res.json({ text, usedUrl: url, attempted: urls.slice(0, i + 1) });
          return;
        }
      }
    } catch (e) {
      console.warn(`proxyBookText attempt ${i} failed (${url}):`, e.message);
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
exports.proxyMangaImage = functions.https.onRequest(async (req, res) => {
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

  const idToken = req.get('Authorization')?.replace('Bearer ', '');
  if (idToken) {
    try {
      await admin.auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: 'Invalid or expired auth token' });
      return;
    }
  }

  const targetUrl = req.query.url;
  if (typeof targetUrl !== 'string' || targetUrl.length === 0) {
    res.status(400).json({ error: 'Missing ?url=<image url> query param' });
    return;
  }

  // Only allow MangaDex at-home hosts and the uploads host. This
  // prevents the proxy from being abused to fetch arbitrary URLs.
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
      timeout: 20000,
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
