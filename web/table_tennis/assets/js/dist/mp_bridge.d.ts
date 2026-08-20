/** Typed port of js/mp-hooks.js:1 + js/bridge.js:1
 *  Drop-in replacement: keeps window.TTMultiplayer shape so existing Flutter bridge still works.
 *  New typed API is exported for future refactor.
 */
import type { BallStateDTO } from './types/index.js';
export interface TTMultiplayerAPI {
    enabled: boolean;
    isHost: boolean;
    localSide: 'near' | 'far';
    _remotePaddleY: number;
    _remoteBallState: BallStateDTO;
    _localPaddleY: number;
    _hostScore: number;
    _guestScore: number;
    setRemotePaddleY(y: number): void;
    setRemoteBallState(x: number, y: number, vx: number, vy: number): void;
    getLocalPaddleY(): number;
    setLocalPaddleY(y: number): void;
    getLocalBallState(): BallStateDTO;
    disableAI(): void;
    startMatch(isHost: boolean, side: 'near' | 'far'): void;
    endMatch(): void;
    syncScore(h: number, g: number): void;
    getScores(): {
        hostScore: number;
        guestScore: number;
    };
}
export declare function installMPHooks(): TTMultiplayerAPI;
//# sourceMappingURL=mp_bridge.d.ts.map