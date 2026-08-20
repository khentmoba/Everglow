import type { AssetData, FileSpec } from '../types/index.js';
/**
 * Typed port of Utils.AssetLoader game.js:28
 * Loads images + JSON (via XHR/fetch) and fires onReady when totalAssets == assetsLoaded.
 * Includes Everglow placeholder fallback from assets/index.html:43.
 */
export declare class AssetLoader {
    private aFileData;
    private ctx;
    private canvasWidth;
    private canvasHeight;
    oAssetData: Record<string, AssetData>;
    textData: Record<string, unknown>;
    assetsLoaded: number;
    totalAssets: number;
    showBar: boolean;
    spinnerRot: number;
    private loadedCallback;
    private oLoaderImgData?;
    private oLoadSpinnerImgData?;
    constructor(_lang: string, aFileData: FileSpec[], ctx: CanvasRenderingContext2D, canvasWidth: number, canvasHeight: number, showBar?: boolean);
    render(): void;
    displayNumbers(): void;
    loadExtraAssets(callback: () => void, aFileData: FileSpec[]): void;
    loadJSON(oData: FileSpec): void;
    loadImage(oData: FileSpec): void;
    private getSpriteSize;
    private checkLoadComplete;
    onReady(fn: () => void): void;
    getImg(id: string): HTMLImageElement | HTMLCanvasElement;
    getData(id: string): AssetData;
}
//# sourceMappingURL=asset_loader.d.ts.map