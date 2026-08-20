import type { AssetData } from '../types/index.js';

/** Typed port of Utils.AnimSprite game.js:195 + Utils.BasicSprite game.js:308 */
export class AnimSprite {
  x = 0; y = 0; rotation = 0; radius = 10;
  removeMe = false;
  frameInc = 0;
  animType: 'loop'|'once' = 'loop';
  offsetX = 0; offsetY = 0;
  scaleX = 1; scaleY = 1; alpha = 1;
  oImgData: AssetData;
  private oAnims: AssetData['oData']['oAnims'];
  fps: number; radius2: number;
  animId: string | null;
  centreX: number; centreY: number;
  fixedFrame?: number; curFrame?: number;
  maxIdx = 0;
  animEndedFunc: (()=>void) | null = null;

  constructor(oImgData: AssetData, fps: number, radius: number, animId: string | null) {
    this.oImgData = oImgData;
    this.oAnims = oImgData.oData.oAnims;
    this.fps = fps; this.radius2 = radius; this.animId = animId;
    this.centreX = Math.round(oImgData.oData.spriteWidth/2);
    this.centreY = Math.round(oImgData.oData.spriteHeight/2);
  }

  updateAnimation(delta: number): void { this.frameInc += this.fps * delta; }

  changeImgData(newImgData: AssetData, animId: string | null): void {
    this.oImgData = newImgData; this.oAnims = newImgData.oData.oAnims;
    this.animId = animId;
    this.centreX = Math.round(newImgData.oData.spriteWidth/2);
    this.centreY = Math.round(newImgData.oData.spriteHeight/2);
    this.resetAnim();
  }
  resetAnim(): void { this.frameInc = 0; }
  setFrame(n: number): void { this.fixedFrame = n; }
  setAnimType(type:'loop'|'once', animId:string|null, reset=true): void {
    this.animId = animId; this.animType = type;
    if (reset) this.resetAnim();
    if (type==='once' && animId && this.oAnims?.[animId]) this.maxIdx = this.oAnims[animId].length - 1;
  }

  render(ctx: CanvasRenderingContext2D): void {
    ctx.save(); ctx.translate(this.x,this.y); ctx.rotate(this.rotation);
    ctx.scale(this.scaleX,this.scaleY); ctx.globalAlpha = this.alpha;
    let imgX:number, imgY:number;
    if (this.animId != null && this.oAnims?.[this.animId]) {
      const frames = this.oAnims[this.animId]!; const max = frames.length;
      const idx = Math.floor(this.frameInc); this.curFrame = frames[idx % max];
      imgX = (this.curFrame * this.oImgData.oData.spriteWidth) % (this.oImgData.img as HTMLImageElement).width;
      imgY = Math.floor(this.curFrame / ((this.oImgData.img as HTMLImageElement).width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
      if (this.animType==='once' && idx > this.maxIdx) {
        this.fixedFrame = frames[max-1]; this.animId = null;
        this.animEndedFunc?.();
        imgX = (this.fixedFrame * this.oImgData.oData.spriteWidth) % (this.oImgData.img as HTMLImageElement).width;
        imgY = Math.floor(this.fixedFrame / ((this.oImgData.img as HTMLImageElement).width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
      }
    } else {
      const ff = this.fixedFrame ?? 0;
      imgX = (ff * this.oImgData.oData.spriteWidth) % (this.oImgData.img as HTMLImageElement).width;
      imgY = Math.floor(ff / ((this.oImgData.img as HTMLImageElement).width / this.oImgData.oData.spriteWidth)) * this.oImgData.oData.spriteHeight;
    }
    ctx.drawImage(this.oImgData.img as CanvasImageSource,
      imgX,imgY,this.oImgData.oData.spriteWidth,this.oImgData.oData.spriteHeight,
      -this.centreX+this.offsetX, -this.centreY+this.offsetY,
      this.oImgData.oData.spriteWidth,this.oImgData.oData.spriteHeight);
    ctx.restore();
  }

  renderSimple(ctx: CanvasRenderingContext2D): void {
    let imgX:number, imgY:number;
    if (this.animId != null && this.oAnims?.[this.animId]) {
      const frames = this.oAnims[this.animId]!; const max = frames.length; const idx=Math.floor(this.frameInc);
      this.curFrame = frames[idx%max];
      imgX = (this.curFrame*this.oImgData.oData.spriteWidth)%(this.oImgData.img as HTMLImageElement).width;
      imgY = Math.floor(this.curFrame/((this.oImgData.img as HTMLImageElement).width/this.oImgData.oData.spriteWidth))*this.oImgData.oData.spriteHeight;
      if (this.animType==='once' && idx>this.maxIdx) {
        this.fixedFrame=frames[max-1]; this.animId=null; this.animEndedFunc?.();
        imgX=(this.fixedFrame*this.oImgData.oData.spriteWidth)%(this.oImgData.img as HTMLImageElement).width;
        imgY=Math.floor(this.fixedFrame/((this.oImgData.img as HTMLImageElement).width/this.oImgData.oData.spriteWidth))*this.oImgData.oData.spriteHeight;
      }
    } else {
      const ff=this.fixedFrame??0;
      imgX=(ff*this.oImgData.oData.spriteWidth)%(this.oImgData.img as HTMLImageElement).width;
      imgY=Math.floor(ff/((this.oImgData.img as HTMLImageElement).width/this.oImgData.oData.spriteWidth))*this.oImgData.oData.spriteHeight;
    }
    ctx.drawImage(this.oImgData.img as CanvasImageSource,
      imgX,imgY,this.oImgData.oData.spriteWidth,this.oImgData.oData.spriteHeight,
      this.x-(this.centreX-this.offsetX)*this.scaleX,
      this.y-(this.centreY-this.offsetY)*this.scaleY,
      this.oImgData.oData.spriteWidth*this.scaleX, this.oImgData.oData.spriteHeight*this.scaleY);
  }
}

export class BasicSprite {
  x=0; y=0; rotation=0; radius=10; removeMe=false;
  offsetX=0; offsetY=0; scaleX=1; scaleY=1;
  oImgData: AssetData; frameNum: number;
  constructor(oImgData: AssetData, radius:number, frame=0){ this.oImgData=oImgData; this.radius=radius; this.frameNum=frame; }
  setFrame(n:number){ this.frameNum=n; }
  render(ctx: CanvasRenderingContext2D): void {
    ctx.save(); ctx.translate(this.x,this.y); ctx.rotate(this.rotation); ctx.scale(this.scaleX,this.scaleY);
    const imgX = (this.frameNum*this.oImgData.oData.spriteWidth)%(this.oImgData.img as HTMLImageElement).width;
    const imgY = Math.floor(this.frameNum/((this.oImgData.img as HTMLImageElement).width/this.oImgData.oData.spriteWidth))*this.oImgData.oData.spriteHeight;
    ctx.drawImage(this.oImgData.img as CanvasImageSource,
      imgX,imgY,this.oImgData.oData.spriteWidth,this.oImgData.oData.spriteHeight,
      -this.oImgData.oData.spriteWidth/2+this.offsetX, -this.oImgData.oData.spriteHeight/2+this.offsetY,
      this.oImgData.oData.spriteWidth,this.oImgData.oData.spriteHeight);
    ctx.restore();
  }
}
