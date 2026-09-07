import { db, session, esc, errMsg } from './lib.js';
import { requireCouple } from './auth.js';
import { Shell } from './home.js';

const PLANTS = {
  lily: { emoji: '🌸', name: 'Lily' },
  rose: { emoji: '🌹', name: 'Rose' },
  sunflower: { emoji: '🌻', name: 'Sunflower' },
  tulip: { emoji: '🌷', name: 'Tulip' },
  sakura: { emoji: '🌺', name: 'Sakura' },
};

function stageFor(n) {
  if (n >= 30) return 5;
  if (n >= 20) return 4;
  if (n >= 10) return 3;
  if (n >= 5) return 2;
  if (n >= 1) return 1;
  return 0;
}

const STAGE_WORD = ['a seed of us', 'a tiny sprout', 'growing strong', 'budding love', 'almost blooming', 'in full bloom'];

export async function Garden(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'garden', `
    <div class="topbar"><div><h2 class="serif">Daily Bloom</h2><p class="sub">water it once a day, together</p></div></div>
    <div class="stack" style="margin-top:12px">
      <div class="card center" id="plant"><div class="skel"></div></div>
      <div class="card">
        <p style="margin-top:0"><strong>Choose our plant</strong></p>
        <div class="row" style="flex-wrap:wrap">
          ${Object.entries(PLANTS).map(([k, p]) => `<button type="button" class="ghost" data-p="${k}" style="min-height:52px">${p.emoji} ${p.name}</button>`).join('')}
        </div>
      </div>
      <button id="water" type="button">💧 Water with love</button>
      <p class="muted small center" id="note"></p>
    </div>`);

  const plant = el.querySelector('#plant');
  const note = el.querySelector('#note');
  const water = el.querySelector('#water');
  const refOf = async () => {
    const { db: d, f } = await db();
    return { d, f, ref: f.doc(d, 'users', u.uid, 'garden_stats', 'stats') };
  };

  async function paint() {
    try {
      const { f, ref } = await refOf();
      const s = await f.getDoc(ref);
      const g = s.exists() ? s.data() : { currentStage: 0, streakCount: 0, totalInteractions: 0, plantType: 'lily' };
      const p = PLANTS[g.plantType] || PLANTS.lily;
      const st = g.currentStage ?? stageFor(g.totalInteractions ?? 0);
      plant.innerHTML = `<div class="plant">${p.emoji}</div>
        <p class="serif" style="font-size:26px;margin:0">${p.name} — ${STAGE_WORD[Math.min(st, 5)]}</p>
        <p class="muted small" style="margin:4px 0 0">stage ${st} · ${g.streakCount ?? 0}-day streak · ${g.totalInteractions ?? 0} waters</p>`;
    } catch (e) {
      plant.innerHTML = `<p class="err small">${esc(errMsg(e))}</p>`;
    }
  }
  await paint();

  el.querySelectorAll('[data-p]').forEach((b) => b.addEventListener('click', async () => {
    note.textContent = 'Planting…';
    try {
      const { f, ref } = await refOf();
      const s = await f.getDoc(ref);
      if (s.exists()) await f.updateDoc(ref, { plantType: b.dataset.p });
      else await f.setDoc(ref, { currentStage: 0, lastVisit: f.serverTimestamp(), streakCount: 0, totalInteractions: 0, plantType: b.dataset.p });
      note.textContent = 'Planted with love. 🌷';
      await paint();
    } catch (e) { note.textContent = errMsg(e); }
  }));

  water.addEventListener('click', async () => {
    water.disabled = true;
    note.textContent = 'Watering…';
    try {
      const { f, ref } = await refOf();
      const s = await f.getDoc(ref);
      const now = new Date();
      const sameDay = (t) => {
        try {
          const d = t && typeof t.toDate === 'function' ? t.toDate() : new Date(t);
          return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
        } catch { return false; }
      };
      const yesterday = (t) => {
        try {
          const d = t && typeof t.toDate === 'function' ? t.toDate() : new Date(t);
          const y = new Date(now); y.setDate(y.getDate() - 1);
          return d.getFullYear() === y.getFullYear() && d.getMonth() === y.getMonth() && d.getDate() === y.getDate();
        } catch { return false; }
      };
      if (!s.exists()) {
        await f.setDoc(ref, { currentStage: 1, lastVisit: f.serverTimestamp(), streakCount: 1, totalInteractions: 1, plantType: 'lily' });
      } else {
        const g = s.data();
        const streak = sameDay(g.lastVisit) ? (g.streakCount ?? 1) : yesterday(g.lastVisit) ? (g.streakCount ?? 0) + 1 : 1;
        const total = (g.totalInteractions ?? 0) + 1;
        await f.updateDoc(ref, { currentStage: stageFor(total), lastVisit: f.serverTimestamp(), streakCount: streak, totalInteractions: total });
      }
      note.textContent = 'Watered. See you tomorrow. 💧';
      await paint();
    } catch (e) { note.textContent = errMsg(e); }
    finally { water.disabled = false; }
  });
}
