import { auth, db, session, esc, errMsg, monthDay } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const PROXY = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyTmdb';
const IMG = 'https://image.tmdb.org/t/p/w342';

let tokenCache = null;
let tokenAt = 0;
async function idToken() {
  const now = Date.now();
  if (tokenCache && now - tokenAt < 4 * 60 * 1000) return tokenCache;
  const a = await auth();
  tokenCache = await a.auth.currentUser.getIdToken();
  tokenAt = now;
  return tokenCache;
}

async function tmdb(path, params = {}) {
  const url = new URL(`${PROXY}/${path.replace(/^\/+/, '')}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, String(v));
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 12000);
  try {
    const r = await fetch(url, { headers: { Authorization: `Bearer ${await idToken()}` }, signal: ctrl.signal });
    if (!r.ok) throw new Error(`tmdb ${r.status}`);
    return r.json();
  } finally {
    clearTimeout(timer);
  }
}

function poster(p) {
  if (!p) return '';
  if (String(p).startsWith('http')) return p;
  return `${IMG}${p}`;
}

function pickTitle(x) {
  const t = x.media_type === 'movie' ? (x.title || x.name) : (x.name || x.title);
  return t || 'Untitled';
}

export async function Cinema(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  const me = session.username;
  Shell(el, 'cinema', `
    <div class="topbar"><div><h2 class="serif">Cinema</h2><p class="sub">movies for us two</p></div></div>
    <div class="stack" style="margin-top:12px">
      <form class="row" id="search"><input id="q" placeholder="Search a movie or show…" maxlength="80" aria-label="Search movies"><button type="submit">Find</button></form>
      <div id="results"></div>
      <div class="card"><strong>Our watchlist</strong><div class="stack" id="list" style="margin-top:8px"><div class="skel"></div></div></div>
      <div class="card"><strong>Trending this week</strong><div class="photos" id="trend" style="margin-top:8px;grid-template-columns:repeat(3,1fr)"><div class="skel"></div><div class="skel"></div><div class="skel"></div></div></div>
    </div>`);
  const list = el.querySelector('#list');
  const trend = el.querySelector('#trend');
  const results = el.querySelector('#results');

  async function paintList() {
    try {
      const { db: d, f } = await db();
      const s = await f.getDocs(f.query(f.collection(d, 'watch_list'), f.where('userName', '==', me), f.limit(50)));
      const items = s.docs.map((x) => ({ id: x.id, ...x.data() }))
        .sort((a, b) => (b.addedAt?.toMillis?.() || 0) - (a.addedAt?.toMillis?.() || 0));
      if (!items.length) {
        list.innerHTML = `<p class="muted small" style="margin:0">Nothing saved yet — search above and add our first film.</p>`;
        return;
      }
      list.innerHTML = items.map((m) => `
        <div class="row" data-id="${esc(m.id)}">
          ${m.posterPath ? `<img loading="lazy" width="46" height="69" src="${esc(poster(m.posterPath))}" alt="" onerror="this.remove()">` : '<span style="font-size:28px">🎬</span>'}
          <div class="grow"><strong>${esc(m.title)}</strong><div class="muted small">${esc(m.year || '')} · ${esc(statusLabel(m.status))}</div></div>
          ${m.status !== 'watching-self' && m.status !== 'watching-both' ? `<button class="ghost" data-act="watching" type="button">▶</button>` : ''}
          ${m.status !== 'watched-self' && m.status !== 'watched-both' ? `<button class="ghost" data-act="watched" type="button">✓</button>` : ''}
          <button class="ghost" data-act="rm" type="button" aria-label="Remove">✕</button>
        </div>`).join('');
    } catch (e) {
      list.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
  }

  function statusLabel(s) {
    if (s === 'watched-self' || s === 'watched-both' || s === 'watched') return 'watched';
    if ((s || '').startsWith('watching')) return 'watching';
    return 'to watch';
  }

  list.addEventListener('click', async (ev) => {
    const b = ev.target.closest('[data-act]');
    if (!b) return;
    const row = ev.target.closest('[data-id]');
    const id = row && row.dataset.id;
    if (!id) return;
    try {
      const { db: d, f } = await db();
      if (b.dataset.act === 'rm') await f.deleteDoc(f.doc(d, 'watch_list', id));
      else await f.updateDoc(f.doc(d, 'watch_list', id), { status: b.dataset.act === 'watched' ? 'watched-self' : 'watching-self' });
      await paintList();
    } catch (e) { alert(errMsg(e)); }
  });

  async function paintTrend() {
    try {
      const data = await tmdb('trending/all/week');
      const items = (data.results || []).filter((x) => x.poster_path).slice(0, 6);
      trend.innerHTML = items.map((x) => `
        <figure data-tmdb='${esc(JSON.stringify({ id: x.id, media_type: x.media_type || 'movie', title: pickTitle(x), poster_path: x.poster_path, year: String(x.release_date || x.first_air_date || '').slice(0, 4) }))}'>
          <div class="ph"><span>…</span><img loading="lazy" width="150" height="225" src="${esc(poster(x.poster_path))}" alt="${esc(pickTitle(x))}" onload="this.previousElementSibling.remove()" onerror="this.parentNode.innerHTML='🎬'"></div>
          <figcaption>${esc(pickTitle(x))}</figcaption></figure>`).join('') || `<p class="muted small">Nothing trending right now.</p>`;
    } catch (e) {
      trend.innerHTML = `<p class="err small" style="grid-column:1/-1">${esc(errMsg(e))}</p>`;
    }
  }

  async function addItem(x) {
    try {
      const { db: d, f } = await db();
      const dup = await f.getDocs(f.query(
        f.collection(d, 'watch_list'),
        f.where('tmdbId', '==', x.id), f.where('userName', '==', me), f.limit(1)));
      if (!dup.empty) {
        await f.updateDoc(f.doc(d, 'watch_list', dup.docs[0].id), { status: 'to-watch' });
      } else {
        await f.addDoc(f.collection(d, 'watch_list'), {
          tmdbId: x.id,
          title: x.title,
          mediaType: x.media_type || 'movie',
          posterPath: x.poster_path ? `https://image.tmdb.org/t/p/w500${x.poster_path}` : '',
          backdropPath: '',
          year: x.year || '',
          status: 'to-watch',
          isAnime: false,
          userName: me,
          addedAt: f.serverTimestamp(),
          source: 'tmdb',
          monthDay: monthDay(),
        });
      }
      await paintList();
      results.innerHTML = `<p class="ok small">Saved “${esc(x.title)}” to our watchlist. 💖</p>`;
    } catch (e) { results.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`; }
  }

  el.querySelector('#search').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const q = el.querySelector('#q').value.trim();
    if (!q) return;
    results.innerHTML = `<div class="skel"></div>`;
    try {
      const data = await tmdb('search/multi', { query: q });
      const items = (data.results || []).filter((x) => (x.media_type === 'movie' || x.media_type === 'tv') && x.poster_path).slice(0, 6);
      results.innerHTML = items.length ? items.map((x) => `
        <div class="row" style="margin-top:8px">
          <img loading="lazy" width="46" height="69" src="${esc(poster(x.poster_path))}" alt="" onerror="this.remove()">
          <div class="grow"><strong>${esc(pickTitle(x))}</strong><div class="muted small">${esc(String(x.release_date || x.first_air_date || '').slice(0, 4))}</div></div>
          <button type="button" data-add='${esc(JSON.stringify({ id: x.id, media_type: x.media_type, title: pickTitle(x), poster_path: x.poster_path, year: String(x.release_date || x.first_air_date || '').slice(0, 4) }))}'>+ Add</button>
        </div>`).join('') : `<p class="muted small">No matches — try another title.</p>`;
    } catch (e) { results.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`; }
  });

  results.addEventListener('click', (ev) => {
    const b = ev.target.closest('[data-add]');
    if (b) addItem(JSON.parse(b.dataset.add));
  });
  trend.addEventListener('click', (ev) => {
    const fig = ev.target.closest('[data-tmdb]');
    if (fig) addItem(JSON.parse(fig.dataset.tmdb));
  });

  await paintList();
  await paintTrend();
}
