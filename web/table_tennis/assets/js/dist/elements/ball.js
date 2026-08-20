import { PHYSICS, TABLE } from '../utils/constants.js';
/** Typed port of Elements.Ball game.js:1508 — 250+ lines of physics.
 *  Table coords normalised X∈[-1,1] Y∈[0,1]; height is vertical arc.
 */
export class Ball {
    constructor(getCanvas, getCtx, getTableTop, getUserBat, getEnemyBat, onScore) {
        this.getCanvas = getCanvas;
        this.getCtx = getCtx;
        this.getTableTop = getTableTop;
        this.getUserBat = getUserBat;
        this.getEnemyBat = getEnemyBat;
        this.onScore = onScore;
        this.x = 0;
        this.y = 0;
        this.height = 0;
        this.heightInc = 0;
        this.tablePosY = 0.5;
        this.tablePosX = 0;
        this.scale = 0;
        this.lastHit = 'user';
        this.speed = 0.45;
        this.offTable = false;
        this.offSide = false;
        this.pause = false;
        this.spin = 0;
        this.spinInc = 0;
        this.servingState = 0; // 0 serving, 1 first flight, 2 rally
        this.canHit = false;
        this.serveFlip = true;
        this.bounceX = 0;
        this.bounceY = 0;
        this.bounceNum = 0;
        this.ballShortState = 0; // 0 ok, 1 clipped net, 2 after-net
        this.aTrailPoints = [];
        this.tableVX = 0;
        this.tableVY = 0;
        this.targBounceX = 0;
        this.targBounceY = 0;
        this.servePosInc = 0;
        this.offTableVX = 0;
        this.offTableVY = 0;
        this.servePrepTween = null;
        this.offTableTween = null;
        const al = window.assetLib;
        this.oGameElementsImgData = al.getData('gameElements');
        this.resetServe('user');
    }
    resetServe(toServe) {
        const tt = this.getTableTop();
        const eb = this.getEnemyBat();
        this.servingState = 0;
        this.canHit = false;
        eb.resetToCentre();
        tt.tweenToPos(0, 1, this.speed, this.lastHit, this.spin);
        this.lastHit = toServe;
        window.rallyHits = 0;
        this.x = -100;
        this.bounceNum = 0;
        this.ballShortState = 0;
        this.offTable = false;
        this.offSide = false;
        if (this.lastHit === 'user') {
            this.tablePosX = 0;
            this.tablePosY = 0.9;
            this.height = 25;
            this.heightInc = 0;
            this.aTrailPoints = [];
            this.tableVX = 0;
            this.tableVY = 0;
        }
        else {
            this.tablePosX = 0;
            this.tablePosY = 0.2;
            this.height = 15;
            this.heightInc = 0;
            this.aTrailPoints = [];
        }
        this.servePosInc = 0;
        const gs = window.TweenLite;
        this.servePrepTween?.kill();
        this.servePrepTween = gs.to(this, 0.5, { servePosInc: 1, ease: 'Quad.easeOut', onComplete: () => { this.canHit = true; } });
    }
    enemyServe() {
        const eb = this.getEnemyBat();
        this.setBouncePoint(eb.getHitData(this.tablePosX, this.tablePosY));
    }
    setBouncePoint(t) {
        const tt = this.getTableTop();
        const eb = this.getEnemyBat();
        this.spin = t.spin;
        this.spinInc = 0;
        if (this.lastHit === 'enemy') {
            this.targBounceX = t.x;
            this.targBounceY = t.y;
            this.speed = t.speed;
            tt.tweenToPos(this.targBounceX, this.targBounceY, this.speed, this.lastHit, this.spin);
            if (this.servingState === 0) {
                this.servingState = 1;
                this.heightInc = -(-2400 + this.height * 6) * (0.8 - this.speed) * 1.2;
                this.speed = (this.speed - 0.3) / 4 + 0.3;
            }
            else {
                this.heightInc = (-2400 + this.height * 6) * (0.8 - this.speed);
            }
        }
        else {
            this.targBounceX = t.x;
            this.targBounceY = t.y;
            this.speed = t.speed;
            if (this.servingState === 0) {
                this.servingState = 1;
                this.heightInc = -(-2400 + this.height * 6) * (0.8 - this.speed) * 1.2;
                this.speed = (this.speed - 0.3) / 6 + 0.3;
            }
            else {
                this.heightInc = (-2400 + this.height * 6) * (0.8 - this.speed);
            }
            tt.tweenToPos(0, 1, this.speed, this.lastHit, this.spin);
            eb.setBouncePos(this.targBounceX, this.targBounceY, this.spin);
        }
        this.tableVX = (this.targBounceX - this.tablePosX) / ((1 - this.speed) * 1.1);
        this.tableVY = (this.targBounceY - this.tablePosY) / ((1 - this.speed) * 1.1);
    }
    update() {
        const c = this.getCanvas();
        const tt = this.getTableTop();
        const ub = this.getUserBat();
        const eb = this.getEnemyBat();
        const delta = window.delta || 0.016;
        const playSound = window.playSound ?? (() => { });
        if (this.servingState === 0) {
            if (this.lastHit === 'user') {
                this.y = (c.height / 4) + tt.offsetY * 50 + ((this.tablePosY * this.tablePosY) * TABLE.heightFactor) * (1 + tt.offsetY / 2) + (1 - this.servePosInc) * 100;
                this.tablePosX = Math.min(Math.max((ub.x - c.width / 2) / 300, -0.95), 0.95);
                this.x = c.width / 2 + (((this.y - (c.height / 4)) * (tt.offsetX + this.tablePosX * 0.6)) * 1.28 * (1 + tt.offsetY / 2) + (this.tablePosX * TABLE.widthFactor) / 2 + tt.offsetX * tt.sideMultiplier) + (1 - this.servePosInc) * -500;
                this.scale = 0.27 + (this.y - (c.height / 4)) / 600;
                if (this.canHit && ub.getHitData(this.tablePosX, this.tablePosY).y < 0.4) {
                    if (ub.x > this.x - 80 * ub.scale && ub.x < this.x + 80 * ub.scale &&
                        ub.y > this.y - this.height * (this.scale * 3) - 16 - 80 * ub.scale && ub.y < this.y - this.height * (this.scale * 3) - 16 + 80 * ub.scale) {
                        this.bounceNum = 0;
                        this.lastHit = 'user';
                        this.setBouncePoint(ub.getHitData(this.tablePosX, this.tablePosY));
                    }
                }
            }
            else {
                this.y = (c.height / 4) + tt.offsetY * 50 + ((this.tablePosY * this.tablePosY) * TABLE.heightFactor) * (1 + tt.offsetY / 2) + (1 - this.servePosInc) * 100;
                this.tablePosX = 0;
                this.x = c.width / 2 + (((this.y - (c.height / 4)) * (tt.offsetX + this.tablePosX * 0.6)) * 1.28 * (1 + tt.offsetY / 2) + (this.tablePosX * TABLE.widthFactor) / 2 + tt.offsetX * tt.sideMultiplier) + (1 - this.servePosInc) * -500;
                this.scale = 0.27 + (this.y - (c.height / 4)) / 600;
            }
            return;
        }
        // in-flight
        if (!this.offTable) {
            if (this.lastHit === 'user')
                this.spinInc = Math.min(Math.max(this.spinInc + (Math.pow(this.spin * PHYSICS.spinPowUser, 3) * delta) * (1 - this.tablePosY), -PHYSICS.spinClampUser), PHYSICS.spinClampUser);
            else
                this.spinInc = Math.min(Math.max(this.spinInc + (Math.pow(this.spin * PHYSICS.spinPowEnemy, 3) * delta) * this.tablePosY, -PHYSICS.spinClampEnemy), PHYSICS.spinClampEnemy);
            this.tablePosX += (this.tableVX + this.spinInc) * delta;
            this.tablePosY += this.tableVY * delta;
        }
        if (!this.offTable && this.lastHit === 'user' && this.tablePosY < 0) {
            this.offTable = true;
            this.offTableVX = (this.x - (this.aTrailPoints[0]?.x ?? this.x)) * 10;
            this.offTableVY = (this.y - (this.aTrailPoints[0]?.y ?? this.y)) * 10;
            this.offTableTween?.kill();
            const gs = window.TweenLite;
            this.offTableTween = gs.to(this, 2, { offTableVX: 0, offTableVY: 0, ease: 'Quad.easeOut' });
            eb.flail();
        }
        this.heightInc += PHYSICS.gravity * delta;
        this.height -= (this.heightInc * this.speed) * delta;
        if (this.ballShortState === 1 && this.tablePosY <= PHYSICS.netBounceY) {
            playSound('hitNet');
            this.tableVY *= -0.5;
            this.tableVX *= 0.5;
            this.ballShortState = 2;
            this.heightInc *= 0.2;
        }
        if (this.tablePosX > -1 && this.tablePosX < 1 && this.tablePosY > 0 && this.tablePosY < 1 && this.height <= 0 && !this.offSide) {
            this.height = 0;
            this.heightInc *= PHYSICS.bounceDamp;
            if (this.ballShortState === 0)
                playSound('bounce' + Math.floor(Math.random() * 6));
            else
                this.height = -3;
            this.bounceNum++;
            this.bounceX = this.tablePosX;
            this.bounceY = this.tablePosY;
            tt.bounce();
            if (this.lastHit === 'user' && this.tablePosY > 0.5 && this.servingState > 1) {
                this.spin = 0;
                this.ballShortState = 1;
            }
        }
        else if ((this.tablePosX < -1 || this.tablePosX > 1) && !this.offTable && this.tablePosY < 1 && this.height <= 0) {
            this.offSide = true;
        }
        if ((this.offTable || this.offSide) && this.height <= PHYSICS.offTableThreshold) {
            if (this.lastHit === 'user') {
                if (this.bounceNum === 0)
                    this.onScore('enemy');
                else
                    this.onScore('user');
            }
            else {
                if (this.bounceNum === 0)
                    this.onScore('user');
                else
                    this.onScore('enemy');
            }
            this.handleServeFlip();
            return;
        }
        if (!this.offTable) {
            this.y = (c.height / 4) + tt.offsetY * 50 + ((this.tablePosY * this.tablePosY) * TABLE.heightFactor) * (1 + tt.offsetY / 2);
            this.x = c.width / 2 + ((this.y - (c.height / 4)) * (tt.offsetX + this.tablePosX * 0.6)) * 1.28 * (1 + tt.offsetY / 2) + (this.tablePosX * TABLE.widthFactor) / 2 + tt.offsetX * tt.sideMultiplier;
        }
        else {
            this.x += this.offTableVX * delta;
            this.y += this.offTableVY * delta;
        }
        this.scale = 0.27 + (this.y - (c.height / 4)) / 600;
        this.aTrailPoints.push({ x: this.x, y: this.y, height: this.height, scale: this.scale });
        if (this.aTrailPoints.length > PHYSICS.trailMax)
            this.aTrailPoints.shift();
        if (this.y > c.height) {
            if (this.bounceNum > 0 || this.ballShortState > 0)
                this.onScore('enemy');
            else
                this.onScore('user');
            this.handleServeFlip();
            return;
        }
        // user return
        if (this.lastHit === 'enemy' && ((this.servingState === 2 && this.bounceNum === 1) || (this.servingState === 1 && this.bounceNum === 2))
            && !((this.height < 0) && this.bounceNum === 0) && this.tablePosY > 0.5
            && ub.x > this.x - 82 * ub.scale && ub.x < this.x + 82 * ub.scale
            && ub.y > this.y - this.height * (this.scale * 3) - 16 - 82 * ub.scale && ub.y < this.y - this.height * (this.scale * 3) - 16 + 82 * ub.scale) {
            playSound('hit' + Math.floor(Math.random() * 6));
            window.rallyHits = (window.rallyHits ?? 0) + 1;
            this.servingState = 2;
            this.bounceNum = 0;
            this.lastHit = 'user';
            this.setBouncePoint(ub.getHitData(this.tablePosX, this.tablePosY));
        }
        // enemy return
        if (this.lastHit === 'user' && ((this.servingState === 2 && this.bounceNum === 1) || (this.servingState === 1 && this.bounceNum === 2))
            && this.tablePosY < 0.5 && this.tablePosY > 0
            && eb.x > this.x - 70 * eb.scale && eb.x < this.x + 70 * eb.scale
            && eb.y > this.y - this.height * (this.scale * 3) - 16 - 70 * eb.scale && eb.y < this.y - this.height * (this.scale * 3) - 16 + 70 * eb.scale) {
            playSound('hit' + Math.floor(Math.random() * 6));
            window.rallyHits = (window.rallyHits ?? 0) + 1;
            this.servingState = 2;
            this.bounceNum = 0;
            this.lastHit = 'enemy';
            this.setBouncePoint(eb.getHitData(this.tablePosX, this.tablePosY));
        }
    }
    handleServeFlip() {
        const od = window.oGameData;
        if ((od.userScore + od.enemyScore) % 2 === 0 || (od.userScore >= 10 && od.enemyScore >= 10))
            this.serveFlip = !this.serveFlip;
        this.resetServe(this.serveFlip ? 'user' : 'enemy');
    }
    render(ctx) {
        const oids = window.oImageIds;
        if (this.tablePosX > -1 && this.tablePosX < 1 && this.tablePosY > 0 && this.tablePosY < 1) {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.ballShadow];
            if (f)
                ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, this.x - (f.width / 2) * this.scale, this.y - (f.height / 2) * this.scale, f.width * this.scale, f.height * this.scale);
        }
        if (this.lastHit === 'enemy' && this.ballShortState === 0)
            this.renderTrail(ctx);
        {
            const f = this.oGameElementsImgData.oData.oAtlasData[oids.ball];
            ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, this.x - (f.width / 2) * this.scale, this.y - (f.height / 2) * this.scale - this.height * (this.scale * 3) - 16, f.width * this.scale, f.height * this.scale);
        }
        if (this.lastHit === 'user' && this.ballShortState === 0)
            this.renderTrail(ctx);
    }
    renderTrail(ctx) {
        const oids = window.oImageIds;
        const tempTrailNum = Math.floor((this.aTrailPoints.length / 0.3) * (Math.max(Math.min(this.speed, 0.6), 0.3) - 0.3));
        for (let i = 0; i < tempTrailNum; i++) {
            const pt = this.aTrailPoints[this.aTrailPoints.length - 1 - i];
            if (!pt)
                continue;
            const idx = Math.min(i, 4);
            const key = ('ballTrail' + idx);
            const f = this.oGameElementsImgData.oData.oAtlasData[oids[key]];
            if (!f)
                continue;
            const alpha = 1 - (i / tempTrailNum) * 0.7;
            ctx.save();
            ctx.globalAlpha = alpha;
            ctx.drawImage(this.oGameElementsImgData.img, f.x, f.y, f.width, f.height, pt.x - (f.width / 2) * pt.scale, pt.y - (f.height / 2) * pt.scale - pt.height * (pt.scale * 3) - 16, f.width * pt.scale, f.height * pt.scale);
            ctx.restore();
        }
    }
}
//# sourceMappingURL=ball.js.map