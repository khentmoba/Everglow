import type { AssetData } from '../types/index.js';
/** Trimmed typed port of Elements.Panel game.js:789 — only structure, full render in original 400L+ */
export type PanelType = 'splash' | 'start' | 'credits' | 'chooseCountry' | 'map' | 'gameIntro' | 'game' | 'pause' | 'gameComplete' | 'load';
export interface PanelBut {
    oImgData: AssetData;
    aPos: [number, number];
    align: [number, number];
    id: string;
    scale?: number;
    noMove?: boolean;
}
export declare class Panel {
    panelType: PanelType;
    aButs: PanelBut[];
    posY: number;
    incY: number;
    flareRot: number;
    cupFlipInc: number;
    userCardScale: number;
    enemyCardScale: number;
    userBatX: number;
    userBatY: number;
    enemyBatX: number;
    enemyBatY: number;
    ballX: number;
    ballY: number;
    ballHeight: number;
    private oSplashLogoImgData;
    private oCountryFlagsImgData;
    private oUiElementsImgData;
    private oGameElementsImgData;
    constructor(panelType: PanelType, aButs: PanelBut[]);
    update(): void;
    startTween1(): void;
    startTut(): void;
    private movePlayerBat;
    cardTween(player: 'user' | 'enemy'): void;
    switchBut(id0: string, id1: string): void;
    addButs(_ctx: CanvasRenderingContext2D): void;
    render(_butsOnTop?: boolean): void;
}
//# sourceMappingURL=panel.d.ts.map