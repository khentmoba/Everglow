import { db, session, esc, errMsg, fmtTime } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const CHOICES = [
  { emoji: '🥰', score: 5, label: 'glowing' },
  { emoji: '😊', score: 4, label: 'happy' },
  { emoji: '😐', score: 3, label: 'okay' },
  { emoji: '😔', score: 2, label: 'low' },
  { emoji: '😭', score: 1, label: 'heavy' },
];

export async function Moods(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'moods', `
    <div class="topbar"><div><h2 class="serif">Heartbeat</h2><p class="sub">how are our hearts today?</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card" id="status"><div class="skel"></div></div>
      <div class="card">
        <p style="margin-top:0"><strong>How do you feel right now?</strong></p>
        <div class="moods" role="group" aria-label="Pick your mood">
          ${CHOICES.map((c) => `<button type="button" data-e="${c.emoji}" data-s="${c.score}" title="${c.label}">${c.emoji}</button>`).join('')}
        </div>
        <p class="muted small" id="note" style="margin-bottom:0">One tap shares it with your love.</p>
      </div>
    </div>`);

  const status = el.querySelector('#status');
  const note = el.querySelector('#note');

  async function refresh() {
    try {
      const { db: d, f } = await db();
      const rows = await Promise.all(['clairjassen', 'khentsgdz'].map(async (who) => {
        const s = await f.getDocs(f.query(
          f.collection(d, 'moods'), f.where('username', '==', who),
          f.orderBy('timestamp', 'desc'), f.limit(1)));
        return { who: who === 'clairjassen' ? 'Clair' : 'Khent', doc: s.empty ? null : s.docs[0].data() };
      }));
      status.innerHTML = rows.map((r) => r.doc
        ? `<div class="row"><span style="font-size:28px">${esc(r.doc.moodEmoji || '💖')}</span><div><strong>${r.who}</strong><div class="muted small">${esc(fmtTime(r.doc.timestamp))}</div></div></div>`
        : `<div class="row"><span style="font-size:28px">🤍</span><div><strong>${r.who}</strong><div class="muted small">no mood yet today</div></div></div>`).join('');
    } catch (e) {
      status.innerHTML = `<p class="err small" style="margin:0">${esc(errMsg(e))}</p>`;
    }
  }
  await refresh();

  el.querySelectorAll('[data-e]').forEach((b) => b.addEventListener('click', async () => {
    b.setAttribute('aria-pressed', 'true');
    note.textContent = 'Sharing…';
    try {
      const { db: d, f } = await db();
      await f.addDoc(f.collection(d, 'moods'), {
        username: session.username,
        moodScore: Number(b.dataset.s),
        moodEmoji: b.dataset.e,
        timestamp: f.serverTimestamp(),
      });
      note.textContent = 'Shared with love. 💖';
      await refresh();
    } catch (e) {
      note.textContent = errMsg(e);
    } finally {
      b.removeAttribute('aria-pressed');
    }
  }));
}
