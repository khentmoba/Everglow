'use strict';

const common = require('./common.js');
const { cappedHttps, enforceRateLimit, getAdmin } = common;
const { resolveKatanaServerCookie } = require('./media_proxy_core.js');
const { streamMediaBody } = require('./stream_media_body');

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

  const allowedSuffixes = [
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
    '.bato.to',
    '.img.bato.to',
    '.mangasee123.com',
    '.scans-hot.xyz',
    '.mangakatana.com',
    '.mangakatana.net',
    '.blogspot.com',
    '.bp.blogspot.com',
    '.googleusercontent.com',
    '.wp.com',
    '.wordpress.com',
  ];
  const hostAllowed = allowedSuffixes.some(
    (s) => parsed.hostname === s.slice(1) || parsed.hostname.endsWith(s),
  );
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  try {
    const upstream = await common.fetchPublicUrl(targetUrl, {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyFetchHtml', limit: 60, windowMs: 60000 })) return;
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

  const allowedExactHosts = new Set([
    'everglow-1c6db.web.app',
    'us-central1-everglow-1c6db.cloudfunctions.net',
  ]);
  const allowedSuffixes = [
    '.mangakakalot.com',
    '.mangakatana.com',
    '.bato.to',
    '.mangasee123.com',
    '.vidlink.pro',
    '.megaplay.buzz',
    '.megaplays.se',
    '.megaplay.su',
    '.anixo.buzz',
    '.megavid.buzz',
    '.tryembed.us.cc',
    '.vidcore.org',
    '.rivestream.us',
    '.fmov.my',
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
  const hostAllowed =
    allowedExactHosts.has(parsed.hostname) ||
    allowedSuffixes.some(
      (s) => parsed.hostname === s.slice(1) || parsed.hostname.endsWith(s),
    );
  if (parsed.protocol !== 'https:' || !hostAllowed) {
    res.status(400).json({ error: 'Host not allowed' });
    return;
  }

  const serverCookie = resolveKatanaServerCookie(
    parsed.hostname,
    req.query.cookie,
  );

  try {
    let body = '';
    let status = 502;
    for (let attempt = 0; attempt < 3; attempt++) {
      const upstream = await common.fetchPublicUrl(targetUrl, {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          Referer: parsed.origin + '/',
          ...(serverCookie ? { Cookie: serverCookie } : {}),
        },
        signal: AbortSignal.timeout(20000),
      });
      body = await new Response(upstream.body).text();
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
