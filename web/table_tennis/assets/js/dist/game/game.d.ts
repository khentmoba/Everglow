/**
 * Typed Game orchestrator — replaces ~1200 lines of scattered globals in game.js:2720-5300
 * Maintains same state machine but with explicit dependencies and no implicit window.* leakage.
 */
import type { OGameData, GameState, OImageIds } from '../types/index.js';
import { AssetLoader } from '../core/asset_loader.js';
import { UserInput } from '../core/user_input.js';
import { SaveDataHandler } from '../core/save_data.js';
import { CountryFlags } from '../core/country_flags.js';
import { TableTop } from '../elements/table_top.js';
import { UserBat } from '../elements/user_bat.js';
import { EnemyBat } from '../elements/enemy_bat.js';
import { Ball } from '../elements/ball.js';
import { Background } from '../elements/background.js';
import { Panel } from '../elements/panel.js';
declare const Howl: new (opts: {
    src: string[];
    volume: number;
    loop: boolean;
    sprite?: Record<string, [number, number]>;
}) => {
    play(s?: string): void;
    pause(): void;
    volume(): number;
    volume(v: number): void;
    mute(b: boolean): void;
    playing(): boolean;
    fade(from: number, to: number, dur: number): void;
};
export declare class Game {
    canvas: HTMLCanvasElement;
    ctx: CanvasRenderingContext2D;
    canvasScale: number;
    delta: number;
    previousTime: number;
    gameState: GameState;
    oGameData: OGameData;
    oImageIds: OImageIds;
    firstRun: boolean;
    controlState: 0 | 1;
    flagPage: number;
    justWonCup: boolean;
    rallyHits: number;
    isMobile: boolean;
    isBugBrowser: boolean;
    muted: boolean;
    hasFocus: boolean;
    audioType: 0 | 1 | 2;
    swipeState: 0 | 1;
    startTouchY: number;
    assetLib: AssetLoader;
    preAssetLib: AssetLoader;
    saveDataHandler: SaveDataHandler;
    countryFlags: CountryFlags;
    userInput: UserInput;
    background: Background;
    panel: Panel;
    tableTop: TableTop;
    userBat: UserBat;
    enemyBat: EnemyBat;
    ball: Ball;
    sound: InstanceType<typeof Howl>;
    music: InstanceType<typeof Howl>;
    constructor(canvasId?: string);
    extGameLoad(): void;
    private loadPreAssets;
    private loadAssets;
    private syncGlobals;
    initSplash(): void;
    initStartScreen(): void;
    initGameIntro(): void;
    /** Starts a match — replaces _initGame game.js:3473 */
    initGame(_restart?: boolean): void;
    private _initGame;
    private getDelta;
    private updateLoaderEvent;
    private updateStartScreenEvent;
    private updateGameIntroScreenEvent;
    private updateGameEvent;
    private updateScore;
    private initGameComplete;
    butEventHandler(id: string, _data?: unknown): void;
    private initChooseCountry;
    private initMapScreen;
    resizeCanvas(): void;
}
export {};
//# sourceMappingURL=game.d.ts.map