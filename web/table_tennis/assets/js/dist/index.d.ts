/** Entry — replaces window.famobi_gameJS bootstrap in assets/index.html:34 */
import { Game } from './game/game.js';
declare global {
    interface Window {
        TTGame: Game;
        extGameLoad: () => void;
        resizeCanvas: () => void;
    }
}
export { Game };
export * from './types/index.js';
export * from './utils/constants.js';
//# sourceMappingURL=index.d.ts.map