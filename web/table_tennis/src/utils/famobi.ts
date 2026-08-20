/** Typed Famobi stub — replaces window.famobi_* globals.
 *  Original: web/table_tennis/assets/js/famobi-stub.js + custom.js
 */

export type FamobiFeature = 'skip_title' | 'external_start' | 'external_mute' | 'external_pause' | 'lockPointer' | 'credits';

export interface FamobiConfig {
  features: Record<FamobiFeature, boolean>;
}

export interface FamobiAnalytics {
  trackEvent(event: string, params?: Record<string, unknown>): Promise<void>;
  trackScreen(screen: string): void;
  trackStats(key: string, value?: unknown): void;
  EVENT_LEVELSTART: string; EVENT_LEVELEND: string;
  EVENT_LEVELRESTART: string; EVENT_LEVELFAIL: string;
  EVENT_LEVELSUCCESS: string; EVENT_TOTALSCORE: string;
  EVENT_LIVESCORE: string; EVENT_VOLUMECHANGE: string;
  SCREEN_HOME: string; SCREEN_CREDITS: string;
  SCREEN_LEVELINTRO: string; SCREEN_LEVEL: string;
  SCREEN_PAUSE: string; SCREEN_LEVELRESULT: string;
}

export interface Famobi {
  config: FamobiConfig;
  hasFeature(f: string): boolean;
  hasRewardedAd(): boolean;
  rewardedAd(cb: (r: {adDidLoad:boolean; adDidShow:boolean; rewardGranted:boolean})=>void): void;
  onRequest(key: string, fn: (...a: unknown[])=>void): void;
  offRequest(key: string): void;
  getVolume(): number; setVolume(v: number): void;
  getMoreGamesButtonImage(): string;
  moreGamesLink(): void;
  gameReady(): void; playerReady(): void;
  setPreloadProgress(p: number): void;
  localStorage: Storage; sessionStorage: Storage;
  pointerLockHelper?: { mousePos: { x:number; y:number } };
  log(...a: unknown[]): void; showAd(cb: ()=>void): void;
}

declare global {
  interface Window {
    famobi: Famobi;
    famobi_analytics: FamobiAnalytics;
    famobi_tracking: { init():void; trackEvent(e:string,p?:unknown):void; EVENTS: Record<string,string> };
    famobi_gameID: string;
    famobi_gameJS: unknown[];
    famobi_onPauseRequested?: ()=>void;
    famobi_onResumeRequested?: ()=>void;
    lechuck: { stat: { put(cb:(r:unknown)=>void, key:string, val:number): void } };
  }
}

export function getFamobi(): Famobi {
  const w = window as unknown as Window & { famobi: Famobi };
  if (!w.famobi) {
    const stub: Famobi = {
      config: { features: {
        skip_title:false, external_start:false, external_mute:true,
        external_pause:false, lockPointer:false, credits:false,
      }},
      hasFeature: (f)=> !!(stub.config.features as Record<string,boolean>)[f],
      hasRewardedAd: ()=> false,
      rewardedAd: (cb)=> cb({adDidLoad:false, adDidShow:false, rewardGranted:false}),
      onRequest: (_k,_fn)=>{}, offRequest: (_k)=>{},
      getVolume: ()=>1, setVolume: (_v)=>{},
      getMoreGamesButtonImage: ()=> 'images/BrandingPlaceholderButton.png',
      moreGamesLink: ()=>{}, gameReady: ()=>{}, playerReady: ()=>{},
      setPreloadProgress: (_p)=>{}, localStorage: window.localStorage,
      sessionStorage: window.sessionStorage, log: ()=>{}, showAd: (cb)=> cb(),
    };
    w.famobi = stub;
  }
  return w.famobi;
}

export function ensureAnalytics(): FamobiAnalytics {
  const w = window as unknown as { famobi_analytics: FamobiAnalytics };
  if (!w.famobi_analytics) {
    w.famobi_analytics = {
      trackEvent: ()=> Promise.resolve(),
      trackScreen: ()=>{}, trackStats: ()=>{},
      EVENT_LEVELSTART:'event/level/start', EVENT_LEVELEND:'event/level/end',
      EVENT_LEVELRESTART:'event/level/restart', EVENT_LEVELFAIL:'event/level/fail',
      EVENT_LEVELSUCCESS:'event/level/success', EVENT_TOTALSCORE:'EVENT_TOTALSCORE',
      EVENT_LIVESCORE:'EVENT_LIVESCORE', EVENT_VOLUMECHANGE:'EVENT_VOLUMECHANGE',
      SCREEN_HOME:'home', SCREEN_CREDITS:'credits', SCREEN_LEVELINTRO:'levelintro',
      SCREEN_LEVEL:'level', SCREEN_PAUSE:'pause', SCREEN_LEVELRESULT:'levelresult',
    } as FamobiAnalytics;
  }
  return w.famobi_analytics;
}
