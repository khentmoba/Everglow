import { session, esc } from './lib.js';
import { loginCouple, displayName, isCouple } from './auth.js';

export function Gateway(el, nav) {
  let input = '';
  let busy = false;

  function paint(error) {
    const dots = [0, 1, 2, 3].map((i) => `<span class="dot${i < input.length ? ' on' : ''}"></span>`).join('');
    el.innerHTML = `
      <div class="wrap stack">
        <div class="hero">
          <span class="kicker">Khent &amp; Clair</span>
          <h1 class="serif">Everglow</h1>
          <p>our little world, behind one small door</p>
        </div>
        <div class="card center" id="door">
          <p class="muted small" style="margin:0">Enter our 4-digit passcode</p>
          <div class="dots" aria-hidden="true">${dots}</div>
          ${error ? `<p class="err small" role="alert" style="margin:0 0 8px">${esc(error)}</p>` : ''}
          <div class="pad" role="group" aria-label="Passcode keypad">
            ${[1, 2, 3, 4, 5, 6, 7, 8, 9, '', 0, 'back'].map((k) =>
              k === '' ? '<span></span>' : `<button type="button" data-k="${k}" ${busy ? 'disabled' : ''}>${k === 'back' ? '←' : k}</button>`).join('')}
          </div>
        </div>
        <p class="center muted small">Made with love, only for us two.</p>
      </div>`;
    el.querySelectorAll('[data-k]').forEach((b) => b.addEventListener('click', () => press(b.dataset.k)));
  }

  async function press(k) {
    if (busy) return;
    if (k === 'back') { input = input.slice(0, -1); paint(); return; }
    if (input.length >= 4) return;
    input += k;
    if (input.length < 4) { paint(); return; }
    paint();
    busy = true;
    paint();
    try {
      const username = await loginCouple(input);
      if (username && isCouple(username)) {
        nav('#/home');
        return;
      }
      input = '';
      busy = false;
      setTimeout(() => paint('That code did not open our door. Try again, love.'), 350);
    } catch (e) {
      input = '';
      busy = false;
      paint('The door could not reach our server. Check connection and try again.');
    }
  }

  paint();
  if (session.username && isCouple(session.username)) {
    el.insertAdjacentHTML('beforeend', `<div class="wrap center"><p class="muted small">Welcome back, ${esc(displayName(session.username))}.</p></div>`);
  }
}
