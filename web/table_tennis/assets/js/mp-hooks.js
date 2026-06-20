(function () {
  var TT = window.TTMultiplayer = {
    enabled: false,
    isHost: false,
    localSide: 'near',
    _remotePaddleY: 0.5,
    _remoteBallState: { x: 0, y: 0, vx: 0, vy: 0 },
    _localPaddleY: 0.5,
    _hostScore: 0,
    _guestScore: 0,
    _onScoreCallback: null,
    _onMatchEndCallback: null,

    setRemotePaddleY: function (y) {
      TT._remotePaddleY = y;
    },

    setRemoteBallState: function (x, y, vx, vy) {
      TT._remoteBallState = { x: x, y: y, vx: vx, vy: vy };
    },

    getLocalPaddleY: function () {
      return TT._localPaddleY;
    },

    setLocalPaddleY: function (y) {
      TT._localPaddleY = y;
    },

    getLocalBallState: function () {
      if (typeof ball === 'undefined') return { x: 0, y: 0, vx: 0, vy: 0 };
      return { x: ball.x, y: ball.y, vx: ball.tableVX, vy: ball.tableVY };
    },

    onPointScored: function (scorer) {
      if (TT._onScoreCallback) TT._onScoreCallback(scorer);
    },

    getScoreCallback: function () {
      return TT._onScoreCallback;
    },

    disableAI: function () {
      if (typeof enemyBat !== 'undefined') {
        enemyBat.trackBall = false;
      }
    },

    startMatch: function (isHost, side) {
      TT.enabled = true;
      TT.isHost = isHost;
      TT.localSide = side;
      TT._hostScore = 0;
      TT._guestScore = 0;
      TT.disableAI();
    },

    endMatch: function () {
      TT.enabled = false;
      TT._hostScore = 0;
      TT._guestScore = 0;
    },

    syncScore: function (hostScore, guestScore) {
      TT._hostScore = hostScore;
      TT._guestScore = guestScore;
    },

    getScores: function () {
      return { hostScore: TT._hostScore, guestScore: TT._guestScore };
    }
  };
})();
