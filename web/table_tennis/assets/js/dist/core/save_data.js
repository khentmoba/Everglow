import { SAVE_KEY, FIRST_RUN_USER_ID } from '../utils/constants.js';
/** Typed port of Utils.SaveDataHandler game.js:2560 */
export class SaveDataHandler {
    constructor(saveDataId = SAVE_KEY) {
        this.saveDataId = saveDataId;
        this.aLevelStore = [];
        this.clearData();
        this.setInitialData();
    }
    clearData() {
        this.aLevelStore = [1];
        for (let i = 0; i < 9; i++)
            this.aLevelStore.push(0);
        this.aLevelStore.push(FIRST_RUN_USER_ID);
        this.aLevelStore.push(0);
    }
    resetData() { this.clearData(); this.saveData(); }
    setInitialData() {
        try {
            const raw = window.famobi?.localStorage?.getItem(this.saveDataId)
                ?? window.localStorage.getItem(this.saveDataId);
            if (raw != null && raw !== '') {
                this.aLevelStore = raw.split(',').map(s => parseInt(s, 10));
                return;
            }
        }
        catch { }
        this.saveData();
    }
    getUserId() { return this.aLevelStore[this.aLevelStore.length - 2]; }
    getControlState() { return this.aLevelStore[this.aLevelStore.length - 1]; }
    setUserId(id) { this.aLevelStore[this.aLevelStore.length - 2] = id; }
    setControlState(id) { return this.aLevelStore[this.aLevelStore.length - 1] = id; }
    getCurCupId() {
        let n = 0;
        for (let i = 0; i < 10; i++)
            if (this.aLevelStore[i] === 7)
                n++;
        return n;
    }
    getCurGameId() {
        let n = 0;
        for (let i = 0; i < 10; i++)
            if (this.aLevelStore[i] !== 0)
                n = this.aLevelStore[i] - 1;
        return n;
    }
    setGameData(d) {
        for (let i = 0; i < 10; i++) {
            if (i < d.cupId)
                this.aLevelStore[i] = 7;
            else if (i === d.cupId)
                this.aLevelStore[i] = d.gameId + 1;
            else
                this.aLevelStore[i] = 0;
        }
    }
    saveData() {
        const str = this.aLevelStore.join(',');
        try {
            const ls = (window.famobi?.localStorage ?? window.localStorage);
            ls.setItem(this.saveDataId, str);
        }
        catch { }
    }
}
//# sourceMappingURL=save_data.js.map