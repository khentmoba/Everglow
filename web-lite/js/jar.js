import { db, session, esc, errMsg, monthDay, fmtTime } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const CATS = [['gratitude', '🙏'], ['memory', '📸'], ['love', '💕'], ['dream', '🌙'], ['milestone', '🎉'], ['surprise', '✨']];
const catEmoji = (c) => (CATS.find((x) => x[0] === c) || ['', '✨'])[1];

export async function Jar(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'jar', `
    <div class="topbar"><div><h2 class="serif">Starlight jar</h2><p class="sub">little lights we keep</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card center" id="lucky"><p class="muted small" style="margin:0">feeling lucky?</p>
        <div style="margin-top:8px"><button class="ghost" id="draw" type="button">✨ Draw a star</button></div>
        <div id="star" style="margin-top:8px"></div></div>
      <form class="card stack" id="add">
        <div><label for="content">Drop a little light</label><textarea id="content" maxlength="2000" placeholder="Thank you for…" required></textarea></div>
        <div><label for="cat">Kind of light</label><select id="cat" style="width:100%;min-height:48px;background:rgba(0,0,0,.35);color:var(--paper);border:1px solid var(--line);border-radius:12px;padding:12px">${CATS.map((c) => `<option value="${c[0]}">${c[1]} ${c[0]}</option>`).join('')}</select></div>
        <button type="submit">Drop it in ⭐</button>
      </form>
      <div class="stack" id="list"><div class="skel"></div></div>
    </div>`);

  const list = el.querySelector('#list');

  async function paint() {
    try {
      const { db: d, f } = await db();
      const s = await f.getDocs(f.query(f.collection(d, 'starlight_jar'), f.orderBy('timestamp', 'desc'), f.limit(40)));
      const items = s.docs.map((x) => ({ id: x.id, ...x.data() }));
      if (!items.length) {
        list.innerHTML = `<div class="card center"><p class="serif" style="font-size:22px;margin:0">An empty jar</p><p class="muted small">Drop your first light above.</p></div>`;
        return;
      }
      list.innerHTML = items.map((m) => `
        <div class="card" data-id="${esc(m.id)}">
          <div class="row"><span style="font-size:24px">${catEmoji(m.category)}</span>
            <div class="grow"><p style="margin:0">${esc(m.content)}</p>
            <div class="muted small">${esc(m.author || '')} · ${esc(fmtTime(m.timestamp))}</div></div>
            <button class="ghost" data-act="rm" type="button" aria-label="Remove">✕</button></div>
        </div>`).join('');
    } catch (e) {
      list.innerHTML = `<div class="card"><p class="err small">${esc(errMsg(e))}</p><button class="ghost" type="button" id="retry">Try again</button></div>`;
      list.querySelector('#retry').addEventListener('click', paint);
    }
  }

  el.querySelector('#add').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const content = el.querySelector('#content').value.trim();
    if (!content) return;
    try {
      const { db: d, f } = await db();
      await f.addDoc(f.collection(d, 'starlight_jar'), {
        content: content.slice(0, 2000),
        author: session.username,
        timestamp: f.serverTimestamp(),
        category: el.querySelector('#cat').value,
        tags: [],
        monthDay: monthDay(),
      });
      el.querySelector('#content').value = '';
      await paint();
    } catch (e) { alert(errMsg(e)); }
  });

  el.querySelector('#draw').addEventListener('click', async () => {
    const star = el.querySelector('#star');
    star.innerHTML = `<p class="muted small">Reaching in…</p>`;
    try {
      const { db: d, f } = await db();
      const s = await f.getDocs(f.query(f.collection(d, 'starlight_jar'), f.orderBy('timestamp', 'desc'), f.limit(20)));
      if (s.empty) { star.innerHTML = `<p class="muted small">The jar is empty — drop one first.</p>`; return; }
      const docs = s.docs.map((x) => x.data());
      const pick = docs[Math.floor(Math.random() * docs.length)];
      star.innerHTML = `<div class="card"><p class="serif" style="font-size:20px;margin:0">“${esc(pick.content)}”</p><p class="muted small" style="margin:4px 0 0">— ${esc(pick.author || 'us')}</p></div>`;
    } catch (e) { star.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`; }
  });

  list.addEventListener('click', async (ev) => {
    const b = ev.target.closest('[data-act="rm"]');
    if (!b) return;
    const id = ev.target.closest('[data-id]').dataset.id;
    try {
      const { db: d, f } = await db();
      await f.deleteDoc(f.doc(d, 'starlight_jar', id));
      await paint();
    } catch (e) { alert(errMsg(e)); }
  });

  await paint();
}
