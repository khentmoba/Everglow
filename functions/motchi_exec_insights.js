'use strict';

/* Motchi insights tool executors — moved verbatim from
 * motchi_chat.js executeTool() (mechanical split, no behavior change).
 * Each executor is (ctx, args) => JSON string. Shared services
 * ride on ctx (see motchi_exec_tools.js createToolCtx).
 */

const { computeInsights, generateTrivia, composeTodayRecap } = require('./motchi_core.js');
const { fetchAniListAnime, fetchJikanAnime } = require('./motchi_exec_media.js');

async function exec_get_relationship_insights(ctx, _args) {
    const [moodSnap, activitySnap] = await Promise.all([
      ctx.db.collection('moods').orderBy('timestamp', 'desc').limit(100).get(),
      ctx.db.collection('recent_activity').orderBy('timestamp', 'desc').limit(20).get(),
    ]);
    const moods = moodSnap.docs.map(d => d.data().mood || d.data().moodEmoji || '');
    const activities = activitySnap.docs.map(
      d => d.data().activity || d.data().description || ''
    );
    const insights = computeInsights({ moods, activities });
    return JSON.stringify({ insights });
}

async function exec_get_memory_trivia(ctx, args) {
    const count = Math.min(args.count || 5, 10);
    const snapshot = await ctx.db.collection('ai_memories').doc('shared').collection('facts')
      .orderBy('createdAt', 'desc')
      .limit(150)
      .get();
    const facts = snapshot.docs.map(d => {
      const data = d.data();
      return {
        fact: data.fact || '',
        subject: data.subject || null,
        relation: data.relation || null,
        object: data.object || null,
        occurredAt: data.occurredAt?.toDate?.() || null,
      };
    });
    const questions = generateTrivia(facts, count);
    return JSON.stringify({ questions });
}

async function exec_get_today_recap(ctx, _args) {
    const today = ctx.phtDateString();
    const [moodSnap, activitySnap, watchSnap, starSnap, memorySnap] = await Promise.all([
      ctx.db.collection('moods').where('date', '==', today).get(),
      ctx.db.collection('recent_activity').orderBy('timestamp', 'desc').limit(5).get(),
      ctx.db.collection('our_cinema').limit(5).get(),
      ctx.db.collection('starlight_jar').orderBy('timestamp', 'desc').limit(3).get(),
      ctx.db.collection('ai_memories').doc('shared').collection('facts')
        .orderBy('createdAt', 'desc').limit(150).get(),
    ]);
    const recap = composeTodayRecap({
      dateLabel: today,
      moods: moodSnap.docs.map(d => ({
        uid: d.data().uid || 'someone',
        mood: d.data().mood || 'okay',
      })),
      activities: activitySnap.docs.map(
        d => d.data().activity || d.data().description || ''
      ),
      watchlist: watchSnap.docs.map(d => d.data().title || '').filter(Boolean),
      starlight: starSnap.docs.map(d => d.data().content || '').filter(Boolean),
      memories: memorySnap.docs.map(d => {
        const data = d.data();
        return {
          fact: data.fact || '',
          occurredAt: data.occurredAt?.toDate?.() || null,
        };
      }),
    });
    return JSON.stringify({ recap, date: today });
}

async function exec_search_everglow(ctx, args) {
    const query = String(args.query || '').trim();
    if (!query) return JSON.stringify({ error: 'No query provided' });
    const qLower = query.toLowerCase();
    const cacheKey = `everglow:search:${qLower}`;
    const cachedEver = ctx.cacheGet(cacheKey, ctx.cacheTTLs.tmdb);
    if (cachedEver) return JSON.stringify(cachedEver);
    // Parallel searches: movies, books, anime, spotify (best-effort)
    const [moviesRes, booksRes, animeRes, spotifyRes] = await Promise.allSettled([
      (async () => {
        const k = ctx.getTmdbKey();
        if (!k) return [];
        const r = await fetch(`https://api.themoviedb.org/3/search/multi?query=${encodeURIComponent(query)}&api_key=${k}`, { signal: AbortSignal.timeout(8000) });
        const d = await r.json();
        return (d.results || []).slice(0, 3).map(x => ({ title: x.title || x.name, year: (x.release_date || x.first_air_date || '').slice(0,4), type: x.media_type || 'movie' }));
      })(),
      (async () => {
        const r = await fetch(`https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=3&fields=key,title,author_name,first_publish_year`, { signal: AbortSignal.timeout(8000) });
        const d = await r.json();
        return (d.docs || []).slice(0, 3).map(b => ({ title: b.title, authors: (b.author_name||[]).slice(0,2).join(', '), type: 'book' }));
      })(),
      (async () => {
        try {
          const list = await fetchAniListAnime(query, 3);
          if (list.length > 0) return list.map(a => ({ title: a.title, type: 'anime', score: a.score }));
        } catch (_) {}
        try {
          const list = await fetchJikanAnime(query, 3);
          return list.map(a => ({ title: a.title, type: 'anime', score: a.score }));
        } catch (_) {
          return [];
        }
      })(),
      (async () => {
        const token = await ctx.getSpotifyAppToken();
        if (!token) return [];
        const url = 'https://api.spotify.com/v1/search?' + new URLSearchParams({ q: query, type: 'track', limit: '3', market: 'US' }).toString();
        const r = await fetch(url, { headers: { 'Authorization': 'Bearer ' + token }, signal: AbortSignal.timeout(8000) });
        const d = await r.json();
        const items = d.tracks?.items || [];
        return items.slice(0,3).map(t=>({ title: t.name, artist: t.artists?.[0]?.name || '', type: 'track' }));
      })(),
    ]);
    const result = {
      query,
      movies: moviesRes.status === 'fulfilled' ? moviesRes.value : [],
      books: booksRes.status === 'fulfilled' ? booksRes.value : [],
      anime: animeRes.status === 'fulfilled' ? animeRes.value : [],
      tracks: spotifyRes.status === 'fulfilled' ? spotifyRes.value : [],
    };
    ctx.cacheSet(cacheKey, result);
    return JSON.stringify(result);
}

// ── Free web stack ──────────────────────────────────────────────
// Ordinary lookups go out free first, on the same keyless stack the pi
// harness uses: DuckDuckGo's lite endpoint for search, Jina's reader for
// pages. That keeps Motchi answering from the web even when the paid
// key is gone, empty or rate-limited, and a normal search stops costing
// $0.005. TinyFish stays as the fallback and still owns the filters the
// free path cannot do (news type, date ranges, geo).
// ponytail: DDG lite returns one page of ~10 hits with no date filter.
// Upgrade path: a Brave/Serper key if free quality ever matters.
const FREE_BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
const FREE_SEARCH_URL = 'https://lite.duckduckgo.com/lite/?q=';
const FREE_READER_URL = 'https://r.jina.ai/';

function _htmlText(html) {
  return String(html || '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&#(\d+);/g, (_m, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_m, n) => String.fromCharCode(parseInt(n, 16)))
    .replace(/&quot;/g, '"')
    .replace(/&(?:nbsp|#0?39|apos);/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

function _hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch (_) {
    return '';
  }
}

// DuckDuckGo wraps every hit in //duckduckgo.com/l/?uddg=<encoded target>.
function _freeSearchTarget(href) {
  const raw = String(href || '').replace(/&amp;/g, '&');
  const m = /[?&]uddg=([^&]+)/.exec(raw);
  if (m) {
    try {
      return decodeURIComponent(m[1]);
    } catch (_) {
      return '';
    }
  }
  return /^https?:\/\//i.test(raw) ? raw : '';
}

/** DuckDuckGo lite HTML -> TinyFish-shaped results, deduped and host-capped. */
function parseFreeSearch(html, limit) {
  const src = String(html || '');
  // Attribute order is not stable in DDG's own markup (href can come
  // before or after class), so match the tag once and read href out.
  const links = [...src.matchAll(/<a([^>]*class=['"][^'"]*result-link[^'"]*['"][^>]*)>([\s\S]*?)<\/a>/g)]
    .map((m) => [(/href=["']([^"']+)["']/.exec(m[1]) || [])[1] || '', m[2]]); // [href, title]
  const snippets = [...src.matchAll(
    /<td[^>]*class=['"]result-snippet['"][^>]*>([\s\S]*?)<\/td>/g
  )];
  const out = [];
  const seen = new Set();
  const perHost = new Map();
  for (let i = 0; i < links.length; i++) {
    const url = _freeSearchTarget(links[i][0]);
    if (!url || seen.has(url)) continue;
    // One site must not fill the list — that is how Motchi ends up
    // answering a whole question from five links on the same wiki hub.
    const host = _hostOf(url);
    const hits = perHost.get(host) || 0;
    if (hits >= 2) continue;
    seen.add(url);
    perHost.set(host, hits + 1);
    out.push({
      title: _htmlText(links[i][1]).slice(0, 200),
      url,
      snippet: (snippets[i] ? _htmlText(snippets[i][1]) : '').slice(0, 280),
      site_name: host,
      date: null,
    });
  }
  return out.slice(0, limit);
}

// Free search. Never throws: a blocked or slow free endpoint just means
// the paid fallback answers instead.
async function freeSearch(query, limit) {
  try {
    const res = await fetch(FREE_SEARCH_URL + encodeURIComponent(query), {
      headers: {
        'User-Agent': FREE_BROWSER_UA,
        'Accept-Language': 'en-US,en;q=0.9',
      },
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return [];
    return parseFreeSearch(await res.text(), limit);
  } catch (_) {
    return [];
  }
}

// Free page reader (Jina): markdown text for one URL, no key. Used when
// TinyFish is out of credit, rate-limited or refused the page. Returns
// null instead of throwing so the caller keeps the paid error text.
// ponytail: capped at 6s so the free hop still fits inside the 25s tool
// budget after a paid read. A page that timed out twice gets no free
// retry — that budget is spent.
const FREE_READ_TIMEOUT_MS = 6000;

async function freeReadPage(url, timeoutMs) {
  try {
    const res = await fetch(FREE_READER_URL + url, {
      headers: { Accept: 'text/plain', 'X-Return-Format': 'markdown' },
      signal: AbortSignal.timeout(
        Math.min(timeoutMs || FREE_READ_TIMEOUT_MS, FREE_READ_TIMEOUT_MS),
      ),
    });
    if (!res.ok) return null;
    const raw = await res.text();
    const marker = 'Markdown Content:';
    const at = raw.indexOf(marker);
    const text = (at >= 0 ? raw.slice(at + marker.length) : raw).trim();
    if (text.length < 120) return null;
    // Jina puts the title on the first line. Read only that line, or a
    // single-line response swallows the whole page into the title.
    const title = ((/^Title:\s*(.+)$/.exec(raw.split('\n', 1)[0].trim()) || [])[1] || '')
      .slice(0, 200);
    return { url, title: title.trim(), text: text.slice(0, 4000) };
  } catch (_) {
    return null;
  }
}

// Paid search, one request, honest error text the model can relay.
async function tinyfishSearch(apiKey, params) {
  let res;
  try {
    res = await fetch(`https://api.search.tinyfish.ai?${params.toString()}`, {
      headers: { 'X-API-Key': apiKey },
      signal: AbortSignal.timeout(8000),
    });
  } catch (_) {
    return { error: 'Web search timed out — answer from what you know and say the web was slow.' };
  }
  if (res.status === 401 || res.status === 403) return { error: 'Web search API key is invalid or forbidden.' };
  if (res.status === 402) return { error: 'Web search account needs a top-up at agent.tinyfish.ai/wallet.' };
  if (res.status === 429) return { error: 'Web search rate limit hit — try again in a minute.' };
  if (!res.ok) return { error: `Web search failed (HTTP ${res.status}).` };
  return { data: await res.json() };
}

async function exec_web_search(ctx, args) {
    const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
    const query = String(args.query || '').trim();
    if (!query) return JSON.stringify({ error: 'No search query provided' });
    const location = String(args.location || 'PH').trim().toUpperCase();
    const language = 'en';
    const params = new URLSearchParams({ query, location, language });
    if (args.domain_type) params.set('domain_type', String(args.domain_type));
    if (args.recency_minutes) params.set('recency_minutes', String(Math.max(1, Math.floor(Number(args.recency_minutes)))));
    if (args.after_date && /^\d{4}-\d{2}-\d{2}$/.test(String(args.after_date))) params.set('after_date', String(args.after_date));
    if (args.before_date && /^\d{4}-\d{2}-\d{2}$/.test(String(args.before_date))) params.set('before_date', String(args.before_date));
    if (args.include_domains) params.set('include_domains', String(args.include_domains));
    if (args.exclude_domains) params.set('exclude_domains', String(args.exclude_domains));
    // Fresh asks (news, recency, date filters) cache briefly; everything
    // else reuses results for an hour so repeat asks answer instantly.
    const wantsFresh = String(args.domain_type || '') === 'news' ||
      args.recency_minutes || args.after_date || args.before_date;
    const searchTtl = wantsFresh
      ? ctx.cacheTTLs.web_search
      : (ctx.cacheTTLs.web_search_long || ctx.cacheTTLs.web_search);
    const searchKey = `websearch:${params.toString()}`;
    // Free path for ordinary lookups. News type, date ranges and domain
    // filters only TinyFish can do, so those asks skip the free hop.
    const needsPaidFilters =
      wantsFresh ||
      args.domain_type ||
      args.include_domains ||
      args.exclude_domains;
    let searchData = ctx.cacheGet(searchKey, searchTtl);
    if (!searchData && !needsPaidFilters) {
      const free = await freeSearch(query, 8);
      if (free.length > 0) {
        searchData = { results: free, total_results: free.length };
        ctx.cacheSet(searchKey, searchData);
      }
    }
    let paidError = null;
    if (!searchData) {
      if (!apiKey) paidError = 'Web search is not configured on the server yet.';
      else {
        const paid = await tinyfishSearch(apiKey, params);
        if (paid.error) paidError = paid.error;
        else {
          searchData = paid.data;
          ctx.cacheSet(searchKey, searchData);
        }
      }
    }
    if (!searchData) return JSON.stringify({ error: paidError || 'Web search found nothing.' });
    const seenUrls = new Set();
    const results = (searchData.results || [])
      .filter(r => {
        const url = r.url || '';
        return url && !seenUrls.has(url) && seenUrls.add(url);
      })
      .slice(0, 5)
      .map(r => ({
        title: r.title || '',
        url: r.url || '',
        snippet: (r.snippet || '').slice(0, 280),
        site: r.site_name || _hostOf(r.url || ''),
        date: r.date || null,
      }));
    // One-round answers: fetch the top hit's content right here (best
    // effort, cached) so Motchi usually needs no second read_web_page
    // round — that saved LLM round is the biggest speed win.
    let topPage = null;
    const topUrl = results.length > 0 ? results[0].url : '';
    if (/^https?:\/\//i.test(topUrl || '')) {
      try {
        const page = await readOnePage(ctx, apiKey, topUrl, 8000);
        topPage = { url: page.url || topUrl, title: page.title || results[0].title || '', content: page.text.slice(0, 1800) };
      } catch (_) {
        // Top-page fetch is a bonus — snippets alone still answer.
      }
    }
    // top_page first: the model's trimmed copy keeps the most useful
    // content when the payload is long.
    return JSON.stringify({ query, top_page: topPage, results, total: searchData.total_results || results.length });
}

// One page per request, cached per URL under the same key web_search and
// read_web_page both use, so the top hit a search already fetched is free
// to read later. Throws on a hard API error or an unreadable page; the
// caller decides whether that is fatal. Text is trimmed once here and each
// caller slices it down further for its own payload budget.
async function readOnePage(ctx, apiKey, url, timeoutMs) {
    const key = `webpage:${url}`;
    const cached = ctx.cacheGet(key, ctx.cacheTTLs.web_page);
    if (cached && cached.text) return cached;
    // A slow page gets exactly one more try (2 x 10s + a pause stays
    // inside the 25s tool budget). The retry lives here rather than in
    // executeToolCall because a per-URL failure never throws out of the
    // batch, so the outer retry cannot see it.
    let paidError = apiKey ? null : 'Web page reading is not configured on the server yet.';
    for (let attempt = 1; paidError === null; attempt++) {
      try {
        const res = await fetch('https://api.fetch.tinyfish.ai', {
          method: 'POST',
          headers: { 'X-API-Key': apiKey, 'Content-Type': 'application/json' },
          body: JSON.stringify({ urls: [url], format: 'markdown' }),
          signal: AbortSignal.timeout(timeoutMs),
        });
        if (res.status === 401 || res.status === 403) throw new Error('Web page reading API key is invalid or forbidden.');
        if (res.status === 402) throw new Error('Web page reading account needs a top-up at agent.tinyfish.ai/wallet.');
        if (res.status === 429) throw new Error('Web page reading rate limit hit — try again in a minute.');
        if (!res.ok) throw new Error(`Web page reading failed (HTTP ${res.status}).`);
        const data = await res.json();
        const first = (data.results || [])[0];
        if (!first || !first.text) {
          const err = (data.errors || [])[0];
          throw new Error((err && err.error) || 'The page returned no readable text.');
        }
        const page = { url: first.url || url, title: first.title || '', text: String(first.text).slice(0, 4000) };
        ctx.cacheSet(key, page);
        return page;
      } catch (err) {
        const slow = err && (err.name === 'TimeoutError' || err.name === 'AbortError');
        if (!slow || attempt >= 2) {
          paidError = (err && err.message) || 'Web page reading failed.';
          break;
        }
        await new Promise((r) => setTimeout(r, 500));
      }
    }
    // Paid path said no (no key, no credit, blocked page, timeout). The
    // free reader often still has it, so one free try before giving up.
    const free = await freeReadPage(url, timeoutMs);
    if (!free) throw new Error(paidError);
    ctx.cacheSet(key, free);
    return free;
}

async function exec_read_web_page(ctx, args) {
    // No key check up front: the free reader in readOnePage can still
    // answer without one.
    const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
    const urlsRaw = Array.isArray(args.urls) ? args.urls : [args.urls];
    const urls = urlsRaw.map(u => String(u || '').trim()).filter(u => /^https?:\/\//i.test(u)).slice(0, 3);
    if (urls.length === 0) return JSON.stringify({ error: 'No valid http(s) URLs provided' });
    // One request per URL, all in parallel: a single blocked or slow page
    // (Facebook, Reddit) used to take the whole batch down with it and left
    // Motchi with nothing. Same wall-clock as one batched call, and the
    // pages that did load still reach the model.
    const settled = await Promise.allSettled(urls.map(url => readOnePage(ctx, apiKey, url, 10000)));
    const pages = [];
    const pageErrors = [];
    settled.forEach((r, i) => {
      if (r.status === 'fulfilled') {
        pages.push({ url: r.value.url, title: r.value.title, content: r.value.text.slice(0, 4000) });
      } else {
        pageErrors.push({ url: urls[i], error: (r.reason && r.reason.message) || 'unknown' });
      }
    });
    // Every URL failed: report one honest error, with the per-URL detail
    // kept alongside it so the receipt still shows what was attempted.
    if (pages.length === 0 && pageErrors.length > 0) {
      return JSON.stringify({ error: pageErrors[0].error, pages, errors: pageErrors });
    }
    return JSON.stringify({ pages, errors: pageErrors });
}

// TinyFish browser automation (the "agent" tool). Runs queue async and
// poll inside the tool's time budget — a sync run takes minutes, far
// beyond the 25s tool timeout, so the model resumes with run_id while
// the status is RUNNING. No agent_config caps: custom max steps are a
// gated beta and the API 403s without it — server defaults apply.
const TINYFISH_AGENT_BASE = 'https://agent.tinyfish.ai';
const BROWSE_POLL_MS = 3000;
const BROWSE_BUDGET_MS = 20000;

async function exec_browse_web(ctx, args) {
    const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
    if (!apiKey) return JSON.stringify({ error: 'Web browsing is not configured on the server yet.' });
    const attempt = Math.max(1, Math.floor(Number(args.attempt) || 1));
    const resumeHint = (_runId) =>
      attempt >= 2
        ? 'Still browsing in the background, but this page is taking too long — do not call browse_web again. Synthesize your answer now from what you already found or use web_search / read_web_page for quick text.'
        : `Still browsing — call browse_web once more with the same url, goal, and run_id, and attempt 2. If it still does not finish, proceed with answering from what you have.`;
    let runId = String(args.run_id || '').trim();
    let url = String(args.url || '').trim();
    const goal = String(args.goal || '').trim();
    let cacheKey = null;
    if (!runId) {
      if (!/^https?:\/\//i.test(url)) return JSON.stringify({ error: 'No valid http(s) URL provided' });
      if (!goal) return JSON.stringify({ error: 'No goal provided' });
      // Repeat asks answer instantly from cache.
      cacheKey = `browse:${url}|${goal.slice(0, 200)}`;
      const cached = ctx.cacheGet(cacheKey, ctx.cacheTTLs.web_page);
      if (cached) return JSON.stringify(cached);
      let queueRes;
      try {
        queueRes = await fetch(`${TINYFISH_AGENT_BASE}/v1/automation/run-async`, {
          method: 'POST',
          headers: { 'X-API-Key': apiKey, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            url,
            goal,
            browser_profile: args.stealth === true ? 'stealth' : 'lite',
            capture_config: { screenshots: false },
          }),
          signal: AbortSignal.timeout(10000),
        });
      } catch (_) {
        return JSON.stringify({ error: 'Browsing timed out while starting — try again in a moment.' });
      }
      if (queueRes.status === 401 || queueRes.status === 403) return JSON.stringify({ error: 'Web browsing API key is invalid or forbidden.' });
      if (queueRes.status === 402) return JSON.stringify({ error: 'Web browsing account needs a top-up at agent.tinyfish.ai/wallet.' });
      if (queueRes.status === 429) return JSON.stringify({ error: 'Web browsing rate limit hit — try again in a minute.' });
      if (!queueRes.ok) return JSON.stringify({ error: `Web browsing failed to start (HTTP ${queueRes.status}).` });
      const queued = await queueRes.json().catch(() => ({}));
      runId = String(queued.run_id || '');
      if (!runId) {
        const msg = queued.error && queued.error.message ? queued.error.message : 'unknown';
        return JSON.stringify({ error: `Web browsing failed to start: ${msg}` });
      }
    } else if (url && goal) {
      // Resume calls repeat url+goal so completions land in the same cache.
      cacheKey = `browse:${url}|${goal.slice(0, 200)}`;
    }
    // Poll for completion inside the tool budget.
    const deadline = Date.now() + BROWSE_BUDGET_MS;
    for (;;) {
      let runRes;
      try {
        runRes = await fetch(`${TINYFISH_AGENT_BASE}/v1/runs/${encodeURIComponent(runId)}`, {
          headers: { 'X-API-Key': apiKey },
          signal: AbortSignal.timeout(8000),
        });
      } catch (_) {
        return JSON.stringify({ status: 'RUNNING', run_id: runId, url, hint: resumeHint(runId) });
      }
      if (runRes.status === 401 || runRes.status === 403) return JSON.stringify({ error: 'Web browsing API key is invalid or forbidden.' });
      if (!runRes.ok) return JSON.stringify({ error: `Web browsing status check failed (HTTP ${runRes.status}).` });
      const run = await runRes.json().catch(() => ({}));
      const status = String(run.status || 'RUNNING').toUpperCase();
      if (status === 'COMPLETED') {
        const result = run.result && typeof run.result === 'object' ? run.result : {};
        const keys = Object.keys(result);
        if (keys.length === 0) {
          return JSON.stringify({ status: 'COMPLETED', run_id: runId, url, title: '', text: '', note: 'The browse finished but returned no data — try a more specific goal.' });
        }
        const title = typeof result.title === 'string' ? result.title.slice(0, 200)
          : typeof result.name === 'string' ? result.name.slice(0, 200) : '';
        const done = { status: 'COMPLETED', run_id: runId, url, title, text: JSON.stringify(result).slice(0, 4000) };
        if (cacheKey) ctx.cacheSet(cacheKey, done);
        return JSON.stringify(done);
      }
      if (status === 'FAILED' || status === 'CANCELLED') {
        const msg = run.error && run.error.message ? run.error.message : status.toLowerCase();
        return JSON.stringify({ status, run_id: runId, url, error: `Browse ${status.toLowerCase()}: ${msg}` });
      }
      if (Date.now() >= deadline) {
        return JSON.stringify({ status: 'RUNNING', run_id: runId, url, hint: resumeHint(runId) });
      }
      await new Promise((r) => setTimeout(r, BROWSE_POLL_MS));
    }
}

module.exports = {
  exec_get_relationship_insights,
  exec_get_memory_trivia,
  exec_get_today_recap,
  exec_search_everglow,
  exec_web_search,
  exec_read_web_page,
  exec_browse_web,
};
