(function () {
  var famobi = window.famobi || {};

  famobi.config = famobi.config || {};
  famobi.config.features = famobi.config.features || {};
  famobi.config.features.external_mute = true;
  famobi.config.features.skip_title = false;
  famobi.config.features.external_start = false;
  famobi.config.features.external_pause = false;
  famobi.config.features.lockPointer = false;
  famobi.config.features.credits = false;

  famobi.hasFeature = function (feat) {
    return !!famobi.config.features[feat];
  };

  famobi.localStorage = window.localStorage;
  famobi.sessionStorage = window.sessionStorage;

  famobi.getVolume = function () { return 1.0; };
  famobi.setVolume = function (v) {
    if (typeof Howler !== 'undefined') Howler.volume(v);
  };

  famobi.log = function () {};
  famobi.gameReady = function () {};
  famobi.showAd = function (cb) { if (typeof cb === 'function') cb(); };
  famobi.playerReady = function () {};
  famobi.setPreloadProgress = function () {};

  var _requestMap = {};
  famobi.onRequest = function (key, fn) { _requestMap[key] = fn; };
  famobi.offRequest = function (key) { delete _requestMap[key]; };

  famobi.hasRewardedAd = function () { return false; };
  famobi.rewardedAd = function (cb) {
    if (typeof cb === 'function') cb({ adDidLoad: false, adDidShow: false, rewardGranted: false });
  };

  famobi.pointerLockHelper = {
    mousePos: { x: window.innerWidth / 2, y: window.innerHeight / 2 }
  };

  window.famobi = famobi;
  window.famobi_onPauseRequested = function () {};
  window.famobi_onResumeRequested = function () {};

  window.famobi_analytics = {
    trackEvent: function () { return Promise.resolve(); },
    trackScreen: function () {},
    trackStats: function () {},
    EVENT_LEVELSTART: 'event/level/start',
    EVENT_LEVELEND: 'event/level/end',
    EVENT_LEVELRESTART: 'event/level/restart',
    EVENT_LEVELFAIL: 'event/level/fail',
    EVENT_LEVELSUCCESS: 'event/level/success',
    EVENT_TOTALSCORE: 'EVENT_TOTALSCORE',
    EVENT_LIVESCORE: 'EVENT_LIVESCORE',
    EVENT_VOLUMECHANGE: 'EVENT_VOLUMECHANGE',
    SCREEN_HOME: 'home',
    SCREEN_CREDITS: 'credits',
    SCREEN_LEVELINTRO: 'levelintro',
    SCREEN_LEVEL: 'level',
    SCREEN_PAUSE: 'pause',
    SCREEN_LEVELRESULT: 'levelresult'
  };

  window.famobi_tracking = {
    init: function () {},
    trackEvent: function () {},
    EVENTS: {
      LEVEL_START: 'event/level/start',
      LEVEL_END: 'event/level/end',
      LEVEL_UPDATE: 'event/level/update',
      PING: 'event/ping',
      AD: 'event/ad'
    }
  };

  window.lechuck = {
    stat: {
      put: function (cb) {
        if (typeof cb === 'function') cb({});
      }
    }
  };
})();
