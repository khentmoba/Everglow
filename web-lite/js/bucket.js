import { db, session, esc, errMsg } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const CATS = [['travel', '✈️', 'Travel'], ['experience', '🎭', 'Experience'], ['food', '🍽️', 'Food'], ['adventure', '🏔️', 'Adventure'], ['milestone', '🏆', 'Milestone'], ['other', '💫', 'Other']];
const STATUSES = [['wish', '🌟 Wished'], ['planned', '📋 Planned'], ['completed', '✅ Done']];
const catEmoji = (c) => (CATS.find((x) => x[0] === c) || ['', '💫'])[1];

export async function Bucket(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'bucket', `
    <div class="topbar"><div><h2 class="serif">Dreams</h2><p class="sub">things we will do, together</p></div></div>
    <div class="stack" style="margin-top:12px">
      <form class="card stack" id="add">
        <div><label for="title">A new dream</label><input id="title" maxlength="120" placeholder="Watch the sunrise in Siargao…" required></div>
        <div class="grid2">
          <div><label for="cat">Kind</label><select id="cat" style="width:100%;min-height:48px;background:rgba(0,0,0,.35);color:var(--paper);border:1px solid var(--line);border-radius:12px;padding:12px">${CATS.map((c) => `<option value="${c[0]}">${c[1]} ${c[2]}</option>`).join('')}</select></div>
          <div><label for="st">Starts as</label><select id="st" style="width:100%;min-height:48px;background:rgba(0,0,0,.35);color:var(--paper);border:1px solid var(--line);border-radius:12px;padding:12px">${STATUSES.map((s) => `<option value="${s[0]}">${s[1]}</option>`).join('')}</select></div>
        </div>
        <button type="submit">Dream it ✨</button>
      </form>
      <div class="row" style="flex-wrap:wrap" role="group" aria-label="Filter dreams">
        ${[['all', 'All'], ...STATUSES.map((s) => [s[0], s[1]])].map(([v, l]) => `<button class="ghost small" data-f="${v}" type="button">${l}</button>`).join('')}
      </div>
      <div class="stack" id="list"><div class="skel"></div></div>
    </div>`);

  const list = el.querySelector('#list');
  let filter = 'all';

  async function paint() {
    try {
      const { db: d, f } = await db();
      let q = f.query(f.collection(d, 'bucket_list'), f.orderBy('createdAt', 'desc'), f.limit(100));
      if (filter !== 'all') q = f.query(f.collection(d, 'bucket_list'), f.where('status', '==', filter), f.orderBy('createdAt', 'desc'), f.limit(50));
      const s = await f.getDocs(q);
      const items = s.docs.map((x) => ({ id: x.id, ...x.data() }));
      if (!items.length) {
        list.innerHTML = `<div class="card center"><p class="serif" style="font-size:22px;margin:0">No dreams yet</p><p class="muted small">Dream one above, love.</p></div>`;
        return;
      }
      list.innerHTML = items.map((m) => `
        <div class="card" data-id="${esc(m.id)}">
          <div class="row"><span style="font-size:24px">${catEmoji(m.category)}</span>
            <div class="grow"><strong>${esc(m.title)}</strong>
            <div class="muted small">${esc((m.status || 'wish'))} · by ${esc(m.createdBy || 'us')}</div></div>
            ${m.status !== 'completed' ? `<button class="ghost" data-act="done" type="button">✓</button>` : ''}
            <button class="ghost" data-act="rm" type="button" aria-label="Remove">✕</button></div>
          ${m.status !== 'completed' && m.status !== 'planned' && m.status !== 'wish' ? '' : m.status === 'wish' ? `<div style="margin-top:8px"><button class="ghost small" data-act="plan" type="button">Plan it 📋</button></div>` : ''}
        </div>`).join('');
    } catch (e) {
      list.innerHTML = `<div class="card"><p class="err small">${esc(errMsg(e))}</p><button class="ghost" type="button" id="retry">Try again</button></div>`;
      list.querySelector('#retry').addEventListener('click', paint);
    }
  }

  el.querySelector('#add').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const title = el.querySelector('#title').value.trim();
    if (!title) return;
    try {
      const { db: d, f } = await db();
      await f.addDoc(f.collection(d, 'bucket_list'), {
        title: title.slice(0, 120),
        description: '',
        category: el.querySelector('#cat').value,
        status: el.querySelector('#st').value,
        createdBy: session.username,
        createdAt: f.serverTimestamp(),
        notes: '',
        priority: 'medium',
      });
      el.querySelector('#title').value = '';
      await paint();
    } catch (e) { alert(errMsg(e)); }
  });

  el.querySelectorAll('[data-f]').forEach((b) => b.addEventListener('click', () => { filter = b.dataset.f; paint(); }));

  list.addEventListener('click', async (ev) => {
    const b = ev.target.closest('[data-act]');
    if (!b) return;
    const id = ev.target.closest('[data-id]').dataset.id;
    try {
      const { db: d, f } = await db();
      if (b.dataset.act === 'rm') await f.deleteDoc(f.doc(d, 'bucket_list', id));
      else if (b.dataset.act === 'done') await f.updateDoc(f.doc(d, 'bucket_list', id), { status: 'completed', completedAt: f.serverTimestamp(), completedBy: session.username });
      else if (b.dataset.act === 'plan') await f.updateDoc(f.doc(d, 'bucket_list', id), { status: 'planned' });
      await paint();
    } catch (e) { alert(errMsg(e)); }
  });

  await paint();
}
