import { Gateway } from './gateway.js';

const app = document.getElementById('app');
const splash = document.getElementById('splash');
let cleanup = null;

const routes = {
  '/': () => Promise.resolve({ view: Gateway }),
  '/home': () => import('./home.js').then((m) => ({ view: m.Dashboard })),
  '/chat': () => import('./chat.js').then((m) => ({ view: m.Chat })),
  '/gallery': () => import('./gallery.js').then((m) => ({ view: m.Gallery })),
  '/moods': () => import('./moods.js').then((m) => ({ view: m.Moods })),
  '/garden': () => import('./garden.js').then((m) => ({ view: m.Garden })),
  '/cinema': () => import('./cinema.js').then((m) => ({ view: m.Cinema })),
  '/bucket': () => import('./bucket.js').then((m) => ({ view: m.Bucket })),
  '/calendar': () => import('./calendar.js').then((m) => ({ view: m.Calendar })),
  '/journal': () => import('./journal.js').then((m) => ({ view: m.Journal })),
  '/jar': () => import('./jar.js').then((m) => ({ view: m.Jar })),
  '/jukebox': () => import('./jukebox.js').then((m) => ({ view: m.Jukebox })),
  '/books': () => import('./books.js').then((m) => ({ view: m.Books })),
  '/anime': () => import('./anime.js').then((m) => ({ view: m.Anime })),
  '/spotify/callback': () => import('./spotify_callback.js').then((m) => ({ view: m.SpotifyCallback })),
};

function nav(hash) {
  if (location.hash === hash) render();
  else location.hash = hash;
}

async function render() {
  try { if (cleanup) cleanup(); } catch {}
  cleanup = null;
  const path = (location.hash || '#/').slice(1) || '/';
  const load = routes[path] || routes['/'];
  app.innerHTML = '';
  const host = document.createElement('div');
  host.id = 'view';
  host.cleanup = null;
  app.appendChild(host);
  const { view } = await load().catch(() => ({ view: null }));
  if (!view) {
    host.innerHTML = `<div class="wrap"><div class="card center"><p>That page could not open.</p><a class="btn ghost" href="#/">Back to the door</a></div></div>`;
  } else {
    try {
      await view(host, nav);
    } catch {
      host.innerHTML = `<div class="wrap"><div class="card center"><p>That page could not open.</p><a class="btn ghost" href="#/">Back to the door</a></div></div>`;
    }
  }
  if (host.cleanup) cleanup = host.cleanup;
  splash.classList.add('done');
  window.scrollTo(0, 0);
}

window.addEventListener('hashchange', render);
if (!location.hash) location.hash = '#/';
render();
