import { db, session, esc, errMsg, monthDay, fmtTime } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const CATS = [['daily', '📔 Daily'], ['gratitude', '🙏 Gratitude'], ['memory', '📸 Memory'], ['letter', '💌 Letter'], ['dream', '🌙 Dream'], ['idea', '💡 Idea']];

export async function Journal(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'journal', `
    <div class="topbar"><div><h2 class="serif">Journal</h2><p class="sub">pages of us</p></div></div>
    <div class="stack" style="margin-top:12px">
      <form class="card stack" id="add">
        <div><label for="title">Title</label><input id="title" maxlength="120" placeholder="Today with you…" required></div>
        <div><label for="body">Words</label><textarea id="body" maxlength="8000" placeholder="Write from the heart…" required></textarea></div>
        <div class="grid2">
          <div><label for="cat">Shelf</label><select id="cat" style="width:100%;min-height:48px;background:rgba(0,0,0,.35);color:var(--paper);border:1px solid var(--line);border-radius:12px;padding:12px">${CATS.map((c) => `<option value="${c[0]}">${c[1]}</option>`).join('')}</select></div>
          <div style="display:flex;align-items:flex-end;gap:8px"><label style="display:flex;gap:8px;align-items:center;margin:0"><input id="pin" type="checkbox" style="width:22px;min-height:22px"> 📌 Pin</label></div>
        </div>
        <button type="submit">Keep this page 📔</button>
      </form>
      <div class="stack" id="list"><div class="skel"></div></div>
      <div class="center"><button class="ghost" id="more" type="button" hidden>Older pages</button></div>
    </div>`);

  const list = el.querySelector('#list');
  const more = el.querySelector('#more');
  let last = null;
  let done = false;

  function card(m) {
    const locked = m.isLocked ? ' 🔒' : '';
    return `<div class="card" data-id="${esc(m.id)}">
      <div class="row"><div class="grow"><strong>${m.isPinned ? '📌 ' : ''}${esc(m.title)}${locked}</strong>
      <div class="muted small">${esc(m.author || '')} · ${esc(fmtTime(m.createdAt))}</div></div>
      <button class="ghost" data-act="open" type="button">Open</button>
      <button class="ghost" data-act="rm" type="button" aria-label="Remove">✕</button></div>
      <p class="muted small" style="margin:8px 0 0">${esc(String(m.content || '').slice(0, 140))}${String(m.content || '').length > 140 ? '…' : ''}</p>
      <div class="full" hidden><p style="white-space:pre-wrap">${esc(m.content)}</p></div>
    </div>`;
  }

  async function page() {
    try {
      const { db: d, f } = await db();
      let q = f.query(f.collection(d, 'journal_entries'), f.orderBy('createdAt', 'desc'), f.limit(20));
      if (last) q = f.query(f.collection(d, 'journal_entries'), f.orderBy('createdAt', 'desc'), f.startAfter(last), f.limit(20));
      const s = await f.getDocs(q);
      if (s.empty && !last) {
        list.innerHTML = `<div class="card center"><p class="serif" style="font-size:22px;margin:0">A blank book</p><p class="muted small">Write your first page above.</p></div>`;
        return;
      }
      if (!last) list.innerHTML = '';
      list.insertAdjacentHTML('beforeend', s.docs.map((x) => card({ id: x.id, ...x.data() })).join(''));
      last = s.docs[s.docs.length - 1] || null;
      done = s.docs.length < 20;
      more.hidden = done;
    } catch (e) {
      list.innerHTML = `<div class="card"><p class="err small">${esc(errMsg(e))}</p><button class="ghost" type="button" id="retry">Try again</button></div>`;
      list.querySelector('#retry').addEventListener('click', () => { last = null; page(); });
    }
  }

  el.querySelector('#add').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const title = el.querySelector('#title').value.trim();
    const body = el.querySelector('#body').value.trim();
    if (!title || !body) return;
    try {
      const { db: d, f } = await db();
      const now = new Date();
      await f.addDoc(f.collection(d, 'journal_entries'), {
        title: title.slice(0, 120),
        content: body.slice(0, 8000),
        author: session.username,
        createdAt: f.serverTimestamp(),
        updatedAt: f.serverTimestamp(),
        category: el.querySelector('#cat').value,
        tags: [],
        isPinned: el.querySelector('#pin').checked,
        isLocked: false,
        wordCount: body.split(/\s+/).filter(Boolean).length,
        monthDay: monthDay(now),
        searchKey: `${title} ${body.slice(0, 500)}`.toLowerCase(),
      });
      el.querySelector('#title').value = '';
      el.querySelector('#body').value = '';
      last = null;
      await page();
    } catch (e) { alert(errMsg(e)); }
  });

  list.addEventListener('click', async (ev) => {
    const b = ev.target.closest('[data-act]');
    if (!b) return;
    const wrap = ev.target.closest('[data-id]');
    if (b.dataset.act === 'open') {
      const full = wrap.querySelector('.full');
      full.hidden = !full.hidden;
      b.textContent = full.hidden ? 'Open' : 'Close';
      return;
    }
    try {
      const { db: d, f } = await db();
      await f.deleteDoc(f.doc(d, 'journal_entries', wrap.dataset.id));
      wrap.remove();
    } catch (e) { alert(errMsg(e)); }
  });
  more.addEventListener('click', page);

  await page();
}
