/** Typed port of js/mp-hooks.js:1 + js/bridge.js:1
 *  Drop-in replacement: keeps window.TTMultiplayer shape so existing Flutter bridge still works.
 *  New typed API is exported for future refactor.
 */
import type { BallStateDTO, HitData } from './types/index.js';

export interface TTMultiplayerAPI {
  enabled: boolean;
  isHost: boolean;
  localSide: 'near'|'far';
  _remotePaddleY: number;
  _remoteBallState: BallStateDTO;
  _localPaddleY: number;
  _hostScore: number; _guestScore: number;
  setRemotePaddleY(y:number): void;
  setRemoteBallState(x:number,y:number,vx:number,vy:number): void;
  getLocalPaddleY(): number; setLocalPaddleY(y:number): void;
  getLocalBallState(): BallStateDTO;
  disableAI(): void;
  startMatch(isHost:boolean, side:'near'|'far'): void;
  endMatch(): void;
  syncScore(h:number,g:number): void;
  getScores(): { hostScore:number; guestScore:number };
}

export function installMPHooks(): TTMultiplayerAPI {
  const TT: TTMultiplayerAPI = {
    enabled:false, isHost:false, localSide:'near',
    _remotePaddleY:0.5, _remoteBallState:{x:0,y:0,vx:0,vy:0},
    _localPaddleY:0.5, _hostScore:0, _guestScore:0,
    setRemotePaddleY(y){ TT._remotePaddleY=y; },
    setRemoteBallState(x,y,vx,vy){ TT._remoteBallState={x,y,vx,vy}; },
    getLocalPaddleY(){ return TT._localPaddleY; },
    setLocalPaddleY(y){ TT._localPaddleY=y; },
    getLocalBallState(){
      const ball = (window as unknown as {ball?:{x:number; y:number; tableVX:number; tableVY:number}}).ball;
      if (!ball) return {x:0,y:0,vx:0,vy:0};
      return { x: ball.x, y: ball.y, vx: ball.tableVX, vy: ball.tableVY };
    },
    disableAI(){
      const eb = (window as unknown as {enemyBat?:{trackBall:boolean}}).enemyBat;
      if (eb) eb.trackBall=false;
    },
    startMatch(isHost, side){ TT.enabled=true; TT.isHost=isHost; TT.localSide=side; TT._hostScore=0; TT._guestScore=0; TT.disableAI(); },
    endMatch(){ TT.enabled=false; TT._hostScore=0; TT._guestScore=0; },
    syncScore(h,g){ TT._hostScore=h; TT._guestScore=g; },
    getScores(){ return { hostScore:TT._hostScore, guestScore:TT._guestScore }; },
  };
  (window as unknown as {TTMultiplayer:TTMultiplayerAPI}).TTMultiplayer = TT;

  // bridge: listen for REMOTE_* from Flutter, emit LOCAL_* each frame
  const isMP = window.location.search.includes('mode=mp');
  if (!isMP) return TT;

  window.addEventListener('message', (e: MessageEvent)=>{
    const d = e.data as {type?:string; y?:number; x?:number; vx?:number; vy?:number; hostScore?:number; guestScore?:number; isHost?:boolean; side?:'near'|'far'};
    if (!d?.type) return;
    switch(d.type){
      case 'REMOTE_PADDLE': TT.setRemotePaddleY(d.y ?? 0.5); break;
      case 'REMOTE_BALL': TT.setRemoteBallState(d.x??0,d.y??0,d.vx??0,d.vy??0); break;
      case 'REMOTE_SCORE': TT.syncScore(d.hostScore??0,d.guestScore??0); break;
      case 'START_MP': TT.startMatch(!!d.isHost, (d.side as 'near'|'far') ?? 'near'); break;
      case 'END_MP': TT.endMatch(); break;
    }
  });

  const sendLoop = ()=>{
    if (TT.enabled && window.parent){
      window.parent.postMessage({ type:'LOCAL_PADDLE', y: TT.getLocalPaddleY() }, '*');
      if (TT.isHost){
        const b = TT.getLocalBallState();
        window.parent.postMessage({ type:'LOCAL_BALL', x:b.x, y:b.y, vx:b.vx, vy:b.vy }, '*');
      }
    }
    requestAnimationFrame(sendLoop);
  };
  requestAnimationFrame(sendLoop);
  return TT;
}
