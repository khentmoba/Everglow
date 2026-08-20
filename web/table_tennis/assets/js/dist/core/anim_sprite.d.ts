import type { AssetData } from '../types/index.js';
/** Typed port of Utils.AnimSprite game.js:195 + Utils.BasicSprite game.js:308 */
export declare class AnimSprite {
    x: number;
    y: number;
    rotation: number;
    radius: number;
    removeMe: boolean;
    frameInc: number;
    animType: 'loop' | 'once';
    offsetX: number;
    offsetY: number;
    scaleX: number;
    scaleY: number;
    alpha: number;
    oImgData: AssetData;
    private oAnims;
    fps: number;
    radius2: number;
    animId: string | null;
    centreX: number;
    centreY: number;
    fixedFrame?: number;
    curFrame?: number;
    maxIdx: number;
    animEndedFunc: (() => void) | null;
    constructor(oImgData: AssetData, fps: number, radius: number, animId: string | null);
    updateAnimation(delta: number): void;
    changeImgData(newImgData: AssetData, animId: string | null): void;
    resetAnim(): void;
    setFrame(n: number): void;
    setAnimType(type: 'loop' | 'once', animId: string | null, reset?: boolean): void;
    render(ctx: CanvasRenderingContext2D): void;
    renderSimple(ctx: CanvasRenderingContext2D): void;
}
export declare class BasicSprite {
    x: number;
    y: number;
    rotation: number;
    radius: number;
    removeMe: boolean;
    offsetX: number;
    offsetY: number;
    scaleX: number;
    scaleY: number;
    oImgData: AssetData;
    frameNum: number;
    constructor(oImgData: AssetData, radius: number, frame?: number);
    setFrame(n: number): void;
    render(ctx: CanvasRenderingContext2D): void;
}
//# sourceMappingURL=anim_sprite.d.ts.map