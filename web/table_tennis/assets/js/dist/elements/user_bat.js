import { CANVAS } from '../utils/constants.js';
/** Typed port of Elements.UserBat game.js:1309 */
export class UserBat {
    constructor(getCanvas, getTableTop) {
        this.getCanvas = getCanvas;
        this.getTableTop = getTableTop;
        this.x = 0;
        this.y = 0;
        this.rotation = 0;
        this.scale = 1;
        this.prevX = 0;
        this.prevY = 0;
        this.maxY = 0;
        this.hitX = 0;
        this.hitY = 0;
        const al = window.assetLib;
        this.oGameElementsImgData = al.getData('gameElements');
        const c = getCanvas();
        this.targX = c.width / 2;
        this.targY = c.height - 150;
    }
    update(delta) {
        const c = this.getCanvas();
        const tt = this.getTableTop();
        const oids = window.oImageIds;
        const segH = this.oGameElementsImgData.oData.oAtlasData[oids.table0].height;
        this.maxY = c.height / 4 + ((segH / tt.segs) * (0.28 * tt.segs)) * (1 + tt.offsetY / 3) + tt.offsetY * 50;
        this.prevX = this.x;
        this.prevY = this.y;
        this.x = this.targX;
        this.y = Math.max(this.targY, this.maxY);
        this.rotation = Math.max(Math.min((this.x - c.width / 2) / 200, 90 * CANVAS.radian), -90 * CANVAS.radian);
        this.scale = 0.47 + (this.y - this.maxY) / 500;
        void delta;
    }
    /** Derives serve/rally target from swipe velocity. Mirrors game.js:1330 */
    getHitData(tablePosX, _tablePosY) {
        tablePosX = Math.min(Math.max(tablePosX, -1), 1);
        const delta = window.delta || 0.016;
        const servingState = window.ball?.servingState ?? 2;
        let tempX = Math.max(Math.min((this.x - this.prevX) / delta, 3500), -3500) / 3500;
        const tempY = Math.max(Math.min((this.prevY - this.y) / delta, 4500) / 4500, 0);
        let tempSpin = 0;
        if (tempY < 0.5) {
            if (tempX > 0.5)
                tempSpin = -((tempX - 0.5) * 2) * (1 - (tempY * 2));
            else if (tempX < -0.5)
                tempSpin = -((tempX + 0.5) * 2) * (1 - (tempY * 2));
        }
        if (tablePosX < 0) {
            if (tempX > 0)
                tempX *= (1 - tablePosX / 1);
            else
                tempX *= 1.2;
        }
        else {
            if (tempX < 0)
                tempX *= (1 + tablePosX / 1);
            else
                tempX *= 1.2;
        }
        if (servingState === 0)
            tempX *= 0.5;
        this.hitX = tempX + tablePosX * 0.8;
        this.hitY = (1 - tempY) * 0.4;
        return { x: this.hitX, y: this.hitY, speed: 0.3 + (0.3 / 0.4) * (0.4 - this.hitY), spin: tempSpin };
    }
    render(ctx, canvas) {
        const oids = window.oImageIds;
        ctx.save();
        ctx.translate(this.x, this.y - 20 * this.scale);
        ctx.scale(this.scale, this.scale * Math.min(1 - ((this.y - canvas.height * 0.5) / (canvas.height * 0.5)) * 0.3, 1));
        ctx.rotate(this.rotation);
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.userBatCentre];
            ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, -f.width / 2, -f.height / 3, f.width, f.height);
        }
        ctx.rotate(-this.rotation);
        ctx.translate(0, Math.min(7 * Math.max(((this.y - canvas.height * 0.5) / (canvas.height * 0.5)), 0), 7));
        ctx.rotate(this.rotation);
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.userBatEdge];
            ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, -f.width / 2, -f.height / 3 - 23, f.width, f.height);
        }
        ctx.restore();
    }
}
//# sourceMappingURL=user_bat.js.map