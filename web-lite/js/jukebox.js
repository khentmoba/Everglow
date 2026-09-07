import { db, esc, errMsg, getIdToken, session } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';
import { linkSpotify, linkStatus, currentlyPlaying, unlinkSpotify } from './spotify.js';

const LASTFM = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyLastfm';
const SPOTIFY_SEARCH = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxySpotifySearch';

async function authedGet(url, timeoutMs = 10000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(url, { headers: { Authorization: `Bearer ${await getIdToken()}` }, signal: ctrl.signal });
    if (!r.ok) throw new Error(`music ${r.status}`);
    return r.json();
  } finally {
    clearTimeout(timer);
  }
}

function cleanImg(url) {
  if (!url) return '';
  for (const h of ['2a96cbd8b46e442fc41c2b86b821562', 'c6fdd01fe6b0203b3885fdb896dd102']) {
    if (url.includes(h)) return '';
  }
  return url;
}

function trackFromJson(t, username) {
  const imgs = t.image || [];
  let img = (imgs.find((i) => i.size === 'extralarge') || imgs[imgs.length - 1] || {})['#text'] || '';
  img = cleanImg(img);
  return {
    username,
    trackName: t.name || 'Silent Night',
    artistName: (t.artist && t.artist['#text']) || 'Unknown Artist',
    albumName: (t.album && t.album['#text']) || '',
    imageUrl: img,
    isPlaying: !!(t['@attr'] && t['@attr'].nowplaying === 'true'),
    ts: t.date && t.date.uts ? Number(t.date.uts) * 1000 : null,
    spotifyUrl: `https://open.spotify.com/search/${encodeURIComponent(`${(t.artist && t.artist['#text']) || ''} ${t.name || ''}`)}`,
  };
}

function labelFor(u) {
  return u === 'khentsgdz' ? 'Khent' : u === 'clairjassen' ? 'Clair' : (u || 'Love');
}

export async function Jukebox(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  const me = session.username;
  const partner = me === 'khentsgdz' ? 'clairjassen' : 'khentsgdz';
  Shell(el, 'jukebox', `
    <div class="topbar"><div><h2 class="serif">Jukebox</h2><p class="sub">what we are vibing to</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card" id="spotify"><div class="skel"></div></div>
      <div class="card" id="now"><div class="skel"></div></div>
      <div class="card" id="live"><div class="skel"></div></div>
      <div class="card"><strong>Recent plays</strong><div class="stack" id="recent" style="margin-top:8px"><div class="skel"></div></div></div>
      <div class="card"><strong>Top songs</strong><div class="stack" id="top" style="margin-top:8px"><div class="skel"></div></div></div>
      <div class="card"><strong>Dedicate a song 💌</strong>
        <form class="stack" id="ded" style="margin-top:8px">
          <div><label for="d-track">Song</label><input id="d-track" maxlength="120" placeholder="Perfect" required></div>
          <div><label for="d-artist">Artist</label><input id="d-artist" maxlength="120" placeholder="Ethel Cain" required></div>
          <div><label for="d-msg">Note for ${esc(labelFor(partner))} (optional)</label><input id="d-msg" maxlength="280" placeholder="This one is us…"></div>
          <button type="submit">Send dedication</button>
        </form></div>
      <div class="card"><strong>Dedications</strong><div class="stack" id="deds" style="margin-top:8px"><div class="skel"></div></div></div>
    </div>`);
  const spot = el.querySelector('#spotify');
  const now = el.querySelector('#now');
  const live = el.querySelector('#live');
  const recent = el.querySelector('#recent');
  const top = el.querySelector('#top');
  const deds = el.querySelector('#deds');

  function statusCard(t) {
    return `<div class="row">
      ${t.imageUrl ? `<img loading="lazy" width="56" height="56" style="border-radius:12px" src="${esc(t.imageUrl)}" alt="" onerror="this.remove()">` : '<span style="font-size:32px">🎵</span>'}
      <div class="grow"><strong>${esc(t.trackName)}</strong>
      <div class="muted small">${esc(t.artistName)}${t.albumName ? ` · ${esc(t.albumName)}` : ''}</div>
      <div class="muted small">${esc(labelFor(t.username))}${t.isPlaying ? ' · <span class="ok">playing now</span>' : t.ts ? ` · ${esc(new Date(t.ts).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }))}` : ''}</div></div>
      <button class="ghost" type="button" data-listen='${esc(JSON.stringify({ artist: t.artistName, track: t.trackName }))}'>▶</button>
    </div>`;
  }

  async function paintSpotify() {
    try {
      const st = await linkStatus(u.uid);
      if (!st.linked) {
        spot.innerHTML = `<div class="row"><span style="font-size:28px">🎧</span>
          <div class="grow"><strong>Connect Spotify</strong>
          <div class="muted small">For live currently-playing (your login stays ours).</div></div>
          <button type="button" id="link">Connect</button></div>`;
        spot.querySelector('#link').addEventListener('click', async () => {
          try {
            await linkSpotify();
          } catch {
            spot.insertAdjacentHTML('beforeend', `<p class="err small">Spotify is not configured yet — ask Khent to check the server keys.</p>`);
          }
        });
        return;
      }
      spot.innerHTML = `<div class="row"><span style="font-size:28px">🎧</span>
        <div class="grow"><strong>Spotify linked</strong>
        <div class="muted small">${esc(st.name || 'Premium ✓')}</div></div>
        <button class="ghost" type="button" id="unlink">Unlink</button></div>`;
      spot.querySelector('#unlink').addEventListener('click', async () => {
        await unlinkSpotify(u.uid);
        await paintSpotify();
        await paintNow();
      });
    } catch {
      spot.innerHTML = `<p class="muted small" style="margin:0">Spotify status unavailable.</p>`;
    }
  }

  async function paintNow() {
    try {
      const cp = await currentlyPlaying();
      if (!cp || !cp.connected) {
        now.innerHTML = `<p class="muted small" style="margin:0">Connect Spotify above to see live currently-playing here.</p>`;
        return;
      }
      if (!cp.isPlaying || !cp.trackName) {
        now.innerHTML = `<p class="muted small" style="margin:0">Nothing playing on Spotify right now. 🤍</p>`;
        return;
      }
      now.innerHTML = `<div class="row">
        ${cp.imageUrl ? `<img loading="lazy" width="56" height="56" style="border-radius:12px" src="${esc(cp.imageUrl)}" alt="" onerror="this.remove()">` : '<span style="font-size:32px">🎵</span>'}
        <div class="grow"><strong>${esc(cp.trackName)}</strong>
        <div class="muted small">${esc(cp.artistName || '')}${cp.albumName ? ` · ${esc(cp.albumName)}` : ''}</div>
        <div class="muted small">playing now on Spotify · <span class="ok">live</span></div></div>
        ${cp.spotifyUrl ? `<a class="btn ghost small" href="${esc(cp.spotifyUrl)}" target="_blank" rel="noopener">Open</a>` : ''}
      </div>`;
    } catch {
      now.innerHTML = `<p class="muted small" style="margin:0">Live Spotify check failed.</p>`;
    }
  }

  async function paintLive() {
    try {
      const { db: d, f } = await db();
      const snap = await f.getDocs(f.query(f.collection(d, 'music_status'), f.limit(10)));
      const rows = snap.docs.map((x) => x.data()).filter((m) => m && (m.trackName || m.artistName));
      if (!rows.length) {
        live.innerHTML = `<p class="serif center" style="font-size:22px;margin:0">Quiet for now 🤍</p><p class="muted small center" style="margin:4px 0 0">Once our plays sync, they will glow here.</p>`;
        return;
      }
      live.innerHTML = rows.map(statusCard).join('');
    } catch (e) {
      live.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
  }

  async function paintRecent() {
    try {
      const names = await lastfmNames();
      if (!names.length) {
        recent.innerHTML = `<p class="muted small" style="margin:0">Live history is not linked yet — the cards above still show our latest sync.</p>`;
        return;
      }
      const per = await Promise.all(names.map(async (who) => {
        try {
          const url = new URL(LASTFM);
          url.searchParams.set('method', 'user.getrecenttracks');
          url.searchParams.set('user', who.user);
          url.searchParams.set('format', 'json');
          url.searchParams.set('limit', '5');
          const data = await authedGet(url);
          const tracks = data.recenttracks && data.recenttracks.track;
          const arr = Array.isArray(tracks) ? tracks : tracks ? [tracks] : [];
          return arr.slice(0, 3).map((t) => trackFromJson(t, who.label));
        } catch {
          return [];
        }
      }));
      const flat = per.flat().filter(Boolean);
      recent.innerHTML = flat.length ? flat.map(statusCard).join('') : `<p class="muted small" style="margin:0">No recent plays found.</p>`;
    } catch (e) {
      recent.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
  }

  async function paintTop() {
    try {
      const names = await lastfmNames();
      if (!names.length) {
        top.innerHTML = `<p class="muted small" style="margin:0">Top songs appear once live history is linked.</p>`;
        return;
      }
      const per = await Promise.all(names.map(async (who) => {
        try {
          const url = new URL(LASTFM);
          url.searchParams.set('method', 'user.gettoptracks');
          url.searchParams.set('user', who.user);
          url.searchParams.set('period', 'overall');
          url.searchParams.set('limit', '5');
          url.searchParams.set('format', 'json');
          const data = await authedGet(url);
          const tracks = data.toptracks && data.toptracks.track;
          const arr = Array.isArray(tracks) ? tracks : tracks ? [tracks] : [];
          return { who: who.label, tracks: arr.slice(0, 5) };
        } catch {
          return { who: who.label, tracks: [] };
        }
      }));
      top.innerHTML = per.map(({ who, tracks }) => tracks.length
        ? `<div><p class="muted small" style="margin:0 0 6px">${esc(who)} · all-time</p>${tracks.map((t, i) => `
          <div class="row" style="margin-top:6px"><span class="gold" style="min-width:20px">${i + 1}</span>
            <div class="grow"><strong>${esc(t.name || 'Unknown')}</strong>
            <div class="muted small">${esc((t.artist && t.artist.name) || '')} · ${esc(String(t.playcount || 0))} plays</div></div>
            <button class="ghost" type="button" data-listen='${esc(JSON.stringify({ artist: (t.artist && t.artist.name) || '', track: t.name || '' }))}'>▶</button>
          </div>`).join('')}</div>`
        : '').join('') || `<p class="muted small" style="margin:0">No top songs yet.</p>`;
    } catch (e) {
      top.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
  }

  async function paintDeds() {
    try {
      const { db: d, f } = await db();
      const s = await f.getDocs(f.query(f.collection(d, 'jukebox_dedications'), f.orderBy('createdAt', 'desc'), f.limit(10)));
      const items = s.docs.map((x) => ({ id: x.id, ...x.data() }));
      if (!items.length) {
        deds.innerHTML = `<p class="muted small" style="margin:0">No dedications yet — send the first one above. 💌</p>`;
        return;
      }
      deds.innerHTML = items.map((m) => `
        <div class="row"><span style="font-size:26px">💌</span>
          <div class="grow"><strong>${esc(m.trackName)} — ${esc(m.artistName)}</strong>
          <div class="muted small">${esc(labelFor(m.fromUsername))} → ${esc(labelFor(m.toUsername))}${m.message ? ` · “${esc(m.message)}”` : ''}</div></div>
          <button class="ghost" type="button" data-listen='${esc(JSON.stringify({ artist: m.artistName, track: m.trackName }))}'>▶</button>
        </div>`).join('');
    } catch (e) {
      deds.innerHTML = `<p class="muted small" style="margin:0">Dedications need the couple login — they will appear after you re-enter the door.</p>`;
    }
  }

  el.addEventListener('click', async (ev) => {
    const b = ev.target.closest('[data-listen]');
    if (!b) return;
    let info = null;
    try { info = JSON.parse(b.dataset.listen); } catch { return; }
    b.disabled = true;
    try {
      const url = new URL(SPOTIFY_SEARCH);
      url.searchParams.set('artist', info.artist || '');
      url.searchParams.set('track', info.track || '');
      const hit = await authedGet(url);
      const open = (hit && (hit.spotifyUrl || hit.embedUrl)) || `https://open.spotify.com/search/${encodeURIComponent(`${info.artist || ''} ${info.track || ''}`)}`;
      window.open(open, '_blank', 'noopener');
    } catch {
      window.open(`https://open.spotify.com/search/${encodeURIComponent(`${info.artist || ''} ${info.track || ''}`)}`, '_blank', 'noopener');
    } finally {
      b.disabled = false;
    }
  });

  el.querySelector('#ded').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const track = el.querySelector('#d-track').value.trim();
    const artist = el.querySelector('#d-artist').value.trim();
    const msg = el.querySelector('#d-msg').value.trim();
    if (!track || !artist) return;
    try {
      const { db: d, f } = await db();
      await f.addDoc(f.collection(d, 'jukebox_dedications'), {
        fromUsername: me,
        toUsername: partner,
        trackName: track.slice(0, 120),
        artistName: artist.slice(0, 120),
        imageUrl: null,
        message: msg.slice(0, 280) || null,
        createdAt: f.serverTimestamp(),
      });
      el.querySelector('#d-track').value = '';
      el.querySelector('#d-artist').value = '';
      el.querySelector('#d-msg').value = '';
      await paintDeds();
    } catch (e) { alert(errMsg(e)); }
  });

  await paintSpotify();
  await paintNow();
  await paintLive();
  await paintDeds();
  paintRecent();
  paintTop();
}

let cachedNames = null;
async function lastfmNames() {
  if (cachedNames) return cachedNames;
  const out = [{ label: 'khentsgdz', user: 'khentsgdz' }, { label: 'clairjassen', user: 'clairjassen' }];
  try {
    const { db: d, f } = await db();
    const snap = await f.getDocs(f.query(f.collection(d, 'music_status'), f.limit(10)));
    const seen = new Set();
    snap.docs.forEach((x) => {
      const m = x.data();
      const u = (m && m.username) || x.id;
      if (u && !seen.has(u)) seen.add(u);
    });
    if (seen.size) {
      cachedNames = [...seen].map((u) => ({ label: u, user: u }));
      return cachedNames;
    }
  } catch { /* fall through to app defaults */ }
  cachedNames = out;
  return out;
}
