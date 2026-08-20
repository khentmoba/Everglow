/** Typed port of Utils.FpsMeter game.js:715 */
export class FpsMeter {
    constructor(canvasHeight) {
        this.canvasHeight = canvasHeight;
        this.updateFreq = 10;
        this.updateInc = 0;
        this.frameAverage = 0;
        this.display = 1;
        this.log = '';
        this.delta = 0;
    }
    update(delta) { this.delta = delta; }
    render(ctx) {
        this.frameAverage += this.delta / this.updateFreq;
        if (++this.updateInc >= this.updateFreq) {
            this.updateInc = 0;
            this.display = this.frameAverage;
            this.frameAverage = 0;
        }
        ctx.textAlign = 'left';
        ctx.font = '10px Helvetica';
        ctx.fillStyle = '#333333';
        ctx.beginPath();
        ctx.rect(0, this.canvasHeight - 15, 40, 15);
        ctx.closePath();
        ctx.fill();
        ctx.fillStyle = '#ffffff';
        ctx.fillText(`${Math.round(1000 / (this.display * 1000))} fps ${this.log}`, 5, this.canvasHeight - 5);
    }
}
//# sourceMappingURL=fps_meter.js.map