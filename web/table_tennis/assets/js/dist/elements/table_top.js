import { TABLE } from '../utils/constants.js';
/** Typed port of Elements.TableTop game.js:1760 */
export class TableTop {
    constructor(getCupId, isMobile, getDelta) {
        this.getCupId = getCupId;
        this.isMobile = isMobile;
        this.getDelta = getDelta;
        this.offsetX = 0;
        this.offsetY = 0;
        this.netY = 0;
        this.netHeight = 0;
        this.sideMultiplier = TABLE.sideMultiplier;
        this.bounceMarkScale = 0;
        this.offsetTween = null;
        this.segs = isMobile ? TABLE.segsMobile : TABLE.segsDesktop;
        // assetLib not yet typed globally – use window
        const al = window.assetLib;
        this.oGameElementsImgData = al.getData('gameElements');
        this.oShadowImgData = al.getData('shadow');
        this.id = (getCupId() * 6 + 0) % 4; // real gameId injected later; mismatch harmless for bg
    }
    bounce() {
        this.bounceMarkScale = 1;
        const gs = window.TweenLite;
        gs.to(this, 0.3, { bounceMarkScale: 0, ease: 'Quad.easeIn' });
    }
    tweenToPos(x, y, speed, hitBy, spin) {
        this.offsetTween?.kill();
        let tempX = 0, tempY = 0;
        if (x > 0.3 || x < -0.3)
            tempX = -x / 1.75 - spin / 2;
        let tempTime = 0.5;
        if (hitBy === 'enemy') {
            tempTime = 0.5;
            tempY = (1 - (y - 0.5) * 2) * (0.3 - (speed - 0.3)) / 0.3;
        }
        const gs = window.TweenLite;
        this.offsetTween = gs.to(this, tempTime, { offsetX: tempX, offsetY: tempY, ease: 'Quad.easeOut' });
    }
    render(cvs, context) {
        const oids = window.oImageIds;
        const bHeight0 = this.oGameElementsImgData.oData.oAtlasData[oids.table0].height;
        this.netY = cvs.height / 4 - bHeight0 + ((this.oGameElementsImgData.oData.oAtlasData[oids.table0].height / this.segs) * (0.282 * this.segs)) * (1 + this.offsetY / 3) + this.offsetY * 50;
        this.netHeight = this.oGameElementsImgData.oData.oAtlasData[oids.net].height * (1 + this.offsetY / 3);
        // tableClip
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.tableClip];
            context.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, cvs.width / 2 - (f.width / 2) * (1 + this.offsetY / 3) + ((this.offsetX * (0.282 * this.segs)) * 3) * (1 + this.offsetY / 3) + this.offsetX * this.sideMultiplier, this.netY + this.netHeight - 3 * (1 + this.offsetY / 3), f.width * (1 + this.offsetY / 3), f.height * (1 + this.offsetY / 3));
        }
        // shadow / legs
        {
            const f = this.oShadowImgData.oData.oAtlasData?.['none'] ?? { x: 0, y: 0, width: this.oShadowImgData.img.width ?? 256, height: this.oShadowImgData.img.height ?? 32 };
            // fallback when no atlas
        }
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.tableLegs];
            context.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, cvs.width / 2 - (f.width / 2) * (1 + this.offsetY / 3) + ((this.offsetX * 100) * 2.3) * (1 + this.offsetY / 3) + this.offsetX * this.sideMultiplier, cvs.height / 4 + (this.oGameElementsImgData.oData.oAtlasData[oids.table0].height) * (1 + this.offsetY / 3.5) + this.offsetY * 50 + 25, f.width * (1 + this.offsetY / 3), f.height * (1 + this.offsetY / 3));
        }
        // table surface segmented (parallax)
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids['table' + this.id]];
            for (let i = 0; i < this.segs; i++) {
                context.drawImage(this.oGameElementsImgData.img, f.x, f.y + (f.height / this.segs) * i, f.width, (f.height / this.segs), cvs.width / 2 - (f.width / 2) * (1 + this.offsetY / 3) + ((this.offsetX * (i * (100 / this.segs))) * 3) * (1 + this.offsetY / 3) + this.offsetX * this.sideMultiplier, cvs.height / 4 + ((f.height / this.segs) * i) * (1 + this.offsetY / 2) + this.offsetY * 50, f.width * (1 + this.offsetY / 3), (f.height / this.segs) * (1 + this.offsetY / 2));
            }
        }
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.tableEdge];
            context.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, cvs.width / 2 - (f.width / 2) * (1 + this.offsetY / 3) + ((this.offsetX * 100) * 3) * (1 + this.offsetY / 3) + this.offsetX * this.sideMultiplier, cvs.height / 4 + (this.oGameElementsImgData.oData.oAtlasData[oids.table0].height) * (1 + this.offsetY / 2) + this.offsetY * 50, f.width * (1 + this.offsetY / 3), f.height * (1 + this.offsetY / 3));
        }
        if (this.bounceMarkScale > 0) {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.bounceMark];
            const ball = window.ball;
            const tempY = (cvs.height / 4) + this.offsetY * 50 + ((ball.bounceY * ball.bounceY) * TABLE.heightFactor) * (1 + this.offsetY / 2);
            const tempX = cvs.width / 2 + ((tempY - (cvs.height / 4)) * (this.offsetX + ball.bounceX * 0.6)) * 1.28 * (1 + this.offsetY / 2) + (ball.bounceX * TABLE.widthFactor) / 2 + this.offsetX * this.sideMultiplier;
            const tempScale = 0.27 + (tempY - (cvs.height / 4)) / 600;
            context.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, tempX - (f.width / 2) * (tempScale * this.bounceMarkScale), tempY - (f.height / 2) * (tempScale * this.bounceMarkScale), f.width * (tempScale * this.bounceMarkScale), f.height * (tempScale * this.bounceMarkScale));
        }
    }
    renderNet(cvs, context) {
        const oids = window.oImageIds;
        const f = this.oGameElementsImgData.oData.oAtlasData[oids.net];
        context.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, cvs.width / 2 - (f.width / 2) * (1 + this.offsetY / 3) + ((this.offsetX * (0.282 * this.segs)) * 3) * (1 + this.offsetY / 3) + this.offsetX * this.sideMultiplier, this.netY, f.width * (1 + this.offsetY / 3), this.netHeight);
    }
}
//# sourceMappingURL=table_top.js.map