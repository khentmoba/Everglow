import type { AssetData } from '../types/index.js';
/** Typed port of Elements.TableTop game.js:1760 */
export declare class TableTop {
    private getCupId;
    private isMobile;
    private getDelta;
    segs: number;
    offsetX: number;
    offsetY: number;
    netY: number;
    netHeight: number;
    id: number;
    sideMultiplier: 100;
    bounceMarkScale: number;
    oGameElementsImgData: AssetData;
    oShadowImgData: AssetData;
    private offsetTween;
    constructor(getCupId: () => number, isMobile: boolean, getDelta: () => number);
    bounce(): void;
    tweenToPos(x: number, y: number, speed: number, hitBy: 'user' | 'enemy', spin: number): void;
    render(cvs: HTMLCanvasElement, context: CanvasRenderingContext2D): void;
    renderNet(cvs: HTMLCanvasElement, context: CanvasRenderingContext2D): void;
}
//# sourceMappingURL=table_top.d.ts.map