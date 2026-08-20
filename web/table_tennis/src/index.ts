/** Entry — replaces window.famobi_gameJS bootstrap in assets/index.html:34 */
import { Game } from './game/game.js';

declare global {
  interface Window {
    TTGame: Game;
    extGameLoad: () => void;
    resizeCanvas: () => void;
  }
}

const game = new Game('canvas');
window.TTGame = game;
window.extGameLoad = () => game.extGameLoad();
window.resizeCanvas = () => game.resizeCanvas();

// auto-boot if DOM already ready (mirrors <script>extGameLoad(); in index.html:99)
if (document.readyState !== 'loading') game.extGameLoad();
else document.addEventListener('DOMContentLoaded', () => game.extGameLoad());

export { Game };
export * from './types/index.js';
export * from './utils/constants.js';
