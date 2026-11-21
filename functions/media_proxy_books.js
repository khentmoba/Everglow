'use strict';

const { applyCors, cappedHttps, enforceRateLimit, fetchPublicUrl, isAllowedBookTextUrl, requireAuth } = require('./common.js');

const MAX_URLS = 10;
const MAX_TEXT_BYTES = 5 * 1024 * 1024;
const MAX_EPUB_BYTES = 7 * 1024 * 1024;

async function readStreamCapped(body, maxBytes) {
  if (!body || typeof body.getReader !== 'function') return null;
  const reader = body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > maxBytes) return null;
      chunks.push(Buffer.from(value));
    }
    return Buffer.concat(chunks, total);
  } finally {
    await reader.cancel().catch(() => {});
  }
}

const proxyBookText = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');

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

  const candidates = urls.slice(0, MAX_URLS);
  for (let i = 0; i < candidates.length; i++) {
    const url = candidates[i];
    if (typeof url !== 'string' || !isAllowedBookTextUrl(url)) {
      console.warn(`proxyBookText rejected URL ${url}`);
      continue;
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await fetchPublicUrl(url, {
        headers: { 'Accept': 'text/plain' },
        signal: controller.signal,
      });
      const contentType = response.headers.get('content-type') || '';
      const isPlainText = contentType.toLowerCase().includes('text/plain');
      if (response.ok && isPlainText) {
        const buf = await readStreamCapped(response.body, MAX_TEXT_BYTES);
        if (!buf) continue;
        const text = buf.toString('utf8');
        const looksLikeHtml =
          text.trimStart().toLowerCase().startsWith('<!doctype') ||
          text.trimStart().toLowerCase().startsWith('<html') ||
          (text.trimStart().startsWith('<') && text.trim().length < 4096);
        if (text.trim().length > 0 && !looksLikeHtml) {
          res.json({ text, usedUrl: url, attempted: candidates.slice(0, i + 1) });
          return;
        }
      } else {
        await response.body?.cancel().catch(() => {});
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
    attempted: candidates,
    error: `Tried ${candidates.length} source(s); none responded with readable text.`,
  });
});

const proxyBookFile = cappedHttps(10, async (req, res) => {
  applyCors(req, res, 'POST, OPTIONS');
  res.set('Access-Control-Expose-Headers', 'X-Book-Source');

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

  const candidates = urls.slice(0, MAX_URLS);
  for (let i = 0; i < candidates.length; i++) {
    const url = candidates[i];
    if (typeof url !== 'string' || !isAllowedBookTextUrl(url)) {
      console.warn(`proxyBookFile rejected URL ${url}`);
      continue;
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 20000);
    try {
      const response = await fetchPublicUrl(url, {
        headers: { 'Accept': 'application/epub+zip, application/octet-stream, */*' },
        signal: controller.signal,
      });
      if (!response.ok) {
        await response.body?.cancel().catch(() => {});
        continue;
      }
      const contentType = (response.headers.get('content-type') || '').toLowerCase();
      const looksEpub =
        contentType.includes('epub') ||
        contentType.includes('octet-stream') ||
        contentType.includes('zip') ||
        new URL(url).pathname.toLowerCase().endsWith('.epub');
      if (!looksEpub) {
        await response.body?.cancel().catch(() => {});
        continue;
      }
      const declared = Number(response.headers.get('content-length') || 0);
      if (declared > MAX_EPUB_BYTES) {
        console.warn(`proxyBookFile skipped oversize file ${url} (${declared} bytes)`);
        await response.body?.cancel().catch(() => {});
        continue;
      }
      const buf = await readStreamCapped(response.body, MAX_EPUB_BYTES);
      if (!buf || buf.length === 0 || buf.length > MAX_EPUB_BYTES) continue;
      if (buf[0] !== 0x50 || buf[1] !== 0x4b) continue;
      if (String(req.get('Accept') || '').includes('application/epub+zip')) {
        res.set('Content-Type', 'application/epub+zip');
        res.set('X-Book-Source', encodeURIComponent(url));
        res.send(buf);
      } else {
        res.json({ base64: buf.toString('base64'), usedUrl: url, attempted: candidates.slice(0, i + 1) });
      }
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
    attempted: candidates,
    error: `Tried ${candidates.length} source(s); none responded with a readable EPUB.`,
  });
});

module.exports = { proxyBookText, proxyBookFile };
