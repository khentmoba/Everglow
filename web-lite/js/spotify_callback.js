import { esc } from './lib.js';
import { requireCouple } from './auth.js';
import { handleSpotifyCallback } from './spotify.js';
import { Shell } from './home.js';

export async function SpotifyCallback(el, nav) {
  const u = await requireCouple(nav);
  if (!u) return;
  Shell(el, 'jukebox', `
    <div class="wrap stack">
      <div class="card center">
        <p class="serif" style="font-size:24px;margin:0">🎵 Connecting…</p>
        <p class="muted small" id="msg">Talking to Spotify, one moment love.</p>
        <div style="margin-top:12px" id="back" hidden><a class="btn ghost" href="#/jukebox">Back to Jukebox</a></div>
      </div>
    </div>`);
  const msg = el.querySelector('#msg');
  const back = el.querySelector('#back');
  const res = await handleSpotifyCallback();
  if (res.ok) {
    msg.innerHTML = `<span class="ok">Spotify linked! ✓ Taking you back…</span>`;
    setTimeout(() => nav('#/jukebox'), 1200);
  } else {
    msg.innerHTML = `<span class="err">${esc(res.error || 'Link failed — try again')}</span>`;
    back.hidden = false;
  }
}
