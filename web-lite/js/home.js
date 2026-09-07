import { db, session, esc, ageParts } from './lib.js';
import { displayName, logout, requireCouple } from './auth.js';
import { startPushToasts } from './push.js';

export function Shell(el, active, inner) {
  const more = ['cinema', 'bucket', 'calendar', 'journal', 'jar', 'jukebox', 'books', 'anime'].includes(active);
  el.innerHTML = `
    <div class="wrap">${inner}</div>
    <nav class="nav" aria-label="Everglow">
      <a href="#/home" ${active === 'home' ? 'aria-current="page"' : ''}><span class="i">🏠</span>Home</a>
      <a href="#/chat" ${active === 'chat' ? 'aria-current="page"' : ''}><span class="i">💬</span>Chat</a>
      <a href="#/cinema" ${active === 'cinema' ? 'aria-current="page"' : ''}><span class="i">🎬</span>${more && active === 'cinema' ? 'Cinema' : 'Films'}</a>
      <a href="#/bucket" ${active === 'bucket' ? 'aria-current="page"' : ''}><span class="i">✨</span>${more && active === 'bucket' ? 'Dreams' : 'More'}</a>
      <a href="#/garden" ${active === 'garden' ? 'aria-current="page"' : ''}><span class="i">🌷</span>Garden</a>
    </nav>${more ? `<div class="wrap" style="padding-top:0"><div class="row" style="flex-wrap:wrap">
      <a class="btn ghost small" href="#/gallery">🖼️ Photos</a>
      <a class="btn ghost small" href="#/moods">💖 Moods</a>
      <a class="btn ghost small" href="#/bucket">✨ Dreams</a>
      <a class="btn ghost small" href="#/calendar">📅 Dates</a>
      <a class="btn ghost small" href="#/journal">📔 Journal</a>
      <a class="btn ghost small" href="#/jar">⭐ Stars</a>
      <a class="btn ghost small" href="#/jukebox">🎵 Music</a>
      <a class="btn ghost small" href="#/books">📚 Books</a>
      <a class="btn ghost small" href="#/anime">⛩️ Anime</a>
    </div></div>` : ''}`;
}

export async function Dashboard(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  const name = session.username;
  Shell(el, 'home', `
    <div class="topbar"><div><p class="sub gold" style="letter-spacing:0.2em;font-size:11px">EST. FEBRUARY 14, 2026 — KHENT &amp; CLAIR</p><h2 class="serif">Hello, ${esc(displayName(name))}</h2><p class="sub">our days, glowing softly</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card center" id="counter"><div class="skel"></div></div>
      <div class="tiles">
        <a class="tile" href="#/chat"><span class="t">💬</span><strong>Sanctuary</strong><span id="pv-chat">our latest words…</span></a>
        <a class="tile" href="#/gallery"><span class="t">🖼️</span><strong>Gallery</strong><span id="pv-gallery">our latest photos…</span></a>
        <a class="tile" href="#/moods"><span class="t">💖</span><strong>Heartbeat</strong><span id="pv-moods">how we feel today…</span></a>
        <a class="tile" href="#/garden"><span class="t">🌷</span><strong>Garden</strong><span id="pv-garden">our little bloom…</span></a>
        <a class="tile" href="#/cinema"><span class="t">🎬</span><strong>Cinema</strong><span id="pv-cinema">movies for us…</span></a>
        <a class="tile" href="#/bucket"><span class="t">✨</span><strong>Dreams</strong><span id="pv-bucket">things we will do…</span></a>
        <a class="tile" href="#/calendar"><span class="t">📅</span><strong>Dates</strong><span id="pv-calendar">what is coming…</span></a>
        <a class="tile" href="#/journal"><span class="t">📔</span><strong>Journal</strong><span id="pv-journal">our pages…</span></a>
        <a class="tile" href="#/jar"><span class="t">⭐</span><strong>Star jar</strong><span id="pv-jar">little lights…</span></a>
        <a class="tile" href="#/jukebox"><span class="t">🎵</span><strong>Jukebox</strong><span id="pv-music">what we play…</span></a>
        <a class="tile" href="#/books"><span class="t">📚</span><strong>Books</strong><span id="pv-books">stories for us…</span></a>
        <a class="tile" href="#/anime"><span class="t">⛩️</span><strong>Anime</strong><span id="pv-anime">animated tales…</span></a>
      </div>
      <button class="ghost" id="logout" type="button">Lock the door</button>
    </div>`);
  el.querySelector('#logout').addEventListener('click', async () => { await logout(); nav('#/'); });
  startPushToasts();

  const c = el.querySelector('#counter');
  function tick() {
    const p = ageParts();
    c.innerHTML = `<p class="muted small" style="margin:0">loving each other for</p>
      <p class="serif counter-num">${p.totalDays} <span style="font-size:18px">days</span></p>
      <p class="counter-sub">${p.years}y · ${p.months}m · ${p.days}d · ${p.hours}h ${p.minutes}m ${p.seconds}s</p>`;
  }
  tick();
  const timer = setInterval(() => { if (!document.body.contains(c)) clearInterval(timer); else tick(); }, 1000);

  try {
    const { db: d, f } = await db();
    const [chat, photos] = await Promise.all([
      f.getDocs(f.query(f.collection(d, 'sanctuary_messages'), f.orderBy('timestamp', 'desc'), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'gallery'), f.orderBy('uploadedAt', 'desc'), f.limit(1))).catch(() => null),
    ]);
    if (chat && !chat.empty) {
      const m = chat.docs[0].data();
      el.querySelector('#pv-chat').textContent = `“${String(m.text || '').slice(0, 42)}”`;
    }
    if (photos && !photos.empty) {
      const p = photos.docs[0].data();
      el.querySelector('#pv-gallery').textContent = String(p.caption || 'a new memory').slice(0, 42);
    }
    const moods = await Promise.all(['clairjassen', 'khentsgdz'].map((who) =>
      f.getDocs(f.query(f.collection(d, 'moods'), f.where('username', '==', who), f.orderBy('timestamp', 'desc'), f.limit(1))).catch(() => null)));
    const bits = moods.map((s, i) => (!s || s.empty) ? null : `${i === 0 ? 'Clair' : 'Khent'} ${s.docs[0].data().moodEmoji || ''}`).filter(Boolean);
    if (bits.length) el.querySelector('#pv-moods').textContent = bits.join(' · ');
    const me = await f.getDoc(f.doc(d, 'users', u.uid, 'garden_stats', 'stats')).catch(() => null);
    if (me && me.exists()) {
      const s = me.data();
      el.querySelector('#pv-garden').textContent = `stage ${s.currentStage ?? 0} · ${s.streakCount ?? 0}-day streak`;
    }
    const [films, dreams, dates, pages, stars] = await Promise.all([
      f.getDocs(f.query(f.collection(d, 'watch_list'), f.where('userName', '==', name), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'bucket_list'), f.orderBy('createdAt', 'desc'), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'calendar_events'), f.where('date', '>=', new Date()), f.orderBy('date', 'asc'), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'journal_entries'), f.orderBy('createdAt', 'desc'), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'starlight_jar'), f.orderBy('timestamp', 'desc'), f.limit(1))).catch(() => null),
    ]);
    const set = (id, v) => { const n = el.querySelector('#' + id); if (n && v) n.textContent = v; };
    if (films && !films.empty) set('pv-cinema', `${films.size || 'our'} saved to watch`);
    if (dreams && !dreams.empty) { const x = dreams.docs[0].data(); set('pv-bucket', String(x.title || 'a dream waiting').slice(0, 42)); }
    if (dates && !dates.empty) {
      const x = dates.docs[0].data();
      const t = x.date && typeof x.date.toDate === 'function' ? x.date.toDate() : new Date(x.date);
      set('pv-calendar', `${String(x.title || 'a date').slice(0, 30)} · ${t.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}`);
    }
    if (pages && !pages.empty) set('pv-journal', String(pages.docs[0].data().title || 'a new page').slice(0, 42));
    if (stars && !stars.empty) set('pv-jar', String(stars.docs[0].data().content || 'a little light').slice(0, 42));
    const [music, books, anime] = await Promise.all([
      f.getDocs(f.query(f.collection(d, 'music_status'), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'our_books'), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'watch_list'), f.where('isAnime', '==', true), f.limit(1))).catch(() => null),
    ]);
    if (music && !music.empty) { const m = music.docs[0].data(); set('pv-music', `${String(m.trackName || 'a song').slice(0, 26)} · ${String(m.artistName || '').slice(0, 14)}`); }
    if (books && !books.empty) set('pv-books', String(books.docs[0].data().title || 'a story').slice(0, 42));
    if (anime && !anime.empty) set('pv-anime', String(anime.docs[0].data().title || 'a tale').slice(0, 42));
  } catch (e) {
    ['pv-chat', 'pv-gallery', 'pv-moods', 'pv-garden', 'pv-cinema', 'pv-bucket', 'pv-calendar', 'pv-journal', 'pv-jar', 'pv-music', 'pv-books', 'pv-anime'].forEach((id) => {
      const n = el.querySelector('#' + id);
      if (n) n.textContent = 'open to refresh';
    });
  }
}
