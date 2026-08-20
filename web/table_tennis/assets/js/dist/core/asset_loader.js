/**
 * Typed port of Utils.AssetLoader game.js:28
 * Loads images + JSON (via XHR/fetch) and fires onReady when totalAssets == assetsLoaded.
 * Includes Everglow placeholder fallback from assets/index.html:43.
 */
export class AssetLoader {
    constructor(_lang, aFileData, ctx, canvasWidth, canvasHeight, showBar = true) {
        this.aFileData = aFileData;
        this.ctx = ctx;
        this.canvasWidth = canvasWidth;
        this.canvasHeight = canvasHeight;
        this.oAssetData = {};
        this.textData = {};
        this.assetsLoaded = 0;
        this.spinnerRot = 0;
        this.loadedCallback = null;
        this.totalAssets = aFileData.length;
        this.showBar = showBar;
        for (const f of aFileData) {
            if (f.file.includes('.json'))
                this.loadJSON(f);
            else
                this.loadImage(f);
        }
        // preAssetLib path: game.js:47 uses preAssetLib.getData("loader")
        // Defer — caller must have pre-loaded those; no-op if missing.
    }
    render() {
        const { ctx, canvas } = this;
        // fallback when constructed with real canvas ctx
        const c = (this.ctx.canvas ?? null);
        const w = c?.width ?? this.canvasWidth;
        const h = c?.height ?? this.canvasHeight;
        this.ctx.fillStyle = 'rgba(0,0,0,1)';
        this.ctx.fillRect(0, 0, w, h);
        this.ctx.fillStyle = '#FFFFFF';
        this.ctx.fillRect(w / 2 - 150, h / 2 + 20, (300 / this.totalAssets) * this.assetsLoaded, 30);
        if (this.oLoaderImgData) {
            this.ctx.drawImage(this.oLoaderImgData.img, w / 2 - this.oLoaderImgData.img.width / 2, h / 2 - this.oLoaderImgData.img.height / 2);
        }
        if (this.oLoadSpinnerImgData) {
            this.spinnerRot += 0.016 * 3; // ~delta*3
            this.ctx.save();
            this.ctx.translate(w / 2 - 33, h / 2 - 20);
            this.ctx.rotate(this.spinnerRot);
            this.ctx.drawImage(this.oLoadSpinnerImgData.img, -this.oLoadSpinnerImgData.img.width / 2, -this.oLoadSpinnerImgData.img.height / 2);
            this.ctx.restore();
        }
        this.displayNumbers();
    }
    displayNumbers() {
        const c = this.ctx.canvas;
        const w = c?.width ?? this.canvasWidth;
        const h = c?.height ?? this.canvasHeight;
        this.ctx.textAlign = 'left';
        this.ctx.font = 'bold 40px arial';
        this.ctx.fillStyle = '#ffffff';
        this.ctx.fillText(`${Math.round((this.assetsLoaded / this.totalAssets) * 100)}%`, w / 2, h / 2 - 6);
    }
    loadExtraAssets(callback, aFileData) {
        this.showBar = false;
        this.totalAssets = aFileData.length;
        this.assetsLoaded = 0;
        this.loadedCallback = callback;
        for (const f of aFileData) {
            if (f.file.includes('.json'))
                this.loadJSON(f);
            else
                this.loadImage(f);
        }
    }
    loadJSON(oData) {
        const xobj = new XMLHttpRequest();
        xobj.open('GET', oData.file, true);
        xobj.onreadystatechange = () => {
            if (xobj.readyState === 4 && xobj.status === 200) {
                try {
                    this.textData[oData.id] = JSON.parse(xobj.responseText);
                }
                catch { /* ignore */ }
                ++this.assetsLoaded;
                this.checkLoadComplete();
            }
        };
        xobj.onerror = () => { ++this.assetsLoaded; this.checkLoadComplete(); };
        xobj.send(null);
    }
    loadImage(oData) {
        const img = new Image();
        img.onload = () => {
            const entry = this.oAssetData[oData.id] ?? {
                img, oData: { spriteWidth: img.width, spriteHeight: img.height, oAtlasData: { none: { x: 0, y: 0, width: img.width, height: img.height } } }
            };
            entry.img = img;
            const sz = this.getSpriteSize(oData.file);
            if (sz[0] !== 0) {
                entry.oData.spriteWidth = sz[0];
                entry.oData.spriteHeight = sz[1];
            }
            else {
                entry.oData.spriteWidth = img.width;
                entry.oData.spriteHeight = img.height;
            }
            if (oData.oAnims)
                entry.oData.oAnims = oData.oAnims;
            if (oData.oAtlasData)
                entry.oData.oAtlasData = oData.oAtlasData;
            else if (!entry.oData.oAtlasData?.none)
                entry.oData.oAtlasData = { none: { x: 0, y: 0, width: entry.oData.spriteWidth, height: entry.oData.spriteHeight } };
            this.oAssetData[oData.id] = entry;
            ++this.assetsLoaded;
            this.checkLoadComplete();
        };
        img.onerror = () => {
            // placeholder 64×64 keeps game bootable when asset host is stripped
            const ph = document.createElement('canvas');
            ph.width = 64;
            ph.height = 64;
            const entry = this.oAssetData[oData.id] ?? {
                img: ph, oData: { spriteWidth: 64, spriteHeight: 64, oAtlasData: {} }
            };
            entry.img = ph;
            entry.loaded = true;
            entry.oData = entry.oData ?? { spriteWidth: 64, spriteHeight: 64, oAtlasData: {} };
            entry.oData.oAtlasData = oData.oAtlasData ?? { none: { x: 0, y: 0, width: 64, height: 64 } };
            if (!entry.oData.oAtlasData[oData.id])
                entry.oData.oAtlasData[oData.id] = { x: 0, y: 0, width: 64, height: 64 };
            this.oAssetData[oData.id] = entry;
            ++this.assetsLoaded;
            this.checkLoadComplete();
        };
        img.src = oData.file;
    }
    getSpriteSize(file) {
        let sizeY = '', sizeX = '', stage = 0, inc = file.lastIndexOf('.'), canCont = true;
        const isNum = (n) => !isNaN(parseFloat(n)) && isFinite(Number(n));
        while (canCont) {
            inc--;
            if (inc < 0)
                return [0, 0];
            const ch = file.charAt(inc);
            if (stage === 0 && isNum(ch))
                sizeY = ch + sizeY;
            else if (stage === 0 && sizeY.length > 0 && ch === 'x') {
                inc--;
                stage = 1;
                sizeX = file.charAt(inc) + sizeX;
            }
            else if (stage === 1 && isNum(ch))
                sizeX = ch + sizeX;
            else if (stage === 1 && sizeX.length > 0 && ch === '_')
                return [parseInt(sizeX, 10), parseInt(sizeY, 10)];
            else
                return [0, 0];
        }
        return [0, 0];
    }
    checkLoadComplete() {
        if (this.totalAssets > 10) {
            try {
                window.famobi.setPreloadProgress(Math.round((this.assetsLoaded / this.totalAssets) * 100));
            }
            catch { }
        }
        if (this.assetsLoaded === this.totalAssets)
            this.loadedCallback?.();
    }
    onReady(fn) { this.loadedCallback = fn; }
    getImg(id) { return this.oAssetData[id].img; }
    getData(id) { return this.oAssetData[id]; }
}
//# sourceMappingURL=asset_loader.js.map