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
};

function nav(hash) {
  if (location.hash === hash) render();
  else location.hash = hash;
}

async function render() {
  try { if (cleanup) cleanup(); } catch {}
  cleanup = null;
  const path = (location.hash || '#/').slice(1);
  const load = routes[path] || routes['/'];
  app.innerHTML = '';
  const host = document.createElement('div');
  host.id = 'view';
  host.cleanup = null;
  app.appendChild(host);
  const { view } = await load();
  await view(host, nav);
  if (host.cleanup) cleanup = host.cleanup;
  splash.classList.add('done');
  window.scrollTo(0, 0);
}

window.addEventListener('hashchange', render);
if (!location.hash) location.hash = '#/';
render();
