import type { AssetData, HitCallback, KeyCallback, HitAreaType } from '../types/index.js';
/** Typed port of Utils.UserInput game.js:343
 *  Handles touch/mouse + pointer-lock for desktop paddle aiming.
 */
export interface HitArea {
    id: string;
    callback: HitCallback;
    oData: Record<string, unknown> & {
        isDown?: boolean;
        isBeingDragged?: boolean;
        isDraggable?: boolean;
        multiTouch?: boolean;
        hasLeft?: boolean;
        x?: number;
        y?: number;
    };
    rect: boolean;
    area: [number, number, number, number];
    align: [number, number];
    aTouchIdentifiers: number[];
}
interface KeyEntry {
    id: string;
    callback: KeyCallback;
    oData: {
        isDown: boolean;
    };
    keyCode: number;
}
export declare class UserInput {
    private canvas;
    private isBugBrowser;
    prevHitTime: number;
    pauseIsOn: boolean;
    isDown: boolean;
    aHitAreas: HitArea[];
    aKeys: KeyEntry[];
    private keyDownEvt;
    private keyUpEvt;
    constructor(canvas: HTMLCanvasElement, isBugBrowser: boolean);
    private get canvasScale();
    hitDown(e: Event, posX: number, posY: number, id: number): void;
    hitUp(e: Event, posX: number, posY: number, id: number): void;
    hitCancel(e: Event, posX: number, posY: number, _id: number): void;
    userExitLock: (_e: Event) => void;
    lockPointer(elem?: Element): void;
    unlockPointer(): void;
    move(e: MouseEvent | TouchEvent, posX: number, posY: number, ident: number, isDown: boolean): void;
    keyDown(e: KeyboardEvent): void;
    keyUp(e: KeyboardEvent): void;
    checkKeyFocus(): void;
    addKey(id: string, cb: KeyCallback, data: Record<string, unknown> | null, keyCode: number): void;
    removeKey(id: string): void;
    addHitArea(id: string, cb: HitCallback, oData: Record<string, unknown> | null, type: HitAreaType, oAreaData: {
        oImgData?: AssetData;
        aPos?: [number, number];
        scale?: number;
        align?: [number, number];
        id?: string;
        aRect?: [number, number, number, number];
    }, isUnique?: boolean): void;
    removeHitArea(id: string): void;
    resetAll(): void;
}
export {};
//# sourceMappingURL=user_input.d.ts.map