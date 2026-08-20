import type { HitData } from '../types/index.js';
/** Typed port of Elements.EnemyBat game.js:1355 */
export declare class EnemyBat {
    private getCanvas;
    private getTableTop;
    private getOData;
    x: number;
    y: number;
    rotation: number;
    scale: number;
    targX: number;
    targY: number;
    skillLevel: number;
    id: number;
    trackBall: boolean;
    slideInc: number;
    flailInc: number;
    private moveTween;
    private oGameElementsImgData;
    private aEases;
    constructor(getCanvas: () => HTMLCanvasElement, getTableTop: () => {
        offsetX: number;
        offsetY: number;
        sideMultiplier: number;
    }, getOData: () => {
        cupId: number;
        gameId: number;
    });
    resetToCentre(): void;
    flail(): void;
    /** AI prediction for incoming ball. game.js:1415 */
    setBouncePos(targBounceX: number, targBounceY: number, spin: number): void;
    update(): void;
    getHitData(_tablePosX: number, _tablePosY: number): HitData;
    render(ctx: CanvasRenderingContext2D): void;
}
//# sourceMappingURL=enemy_bat.d.ts.map