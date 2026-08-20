import type { AssetData, OImageIds } from '../types/index.js';

/** Trimmed typed port of Elements.Panel game.js:789 — only structure, full render in original 400L+ */
export type PanelType = 'splash'|'start'|'credits'|'chooseCountry'|'map'|'gameIntro'|'game'|'pause'|'gameComplete'|'load';

export interface PanelBut {
  oImgData: AssetData; aPos:[number,number]; align:[number,number]; id:string; scale?:number; noMove?:boolean;
}

export class Panel {
  posY = 0;
  incY = 0;
  flareRot=0; cupFlipInc=0;
  userCardScale=1; enemyCardScale=1;
  userBatX=0; userBatY=0; enemyBatX=0; enemyBatY=0; ballX=0; ballY=0; ballHeight=0;
  private oSplashLogoImgData: AssetData;
  private oCountryFlagsImgData: AssetData;
  private oUiElementsImgData: AssetData;
  private oGameElementsImgData: AssetData;
  constructor(public panelType: PanelType, public aButs: PanelBut[]) {
    const al = (window as unknown as {assetLib:{getData(s:string):AssetData}}).assetLib;
    this.oSplashLogoImgData = al.getData('splashLogo');
    this.oCountryFlagsImgData = al.getData('countryFlags');
    this.oUiElementsImgData = al.getData('uiElements');
    this.oGameElementsImgData = al.getData('gameElements');
  }
  update(): void {
    const d = (window as unknown as {delta:number}).delta || 0.016;
    this.incY += 10*d;
  }
  startTween1(): void {
    this.posY=500;
    const gs = (window as unknown as {TweenLite:{to(o:unknown,d:number,v:Record<string,unknown>):unknown}}).TweenLite;
    gs.to(this, 0.5, { posY:0, ease:'Cubic.easeOut' });
  }
  startTut(): void {
    const gs = (window as unknown as {TweenLite:{to(o:unknown,d:number,v:Record<string,unknown>):unknown}}).TweenLite;
    this.userBatX=-50; this.userBatY=85; this.enemyBatX=0; this.enemyBatY=-130; this.ballX=0; this.ballY=19;
    gs.to(this, 0.55, { delay:0.35, userBatX:50, userBatY:-60, ease:'Back.easeOut', onComplete: ()=> this.movePlayerBat(0) });
    gs.to(this, 0.5, { delay:0.8, enemyBatX:50, ease:'Back.easeOut' });
    this.ballHeight=30;
    gs.to(this, 0.55, { delay:0.5, ballX:30, ballY:-100, ease:'Linear.easeNone' });
    gs.to(this, 0.6, { delay:0.6, ballHeight:-30, ease:'Quad.easeIn' });
  }
  private movePlayerBat(id:number): void {
    const gs = (window as unknown as {TweenLite:{to(o:unknown,d:number,v:Record<string,unknown>):unknown}}).TweenLite;
    switch(id){
      case 0: gs.to(this,0.5,{userBatX:130,userBatY:85,ease:'Quad.easeInOut',onComplete:()=>this.movePlayerBat(1)}); gs.to(this,0.65,{delay:0.25,ballX:75,ballY:50,ease:'Quad.easeIn',onComplete:()=>{gs.to(this,0.65,{ballX:-20,ballY:-100,ease:'Quad.easeOut'})}}); gs.to(this,0.65,{delay:0.25,ballHeight:40,ease:'Quad.easeIn',onComplete:()=>{gs.to(this,0.65,{ballHeight:-30,ease:'Quad.easeIn'})}}); break;
      case 1: gs.to(this,0.5,{delay:0.3,userBatX:-30,userBatY:-60,ease:'Back.easeOut',onComplete:()=>this.movePlayerBat(2)}); gs.to(this,0.5,{delay:0.8,enemyBatX:-30,ease:'Back.easeOut'}); break;
      case 2: gs.to(this,0.5,{userBatX:-130,userBatY:85,ease:'Quad.easeInOut',onComplete:()=>this.movePlayerBat(3)}); gs.to(this,0.65,{delay:0.25,ballX:-75,ballY:50,ease:'Quad.easeIn',onComplete:()=>{gs.to(this,0.65,{ballX:20,ballY:-100,ease:'Quad.easeOut'})}}); gs.to(this,0.65,{delay:0.25,ballHeight:40,ease:'Quad.easeIn',onComplete:()=>{gs.to(this,0.65,{ballHeight:-30,ease:'Quad.easeIn'})}}); break;
      case 3: gs.to(this,0.5,{delay:0.3,userBatX:30,userBatY:-60,ease:'Back.easeOut',onComplete:()=>this.movePlayerBat(0)}); gs.to(this,0.5,{delay:0.8,enemyBatX:30,ease:'Back.easeOut'}); break;
    }
  }
  cardTween(player:'user'|'enemy'): void {
    const gs = (window as unknown as {TweenLite:{to(o:unknown,d:number,v:Record<string,unknown>):unknown}}).TweenLite;
    if (player==='user'){ this.userCardScale=0.25; gs.to(this,0.5,{userCardScale:1,ease:'Bounce.easeOut'}); }
    else { this.enemyCardScale=0.25; gs.to(this,0.5,{enemyCardScale:1,ease:'Bounce.easeOut'}); }
  }
  switchBut(id0:string, id1:string): void { for(const b of this.aButs) if(b.id===id0){ b.id=id1; break; } }
  addButs(_ctx: CanvasRenderingContext2D): void { /* draws buttons — keep original Panel.render for full fidelity; stub for typed surface */ }
  render(_butsOnTop=true): void {
    // Full render is ~350L of atlas draws; delegate to original at runtime if present.
    // For typed build, this stub preserves API; actual draw calls are in src/game/panel_render.ts if needed.
    void this.oSplashLogoImgData; void this.oCountryFlagsImgData; void this.oUiElementsImgData; void this.oGameElementsImgData;
  }
}
