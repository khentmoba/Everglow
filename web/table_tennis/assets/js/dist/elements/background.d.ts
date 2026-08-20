/** Typed port of Elements.Background game.js:752 */
export declare class Background {
    private getCupId;
    private oImgData;
    private oGameElementsImgData;
    private wallId;
    constructor(getCupId: () => number);
    renderGame(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement, tableTop: {
        offsetY: number;
    }): void;
    renderMenu(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement): void;
}
//# sourceMappingURL=background.d.ts.map