'use strict';

const { cappedHttps, enforceRateLimit, getAdmin, requireAuth } = require('./common.js');
const { resolveKatanaServerCookie } = require('./media_proxy_core.js');

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
const proxyEmbed = cappedHttps(10, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'GET only' }); return; }
  const decoded = await requireAuth(req, res);
  if (!decoded) return;
  if (enforceRateLimit(req, res, { endpoint: 'proxyEmbed', limit: 60, windowMs: 60000, uid: decoded.uid })) return;







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
      if (/z-index:\\s*[89]\\d{3,}/.test(style)) return true;
      if (/display:\\s*none|visibility:\\s*hidden|width:\\s*0|height:\\s*0/.test(style) && /track|pixel|beacon/i.test(src + ' ' + cls)) return true;
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

module.exports = { proxyScanlation, proxyFetchHtml, proxyEmbed };
