/** Typed port of Utils.AnimSprite game.js:195 + Utils.BasicSprite game.js:308 */
export class AnimSprite {
    constructor(oImgData, fps, radius, animId) {
        this.x = 0;
        this.y = 0;
        this.rotation = 0;
        this.radius = 10;
        this.removeMe = false;
        this.frameInc = 0;
        this.animType = 'loop';
        this.offsetX = 0;
        this.offsetY = 0;
        this.scaleX = 1;
        this.scaleY = 1;
        this.alpha = 1;
        this.maxIdx = 0;
        this.animEndedFunc = null;
        this.oImgData = oImgData;
        this.oAnims = oImgData.oData.oAnims;
        this.fps = fps;
        this.radius2 = radius;
        this.animId = animId;
        this.centreX = Math.round(oImgData.oData.spriteWidth / 2);
        this.centreY = Math.round(oImgData.oData.spriteHeight / 2);
    }
    updateAnimation(delta) { this.frameInc += this.fps * delta; }
    changeImgData(newImgData, animId) {
        this.oImgData = newImgData;
        this.oAnims = newImgData.oData.oAnims;
        this.animId = animId;
        this.centreX = Math.round(newImgData.oData.spriteWidth / 2);
        this.centreY = Math.round(newImgData.oData.spriteHeight / 2);
        this.resetAnim();
    }
    resetAnim() { this.frameInc = 0; }
    setFrame(n) { this.fixedFrame = n; }
    setAnimType(type, animId, reset = true) {
        this.animId = animId;
        this.animType = type;
        if (reset)
            this.resetAnim();
        if (type === 'once' && animId && this.oAnims?.[animId])
            this.maxIdx = this.oAnims[animId].length - 1;
    }
    render(ctx) {
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.scale(this.scaleX, this.scaleY);
        ctx.globalAlpha = this.alpha;
        let imgX, imgY;
        if (this.animId != null && this.oAnims?.[this.animId]) {
            const frames = this.oAnims[this.animId];
            const max = frames.length;
            const idx = Math.floor(this.frameInc);
            this.curFrame = frames[idx % max];
            imgX = (this.curFrame * this.oImgData.oData.spriteWidth) % this.oImgData.img.width;
            imgY = Math.floor(this.curFrame / (this.oImgData.img.width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
            if (this.animType === 'once' && idx > this.maxIdx) {
                this.fixedFrame = frames[max - 1];
                this.animId = null;
                this.animEndedFunc?.();
                imgX = (this.fixedFrame * this.oImgData.oData.spriteWidth) % this.oImgData.img.width;
                imgY = Math.floor(this.fixedFrame / (this.oImgData.img.width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
            }
        }
        else {
            const ff = this.fixedFrame ?? 0;
            imgX = (ff * this.oImgData.oData.spriteWidth) % this.oImgData.img.width;
            imgY = Math.floor(ff / (this.oImgData.img.width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
        }
        ctx.drawImage(this.oImgData.img, imgX, imgY, this.oImgData.oData.spriteWidth, this.oImgData.oData.spriteHeight, -this.centreX + this.offsetX, -this.centreY + this.offsetY, this.oImgData.oData.spriteWidth, this.oImgData.oData.spriteHeight);
        ctx.restore();
    }
    renderSimple(ctx) {
        let imgX, imgY;
        if (this.animId != null && this.oAnims?.[this.animId]) {
            const frames = this.oAnims[this.animId];
            const max = frames.length;
            const idx = Math.floor(this.frameInc);
            this.curFrame = frames[idx % max];
            imgX = (this.curFrame * this.oImgData.oData.spriteWidth) % this.oImgData.img.width;
            imgY = Math.floor(this.curFrame / (this.oImgData.img.width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
            if (this.animType === 'once' && idx > this.maxIdx) {
                this.fixedFrame = frames[max - 1];
                this.animId = null;
                this.animEndedFunc?.();
                imgX = (this.fixedFrame * this.oImgData.oData.spriteWidth) % this.oImgData.img.width;
                imgY = Math.floor(this.fixedFrame / (this.oImgData.img.width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
            }
        }
        else {
            const ff = this.fixedFrame ?? 0;
            imgX = (ff * this.oImgData.oData.spriteWidth) % this.oImgData.img.width;
            imgY = Math.floor(ff / (this.oImgData.img.width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
        }
        ctx.drawImage(this.oImgData.img, imgX, imgY, this.oImgData.oData.spriteWidth, this.oImgData.oData.spriteHeight, this.x - (this.centreX - this.offsetX) * this.scaleX, this.y - (this.centreY - this.offsetY) * this.scaleY, this.oImgData.oData.spriteWidth * this.scaleX, this.oImgData.oData.spriteHeight * this.scaleY);
    }
}
export class BasicSprite {
    constructor(oImgData, radius, frame = 0) {
        this.x = 0;
        this.y = 0;
        this.rotation = 0;
        this.radius = 10;
        this.removeMe = false;
        this.offsetX = 0;
        this.offsetY = 0;
        this.scaleX = 1;
        this.scaleY = 1;
        this.oImgData = oImgData;
        this.radius = radius;
        this.frameNum = frame;
    }
    setFrame(n) { this.frameNum = n; }
    render(ctx) {
        ctx.save();
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        ctx.scale(this.scaleX, this.scaleY);
        const imgX = (this.frameNum * this.oImgData.oData.spriteWidth) % this.oImgData.img.width;
        const imgY = Math.floor(this.frameNum / (this.oImgData.img.width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
        ctx.drawImage(this.oImgData.img, imgX, imgY, this.oImgData.oData.spriteWidth, this.oImgData.oData.spriteHeight, -this.oImgData.oData.spriteWidth / 2 + this.offsetX, -this.oImgData.oData.spriteHeight / 2 + this.offsetY, this.oImgData.oData.spriteWidth, this.oImgData.oData.spriteHeight);
        ctx.restore();
    }
}
//# sourceMappingURL=anim_sprite.js.map