import type { AssetData, FileSpec } from '../types/index.js';

/**
 * Typed port of Utils.AssetLoader game.js:28
 * Loads images + JSON (via XHR/fetch) and fires onReady when totalAssets == assetsLoaded.
 * Includes Everglow placeholder fallback from assets/index.html:43.
 */
export class AssetLoader {
  oAssetData: Record<string, AssetData> = {};
  textData: Record<string, unknown> = {};
  assetsLoaded = 0;
  totalAssets: number;
  showBar: boolean;
  spinnerRot = 0;
  private loadedCallback: (()=>void) | null = null;
  private oLoaderImgData?: AssetData;
  private oLoadSpinnerImgData?: AssetData;

  constructor(
    _lang: string,
    private aFileData: FileSpec[],
    private ctx: CanvasRenderingContext2D,
    private canvasWidth: number,
    private canvasHeight: number,
    showBar = true,
  ) {
    this.totalAssets = aFileData.length;
    this.showBar = showBar;
    for (const f of aFileData) {
      if (f.file.includes('.json')) this.loadJSON(f);
      else this.loadImage(f);
    }
    // preAssetLib path: game.js:47 uses preAssetLib.getData("loader")
    // Defer — caller must have pre-loaded those; no-op if missing.
  }

  render(): void {
    const { ctx, canvas } = this as unknown as { ctx: CanvasRenderingContext2D; canvas: HTMLCanvasElement };
    // fallback when constructed with real canvas ctx
    const c = (this.ctx.canvas ?? null) as HTMLCanvasElement | null;
    const w = c?.width ?? this.canvasWidth;
    const h = c?.height ?? this.canvasHeight;
    this.ctx.fillStyle = 'rgba(0,0,0,1)';
    this.ctx.fillRect(0, 0, w, h);
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.fillRect(w/2 - 150, h/2 + 20, (300/this.totalAssets) * this.assetsLoaded, 30);
    if (this.oLoaderImgData) {
      this.ctx.drawImage(this.oLoaderImgData.img as HTMLImageElement,
        w/2 - (this.oLoaderImgData.img as HTMLImageElement).width/2,
        h/2 - (this.oLoaderImgData.img as HTMLImageElement).height/2);
    }
    if (this.oLoadSpinnerImgData) {
      this.spinnerRot += 0.016 * 3; // ~delta*3
      this.ctx.save();
      this.ctx.translate(w/2 - 33, h/2 - 20);
      this.ctx.rotate(this.spinnerRot);
      this.ctx.drawImage(this.oLoadSpinnerImgData.img as HTMLImageElement,
        -(this.oLoadSpinnerImgData.img as HTMLImageElement).width/2,
        -(this.oLoadSpinnerImgData.img as HTMLImageElement).height/2);
      this.ctx.restore();
    }
    this.displayNumbers();
  }

  displayNumbers(): void {
    const c = (this.ctx.canvas as HTMLCanvasElement | null);
    const w = c?.width ?? this.canvasWidth;
    const h = c?.height ?? this.canvasHeight;
    this.ctx.textAlign = 'left';
    this.ctx.font = 'bold 40px arial';
    this.ctx.fillStyle = '#ffffff';
    this.ctx.fillText(`${Math.round((this.assetsLoaded/this.totalAssets)*100)}%`, w/2, h/2 - 6);
  }

  loadExtraAssets(callback: ()=>void, aFileData: FileSpec[]): void {
    this.showBar = false;
    this.totalAssets = aFileData.length;
    this.assetsLoaded = 0;
    this.loadedCallback = callback;
    for (const f of aFileData) {
      if (f.file.includes('.json')) this.loadJSON(f); else this.loadImage(f);
    }
  }

  loadJSON(oData: FileSpec): void {
    const xobj = new XMLHttpRequest();
    xobj.open('GET', oData.file, true);
    xobj.onreadystatechange = () => {
      if (xobj.readyState === 4 && xobj.status === 200) {
        try { this.textData[oData.id] = JSON.parse(xobj.responseText); } catch { /* ignore */ }
        ++this.assetsLoaded;
        this.checkLoadComplete();
      }
    };
    xobj.onerror = () => { ++this.assetsLoaded; this.checkLoadComplete(); };
    xobj.send(null);
  }

  loadImage(oData: FileSpec): void {
    const img = new Image();
    img.onload = () => {
      const entry: AssetData = this.oAssetData[oData.id] ?? {
        img, oData: { spriteWidth: img.width, spriteHeight: img.height, oAtlasData: { none:{x:0,y:0,width:img.width,height:img.height} } }
      };
      entry.img = img;
      const sz = this.getSpriteSize(oData.file);
      if (sz[0] !== 0) { entry.oData.spriteWidth = sz[0]; entry.oData.spriteHeight = sz[1]; }
      else { entry.oData.spriteWidth = img.width; entry.oData.spriteHeight = img.height; }
      if ((oData as FileSpec & {oAnims?: unknown}).oAnims) entry.oData.oAnims = (oData as unknown as {oAnims: AssetData['oData']['oAnims']}).oAnims;
      if (oData.oAtlasData) entry.oData.oAtlasData = oData.oAtlasData;
      else if (!entry.oData.oAtlasData?.none) entry.oData.oAtlasData = { none:{x:0,y:0,width:entry.oData.spriteWidth,height:entry.oData.spriteHeight} };
      this.oAssetData[oData.id] = entry;
      ++this.assetsLoaded;
      this.checkLoadComplete();
    };
    img.onerror = () => {
      // placeholder 64×64 keeps game bootable when asset host is stripped
      const ph = document.createElement('canvas'); ph.width = 64; ph.height = 64;
      const entry: AssetData = this.oAssetData[oData.id] ?? {
        img: ph, oData: { spriteWidth:64, spriteHeight:64, oAtlasData:{} }
      };
      entry.img = ph; entry.loaded = true;
      entry.oData = entry.oData ?? { spriteWidth:64, spriteHeight:64, oAtlasData:{} };
      entry.oData.oAtlasData = oData.oAtlasData ?? { none:{x:0,y:0,width:64,height:64} };
      if (!entry.oData.oAtlasData[oData.id]) entry.oData.oAtlasData[oData.id] = {x:0,y:0,width:64,height:64};
      this.oAssetData[oData.id] = entry;
      ++this.assetsLoaded;
      this.checkLoadComplete();
    };
    img.src = oData.file;
  }

  private getSpriteSize(file: string): [number, number] {
    let sizeY = '', sizeX = '', stage:0|1 = 0, inc = file.lastIndexOf('.'), canCont = true;
    const isNum = (n:string)=> !isNaN(parseFloat(n)) && isFinite(Number(n));
    while (canCont) {
      inc--;
      if (inc < 0) return [0,0];
      const ch = file.charAt(inc);
      if (stage===0 && isNum(ch)) sizeY = ch + sizeY;
      else if (stage===0 && sizeY.length>0 && ch==='x') { inc--; stage=1; sizeX = file.charAt(inc)+sizeX; }
      else if (stage===1 && isNum(ch)) sizeX = ch + sizeX;
      else if (stage===1 && sizeX.length>0 && ch==='_') return [parseInt(sizeX,10), parseInt(sizeY,10)];
      else return [0,0];
    }
    return [0,0];
  }

  private checkLoadComplete(): void {
    if (this.totalAssets > 10) {
      try { (window as unknown as {famobi:{setPreloadProgress(n:number):void}}).famobi.setPreloadProgress(Math.round((this.assetsLoaded/this.totalAssets)*100)); } catch {}
    }
    if (this.assetsLoaded === this.totalAssets) this.loadedCallback?.();
  }

  onReady(fn: ()=>void): void { this.loadedCallback = fn; }
  getImg(id: string): HTMLImageElement | HTMLCanvasElement { return this.oAssetData[id].img; }
  getData(id: string): AssetData { return this.oAssetData[id]; }
}
