import { TABLE } from '../utils/constants.js';
/** Typed port of Elements.EnemyBat game.js:1355 */
export class EnemyBat {
    constructor(getCanvas, getTableTop, getOData) {
        this.getCanvas = getCanvas;
        this.getTableTop = getTableTop;
        this.getOData = getOData;
        this.x = 0;
        this.y = 0;
        this.rotation = 0;
        this.scale = 1;
        this.targX = 0;
        this.targY = 0;
        this.trackBall = false;
        this.slideInc = 0;
        this.flailInc = 0;
        this.moveTween = null;
        this.aEases = ['Quad.easeInOut', 'Back.easeOut', 'Cubic.easeOut', 'Back.easeInOut'];
        const al = window.assetLib;
        this.oGameElementsImgData = al.getData('gameElements');
        const c = getCanvas();
        this.x = c.width / 2;
        const { cupId, gameId } = getOData();
        this.id = (cupId * 6 + gameId) % 7;
        if (cupId === 0)
            this.skillLevel = ((gameId + 1) * (2.5 / 6)) / 10;
        else
            this.skillLevel = (2.5 + (7.5 / 9) * (cupId - 1) + (gameId + 1) * ((7.5 / 9) / 6)) / 10;
    }
    resetToCentre() {
        this.trackBall = false;
        this.moveTween?.kill();
        const c = this.getCanvas();
        this.targX = this.x - c.width / 2;
        const gs = window.TweenLite;
        this.moveTween = gs.to(this, 1, {
            targX: 0, targY: 0, ease: 'Quad.easeInOut',
            onComplete: () => {
                const ball = window.ball;
                if (ball.lastHit === 'enemy')
                    ball.enemyServe();
            }
        });
    }
    flail() {
        this.flailInc = 0;
        const ball = window.ball;
        const targ = ball.x < this.x ? -1 : 1;
        const gs = window.TweenLite;
        gs.to(this, 0.5, {
            flailInc: targ, ease: 'Quad.easeInOut',
            onComplete: () => { gs.to(this, 0.5, { flailInc: 0, ease: 'Quad.easeInOut' }); }
        });
    }
    /** AI prediction for incoming ball. game.js:1415 */
    setBouncePos(targBounceX, targBounceY, spin) {
        this.moveTween?.kill();
        const ball = window.ball;
        const tt = this.getTableTop();
        const gs = window.TweenLite;
        if ((spin === 0 || Math.random() < 0.25) && ball.servingState !== 1) {
            this.trackBall = false;
            let badAim = 0;
            if (Math.random() > 0.75 + this.skillLevel * 0.20)
                badAim = Math.random() * 100 - 50;
            const tempY = (((targBounceY * targBounceY) * TABLE.heightFactor) * (1 + tt.offsetY / 2)) / 2;
            const tempX = ((tempY) * (tt.offsetX + targBounceX * 0.6)) * 1.28 * (1 + tt.offsetY / 2) + (targBounceX * TABLE.widthFactor) / 2 + spin * 100;
            this.moveTween = gs.to(this, (Math.random() * 0.35 + 0.3) * (1 + (1 - this.skillLevel) * 0.75), {
                delay: Math.random() * 0.2, targX: tempX + badAim, targY: tempY,
                ease: this.aEases[Math.floor(Math.random() * this.aEases.length)],
                onComplete: () => {
                    const b = window.ball;
                    if (b.lastHit === 'enemy') {
                        this.moveTween = gs.to(this, (Math.random() * 0.35 + 0.3) * (1 + (1 - this.skillLevel) * 0.5), {
                            delay: (Math.random() * 0.3) * (1 + (1 - this.skillLevel) * 0.5),
                            targX: Math.random() * 200 - 100, targY: 0, ease: 'Quad.easeInOut'
                        });
                    }
                }
            });
        }
        else {
            this.trackBall = true;
            this.slideInc = 0;
            this.moveTween = gs.to(this, (Math.random() * 0.35 + 0.3) * (1 + (1 - this.skillLevel) * 0.5), { targY: 0, ease: 'Quad.easeInOut' });
        }
    }
    update() {
        const c = this.getCanvas();
        const tt = this.getTableTop();
        const delta = window.delta || 0.016;
        const ball = window.ball;
        this.y = this.targY + c.height / 4 + tt.offsetY * 50 - 45;
        if (!this.trackBall) {
            this.x = this.targX + c.width / 2;
        }
        else {
            if (this.x > ball.x + 15)
                this.slideInc = Math.max(this.slideInc - 1000 * delta, -50 + (-50 * this.skillLevel));
            else if (this.x < ball.x - 15)
                this.slideInc = Math.min(this.slideInc + 1000 * delta, 50 + (50 * this.skillLevel));
            this.x += (this.slideInc * 4) * delta;
            if (ball.lastHit === 'enemy') {
                this.targX = this.x - c.width / 2;
                const gs = window.TweenLite;
                this.moveTween = gs.to(this, (Math.random() * 0.35 + 0.3) * (1 + (1 - this.skillLevel) * 0.5), {
                    delay: (Math.random() * 0.3) * (1 + (1 - this.skillLevel) * 0.5), targX: Math.random() * 200 - 100, targY: 0, ease: 'Quad.easeInOut'
                });
                this.trackBall = false;
            }
        }
        this.rotation = (this.x - c.width / 2) / 200;
        this.scale = 0.4 + (this.y - c.height / 4) / 300;
        this.x = Math.min(Math.max(this.x, c.width / 2 - 250), c.width / 2 + 250);
    }
    getHitData(_tablePosX, _tablePosY) {
        const ball = window.ball;
        let hitX, hitY;
        if (ball.servingState === 0) {
            hitX = Math.random() * 2 - 1;
            hitY = Math.random() * 0.2 + 0.65;
        }
        else {
            hitX = (Math.random() * 2 - 1) * (1 + (1 - this.skillLevel) * 0.25);
            hitY = Math.random() * 0.4 + 0.65;
        }
        let spin = 0;
        if (hitY < 0.8) {
            if (hitX > 0.1)
                spin = (Math.random() * -1) * (0.75 + this.skillLevel * 0.25);
            else if (hitX < -0.1)
                spin = (Math.random() * 1) * (0.75 + this.skillLevel * 0.25);
        }
        const speed = 0.3 + ((0.3 / 0.4) * (hitY - 0.6)) * (0.25 + this.skillLevel * 0.75);
        return { x: hitX, y: hitY, speed, spin };
    }
    render(ctx) {
        const oids = window.oImageIds;
        const tt = this.getTableTop();
        ctx.save();
        ctx.translate(this.x + (tt.offsetX + 0.8 * this.flailInc) * tt.sideMultiplier, this.y);
        ctx.rotate(this.rotation);
        ctx.scale(this.scale, this.scale);
        const f = this.oGameElementsImgData.oData.oAtlasData[oids['enemyBat' + this.id]];
        ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, -f.width / 2, -f.height / 3, f.width, f.height);
        ctx.restore();
    }
}
//# sourceMappingURL=enemy_bat.js.map