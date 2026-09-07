import { db, session, esc, errMsg } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

export async function Books(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'books', `
    <div class="topbar"><div><h2 class="serif">Books</h2><p class="sub">stories for us</p></div></div>
    <div class="stack" style="margin-top:12px">
      <form class="row" id="search"><input id="q" placeholder="Search Open Library…" maxlength="80" aria-label="Search books"><button type="submit">Find</button></form>
      <div id="results"></div>
      <div class="card"><strong>Our shelf</strong><div class="stack" id="list" style="margin-top:8px"><div class="skel"></div></div></div>
    </div>`);
  const list = el.querySelector('#list');
  const results = el.querySelector('#results');

  function statusLabel(m) {
    const k = !!m.khentReadAt;
    const c = !!m.clairReadAt;
    if (k && c) return 'read by both';
    if (k) return 'read by Khent';
    if (c) return 'read by Clair';
    return 'to read together';
  }

  async function paintList() {
    try {
      const { db: d, f } = await db();
      const s = await f.getDocs(f.query(f.collection(d, 'our_books'), f.limit(50)));
      const items = s.docs.map((x) => ({ id: x.id, ...x.data() }));
      if (!items.length) {
        list.innerHTML = `<p class="muted small" style="margin:0">Our shelf is empty — search above and add our first book.</p>`;
        return;
      }
      list.innerHTML = items.map((m) => `
        <div class="row" data-id="${esc(m.id)}" data-work="${esc(m.workKey || '')}">
          ${m.coverUrl ? `<img loading="lazy" width="46" height="69" src="${esc(m.coverUrl)}" alt="" onerror="this.remove()">` : '<span style="font-size:28px">📚</span>'}
          <div class="grow"><strong>${esc(m.title)}</strong><div class="muted small">${esc(m.author || '')} · ${esc(statusLabel(m))}</div></div>
          <button class="ghost" data-act="read" type="button">✓</button>
          <button class="ghost" data-act="rm" type="button" aria-label="Remove">✕</button>
        </div>`).join('');
    } catch (e) {
      list.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
  }

  list.addEventListener('click', async (ev) => {
    const b = ev.target.closest('[data-act]');
    if (!b) return;
    const row = ev.target.closest('[data-id]');
    if (!row) return;
    try {
      const { db: d, f } = await db();
      if (b.dataset.act === 'rm') {
        await f.deleteDoc(f.doc(d, 'our_books', row.dataset.id));
      } else {
        const field = session.username === 'khentsgdz' ? 'khentReadAt' : 'clairReadAt';
        await f.updateDoc(f.doc(d, 'our_books', row.dataset.id), { [field]: f.serverTimestamp() });
      }
      await paintList();
    } catch (e) { alert(errMsg(e)); }
  });

  el.querySelector('#search').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const q = el.querySelector('#q').value.trim();
    if (!q) return;
    results.innerHTML = `<div class="skel"></div>`;
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 10000);
      const r = await fetch(`https://openlibrary.org/search.json?q=${encodeURIComponent(q)}&limit=6`, { signal: ctrl.signal });
      clearTimeout(timer);
      if (!r.ok) throw new Error(`books ${r.status}`);
      const data = await r.json();
      const items = (data.docs || []).slice(0, 6);
      results.innerHTML = items.length ? items.map((x, i) => {
        const cover = x.cover_i ? `https://covers.openlibrary.org/b/id/${x.cover_i}-M.jpg` : '';
        return `<div class="row" style="margin-top:8px">
          ${cover ? `<img loading="lazy" width="46" height="69" src="${esc(cover)}" alt="" onerror="this.remove()">` : '<span style="font-size:28px">📚</span>'}
          <div class="grow"><strong>${esc(x.title || 'Untitled')}</strong><div class="muted small">${esc((x.author_name || [])[0] || '')}</div></div>
          <button type="button" data-add="${i}">+ Add</button>
        </div>`;
      }).join('') : `<p class="muted small">No matches — try another title.</p>`;
      results.querySelectorAll('[data-add]').forEach((b) => b.addEventListener('click', async () => {
        const x = items[Number(b.dataset.add)];
        try {
          const { db: d, f } = await db();
          const workKey = x.key || '';
          const dup = workKey
            ? await f.getDocs(f.query(f.collection(d, 'our_books'), f.where('workKey', '==', workKey), f.limit(1)))
            : { empty: false };
          if (dup.empty) {
            await f.addDoc(f.collection(d, 'our_books'), {
              workKey,
              editionKey: '',
              iaId: ((x.ia || [])[0] || ''),
              title: x.title || 'Untitled',
              author: (x.author_name || [])[0] || '',
              coverUrl: x.cover_i ? `https://covers.openlibrary.org/b/id/${x.cover_i}-M.jpg` : '',
              year: String(x.first_publish_year || ''),
              subjects: (x.subject || []).slice(0, 8),
              addedBy: session.username,
              addedAt: f.serverTimestamp(),
              khentReadAt: null,
              clairReadAt: null,
            });
            results.innerHTML = `<p class="ok small">Shelved “${esc(x.title || 'book')}” for us. 📚</p>`;
            await paintList();
          } else {
            results.innerHTML = `<p class="muted small">Already on our shelf. 💛</p>`;
          }
        } catch (e) { results.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`; }
      }));
    } catch (e) { results.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`; }
  });

  await paintList();
}
