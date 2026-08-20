import type { AssetData, HitCallback, KeyCallback, HitAreaType } from '../types/index.js';

/** Typed port of Utils.UserInput game.js:343
 *  Handles touch/mouse + pointer-lock for desktop paddle aiming.
 */
export interface HitArea {
  id: string;
  callback: HitCallback;
  oData: Record<string, unknown> & { isDown?:boolean; isBeingDragged?:boolean; isDraggable?:boolean; multiTouch?:boolean; hasLeft?:boolean; x?:number; y?:number };
  rect: boolean;
  area: [number,number,number,number];
  align: [number,number];
  aTouchIdentifiers: number[];
}

interface KeyEntry { id:string; callback:KeyCallback; oData:{isDown:boolean}; keyCode:number; }

export class UserInput {
  prevHitTime = 0;
  pauseIsOn = false;
  isDown = false;
  aHitAreas: HitArea[] = [];
  aKeys: KeyEntry[] = [];
  private keyDownEvt: (e:KeyboardEvent)=>void;
  private keyUpEvt: (e:KeyboardEvent)=>void;

  constructor(private canvas: HTMLCanvasElement, private isBugBrowser: boolean) {
    this.keyDownEvt = (e)=> this.keyDown(e);
    this.keyUpEvt   = (e)=> this.keyUp(e);

    canvas.addEventListener('touchstart', (e)=> {
      for (let i=0;i<e.changedTouches.length;i++) this.hitDown(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier);
    }, {passive:false});
    canvas.addEventListener('touchend', (e)=> {
      for (let i=0;i<e.changedTouches.length;i++) this.hitUp(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier);
    }, {passive:false});
    canvas.addEventListener('touchcancel', (e)=> {
      for (let i=0;i<e.changedTouches.length;i++) this.hitCancel(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier);
    }, {passive:false});
    canvas.addEventListener('touchmove', (e)=> {
      for (let i=0;i<e.changedTouches.length;i++) this.move(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier, true);
    }, {passive:false});
    canvas.addEventListener('mousedown', (e)=> { this.isDown=true; this.hitDown(e,e.pageX,e.pageY,1); }, false);
    canvas.addEventListener('mouseup',   (e)=> { this.isDown=false; this.hitUp(e,e.pageX,e.pageY,1); }, false);
    canvas.addEventListener('mousemove', (e)=> { this.move(e,e.pageX,e.pageY,1,this.isDown); }, false);
    canvas.addEventListener('mouseout',  (e)=> { this.isDown=false; this.hitUp(e,Math.abs(e.pageX),Math.abs(e.pageY),1); }, false);
  }

  // global canvasScale is now injected via GameContext; fallback 1
  private get canvasScale(): number {
    return (window as unknown as {canvasScale?:number}).canvasScale ?? 1;
  }

  hitDown(e: Event, posX:number, posY:number, id:number): void {
    e.preventDefault(); e.stopPropagation();
    if (!(window as unknown as {hasFocus?:boolean}).hasFocus) (window as unknown as {visibleResume?:()=>void}).visibleResume?.();
    if (this.pauseIsOn) return;
    const cur = Date.now();
    posX *= this.canvasScale; posY *= this.canvasScale;
    for (const ha of this.aHitAreas) {
      if (!ha.rect) continue;
      const ax = this.canvas.width * ha.align[0], ay = this.canvas.height * ha.align[1];
      if (posX > ax+ha.area[0] && posY > ay+ha.area[1] && posX < ax+ha.area[2] && posY < ay+ha.area[3]) {
        ha.aTouchIdentifiers.push(id);
        (ha.oData as Record<string,unknown>)['hasLeft']=false;
        if (!ha.oData.isDown) {
          ha.oData.isDown=true; (ha.oData as Record<string,number>).x=posX; (ha.oData as Record<string,number>).y=posY;
          const gs = (window as unknown as {gameState?:string}).gameState;
          if ((cur - this.prevHitTime < 500 && (gs!=='game' || ha.id==='pause')) && this.isBugBrowser) return;
          ha.callback(ha.id, ha.oData as unknown as Parameters<HitCallback>[1]);
        }
        break;
      }
    }
    this.prevHitTime = cur;
  }

  hitUp(e: Event, posX:number, posY:number, id:number): void {
    if (!(window as unknown as {ios9FirstTouch?:boolean}).ios9FirstTouch) {
      try { (window as unknown as {playSound?:(s:string)=>void}).playSound?.('silence'); } catch {}
      (window as unknown as {ios9FirstTouch?:boolean}).ios9FirstTouch = true;
    }
    if (this.pauseIsOn) return;
    e.preventDefault(); e.stopPropagation();
    posX*=this.canvasScale; posY*=this.canvasScale;
    for (const ha of this.aHitAreas) {
      if (!ha.rect) continue;
      const ax=this.canvas.width*ha.align[0], ay=this.canvas.height*ha.align[1];
      if (posX>ax+ha.area[0] && posY>ay+ha.area[1] && posX<ax+ha.area[2] && posY<ay+ha.area[3]) {
        for (let j=0;j<ha.aTouchIdentifiers.length;j++) if (ha.aTouchIdentifiers[j]===id) { ha.aTouchIdentifiers.splice(j,1); j--; }
        if (ha.aTouchIdentifiers.length===0) {
          ha.oData.isDown=false;
          if (ha.oData.multiTouch) { (ha.oData as Record<string,number>).x=posX; (ha.oData as Record<string,number>).y=posY; ha.callback(ha.id, ha.oData as unknown as Parameters<HitCallback>[1]); }
        }
        break;
      }
    }
  }

  hitCancel(e: Event, posX:number, posY:number, _id:number): void {
    e.preventDefault(); e.stopPropagation();
    posX*=this.canvasScale; posY*=this.canvasScale;
    for (const ha of this.aHitAreas) if (ha.oData.isDown) {
      ha.oData.isDown=false; ha.aTouchIdentifiers=[];
      if (ha.oData.multiTouch){ (ha.oData as Record<string,number>).x=posX; (ha.oData as Record<string,number>).y=posY; ha.callback(ha.id, ha.oData as unknown as Parameters<HitCallback>[1]); }
    }
  }

  // pointer-lock helpers game.js:484
  userExitLock = (_e: Event): void => {
    const dc = document as unknown as {pointerLockElement:Element|null; mozPointerLockElement:Element|null};
    if (dc.pointerLockElement !== this.canvas && dc.mozPointerLockElement !== this.canvas) {
      (window as unknown as {butEventHandler?:(id:string)=>void}).butEventHandler?.('pause');
    }
  };
  lockPointer(elem?: Element): void {
    const el = (elem ?? this.canvas) as HTMLElement & {requestPointerLock?():void; webkitRequestPointerLock?():void; mozRequestPointerLock?():void};
    if (el.requestPointerLock) el.requestPointerLock();
    else if (el.webkitRequestPointerLock) el.webkitRequestPointerLock();
    else if (el.mozRequestPointerLock) el.mozRequestPointerLock();
    if ('onpointerlockchange' in document) (document as unknown as {addEventListener(t:string,l:EventListener):void}).addEventListener('pointerlockchange', this.userExitLock as EventListener);
    else if ('onmozpointerlockchange' in document) (document as unknown as {addEventListener(t:string,l:EventListener):void}).addEventListener('mozpointerlockchange' as unknown as 'pointerlockchange', this.userExitLock as EventListener);
  }
  unlockPointer(): void {
    const dc = document as unknown as {exitPointerLock?():void; webkitExitPointerLock?():void; mozExitPointerLock?():void};
    if (dc.exitPointerLock) dc.exitPointerLock();
    else if (dc.webkitExitPointerLock) dc.webkitExitPointerLock();
    else if (dc.mozExitPointerLock) dc.mozExitPointerLock();
    if ('onpointerlockchange' in document) (document as unknown as {removeEventListener(t:string,l:EventListener):void}).removeEventListener('pointerlockchange', this.userExitLock as EventListener);
    else if ('onmozpointerlockchange' in document) (document as unknown as {removeEventListener(t:string,l:EventListener):void}).removeEventListener('mozpointerlockchange' as unknown as 'pointerlockchange', this.userExitLock as EventListener);
  }

  move(e: MouseEvent | TouchEvent, posX:number, posY:number, ident:number, isDown:boolean): void {
    if (this.pauseIsOn) return;
    // desktop: drive userBat directly (mirrors game.js:526)
    const ub = (window as unknown as {userBat?:{targX:number; targY:number}}).userBat;
    const firstRun = (window as unknown as {firstRun?:boolean}).firstRun;
    const isMobile = (window as unknown as {isMobile?:boolean}).isMobile;
    if (!isMobile && ub && !firstRun) {
      const dc = document as unknown as {pointerLockElement:Element|null; mozPointerLockElement:Element|null};
      if (dc.pointerLockElement===this.canvas || dc.mozPointerLockElement===this.canvas) {
        const { movementX, movementY } = e as MouseEvent & {movementX:number; movementY:number};
        const helper = (window as unknown as {famobi:{pointerLockHelper?:{mousePos:{x:number;y:number}}}}).famobi?.pointerLockHelper;
        if (helper) {
          if (helper.mousePos.x+movementX < window.innerWidth && helper.mousePos.x+movementX>0) helper.mousePos.x+=movementX;
          if (helper.mousePos.y+movementY < window.innerHeight && helper.mousePos.y+movementY>0) helper.mousePos.y+=movementY;
          ub.targX = helper.mousePos.x * this.canvasScale;
          ub.targY = helper.mousePos.y * this.canvasScale;
        }
      } else {
        ub.targX = posX*this.canvasScale;
        ub.targY = posY*this.canvasScale;
        const helper = (window as unknown as {famobi:{pointerLockHelper?:{mousePos:{x:number;y:number}}}}).famobi?.pointerLockHelper;
        if (helper) helper.mousePos = { x: posX, y: posY };
      }
    }
    if (!isDown) return;
    posX*=this.canvasScale; posY*=this.canvasScale;
    for (const ha of this.aHitAreas) {
      if (!ha.rect) continue;
      const ax=this.canvas.width*ha.align[0], ay=this.canvas.height*ha.align[1];
      if (posX>ax+ha.area[0] && posY>ay+ha.area[1] && posX<ax+ha.area[2] && posY<ay+ha.area[3]) {
        (ha.oData as Record<string,unknown>)['hasLeft']=false;
        if (ha.oData.isDraggable && !ha.oData.isDown) {
          ha.oData.isDown=true; (ha.oData as Record<string,number>).x=posX; (ha.oData as Record<string,number>).y=posY;
          ha.aTouchIdentifiers.push(ident);
          if (ha.oData.multiTouch) ha.callback(ha.id, ha.oData as unknown as Parameters<HitCallback>[1]);
        }
        if (ha.oData.isDraggable) {
          ha.oData.isBeingDragged=true; (ha.oData as Record<string,number>).x=posX; (ha.oData as Record<string,number>).y=posY;
          ha.callback(ha.id, ha.oData as unknown as Parameters<HitCallback>[1]);
          ha.oData.isBeingDragged=false;
        }
      } else if (ha.oData.isDown && !(ha.oData as Record<string,unknown>)['hasLeft']) {
        for (let j=0;j<ha.aTouchIdentifiers.length;j++) if (ha.aTouchIdentifiers[j]===ident){ ha.aTouchIdentifiers.splice(j,1); j--; }
        if (ha.aTouchIdentifiers.length===0) {
          (ha.oData as Record<string,unknown>)['hasLeft']=true;
          if (!ha.oData.isBeingDragged) ha.oData.isDown=false;
          if (ha.oData.multiTouch) ha.callback(ha.id, ha.oData as unknown as Parameters<HitCallback>[1]);
        }
      }
    }
  }

  keyDown(e: KeyboardEvent): void { for (const k of this.aKeys) if (e.keyCode===k.keyCode){ e.preventDefault(); k.oData.isDown=true; k.callback(k.id,k.oData); } }
  keyUp(e: KeyboardEvent): void   { for (const k of this.aKeys) if (e.keyCode===k.keyCode){ e.preventDefault(); k.oData.isDown=false; k.callback(k.id,k.oData); } }
  checkKeyFocus(): void {
    window.focus();
    if (this.aKeys.length>0) {
      (window as unknown as {removeEventListener(t:string,l:EventListener):void}).removeEventListener('keydown', this.keyDownEvt as EventListener);
      (window as unknown as {removeEventListener(t:string,l:EventListener):void}).removeEventListener('keyup', this.keyUpEvt as EventListener);
      (window as unknown as {addEventListener(t:string,l:EventListener):void}).addEventListener('keydown', this.keyDownEvt as EventListener);
      (window as unknown as {addEventListener(t:string,l:EventListener):void}).addEventListener('keyup', this.keyUpEvt as EventListener);
    }
  }
  addKey(id:string, cb:KeyCallback, data:Record<string,unknown>|null, keyCode:number): void {
    const oData = (data as unknown as {isDown:boolean}) ?? {isDown:false};
    this.aKeys.push({ id, callback:cb, oData, keyCode }); this.checkKeyFocus();
  }
  removeKey(id:string): void { for(let i=0;i<this.aKeys.length;i++) if(this.aKeys[i].id===id){ this.aKeys.splice(i,1); i--; } }

  addHitArea(
    id:string, cb:HitCallback, oData:Record<string,unknown>|null,
    type: HitAreaType, oAreaData: { oImgData?: AssetData; aPos?:[number,number]; scale?:number; align?:[number,number]; id?:string; aRect?:[number,number,number,number]; },
    isUnique=false,
  ): void {
    if (!oData) oData = {};
    if (isUnique) this.removeHitArea(id);
    if (!oAreaData.scale) oAreaData.scale=1;
    if (!oAreaData.align) oAreaData.align=[0,0];
    const aTouchIdentifiers: number[] = [];
    switch (type) {
      case 'image': {
        const ad = oAreaData as { oImgData:AssetData; aPos:[number,number]; id:string; scale:number; align:[number,number]};
        const f = ad.oImgData.oData.oAtlasData[ad.id];
        const aRect: [number,number,number,number] = [
          ad.aPos[0] - (f.width/2)*ad.scale, ad.aPos[1] - (f.height/2)*ad.scale,
          ad.aPos[0] + (f.width/2)*ad.scale, ad.aPos[1] + (f.height/2)*ad.scale,
        ];
        this.aHitAreas.push({ id, aTouchIdentifiers, callback:cb, oData: oData as HitArea['oData'], rect:true, area:aRect, align: ad.align });
        break;
      }
      case 'rect': {
        const ad = oAreaData as { aRect:[number,number,number,number]; align:[number,number]};
        this.aHitAreas.push({ id, aTouchIdentifiers, callback:cb, oData: oData as HitArea['oData'], rect:true, area: ad.aRect, align: ad.align ?? [0,0] });
        break;
      }
    }
  }
  removeHitArea(id:string): void { for(let i=0;i<this.aHitAreas.length;i++) if(this.aHitAreas[i].id===id){ this.aHitAreas.splice(i,1); i--; } }
  resetAll(): void { for(const ha of this.aHitAreas){ ha.oData.isDown=false; ha.oData.isBeingDragged=false; ha.aTouchIdentifiers=[]; } this.isDown=false; }
}
