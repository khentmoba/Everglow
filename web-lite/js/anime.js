import { db, esc, errMsg } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const IMG = 'https://image.tmdb.org/t/p/w342';

export async function Anime(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'anime', `
    <div class="topbar"><div><h2 class="serif">Anime</h2><p class="sub">our animated shelf</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card"><strong>Watching together</strong><div class="photos" id="watching" style="margin-top:8px;grid-template-columns:repeat(3,1fr)"><div class="skel"></div><div class="skel"></div><div class="skel"></div></div></div>
      <div class="card"><strong>To watch</strong><div class="photos" id="towatch" style="margin-top:8px;grid-template-columns:repeat(3,1fr)"><div class="skel"></div><div class="skel"></div><div class="skel"></div></div></div>
      <div class="card"><strong>Loved</strong><div class="photos" id="watched" style="margin-top:8px;grid-template-columns:repeat(3,1fr)"><div class="skel"></div><div class="skel"></div><div class="skel"></div></div></div>
    </div>`);

  function card(m) {
    const src = m.posterPath && m.posterPath.startsWith('http') ? m.posterPath : m.posterPath ? `${IMG}${m.posterPath}` : '';
    return `<figure><div class="ph">${src ? `<span>…</span><img loading="lazy" width="150" height="225" src="${esc(src)}" alt="${esc(m.title)}" onload="this.previousElementSibling.remove()" onerror="this.parentNode.innerHTML='⛩️'">` : '⛩️'}</div>
      <figcaption>${esc(m.title)}</figcaption></figure>`;
  }

  function paintInto(node, items, empty) {
    node.innerHTML = items.length ? items.slice(0, 6).map(card).join('') : `<p class="muted small" style="grid-column:1/-1">${empty}</p>`;
  }

  try {
    const { db: d, f } = await db();
    const [a, b] = await Promise.all([
      f.getDocs(f.query(f.collection(d, 'watch_list'), f.where('userName', '==', 'khentsgdz'), f.limit(50))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'watch_list'), f.where('userName', '==', 'clairjassen'), f.limit(50))).catch(() => null),
    ]);
    const all = [...(a ? a.docs : []), ...(b ? b.docs : [])]
      .map((x) => ({ id: x.id, ...x.data() }))
      .filter((m) => m.isAnime === true);
    const watching = all.filter((m) => String(m.status || '').startsWith('watching'));
    const towatch = all.filter((m) => !String(m.status || '').startsWith('watching') && !String(m.status || '').startsWith('watched'));
    const watched = all.filter((m) => String(m.status || '').startsWith('watched'));
    paintInto(el.querySelector('#watching'), watching, 'Nothing playing — pick one from Cinema.');
    paintInto(el.querySelector('#towatch'), towatch, 'Queue is clear.');
    paintInto(el.querySelector('#watched'), watched, 'No finished tales yet.');
  } catch (e) {
    ['watching', 'towatch', 'watched'].forEach((id) => {
      el.querySelector('#' + id).innerHTML = `<p class="err small" style="grid-column:1/-1">${esc(errMsg(e))}</p>`;
    });
  }
}
