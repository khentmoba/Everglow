import { db, session, esc, ageParts } from './lib.js';
import { displayName, logout, requireCouple } from './auth.js';

export function Shell(el, active, inner) {
  el.innerHTML = `
    <div class="wrap">${inner}</div>
    <nav class="nav" aria-label="Everglow">
      <a href="#/home" ${active === 'home' ? 'aria-current="page"' : ''}><span class="i">🏠</span>Home</a>
      <a href="#/chat" ${active === 'chat' ? 'aria-current="page"' : ''}><span class="i">💬</span>Chat</a>
      <a href="#/gallery" ${active === 'gallery' ? 'aria-current="page"' : ''}><span class="i">🖼️</span>Photos</a>
      <a href="#/moods" ${active === 'moods' ? 'aria-current="page"' : ''}><span class="i">💖</span>Moods</a>
      <a href="#/garden" ${active === 'garden' ? 'aria-current="page"' : ''}><span class="i">🌷</span>Garden</a>
    </nav>`;
}

export async function Dashboard(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  const name = session.username;
  Shell(el, 'home', `
    <div class="topbar"><div><h2 class="serif">Hello, ${esc(displayName(name))}</h2><p class="sub">our days, glowing softly</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card center" id="counter"><div class="skel"></div></div>
      <div class="tiles">
        <a class="tile" href="#/chat"><span class="t">💬</span><strong>Sanctuary</strong><span id="pv-chat">our latest words…</span></a>
        <a class="tile" href="#/gallery"><span class="t">🖼️</span><strong>Gallery</strong><span id="pv-gallery">our latest photos…</span></a>
        <a class="tile" href="#/moods"><span class="t">💖</span><strong>Heartbeat</strong><span id="pv-moods">how we feel today…</span></a>
        <a class="tile" href="#/garden"><span class="t">🌷</span><strong>Garden</strong><span id="pv-garden">our little bloom…</span></a>
      </div>
      <button class="ghost" id="logout" type="button">Lock the door</button>
    </div>`);
  el.querySelector('#logout').addEventListener('click', async () => { await logout(); nav('#/'); });

  const c = el.querySelector('#counter');
  function tick() {
    const p = ageParts();
    c.innerHTML = `<p class="muted small" style="margin:0">loving each other for</p>
      <p class="serif" style="font-size:40px;margin:4px 0;line-height:1">${p.totalDays} <span style="font-size:18px">days</span></p>
      <p class="muted small" style="margin:0">${p.years}y · ${p.months}m · ${p.days}d · ${p.hours}h ${p.minutes}m ${p.seconds}s</p>`;
  }
  tick();
  const timer = setInterval(() => { if (!document.body.contains(c)) clearInterval(timer); else tick(); }, 1000);

  try {
    const { db: d, f } = await db();
    const [chat, photos] = await Promise.all([
      f.getDocs(f.query(f.collection(d, 'sanctuary_messages'), f.orderBy('timestamp', 'desc'), f.limit(1))).catch(() => null),
      f.getDocs(f.query(f.collection(d, 'gallery'), f.orderBy('uploadedAt', 'desc'), f.limit(1))).catch(() => null),
    ]);
    if (chat && !chat.empty) {
      const m = chat.docs[0].data();
      el.querySelector('#pv-chat').textContent = `“${String(m.text || '').slice(0, 42)}”`;
    }
    if (photos && !photos.empty) {
      const p = photos.docs[0].data();
      el.querySelector('#pv-gallery').textContent = String(p.caption || 'a new memory').slice(0, 42);
    }
    const moods = await Promise.all(['clairjassen', 'khentsgdz'].map((who) =>
      f.getDocs(f.query(f.collection(d, 'moods'), f.where('username', '==', who), f.orderBy('timestamp', 'desc'), f.limit(1))).catch(() => null)));
    const bits = moods.map((s, i) => (!s || s.empty) ? null : `${i === 0 ? 'Clair' : 'Khent'} ${s.docs[0].data().moodEmoji || ''}`).filter(Boolean);
    if (bits.length) el.querySelector('#pv-moods').textContent = bits.join(' · ');
    const me = await f.getDoc(f.doc(d, 'users', u.uid, 'garden_stats', 'stats')).catch(() => null);
    if (me && me.exists()) {
      const s = me.data();
      el.querySelector('#pv-garden').textContent = `stage ${s.currentStage ?? 0} · ${s.streakCount ?? 0}-day streak`;
    }
  } catch (e) {
    ['pv-chat', 'pv-gallery', 'pv-moods', 'pv-garden'].forEach((id) => {
      const n = el.querySelector('#' + id);
      if (n) n.textContent = 'open to refresh';
    });
  }
}
