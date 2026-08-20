/** Typed port of Elements.Background game.js:752 */
export class Background {
    constructor(getCupId) {
        this.getCupId = getCupId;
        const al = window.assetLib;
        this.oImgData = al.getData('background');
        this.oGameElementsImgData = al.getData('gameElements');
        this.wallId = getCupId() % 5;
    }
    renderGame(ctx, canvas, tableTop) {
        const oids = window.oImageIds;
        ctx.fillStyle = 'rgba(0,0,0,1)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.tableBgBottom];
            const tempTop = canvas.height / 4 - 220 + 193 + tableTop.offsetY * 25;
            ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, 0, tempTop, canvas.width, (canvas.height - tempTop) * (1 + tableTop.offsetY / 3) * 1.1);
        }
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids['tableBg' + this.wallId]];
            ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, 0, canvas.height / 4 - 220 + tableTop.offsetY * 25, canvas.width, f.height);
        }
    }
    renderMenu(ctx, canvas) {
        ctx.drawImage(this.oImgData.img, 0, 0, this.oImgData.img.width ?? canvas.width, this.oImgData.img.height ?? canvas.height, 0, 0, canvas.width, canvas.height);
    }
}
//# sourceMappingURL=background.js.map