/** Typed port of Utils.FpsMeter game.js:715 */
export declare class FpsMeter {
    private canvasHeight;
    updateFreq: number;
    updateInc: number;
    frameAverage: number;
    display: number;
    log: string;
    private delta;
    constructor(canvasHeight: number);
    update(delta: number): void;
    render(ctx: CanvasRenderingContext2D): void;
}
//# sourceMappingURL=fps_meter.d.ts.map