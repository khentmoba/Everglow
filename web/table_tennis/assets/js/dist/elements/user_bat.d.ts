import type { HitData } from '../types/index.js';
/** Typed port of Elements.UserBat game.js:1309 */
export declare class UserBat {
    private getCanvas;
    private getTableTop;
    x: number;
    y: number;
    rotation: number;
    scale: number;
    targX: number;
    targY: number;
    prevX: number;
    prevY: number;
    maxY: number;
    hitX: number;
    hitY: number;
    private oGameElementsImgData;
    constructor(getCanvas: () => HTMLCanvasElement, getTableTop: () => {
        offsetY: number;
        offsetX: number;
        sideMultiplier: number;
        segs: number;
    });
    update(delta: number): void;
    /** Derives serve/rally target from swipe velocity. Mirrors game.js:1330 */
    getHitData(tablePosX: number, _tablePosY: number): HitData;
    render(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement): void;
}
//# sourceMappingURL=user_bat.d.ts.map