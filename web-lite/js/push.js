import { db, esc, auth } from './lib.js';

const ROUTES = {
  chat_message: ['💌', '#/chat'],
  mood_update: ['💖', '#/home'],
  starlight_drop: ['⭐', '#/jar'],
  watchlist_update: ['🎬', '#/cinema'],
  gallery_photo: ['🖼️', '#/gallery'],
  milestone: ['🏆', '#/home'],
  special_day: ['💍', '#/home'],
  special_day_upcoming: ['📅', '#/calendar'],
  mood_checkin: ['💖', '#/moods'],
  mochi_note: ['🤖', '#/home'],
  daily_digest: ['🌅', '#/home'],
  night_recap: ['🌙', '#/home'],
  watch_party_invite: ['🎬', '#/cinema'],
};

let started = false;

export function toast({ title, body, route }) {
  document.querySelectorAll('.toast').forEach((t) => t.remove());
  const t = document.createElement('div');
  t.className = 'toast';
  t.setAttribute('role', 'status');
  t.innerHTML = `<div class="grow"><strong>${esc(title)}</strong><span>${esc(body)}</span></div>
    ${route ? `<a class="btn ghost" href="${esc(route)}">View</a>` : ''}
    <button class="ghost" type="button" aria-label="Dismiss">✕</button>`;
  document.body.appendChild(t);
  const kill = () => t.remove();
  t.querySelector('button').addEventListener('click', kill);
  setTimeout(kill, 6000);
}

export async function startPushToasts() {
  if (started) return;
  started = true;
  try {
    const a = await auth();
    const u = a.auth.currentUser;
    if (!u || u.isAnonymous) return;
    const { db: d, f } = await db();
    const seen = new Set();
    let primed = false;
    f.onSnapshot(f.query(f.collection(d, 'sanctuary_messages'), f.orderBy('timestamp', 'desc'), f.limit(1)),
      (snap) => {
        if (!primed) { snap.docs.forEach((x) => seen.add(x.id)); primed = true; return; }
        snap.docs.forEach((x) => {
          const m = x.data();
          if (seen.has(x.id)) return;
          seen.add(x.id);
          if (m.senderUid === u.uid) return;
          toast({ title: `💌 New message from ${m.sender || 'love'}`, body: String(m.text || '').slice(0, 100), route: '#/chat' });
        });
        if (seen.size > 30) { const arr = [...seen]; arr.slice(0, arr.length - 30).forEach((k) => seen.delete(k)); }
      }, () => {});
  } catch { /* toasts are best-effort */ }
}

export function toastFor(type, fallbackTitle, fallbackBody) {
  const hit = ROUTES[type];
  if (!hit) return null;
  return { title: fallbackTitle || `${hit[0]} Everglow`, body: fallbackBody || '', route: hit[1] };
}
