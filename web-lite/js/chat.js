import { db, session, esc, errMsg, monthDay, fmtTime } from './lib.js';
import { displayName, requireCouple } from './auth.js';
import { Shell } from './home.js';

export async function Chat(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'chat', `
    <div class="topbar"><div><h2 class="serif">Sanctuary</h2><p class="sub">just us two, always</p></div></div>
    <div class="bubbles" id="list" aria-live="polite"><div class="skel"></div></div>
    <div style="height:120px"></div>
    <div class="composer"><form class="inner" id="form">
      <input id="box" name="text" placeholder="Say something sweet…" autocomplete="off" maxlength="2000" aria-label="Message">
      <button type="submit" id="send">Send</button>
    </form></div>`);

  const list = el.querySelector('#list');
  const form = el.querySelector('#form');
  const box = el.querySelector('#box');
  const send = el.querySelector('#send');
  let unsub = null;

  const paint = (docs, error) => {
    if (error) {
      list.innerHTML = `<div class="card"><p>${esc(error)}</p><button class="ghost" type="button" id="retry">Try again</button></div>`;
      list.querySelector('#retry').addEventListener('click', () => location.reload());
      return;
    }
    if (!docs.length) {
      list.innerHTML = `<div class="card center"><p class="serif" style="font-size:22px;margin:0">No words yet</p><p class="muted small">Say the first sweet thing.</p></div>`;
      return;
    }
    list.innerHTML = docs.map((m) => {
      const mine = m.senderUid === u.uid;
      return `<div class="bubble${mine ? ' me' : ''}"><span>${esc(m.text)}</span><span class="meta">${esc(m.sender)} · ${esc(fmtTime(m.timestamp))}</span></div>`;
    }).join('');
    list.lastElementChild.scrollIntoView({ block: 'end' });
  };

  try {
    const { db: d, f } = await db();
    const q = f.query(f.collection(d, 'sanctuary_messages'), f.orderBy('timestamp', 'desc'), f.limit(50));
    unsub = f.onSnapshot(q, (snap) => {
      const docs = snap.docs.map((x) => ({ id: x.id, ...x.data() })).reverse();
      paint(docs);
    }, (e) => paint([], errMsg(e)));
  } catch (e) { paint([], errMsg(e)); }

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const text = box.value.trim();
    if (!text) return;
    send.disabled = true;
    try {
      const { db: d, f } = await db();
      await f.addDoc(f.collection(d, 'sanctuary_messages'), {
        text: text.slice(0, 4000),
        sender: displayName(session.username),
        senderUid: u.uid,
        timestamp: f.serverTimestamp(),
        monthDay: monthDay(),
      });
      box.value = '';
    } catch (e) {
      alert(errMsg(e));
    } finally {
      send.disabled = false;
      box.focus();
    }
  });

  el.cleanup = () => { try { unsub && unsub(); } catch {} };
}
