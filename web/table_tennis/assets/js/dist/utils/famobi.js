/** Typed Famobi stub — replaces window.famobi_* globals.
 *  Original: web/table_tennis/assets/js/famobi-stub.js + custom.js
 */
export function getFamobi() {
    const w = window;
    if (!w.famobi) {
        const stub = {
            config: { features: {
                    skip_title: false, external_start: false, external_mute: true,
                    external_pause: false, lockPointer: false, credits: false,
                } },
            hasFeature: (f) => !!stub.config.features[f],
            hasRewardedAd: () => false,
            rewardedAd: (cb) => cb({ adDidLoad: false, adDidShow: false, rewardGranted: false }),
            onRequest: (_k, _fn) => { }, offRequest: (_k) => { },
            getVolume: () => 1, setVolume: (_v) => { },
            getMoreGamesButtonImage: () => 'images/BrandingPlaceholderButton.png',
            moreGamesLink: () => { }, gameReady: () => { }, playerReady: () => { },
            setPreloadProgress: (_p) => { }, localStorage: window.localStorage,
            sessionStorage: window.sessionStorage, log: () => { }, showAd: (cb) => cb(),
        };
        w.famobi = stub;
    }
    return w.famobi;
}
export function ensureAnalytics() {
    const w = window;
    if (!w.famobi_analytics) {
        w.famobi_analytics = {
            trackEvent: () => Promise.resolve(),
            trackScreen: () => { }, trackStats: () => { },
            EVENT_LEVELSTART: 'event/level/start', EVENT_LEVELEND: 'event/level/end',
            EVENT_LEVELRESTART: 'event/level/restart', EVENT_LEVELFAIL: 'event/level/fail',
            EVENT_LEVELSUCCESS: 'event/level/success', EVENT_TOTALSCORE: 'EVENT_TOTALSCORE',
            EVENT_LIVESCORE: 'EVENT_LIVESCORE', EVENT_VOLUMECHANGE: 'EVENT_VOLUMECHANGE',
            SCREEN_HOME: 'home', SCREEN_CREDITS: 'credits', SCREEN_LEVELINTRO: 'levelintro',
            SCREEN_LEVEL: 'level', SCREEN_PAUSE: 'pause', SCREEN_LEVELRESULT: 'levelresult',
        };
    }
    return w.famobi_analytics;
}
//# sourceMappingURL=famobi.js.map