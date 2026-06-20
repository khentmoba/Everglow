(function () {
  var isMP = window.location.search.indexOf('mode=mp') !== -1;
  if (!isMP) return;

  var TT = window.TTMultiplayer;
  if (!TT) return;

  var sendFrame = null;

  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || !d.type) return;

    switch (d.type) {
      case 'REMOTE_PADDLE':
        TT.setRemotePaddleY(d.y);
        break;
      case 'REMOTE_BALL':
        TT.setRemoteBallState(d.x, d.y, d.vx, d.vy);
        break;
      case 'REMOTE_SCORE':
        TT.syncScore(d.hostScore, d.guestScore);
        break;
      case 'START_MP':
        TT.startMatch(d.isHost, d.side);
        break;
      case 'END_MP':
        TT.endMatch();
        break;
    }
  });

  (function sendLoop() {
    if (TT.enabled && parent) {
      var paddle = TT.getLocalPaddleY();
      parent.postMessage({ type: 'LOCAL_PADDLE', y: paddle }, '*');

      if (TT.isHost) {
        var ball = TT.getLocalBallState();
        parent.postMessage({
          type: 'LOCAL_BALL',
          x: ball.x, y: ball.y, vx: ball.vx, vy: ball.vy
        }, '*');
      }
    }
    sendFrame = requestAnimationFrame(sendLoop);
  })();
})();
