import type { OGameData } from '../types/index.js';
/** Typed port of Utils.SaveDataHandler game.js:2560 */
export declare class SaveDataHandler {
    private saveDataId;
    aLevelStore: number[];
    constructor(saveDataId?: string);
    clearData(): void;
    resetData(): void;
    setInitialData(): void;
    getUserId(): number;
    getControlState(): number;
    setUserId(id: number): void;
    setControlState(id: number): number;
    getCurCupId(): number;
    getCurGameId(): number;
    setGameData(d: OGameData): void;
    saveData(): void;
}
//# sourceMappingURL=save_data.d.ts.map