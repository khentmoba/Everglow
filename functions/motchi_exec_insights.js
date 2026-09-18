'use strict';

/* Motchi insights tool executors — moved verbatim from
 * motchi_chat.js executeTool() (mechanical split, no behavior change).
 * Each executor is (ctx, args) => JSON string. Shared services
 * ride on ctx (see motchi_exec_tools.js createToolCtx).
 */

const { computeInsights, generateTrivia, composeTodayRecap } = require('./motchi_core.js');

async function exec_get_relationship_insights(ctx, args) {
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

async function exec_get_today_recap(ctx, args) {
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
        const r = await fetch(`https://api.jikan.moe/v4/anime?q=${encodeURIComponent(query)}&limit=3&sfw=true`, { signal: AbortSignal.timeout(8000) });
        const d = await r.json();
        return (d.data || []).slice(0, 3).map(a => ({ title: a.title, type: 'anime', score: a.score }));
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

async function exec_web_search(ctx, args) {
    const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
    if (!apiKey) return JSON.stringify({ error: 'Web search is not configured on the server yet.' });
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
    let searchData;
    const cachedSearch = ctx.cacheGet(searchKey, searchTtl);
    if (cachedSearch) {
      searchData = cachedSearch;
    } else {
      let searchRes;
      try {
        searchRes = await fetch(`https://api.search.tinyfish.ai?${params.toString()}`, {
          headers: { 'X-API-Key': apiKey },
          signal: AbortSignal.timeout(8000),
        });
      } catch (_) {
        return JSON.stringify({ error: 'Web search timed out — answer from what you know and say the web was slow.' });
      }
      if (searchRes.status === 401 || searchRes.status === 403) return JSON.stringify({ error: 'Web search API key is invalid or forbidden.' });
      if (searchRes.status === 402) return JSON.stringify({ error: 'Web search account needs a top-up at agent.tinyfish.ai/wallet.' });
      if (searchRes.status === 429) return JSON.stringify({ error: 'Web search rate limit hit — try again in a minute.' });
      if (!searchRes.ok) return JSON.stringify({ error: `Web search failed (HTTP ${searchRes.status}).` });
      searchData = await searchRes.json();
      ctx.cacheSet(searchKey, searchData);
    }
    const results = (searchData.results || []).slice(0, 5).map(r => ({
      title: r.title || '',
      url: r.url || '',
      snippet: (r.snippet || '').slice(0, 280),
      site: r.site_name || '',
      date: r.date || null,
    }));
    // One-round answers: fetch the top hit's content right here (best
    // effort, cached) so Motchi usually needs no second read_web_page
    // round — that saved LLM round is the biggest speed win.
    let topPage = null;
    const topUrl = results.length > 0 ? results[0].url : '';
    if (/^https?:\/\//i.test(topUrl || '')) {
      const topKey = `webpage:top:${topUrl}`;
      const cachedTop = ctx.cacheGet(topKey, ctx.cacheTTLs.web_page);
      if (cachedTop && cachedTop.text) {
        topPage = { url: topUrl, title: results[0].title || '', content: String(cachedTop.text).slice(0, 1800) };
      } else {
        try {
          const topRes = await fetch('https://api.fetch.tinyfish.ai', {
            method: 'POST',
            headers: { 'X-API-Key': apiKey, 'Content-Type': 'application/json' },
            body: JSON.stringify({ urls: [topUrl], format: 'markdown' }),
            signal: AbortSignal.timeout(8000),
          });
          if (topRes.ok) {
            const topData = await topRes.json();
            const first = (topData.results || [])[0];
            if (first && first.text) {
              ctx.cacheSet(topKey, { text: String(first.text).slice(0, 1800) });
              topPage = { url: topUrl, title: first.title || results[0].title || '', content: String(first.text).slice(0, 1800) };
            }
          }
        } catch (_) {
          // Top-page fetch is a bonus — snippets alone still answer.
        }
      }
    }
    // top_page first: the model's trimmed copy keeps the most useful
    // content when the payload is long.
    return JSON.stringify({ query, top_page: topPage, results, total: searchData.total_results || results.length });
}

async function exec_read_web_page(ctx, args) {
    const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
    if (!apiKey) return JSON.stringify({ error: 'Web page reading is not configured on the server yet.' });
    const urlsRaw = Array.isArray(args.urls) ? args.urls : [args.urls];
    const urls = urlsRaw.map(u => String(u || '').trim()).filter(u => /^https?:\/\//i.test(u)).slice(0, 3);
    if (urls.length === 0) return JSON.stringify({ error: 'No valid http(s) URLs provided' });
    const fetchKey = `webpage:${urls.join('|')}`;
    let fetchData;
    const cachedPage = ctx.cacheGet(fetchKey, ctx.cacheTTLs.web_page);
    if (cachedPage) {
      fetchData = cachedPage;
    } else {
      let fetchRes;
      try {
        fetchRes = await fetch('https://api.fetch.tinyfish.ai', {
          method: 'POST',
          headers: { 'X-API-Key': apiKey, 'Content-Type': 'application/json' },
          body: JSON.stringify({ urls, format: 'markdown' }),
          signal: AbortSignal.timeout(12000),
        });
      } catch (_) {
        return JSON.stringify({ error: 'Reading the page timed out — answer from the search snippets and say the page was slow.' });
      }
      if (fetchRes.status === 401 || fetchRes.status === 403) return JSON.stringify({ error: 'Web page reading API key is invalid or forbidden.' });
      if (fetchRes.status === 429) return JSON.stringify({ error: 'Web page reading rate limit hit — try again in a minute.' });
      if (!fetchRes.ok) return JSON.stringify({ error: `Web page reading failed (HTTP ${fetchRes.status}).` });
      fetchData = await fetchRes.json();
      ctx.cacheSet(fetchKey, fetchData);
    }
    const pages = (fetchData.results || []).map(r => ({
      url: r.url || '',
      title: r.title || '',
      content: (r.text || '').slice(0, 4000),
    }));
    const pageErrors = (fetchData.errors || []).map(e => ({ url: e.url || '', error: e.error || 'unknown' }));
    return JSON.stringify({ pages, errors: pageErrors });
}

// TinyFish browser automation (the "agent" tool). Runs queue async and
// poll inside the tool's time budget — a sync run takes minutes, far
// beyond the 25s tool timeout, so the model resumes with run_id while
// the status is RUNNING. Caps stay small on purpose: each browse costs
// more than a search, so the schema steers Motchi to web_search and
// read_web_page first.
const TINYFISH_AGENT_BASE = 'https://agent.tinyfish.ai';
const BROWSE_POLL_MS = 3000;
const BROWSE_BUDGET_MS = 20000;

async function exec_browse_web(ctx, args) {
    const apiKey = (process.env.TINYFISH_API_KEY || '').trim();
    if (!apiKey) return JSON.stringify({ error: 'Web browsing is not configured on the server yet.' });
    const attempt = Math.max(1, Math.floor(Number(args.attempt) || 1));
    const resumeHint = (runId) =>
      `Still browsing — call browse_web again with the same url, goal, and run_id, and attempt ${attempt + 1} (up to 5 tries).`;
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
            agent_config: { max_steps: 25, max_duration_seconds: 120 },
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
