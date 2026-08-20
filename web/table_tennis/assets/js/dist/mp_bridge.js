export function installMPHooks() {
    const TT = {
        enabled: false, isHost: false, localSide: 'near',
        _remotePaddleY: 0.5, _remoteBallState: { x: 0, y: 0, vx: 0, vy: 0 },
        _localPaddleY: 0.5, _hostScore: 0, _guestScore: 0,
        setRemotePaddleY(y) { TT._remotePaddleY = y; },
        setRemoteBallState(x, y, vx, vy) { TT._remoteBallState = { x, y, vx, vy }; },
        getLocalPaddleY() { return TT._localPaddleY; },
        setLocalPaddleY(y) { TT._localPaddleY = y; },
        getLocalBallState() {
            const ball = window.ball;
            if (!ball)
                return { x: 0, y: 0, vx: 0, vy: 0 };
            return { x: ball.x, y: ball.y, vx: ball.tableVX, vy: ball.tableVY };
        },
        disableAI() {
            const eb = window.enemyBat;
            if (eb)
                eb.trackBall = false;
        },
        startMatch(isHost, side) { TT.enabled = true; TT.isHost = isHost; TT.localSide = side; TT._hostScore = 0; TT._guestScore = 0; TT.disableAI(); },
        endMatch() { TT.enabled = false; TT._hostScore = 0; TT._guestScore = 0; },
        syncScore(h, g) { TT._hostScore = h; TT._guestScore = g; },
        getScores() { return { hostScore: TT._hostScore, guestScore: TT._guestScore }; },
    };
    window.TTMultiplayer = TT;
    // bridge: listen for REMOTE_* from Flutter, emit LOCAL_* each frame
    const isMP = window.location.search.includes('mode=mp');
    if (!isMP)
        return TT;
    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d?.type)
            return;
        switch (d.type) {
            case 'REMOTE_PADDLE':
                TT.setRemotePaddleY(d.y ?? 0.5);
                break;
            case 'REMOTE_BALL':
                TT.setRemoteBallState(d.x ?? 0, d.y ?? 0, d.vx ?? 0, d.vy ?? 0);
                break;
            case 'REMOTE_SCORE':
                TT.syncScore(d.hostScore ?? 0, d.guestScore ?? 0);
                break;
            case 'START_MP':
                TT.startMatch(!!d.isHost, d.side ?? 'near');
                break;
            case 'END_MP':
                TT.endMatch();
                break;
        }
    });
    const sendLoop = () => {
        if (TT.enabled && window.parent) {
            window.parent.postMessage({ type: 'LOCAL_PADDLE', y: TT.getLocalPaddleY() }, '*');
            if (TT.isHost) {
                const b = TT.getLocalBallState();
                window.parent.postMessage({ type: 'LOCAL_BALL', x: b.x, y: b.y, vx: b.vx, vy: b.vy }, '*');
            }
        }
        requestAnimationFrame(sendLoop);
    };
    requestAnimationFrame(sendLoop);
    return TT;
}
//# sourceMappingURL=mp_bridge.js.map