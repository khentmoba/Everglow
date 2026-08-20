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
    EVENT_LEVELSTART: string;
    EVENT_LEVELEND: string;
    EVENT_LEVELRESTART: string;
    EVENT_LEVELFAIL: string;
    EVENT_LEVELSUCCESS: string;
    EVENT_TOTALSCORE: string;
    EVENT_LIVESCORE: string;
    EVENT_VOLUMECHANGE: string;
    SCREEN_HOME: string;
    SCREEN_CREDITS: string;
    SCREEN_LEVELINTRO: string;
    SCREEN_LEVEL: string;
    SCREEN_PAUSE: string;
    SCREEN_LEVELRESULT: string;
}
export interface Famobi {
    config: FamobiConfig;
    hasFeature(f: string): boolean;
    hasRewardedAd(): boolean;
    rewardedAd(cb: (r: {
        adDidLoad: boolean;
        adDidShow: boolean;
        rewardGranted: boolean;
    }) => void): void;
    onRequest(key: string, fn: (...a: unknown[]) => void): void;
    offRequest(key: string): void;
    getVolume(): number;
    setVolume(v: number): void;
    getMoreGamesButtonImage(): string;
    moreGamesLink(): void;
    gameReady(): void;
    playerReady(): void;
    setPreloadProgress(p: number): void;
    localStorage: Storage;
    sessionStorage: Storage;
    pointerLockHelper?: {
        mousePos: {
            x: number;
            y: number;
        };
    };
    log(...a: unknown[]): void;
    showAd(cb: () => void): void;
}
declare global {
    interface Window {
        famobi: Famobi;
        famobi_analytics: FamobiAnalytics;
        famobi_tracking: {
            init(): void;
            trackEvent(e: string, p?: unknown): void;
            EVENTS: Record<string, string>;
        };
        famobi_gameID: string;
        famobi_gameJS: unknown[];
        famobi_onPauseRequested?: () => void;
        famobi_onResumeRequested?: () => void;
        lechuck: {
            stat: {
                put(cb: (r: unknown) => void, key: string, val: number): void;
            };
        };
    }
}
export declare function getFamobi(): Famobi;
export declare function ensureAnalytics(): FamobiAnalytics;
//# sourceMappingURL=famobi.d.ts.map