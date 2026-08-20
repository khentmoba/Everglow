import type { OGameData } from '../types/index.js';
export declare const CANVAS: {
    readonly minSquare: 500;
    readonly maxSquare: 700;
    readonly radian: number;
};
export declare const PHYSICS: {
    readonly gravity: 3800;
    readonly spinPowUser: 2.5;
    readonly spinPowEnemy: 2;
    readonly spinClampUser: 3;
    readonly spinClampEnemy: 2;
    readonly bounceDamp: -0.85;
    readonly offTableThreshold: -200;
    readonly trailMax: 5;
    readonly netBounceY: 0.5;
};
export declare const TABLE: {
    readonly segsMobile: 75;
    readonly segsDesktop: 150;
    readonly sideMultiplier: 100;
    readonly heightFactor: 235;
    readonly widthFactor: 233;
};
export declare const SCORING: {
    readonly winScore: 11;
    readonly winBy: 2;
    readonly maxScore: 99;
};
export declare const USER_COUNTRIES: readonly ['CA', 'CN', 'BR', 'KG', 'DE', 'FR', 'HK', 'KZ', 'IE', 'IT', 'JP', 'NL', 'PL', 'PT', 'KR', 'ES', 'RU', 'TR', 'GB', 'US', 'CZ', 'AR', 'UA', 'IN', 'MX', 'EG', 'ID', 'IQ', 'IR', 'CL', 'DK', 'CO', 'TH', 'TW', 'AM', 'UZ', 'SK', 'BY', 'UY', 'IL'];
export declare const ENEMY_CUPS: readonly (readonly string[])[];
export declare const SPARE_ENEMY: 'CH';
export declare const MAP_MARKER_POS: readonly (readonly [number, number])[];
export declare const INITIAL_GAME_DATA: Readonly<OGameData>;
export declare const SAVE_KEY: 'tabletennisv3';
export declare const FIRST_RUN_USER_ID: 1234;
export declare const AUDIO: {
    readonly musicSrc: readonly ['audio/music.ogg', 'audio/music.m4a'];
    readonly soundSrc: readonly ['audio/sound.ogg'];
};
//# sourceMappingURL=constants.d.ts.map