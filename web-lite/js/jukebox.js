import { db, esc, errMsg } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

export async function Jukebox(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'jukebox', `
    <div class="topbar"><div><h2 class="serif">Jukebox</h2><p class="sub">what we are vibing to</p></div></div>
    <div class="stack" style="margin-top:12px" id="cards"><div class="skel"></div><div class="skel"></div></div>`);
  const cards = el.querySelector('#cards');
  try {
    const { db: d, f } = await db();
    const snap = await f.getDocs(f.query(f.collection(d, 'music_status'), f.limit(10)));
    const rows = snap.docs.map((x) => x.data()).filter((m) => m && (m.trackName || m.artistName));
    if (!rows.length) {
      cards.innerHTML = `<div class="card center"><p class="serif" style="font-size:22px;margin:0">Quiet for now</p><p class="muted small">Once our plays sync, they will glow here.</p></div>`;
      return;
    }
    cards.innerHTML = rows.map((t) => {
      const who = t.username === 'khentsgdz' ? 'Khent' : t.username === 'clairjassen' ? 'Clair' : (t.username || 'Love');
      return `<div class="card"><div class="row">
        ${t.imageUrl ? `<img loading="lazy" width="56" height="56" style="border-radius:12px" src="${esc(t.imageUrl)}" alt="" onerror="this.remove()">` : '<span style="font-size:32px">🎵</span>'}
        <div class="grow"><strong>${esc(t.trackName || 'Silent Night')}</strong>
        <div class="muted small">${esc(t.artistName || 'Unknown Artist')}${t.albumName ? ` · ${esc(t.albumName)}` : ''}</div>
        <div class="muted small">${esc(who)}${t.isPlaying ? ' · <span class="ok">playing now</span>' : ''}</div></div>
        ${t.spotifyUrl ? `<a class="btn ghost small" href="${esc(t.spotifyUrl)}" target="_blank" rel="noopener">Open</a>` : ''}
      </div></div>`;
    }).join('');
  } catch (e) {
    cards.innerHTML = `<div class="card"><p class="err small">${esc(errMsg(e))}</p><button class="ghost" type="button" id="retry">Try again</button></div>`;
    cards.querySelector('#retry').addEventListener('click', () => Jukebox(el, nav));
  }
}
