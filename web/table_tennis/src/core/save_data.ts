import { SAVE_KEY, FIRST_RUN_USER_ID } from '../utils/constants.js';
import type { OGameData } from '../types/index.js';

/** Typed port of Utils.SaveDataHandler game.js:2560 */
export class SaveDataHandler {
  aLevelStore: number[] = [];

  constructor(private saveDataId: string = SAVE_KEY) {
    this.clearData();
    this.setInitialData();
  }

  clearData(): void {
    this.aLevelStore = [1];
    for (let i=0;i<9;i++) this.aLevelStore.push(0);
    this.aLevelStore.push(FIRST_RUN_USER_ID);
    this.aLevelStore.push(0);
  }
  resetData(): void { this.clearData(); this.saveData(); }

  setInitialData(): void {
    try {
      const raw = window.famobi?.localStorage?.getItem(this.saveDataId)
               ?? window.localStorage.getItem(this.saveDataId);
      if (raw != null && raw !== '') {
        this.aLevelStore = raw.split(',').map(s=> parseInt(s,10));
        return;
      }
    } catch {}
    this.saveData();
  }

  getUserId(): number { return this.aLevelStore[this.aLevelStore.length - 2]!; }
  getControlState(): number { return this.aLevelStore[this.aLevelStore.length - 1]!; }
  setUserId(id:number): void { this.aLevelStore[this.aLevelStore.length - 2] = id; }
  setControlState(id:number): number { return this.aLevelStore[this.aLevelStore.length - 1] = id; }

  getCurCupId(): number {
    let n=0;
    for (let i=0;i<10;i++) if (this.aLevelStore[i]===7) n++;
    return n;
  }
  getCurGameId(): number {
    let n=0;
    for (let i=0;i<10;i++) if (this.aLevelStore[i]!==0) n = this.aLevelStore[i]! - 1;
    return n;
  }
  setGameData(d: OGameData): void {
    for (let i=0;i<10;i++) {
      if (i < d.cupId) this.aLevelStore[i]=7;
      else if (i===d.cupId) this.aLevelStore[i]=d.gameId+1;
      else this.aLevelStore[i]=0;
    }
  }
  saveData(): void {
    const str = this.aLevelStore.join(',');
    try {
      const ls = (window.famobi?.localStorage ?? window.localStorage) as Storage;
      ls.setItem(this.saveDataId, str);
    } catch {}
  }
}
