/**
 * Typed Game orchestrator — replaces ~1200 lines of scattered globals in game.js:2720-5300
 * Maintains same state machine but with explicit dependencies and no implicit window.* leakage.
 */
import type { OGameData, GameState, OImageIds, AssetData, FileSpec } from '../types/index.js';
import { USER_COUNTRIES, ENEMY_CUPS, SPARE_ENEMY, MAP_MARKER_POS, INITIAL_GAME_DATA, SAVE_KEY } from '../utils/constants.js';
import { AssetLoader } from '../core/asset_loader.js';
import { UserInput } from '../core/user_input.js';
import { SaveDataHandler } from '../core/save_data.js';
import { CountryFlags } from '../core/country_flags.js';
import { TableTop } from '../elements/table_top.js';
import { UserBat } from '../elements/user_bat.js';
import { EnemyBat } from '../elements/enemy_bat.js';
import { Ball } from '../elements/ball.js';
import { Background } from '../elements/background.js';
import { Panel } from '../elements/panel.js';
import { getFamobi, ensureAnalytics } from '../utils/famobi.js';

declare const TweenLite: { to(o:unknown,d:number,v:Record<string,unknown>):{kill():void} };
declare const Howler: { volume(v:number):void; mute(b:boolean):void };
declare const Howl: new (opts:{src:string[]; volume:number; loop:boolean; sprite?:Record<string,[number,number]>})=> { play(s?:string):void; pause():void; volume():number; volume(v:number):void; mute(b:boolean):void; playing():boolean; fade(from:number,to:number,dur:number):void };

export class Game {
  // canvas
  canvas: HTMLCanvasElement;
  ctx: CanvasRenderingContext2D;
  canvasScale = 1;
  delta = 0;
  previousTime = 0;

  // state
  gameState: GameState = 'loading';
  oGameData: OGameData = { ...INITIAL_GAME_DATA };
  oImageIds: OImageIds = {} as OImageIds;
  firstRun = true;
  controlState: 0|1 = 0;
  flagPage = 0;
  justWonCup = false;
  rallyHits = 0;
  isMobile = false;
  isBugBrowser = false;
  muted = false;
  hasFocus = true;
  audioType: 0|1|2 = 0;
  swipeState: 0|1 = 0;
  startTouchY = 0;

  // services
  assetLib!: AssetLoader;
  preAssetLib!: AssetLoader;
  saveDataHandler = new SaveDataHandler(SAVE_KEY);
  countryFlags = new CountryFlags(USER_COUNTRIES, false);
  userInput: UserInput;
  background!: Background;
  panel!: Panel;
  tableTop!: TableTop;
  userBat!: UserBat;
  enemyBat!: EnemyBat;
  ball!: Ball;
  sound!: InstanceType<typeof Howl>;
  music!: InstanceType<typeof Howl>;

  constructor(canvasId='canvas') {
    const c = document.getElementById(canvasId) as HTMLCanvasElement | null;
    if (!c) throw new Error(`Canvas #${canvasId} not found`);
    this.canvas = c;
    const ctx = c.getContext('2d');
    if (!ctx) throw new Error('2d context unavailable');
    this.ctx = ctx;
    this.isMobile = /iphone|ipod|ipad|android|iemobile|blackberry|bada/i.test(navigator.userAgent.toLowerCase());
    this.isBugBrowser = /android/i.test(navigator.userAgent) && !/Chrome/.test(navigator.userAgent);
    this.userInput = new UserInput(this.canvas, this.isBugBrowser);
    this.resizeCanvas();
    window.addEventListener('resize', ()=> setTimeout(()=> this.resizeCanvas(),1));
    // expose for legacy modules that still read window.*
    (window as unknown as Record<string,unknown>)['canvas']=this.canvas;
    (window as unknown as Record<string,unknown>)['ctx']=this.ctx;
    (window as unknown as Record<string,unknown>)['delta']=this.delta;
    (window as unknown as Record<string,unknown>)['oGameData']=this.oGameData;
    (window as unknown as Record<string,unknown>)['oImageIds']=this.oImageIds;
    (window as unknown as Record<string,unknown>)['gameState']=this.gameState;
  }

  // -------------------------------------------------------------------------
  // Boot
  // -------------------------------------------------------------------------
  extGameLoad(): void { this.loadPreAssets(); }

  private loadPreAssets(): void {
    this.preAssetLib = new AssetLoader('', [
      { id:'loader', file:'images/loader.png' },
      { id:'loadSpinner', file:'images/loadSpinner.png' },
    ], this.ctx, this.canvas.width, this.canvas.height, false);
    this.preAssetLib.onReady(()=> this.loadAssets());
    (window as unknown as Record<string,unknown>)['preAssetLib']=this.preAssetLib;
  }

  private loadAssets(): void {
    let mg = 'images/BrandingPlaceholderButton.png';
    try { mg = getFamobi().getMoreGamesButtonImage(); } catch {}
    const specs: FileSpec[] = [
      { id:'background', file:'images/bgMain.jpg' },
      { id:'splashLogo', file:'images/splashLogo.png' },
      { id:'countryFlags', file:'images/countryFlags.jpg' },
      { id:'largeNumbers', file:'images/largeNumbers_75x132.png' },
      { id:'smallNumbers', file:'images/smallNumbers_23x34.png' },
      { id:'scoreNumbers', file:'images/scoreNumbers_20x37.png' },
      { id:'uiButs', file:'images/uiButs.png', oAtlasData:{
        id0:{x:0,y:204,width:197,height:101}, id1:{x:384,y:373,width:57,height:64},
        id10:{x:298,y:100,width:75,height:54}, id11:{x:298,y:0,width:97,height:98},
        id12:{x:217,y:300,width:97,height:98}, id13:{x:0,y:104,width:197,height:98},
        id14:{x:199,y:200,width:97,height:98}, id15:{x:199,y:0,width:97,height:98},
        id16:{x:117,y:307,width:98,height:98}, id17:{x:316,y:373,width:66,height:57},
        id2:{x:369,y:156,width:65,height:66}, id3:{x:369,y:224,width:64,height:65},
        id4:{x:298,y:156,width:69,height:67}, id5:{x:199,y:100,width:97,height:98},
        id6:{x:0,y:0,width:197,height:102}, id7:{x:0,y:307,width:115,height:98},
        id8:{x:298,y:225,width:69,height:72}, id9:{x:316,y:299,width:68,height:72},
      }},
      { id:'gameElements', file:'images/gameElements.png', oAtlasData:{
        id0:{x:637,y:1128,width:590,height:234}, id1:{x:0,y:1527,width:414,height:41},
        id10:{x:466,y:1527,width:44,height:44}, id11:{x:1274,y:188,width:113,height:186},
        id12:{x:1344,y:1034,width:109,height:110}, id13:{x:0,y:1570,width:404,height:9},
        id14:{x:0,y:1600,width:589,height:28}, id15:{x:0,y:0,width:635,height:372},
        id16:{x:1229,y:656,width:432,height:188}, id17:{x:637,y:892,width:590,height:234},
        id18:{x:637,y:1364,width:590,height:234}, id19:{x:1229,y:846,width:113,height:186},
        id2:{x:632,y:1616,width:39,height:39}, id20:{x:1274,y:376,width:113,height:186},
        id21:{x:1229,y:1034,width:113,height:186}, id22:{x:1229,y:1410,width:113,height:186},
        id23:{x:1229,y:1222,width:113,height:186}, id24:{x:1274,y:0,width:113,height:186},
        id25:{x:0,y:374,width:635,height:500}, id26:{x:416,y:1527,width:48,height:60},
        id27:{x:637,y:656,width:590,height:234}, id28:{x:0,y:876,width:635,height:274},
        id29:{x:637,y:0,width:635,height:373}, id3:{x:168,y:1630,width:37,height:21},
        id30:{x:0,y:1152,width:635,height:373}, id31:{x:637,y:375,width:635,height:279},
        id32:{x:1274,y:564,width:85,height:85}, id33:{x:129,y:1630,width:37,height:21},
        id4:{x:1344,y:846,width:113,height:186}, id5:{x:0,y:1630,width:127,height:24},
        id6:{x:591,y:1616,width:39,height:40}, id7:{x:591,y:1572,width:41,height:42},
        id8:{x:557,y:1527,width:43,height:43}, id9:{x:512,y:1527,width:43,height:44},
      }},
      { id:'uiElements', file:'images/uiElements.png', oAtlasData:{
        id0:{x:499,y:823,width:441,height:106}, id1:{x:499,y:545,width:452,height:276},
        id10:{x:942,y:823,width:112,height:137}, id11:{x:891,y:322,width:112,height:137},
        id12:{x:953,y:461,width:112,height:136}, id13:{x:621,y:465,width:59,height:59},
        id14:{x:0,y:156,width:619,height:387}, id15:{x:682,y:465,width:57,height:56},
        id16:{x:741,y:465,width:57,height:56}, id17:{x:702,y:84,width:57,height:56},
        id18:{x:0,y:545,width:497,height:498}, id2:{x:0,y:0,width:700,height:154},
        id3:{x:702,y:0,width:113,height:82}, id4:{x:741,y:962,width:84,height:80},
        id5:{x:621,y:156,width:268,height:307}, id6:{x:891,y:0,width:119,height:159},
        id7:{x:891,y:161,width:119,height:159}, id8:{x:499,y:931,width:240,height:118},
        id9:{x:953,y:599,width:112,height:137},
      }},
      { id:'firework', file:'images/firework_175x175.png' },
      { id:'shadow', file:'images/shadow.png' },
      { id:'moreGamesBut', file: mg },
    ];
    this.assetLib = new AssetLoader('', specs, this.ctx, this.canvas.width, this.canvas.height);
    (window as unknown as Record<string,unknown>)['assetLib']=this.assetLib;
    // populate oImageIds exactly as game.js:5133
    Object.assign(this.oImageIds, {
      table0:'id0', net:'id1', ball:'id2', ballShadow:'id3', userBatCentre:'id4', batShadow:'id5',
      ballTrail4:'id6', ballTrail3:'id7', ballTrail2:'id8', ballTrail1:'id9', ballTrail0:'id10',
      enemyBat0:'id11', userBatEdge:'id12', tableClip:'id13', tableEdge:'id14', tableBg0:'id15',
      tableLegs:'id16', table1:'id17', table2:'id18', enemyBat1:'id19', enemyBat2:'id20',
      enemyBat3:'id21', enemyBat4:'id22', enemyBat5:'id23', enemyBat6:'id24', tableBgBottom:'id25',
      scoreCard:'id26', table3:'id27', tableBg1:'id28', tableBg2:'id29', tableBg3:'id30', tableBg4:'id31',
      finger:'id32', bounceMark:'id33',
      playBut:'id0', infoBut:'id1', muteBut1:'id2', muteBut0:'id3', backBut:'id4', cupsBut:'id5',
      restartBut:'id6', moreGamesBut:'id7', pauseBut:'id8', resetBut:'id9', changeCountryBut:'id10',
      control0OnBut:'id11', control1OnBut:'id12', quitBut:'id13', control0OffBut:'id14', control1OffBut:'id15',
      tickBut:'id16', moreBut:'id17',
      titleLogo:'id0', titleBats:'id1', titleFadeBar:'id2', countryBut:'id3', vsText:'id4', flare:'id5',
      winIcon:'id6', loseIcon:'id7', globeLogo:'id8', cup1:'id9', cup2:'id10', cup3:'id11', cup0:'id12',
      titleBall:'id13', map:'id14', mapMarker2:'id15', mapMarker1:'id16', mapMarker0:'id17', tutScreen:'id18',
    });
    this.assetLib.onReady(()=> this.initSplash());
    this.gameState='load'; this.syncGlobals(); this.previousTime=Date.now(); this.updateLoaderEvent();
  }

  private syncGlobals(): void {
    const w = window as unknown as Record<string,unknown>;
    w['gameState']=this.gameState; w['oGameData']=this.oGameData; w['oImageIds']=this.oImageIds;
    w['delta']=this.delta; w['canvasScale']=this.canvasScale;
    w['rallyHits']=this.rallyHits; w['firstRun']=this.firstRun;
    w['isMobile']=this.isMobile; w['assetLib']=this.assetLib;
    w['tableTop']=this.tableTop; w['userBat']=this.userBat; w['enemyBat']=this.enemyBat; w['ball']=this.ball;
  }

  // -------------------------------------------------------------------------
  // State inits (mirror game.js:2974+)
  // -------------------------------------------------------------------------
  initSplash(): void {
    const famobi = getFamobi(); const analytics = ensureAnalytics();
    (window as unknown as {famobi_onPauseRequested?:()=>void}).famobi_onPauseRequested = ()=> { try{ Howler.mute(true); this.music?.pause(); }catch{} };
    (window as unknown as {famobi_onResumeRequested?:()=>void}).famobi_onResumeRequested = ()=> {
      if (!this.muted && this.gameState!=='pause'){ try{ Howler.mute(false); this.music?.play(); }catch{} }
    };
    this.oGameData.cupId = this.saveDataHandler.getCurCupId();
    this.oGameData.gameId = this.saveDataHandler.getCurGameId();
    const uid = this.saveDataHandler.getUserId();
    if (uid===1234){ this.firstRun=true; } else { this.firstRun=false; this.oGameData.userId=uid; }
    this.controlState = this.saveDataHandler.getControlState() as 0|1;
    try{
      famobi.onRequest('pauseGameplay', ()=> { if(this.gameState==='game') this.butEventHandler('pause'); });
      famobi.onRequest('resumeGameplay',()=> { if(this.gameState==='pause') this.butEventHandler('playFromPause'); });
    }catch{}
    this.syncGlobals();
    this.initStartScreen();
  }

  initStartScreen(): void {
    this.background = new Background(()=> this.oGameData.cupId);
    this.gameState='start'; this.syncGlobals();
    ensureAnalytics().trackScreen('home');
    this.previousTime=Date.now(); this.updateStartScreenEvent();
    try{ getFamobi().gameReady(); }catch{}
  }

  initGameIntro(): void {
    if (this.oGameData.cupId===10 && this.oGameData.gameId===6){ this.oGameData.cupId=9; this.oGameData.gameId=5; }
    const enemyIso = ENEMY_CUPS[this.oGameData.cupId]?.[this.oGameData.gameId] ?? SPARE_ENEMY;
    this.oGameData.enemyId = this.countryFlags.getIdFromISO(enemyIso);
    if (this.oGameData.enemyId===this.oGameData.userId) this.oGameData.enemyId=this.countryFlags.getIdFromISO(SPARE_ENEMY);
    this.gameState='gameIntro'; this.syncGlobals();
    this.previousTime=Date.now(); this.updateGameIntroScreenEvent();
  }

  /** Starts a match — replaces _initGame game.js:3473 */
  initGame(_restart=false): void {
    ensureAnalytics().trackEvent(_restart ? 'event/level/restart' : 'event/level/start', { levelName: `${this.oGameData.cupId*6 + (this.oGameData.gameId+1)}` })
      .then(()=> this._initGame(), ()=> this._initGame());
  }
  private _initGame(): void {
    this.gameState='game'; this.syncGlobals();
    this.oGameData.userScore=0; this.oGameData.enemyScore=0; this.justWonCup=false;
    this.background = new Background(()=> this.oGameData.cupId);
    this.tableTop = new TableTop(()=> this.oGameData.cupId, this.isMobile, ()=> this.delta);
    this.userBat  = new UserBat(()=> this.canvas, ()=> this.tableTop);
    this.enemyBat = new EnemyBat(()=> this.canvas, ()=> this.tableTop, ()=> this.oGameData);
    this.ball     = new Ball(()=> this.canvas, ()=> this.ctx, ()=> this.tableTop, ()=> this.userBat, ()=> this.enemyBat,
      (who)=> this.updateScore(who));
    (window as unknown as Record<string,unknown>)['ball']=this.ball;
    (window as unknown as Record<string,unknown>)['tableTop']=this.tableTop;
    (window as unknown as Record<string,unknown>)['userBat']=this.userBat;
    (window as unknown as Record<string,unknown>)['enemyBat']=this.enemyBat;
    this.syncGlobals();
    this.previousTime=Date.now(); this.updateGameEvent();
  }

  // -------------------------------------------------------------------------
  // Loop helpers
  // -------------------------------------------------------------------------
  private getDelta(): number {
    const now=Date.now(); let d=(now-this.previousTime)/1000; this.previousTime=now;
    if (d>0.5) d=0; this.delta=d; (window as unknown as Record<string,unknown>)['delta']=d; return d;
  }

  private updateLoaderEvent(): void {
    if (this.gameState!=='load') return;
    this.getDelta(); this.assetLib.render();
    requestAnimationFrame(()=> this.updateLoaderEvent());
  }
  private updateStartScreenEvent(): void {
    if (this.gameState!=='start') return;
    this.getDelta(); this.background.renderMenu(this.ctx,this.canvas);
    this.panel?.update(); this.panel?.render();
    requestAnimationFrame(()=> this.updateStartScreenEvent());
  }
  private updateGameIntroScreenEvent(): void {
    if (this.gameState!=='gameIntro') return;
    this.getDelta(); this.background.renderMenu(this.ctx,this.canvas);
    requestAnimationFrame(()=> this.updateGameIntroScreenEvent());
  }
  private updateGameEvent(): void {
    if (this.gameState!=='game') return;
    this.getDelta();
    this.background.renderGame(this.ctx,this.canvas,this.tableTop);
    this.ball.update(); this.enemyBat.update();
    // depth sort mirrors game.js:4363
    if ((this.ball.offTable||this.ball.offSide) || (this.ball.height<0 && this.ball.tablePosY<0.5 && (this.ball.tablePosX<-1||this.ball.tablePosX>1))){
      this.ball.render(this.ctx); this.tableTop.render(this.canvas,this.ctx); this.enemyBat.render(this.ctx); this.tableTop.renderNet(this.canvas,this.ctx);
    } else if (this.ball.tablePosY>0.5){ this.tableTop.render(this.canvas,this.ctx); this.enemyBat.render(this.ctx); this.tableTop.renderNet(this.canvas,this.ctx); this.ball.render(this.ctx); }
    else { this.tableTop.render(this.canvas,this.ctx); this.enemyBat.render(this.ctx); this.ball.render(this.ctx); this.tableTop.renderNet(this.canvas,this.ctx); }
    this.userBat.update(this.delta); this.userBat.render(this.ctx,this.canvas);
    requestAnimationFrame(()=> this.updateGameEvent());
  }

  // -------------------------------------------------------------------------
  // Scoring (game.js:4121)
  // -------------------------------------------------------------------------
  private updateScore(player:'user'|'enemy'): void {
    if (player==='user'){
      this.oGameData.userScore++;
      if ((this.oGameData.userScore>=11 && this.oGameData.enemyScore <= this.oGameData.userScore-2) || this.oGameData.userScore===99)
        this.initGameComplete(true);
    } else {
      this.oGameData.enemyScore++;
      if ((this.oGameData.enemyScore>=11 && this.oGameData.userScore <= this.oGameData.enemyScore-2) || this.oGameData.enemyScore===99)
        this.initGameComplete(false);
    }
  }
  private initGameComplete(_won:boolean): void {
    this.gameState='gameComplete'; this.syncGlobals();
    // promotion mirrors game.js:4275
    if (_won){
      this.oGameData.gameId++;
      if (this.oGameData.gameId>=6){ this.oGameData.cupId++; this.justWonCup=true; if(this.oGameData.cupId>9){ this.oGameData.cupId=10; this.oGameData.gameId=6; } else this.oGameData.gameId=0; }
      this.saveDataHandler.setGameData(this.oGameData); this.saveDataHandler.saveData();
    }
  }

  // -------------------------------------------------------------------------
  // Input dispatch (subset of butEventHandler game.js:3722)
  // -------------------------------------------------------------------------
  butEventHandler(id:string, _data?: unknown): void {
    switch(id){
      case 'pause': this.gameState='pause'; this.syncGlobals(); break;
      case 'playFromPause': this.gameState='game'; this.syncGlobals(); this.previousTime=Date.now(); this.updateGameEvent(); break;
      case 'playFromStart': this.firstRun ? this.initChooseCountry() : this.initGameIntro(); break;
      case 'playFromGameIntro': this.initGame(); break;
      case 'changeCountryFromStart': this.initChooseCountry(); break;
      case 'cupsFromStart': this.initMapScreen(); break;
      default: break;
    }
  }
  private initChooseCountry(): void { this.gameState='chooseCountry'; this.syncGlobals(); }
  private initMapScreen(): void { this.gameState='map'; this.syncGlobals(); }

  resizeCanvas(): void {
    const w=window.innerWidth, h=window.innerHeight;
    this.canvas.height=h; this.canvas.width=w;
    this.canvas.style.width=w+'px'; this.canvas.style.height=h+'px';
    if (w>h){
      if (h<500){ this.canvas.height=500; this.canvas.width=500*(w/h); this.canvasScale=500/h; }
      else if (h>700){ this.canvas.height=700; this.canvas.width=700*(w/h); this.canvasScale=700/h; }
      else this.canvasScale=1;
    } else {
      if (w<500){ this.canvas.width=500; this.canvas.height=500*(h/w); this.canvasScale=500/w; }
      else if (w>700){ this.canvas.width=700; this.canvas.height=700*(h/w); this.canvasScale=700/w; }
      else this.canvasScale=1;
    }
    (window as unknown as Record<string,unknown>)['canvasScale']=this.canvasScale;
    window.scrollTo(0,0);
  }
}
