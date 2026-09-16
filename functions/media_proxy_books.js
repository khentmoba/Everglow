'use strict';

const { cappedHttps, enforceRateLimit, isAllowedBookTextUrl, isPublicDnsHost, requireAuth } = require('./common.js');

const proxyBookText = cappedHttps(10, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyBookText', limit: 30, windowMs: 60000, uid: decoded.uid })) return;

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
 * Proxies EPUB book files so the in-app "Read Online" reader can open
 * them on Flutter web (gutenberg.org sends no CORS headers, so a direct
 * browser fetch fails). Same trust shape as `proxyBookText`: Firebase
 * Auth required, same gutenberg.org / archive.org allow-list, same
 * per-user rate limit.
 *
 * Accepts:
 *   POST /proxyBookFile { urls: [<epub url>, ...] }
 *
 * Returns:
 *   { base64, usedUrl, attempted } on success, or
 *   { base64: '', usedUrl: '', attempted, error } when every URL fails.
 *
 * Size cap: 7 MB raw (base64 inflates ~33%, keeping the JSON response
 * under the Functions payload limit). Typical EPUBs are well under this.
 */
const proxyBookFile = cappedHttps(10, async (req, res) => {
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
  if (enforceRateLimit(req, res, { endpoint: 'proxyBookFile', limit: 30, windowMs: 60000, uid: decoded.uid })) return;

  const { urls } = req.body;
  if (!Array.isArray(urls) || urls.length === 0) {
    res.status(400).json({ error: 'Provide a non-empty urls array' });
    return;
  }

  const MAX_BYTES = 7 * 1024 * 1024;

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    if (typeof url !== 'string' || !isAllowedBookTextUrl(url)) {
      console.warn(`proxyBookFile rejected URL ${url}`);
      continue;
    }
    if (!(await isPublicDnsHost(new URL(url).hostname))) {
      console.warn(`proxyBookFile rejected non-public host ${url}`);
      continue;
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 20000);
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: { 'Accept': 'application/epub+zip, application/octet-stream, */*' },
        redirect: 'follow',
        signal: controller.signal,
      });
      if (!response.ok) continue;
      const contentType = (response.headers.get('content-type') || '').toLowerCase();
      const looksEpub =
        contentType.includes('epub') ||
        contentType.includes('octet-stream') ||
        contentType.includes('zip') ||
        new URL(url).pathname.toLowerCase().endsWith('.epub');
      if (!looksEpub) continue;
      const declared = Number(response.headers.get('content-length') || 0);
      if (declared > MAX_BYTES) {
        console.warn(`proxyBookFile skipped oversize file ${url} (${declared} bytes)`);
        continue;
      }
      const buf = Buffer.from(await response.arrayBuffer());
      if (buf.length === 0 || buf.length > MAX_BYTES) continue;
      // Zip magic: EPUBs are zip archives (PK\x03\x04).
      if (buf[0] !== 0x50 || buf[1] !== 0x4b) continue;
      res.json({ base64: buf.toString('base64'), usedUrl: url, attempted: urls.slice(0, i + 1) });
      return;
    } catch (e) {
      console.warn(`proxyBookFile attempt ${i} failed (${url}):`, e.message);
    } finally {
      clearTimeout(timer);
    }
  }

  res.json({
    base64: '',
    usedUrl: '',
    attempted: urls,
    error: `Tried ${urls.length} source(s); none responded with a readable EPUB.`,
  });
});

module.exports = { proxyBookText, proxyBookFile };
