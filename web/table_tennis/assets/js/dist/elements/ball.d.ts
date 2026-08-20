import type { HitData, BallTrailPoint } from '../types/index.js';
/** Typed port of Elements.Ball game.js:1508 — 250+ lines of physics.
 *  Table coords normalised X∈[-1,1] Y∈[0,1]; height is vertical arc.
 */
export declare class Ball {
    private getCanvas;
    private getCtx;
    private getTableTop;
    private getUserBat;
    private getEnemyBat;
    private onScore;
    x: number;
    y: number;
    height: number;
    heightInc: number;
    tablePosY: number;
    tablePosX: number;
    scale: number;
    lastHit: 'user' | 'enemy';
    speed: number;
    offTable: boolean;
    offSide: boolean;
    pause: boolean;
    spin: number;
    spinInc: number;
    servingState: number;
    canHit: boolean;
    serveFlip: boolean;
    bounceX: number;
    bounceY: number;
    bounceNum: number;
    ballShortState: number;
    aTrailPoints: BallTrailPoint[];
    tableVX: number;
    tableVY: number;
    targBounceX: number;
    targBounceY: number;
    servePosInc: number;
    offTableVX: number;
    offTableVY: number;
    private servePrepTween;
    private offTableTween;
    private oGameElementsImgData;
    constructor(getCanvas: () => HTMLCanvasElement, getCtx: () => CanvasRenderingContext2D, getTableTop: () => {
        offsetX: number;
        offsetY: number;
        sideMultiplier: number;
        tweenToPos(x: number, y: number, s: number, h: 'user' | 'enemy', spin: number): void;
        bounce(): void;
    }, getUserBat: () => {
        x: number;
        y: number;
        scale: number;
        getHitData(x: number, y: number): HitData;
    }, getEnemyBat: () => {
        x: number;
        y: number;
        scale: number;
        getHitData(x: number, y: number): HitData;
        resetToCentre(): void;
        setBouncePos(x: number, y: number, spin: number): void;
        flail(): void;
    }, onScore: (who: 'user' | 'enemy') => void);
    resetServe(toServe: 'user' | 'enemy'): void;
    enemyServe(): void;
    setBouncePoint(t: HitData): void;
    update(): void;
    private handleServeFlip;
    render(ctx: CanvasRenderingContext2D): void;
    private renderTrail;
}
//# sourceMappingURL=ball.d.ts.map