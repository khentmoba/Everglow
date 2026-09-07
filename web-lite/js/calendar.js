import { db, session, esc, errMsg } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const TYPES = [['dateNight', '💑 Date night'], ['anniversary', '💍 Anniversary'], ['reminder', '⏰ Reminder'], ['custom', '📌 Custom']];
const typeEmoji = (t) => (TYPES.find((x) => x[0] === t) || ['', '📌'])[1].split(' ')[0];

function startOfDay(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
function endOfDay(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59); }

export async function Calendar(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  const today = new Date();
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59);
  Shell(el, 'calendar', `
    <div class="topbar"><div><h2 class="serif">Dates</h2><p class="sub">never miss us</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card"><strong>Coming up</strong><div class="stack" id="up" style="margin-top:8px"><div class="skel"></div></div></div>
      <form class="card stack" id="add">
        <div><label for="title">A new date</label><input id="title" maxlength="120" placeholder="Dinner at our spot…" required></div>
        <div class="grid2">
          <div><label for="date">Day</label><input id="date" type="date" required></div>
          <div><label for="type">Kind</label><select id="type" style="width:100%;min-height:48px;background:rgba(0,0,0,.35);color:var(--paper);border:1px solid var(--line);border-radius:12px;padding:12px">${TYPES.map((t) => `<option value="${t[0]}">${t[1]}</option>`).join('')}</select></div>
        </div>
        <button type="submit">Save our date 📅</button>
      </form>
      <div class="card"><strong>This month</strong><div class="stack" id="month" style="margin-top:8px"><div class="skel"></div></div></div>
    </div>`);

  async function paint() {
    try {
      const { db: d, f } = await db();
      const [up, mo] = await Promise.all([
        f.getDocs(f.query(
          f.collection(d, 'calendar_events'),
          f.where('date', '>=', startOfDay(today)),
          f.where('date', '<=', new Date(Date.now() + 30 * 86400000)),
          f.orderBy('date', 'asc'), f.limit(20))).catch(() => null),
        f.getDocs(f.query(
          f.collection(d, 'calendar_events'),
          f.where('date', '>=', monthStart),
          f.where('date', '<=', monthEnd),
          f.orderBy('date', 'asc'), f.limit(50))).catch(() => null),
      ]);
      paintInto(el.querySelector('#up'), up, 'Nothing coming — plan something sweet.');
      paintInto(el.querySelector('#month'), mo, 'A quiet month — ours to fill.');
    } catch (e) {
      el.querySelector('#up').innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
  }

  function paintInto(node, snap, empty) {
    if (!snap) { node.innerHTML = `<p class="err small">Could not load. Pull to retry by reopening.</p>`; return; }
    const items = snap.docs.map((x) => ({ id: x.id, ...x.data() }));
    if (!items.length) { node.innerHTML = `<p class="muted small" style="margin:0">${empty}</p>`; return; }
    node.innerHTML = items.map((m) => {
      const t = m.date && typeof m.date.toDate === 'function' ? m.date.toDate() : new Date(m.date);
      return `<div class="row" data-id="${esc(m.id)}">
        <span style="font-size:24px">${typeEmoji(m.type)}</span>
        <div class="grow"><strong>${esc(m.title)}</strong>
        <div class="muted small">${t.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })}</div></div>
        <button class="ghost" data-act="rm" type="button" aria-label="Remove">✕</button></div>`;
    }).join('');
  }

  el.querySelector('#add').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const title = el.querySelector('#title').value.trim();
    const day = el.querySelector('#date').value;
    if (!title || !day) return;
    try {
      const { db: d, f } = await db();
      await f.addDoc(f.collection(d, 'calendar_events'), {
        title: title.slice(0, 120),
        description: '',
        date: new Date(`${day}T12:00:00`),
        type: el.querySelector('#type').value,
        createdBy: session.username,
        recurring: 'none',
        attendees: [],
        isAllDay: true,
      });
      el.querySelector('#title').value = '';
      el.querySelector('#date').value = '';
      await paint();
    } catch (e) { alert(errMsg(e)); }
  });

  el.addEventListener('click', async (ev) => {
    const b = ev.target.closest('[data-act="rm"]');
    if (!b) return;
    const id = ev.target.closest('[data-id]').dataset.id;
    try {
      const { db: d, f } = await db();
      await f.deleteDoc(f.doc(d, 'calendar_events', id));
      await paint();
    } catch (e) { alert(errMsg(e)); }
  });

  await paint();
}
