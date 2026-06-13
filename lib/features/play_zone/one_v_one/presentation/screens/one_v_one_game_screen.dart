import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../models/one_v_one_room.dart';
import '../../services/one_v_one_service.dart';

/// Two-paddle table-tennis game synced via Firestore listeners.
///
/// Roles:
///   * host  — authoritative: runs the ball simulation, writes the full
///             state back every ~80ms.
///   * guest — input only: writes its paddle y on drag; reads everything.
///
/// Both sides render the same CustomPaint from the latest `OneVOneRoom`.
/// We accept ~200-600ms latency in exchange for a free transport.
class OneVOneGameScreen extends StatefulWidget {
  const OneVOneGameScreen({
    super.key,
    required this.initialRoom,
  });

  final OneVOneRoom initialRoom;

  @override
  State<OneVOneGameScreen> createState() => _OneVOneGameScreenState();
}

class _OneVOneGameScreenState extends State<OneVOneGameScreen>
    with SingleTickerProviderStateMixin {
  // Geometry constants. Everything is in normalised 0..1 coordinates so
  // the painter scales cleanly to any aspect ratio.
  static const double _paddleHeightFrac = 0.18;
  static const double _paddleWidthFrac = 0.022;
  static const double _ballRadiusFrac = 0.018;
  static const double _paddleMaxSpeed = 1.4; // normalised y / sec
  static const double _ballBaseSpeed = 0.55; // normalised units / sec
  static const double _ballSpeedupPerHit = 1.06;
  static const double _ballMaxSpeed = 1.6;
  static const Duration _writeInterval = Duration(milliseconds: 80);
  static const Duration _frameInterval = Duration(milliseconds: 16);

  final OneVOneService _service = OneVOneService();

  late final String? _localUid;
  late final bool _isHost;

  OneVOneRoom _room = _EmptyRoom();

  /// Most recent state we wrote. Used to compute simulation deltas in
  /// the host's local sim and to drop stale Firestore updates.
  OneVOneRoom _lastWrittenRoom = _EmptyRoom();

  /// Local paddle y, normalised 0..1. Driven by drag input.
  double _localPaddleY = 0.5;
  double _localPaddleV = 0;

  /// Previous-frame local paddle y, used to estimate velocity for spin.
  double _prevLocalPaddleY = 0.5;
  DateTime _prevInputAt = DateTime.now();

  late final AnimationController _renderCtl;
  Timer? _writeTimer;
  StreamSubscription<OneVOneRoom?>? _roomSub;

  bool _finished = false;
  bool _hostExited = false;
  bool _leaving = false;

  // --- Bookkeeping for the host's local sim ----------------------------
  // The host advances ball physics locally between Firestore writes so
  // motion is smooth. We persist every `_writeInterval` so the guest
  // sees a smooth stream of authoritative frames.
  double _lastSimBallX = 0.5;
  double _lastSimBallY = 0.5;
  double _lastSimBallVx = 0;
  double _lastSimBallVy = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _localUid = auth.uid;
    _isHost = _localUid == widget.initialRoom.hostUid;

    _room = widget.initialRoom;
    _lastWrittenRoom = _room;
    _localPaddleY = _isHost ? _room.hostPaddle.y : _room.guestPaddle.y;
    _lastSimBallX = _room.ball.x;
    _lastSimBallY = _room.ball.y;
    _lastSimBallVx = _room.ball.vx;
    _lastSimBallVy = _room.ball.vy;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _renderCtl = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onRenderTick);
    _renderCtl.repeat();

    _writeTimer = Timer.periodic(_writeInterval, (_) => _flushLocalState());

    _roomSub = _service.watchRoom(_room.code).listen(_onRemoteRoom);
  }

  @override
  void dispose() {
    _writeTimer?.cancel();
    _roomSub?.cancel();
    _renderCtl.removeListener(_onRenderTick);
    _renderCtl.dispose();
    // Best-effort: mark abandoned if neither side has explicitly finished
    // and the host is leaving. Guest leaving is silent — the host's
    // tick will keep going until they too leave.
    if (_isHost && !_finished && !_hostExited) {
      _service.setStatus(
        code: _room.code,
        status: RoomStatus.abandoned,
      );
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ----- Firestore sync ------------------------------------------------

  void _onRemoteRoom(OneVOneRoom? remote) {
    if (remote == null || !mounted) return;
    // Stale-write guard: a write can come back to us from the server
    // *after* we've already advanced locally past it. We accept any
    // remote update whose lastTick is >= our last known tick.
    if (remote.lastTick < _lastWrittenRoom.lastTick) return;

    // Detect finished: when the host flips status to `finished` both
    // sides show the winner.
    if (remote.status == RoomStatus.finished && !_finished) {
      setState(() {
        _room = remote;
        _finished = true;
      });
      return;
    }

    setState(() {
      _room = remote;
      _lastWrittenRoom = remote;
      _lastSimBallX = remote.ball.x;
      _lastSimBallY = remote.ball.y;
      _lastSimBallVx = remote.ball.vx;
      _lastSimBallVy = remote.ball.vy;
    });
  }

  Future<void> _flushLocalState() async {
    if (!mounted) return;
    final paddle = PaddleState(y: _localPaddleY.clamp(0, 1), v: _localPaddleV);
    if (_isHost) {
      await _service.writeHostState(
        code: _room.code,
        localTick: ++_simTick,
        ball: _room.ball,
        hostPaddle: paddle,
        hostScore: _room.hostScore,
        guestScore: _room.guestScore,
        server: _room.server,
        status: _room.status,
        winnerUid: _room.winnerUid,
      );
    } else {
      await _service.writeGuestPaddle(
        code: _room.code,
        localTick: ++_simTick,
        guestPaddle: paddle,
      );
    }
  }

  // Tick counter is split between host and guest only because the
  // service reads `lastTick` on every transaction; both sides
  // monotonically increment.
  int _simTick = 0;

  // ----- Render + input ------------------------------------------------

  void _onRenderTick() {
    if (_finished) return;
    if (_isHost) {
      _advanceHostSim(_frameInterval.inMicroseconds / 1e6);
    }
    // Drive a setState every frame so the painter re-renders. We use
    // a tiny marker field on `mounted` checks only — the actual data
    // shown is the latest _room.
    if (mounted) setState(() {});
  }

  /// Host-side physics. We integrate ball motion in normalised units.
  /// On paddle hit: reflect vx, add a fraction of paddle velocity to vy
  /// for spin, and speed the ball up slightly.
  void _advanceHostSim(double dtSec) {
    if (_room.status != RoomStatus.inProgress) return;
    var bx = _lastSimBallX;
    var by = _lastSimBallY;
    var vx = _lastSimBallVx;
    var vy = _lastSimBallVy;
    // Cap dt to keep us stable after pauses / backgrounding.
    if (dtSec > 0.05) dtSec = 0.05;

    bx += vx * dtSec;
    by += vy * dtSec;

    // Top/bottom wall bounce. The play field is 0..1 in y.
    if (by < _ballRadiusFrac) {
      by = _ballRadiusFrac;
      vy = vy.abs();
    } else if (by > 1 - _ballRadiusFrac) {
      by = 1 - _ballRadiusFrac;
      vy = -vy.abs();
    }

    final paddleHalf = _paddleHeightFrac / 2;
    final hostPaddleY = _localPaddleY; // host controls the top paddle
    final guestPaddleY = _room.guestPaddle.y; // guest controls the bottom

    // Host paddle is the top paddle, anchored at y = _paddleWidthFrac/2.
    final hostPaddleX = _paddleWidthFrac / 2 + _paddleWidthFrac / 2;
    if (vx < 0 &&
        (bx - _ballRadiusFrac) <= hostPaddleX + _paddleWidthFrac / 2 &&
        (bx + _ballRadiusFrac) >= hostPaddleX - _paddleWidthFrac / 2 &&
        (by - _ballRadiusFrac) <= hostPaddleY + paddleHalf &&
        (by + _ballRadiusFrac) >= hostPaddleY - paddleHalf) {
      bx = hostPaddleX + _paddleWidthFrac / 2 + _ballRadiusFrac;
      vx = vx.abs();
      final offset = (by - hostPaddleY) / paddleHalf; // -1..1
      vy = vy * 0.5 + offset * 0.6;
      final speed = math.min(math.sqrt(vx * vx + vy * vy) * _ballSpeedupPerHit, _ballMaxSpeed);
      final ang = math.atan2(vy, vx);
      vx = math.cos(ang) * speed;
      vy = math.sin(ang) * speed;
    }

    // Guest paddle at the bottom.
    final guestPaddleX = 1 - hostPaddleX;
    if (vx > 0 &&
        (bx + _ballRadiusFrac) >= guestPaddleX - _paddleWidthFrac / 2 &&
        (bx - _ballRadiusFrac) <= guestPaddleX + _paddleWidthFrac / 2 &&
        (by - _ballRadiusFrac) <= guestPaddleY + paddleHalf &&
        (by + _ballRadiusFrac) >= guestPaddleY - paddleHalf) {
      bx = guestPaddleX - _paddleWidthFrac / 2 - _ballRadiusFrac;
      vx = -vx.abs();
      final offset = (by - guestPaddleY) / paddleHalf;
      vy = vy * 0.5 + offset * 0.6;
      final speed = math.min(math.sqrt(vx * vx + vy * vy) * _ballSpeedupPerHit, _ballMaxSpeed);
      final ang = math.atan2(vy, vx);
      vx = math.cos(ang) * speed;
      vy = math.sin(ang) * speed;
    }

    // Scoring: ball left the left edge = guest scores, right edge = host.
    var newHostScore = _room.hostScore;
    var newGuestScore = _room.guestScore;
    var server = _room.server;
    var status = _room.status;
    String? winnerUid;
    if (bx < 0) {
      newGuestScore += 1;
      bx = 0.5;
      by = 0.5;
      server = OneVOneSide.host; // host serves after losing
      vx = _ballBaseSpeed;
      vy = 0;
    } else if (bx > 1) {
      newHostScore += 1;
      bx = 0.5;
      by = 0.5;
      server = OneVOneSide.guest;
      vx = -_ballBaseSpeed;
      vy = 0;
    }

    if (newHostScore >= 11 || newGuestScore >= 11) {
      status = RoomStatus.finished;
      winnerUid = newHostScore > newGuestScore
          ? _room.hostUid
          : _room.guestUid ?? '';
      _finished = true;
    }

    _lastSimBallX = bx;
    _lastSimBallY = by;
    _lastSimBallVx = vx;
    _lastSimBallVy = vy;

    _room = _room.copyWith(
      ball: BallState(x: bx, y: by, vx: vx, vy: vy),
      hostScore: newHostScore,
      guestScore: newGuestScore,
      server: server,
      status: status,
      winnerUid: winnerUid,
    );
  }

  void _onPointerMove(PointerMoveEvent e, Size canvasSize) {
    if (canvasSize.height <= 0) return;
    final now = DateTime.now();
    final dt = now.difference(_prevInputAt).inMicroseconds / 1e6;
    _prevInputAt = now;
    final newY = (e.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    _localPaddleV = dt > 0 ? (newY - _prevLocalPaddleY) / dt : 0;
    if (_localPaddleV.abs() > _paddleMaxSpeed) {
      _localPaddleV = _localPaddleV.sign * _paddleMaxSpeed;
    }
    _prevLocalPaddleY = _localPaddleY;
    setState(() => _localPaddleY = newY);
  }

  void _onPointerDown(PointerDownEvent e, Size canvasSize) {
    if (canvasSize.height <= 0) return;
    _prevInputAt = DateTime.now();
    _prevLocalPaddleY = _localPaddleY;
    setState(() => _localPaddleY =
        (e.localPosition.dy / canvasSize.height).clamp(0, 1));
  }

  // ----- Build --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_finished && _room.status == RoomStatus.finished) {
      return _FinishedScreen(
        room: _room,
        isHost: _isHost,
        onPlayAgain: _isHost ? _requestRematch : null,
        onExit: _exitToHub,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHud(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _onPointerDown(e, size),
                    onPointerMove: (e) => _onPointerMove(e, size),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: CustomPaint(
                        painter: _CourtPainter(
                          room: _room,
                          isHost: _isHost,
                          localPaddleY: _localPaddleY,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _exitToHub,
            icon: const Icon(Icons.close_rounded, color: AppTheme.petalWhite),
          ),
          Expanded(
            child: _ScoreStrip(
              hostName: _room.hostName,
              guestName: _room.guestName ?? 'Clair',
              hostScore: _room.hostScore,
              guestScore: _room.guestScore,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Future<void> _exitToHub() async {
    if (_leaving) return;
    _leaving = true;
    if (_isHost && !_finished) {
      _hostExited = true;
      await _service.setStatus(
        code: _room.code,
        status: RoomStatus.abandoned,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _requestRematch() async {
    try {
      await _service.resetForRematch(code: _room.code);
      setState(() {
        _finished = false;
        _room = _room.copyWith(
          status: RoomStatus.inProgress,
          hostScore: 0,
          guestScore: 0,
          winnerUid: null,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start rematch: $e')),
        );
      }
    }
  }
}

// ----- Placeholder empty room -------------------------------------------

class _EmptyRoom extends OneVOneRoom {
  _EmptyRoom()
      : super(
          code: '____',
          hostUid: '',
          hostName: '',
          ball: BallState.serve(server: OneVOneSide.host),
          updatedAt: Timestamp.fromMillisecondsSinceEpoch(0),
        );
}

// Timestamp.zero is non-const, so we use a static const. We never
// actually use this in the UI — it only exists to satisfy the
// OneVOneRoom contract when the screen builds before any update.

// ----- Painter ---------------------------------------------------------

class _CourtPainter extends CustomPainter {
  _CourtPainter({
    required this.room,
    required this.isHost,
    required this.localPaddleY,
  });

  final OneVOneRoom room;
  final bool isHost;
  final double localPaddleY;

  @override
  void paint(Canvas canvas, Size size) {
    // Court background with Everglow palette.
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1a0f1a), Color(0xFF0a0508)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Centre line.
    final centre = Paint()
      ..color = AppTheme.petalWhite.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 12),
        centre,
      );
    }

    // Paddles.
    final paddlePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppTheme.warmAmber, AppTheme.deepRose],
      ).createShader(Offset.zero & size);
    final paddleWidth = size.width * _OneVOneGameScreenState._paddleWidthFrac;
    final paddleHeight = size.height * _OneVOneGameScreenState._paddleHeightFrac;

    final hostY = (isHost ? localPaddleY : room.guestPaddle.y) * size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(paddleWidth, hostY),
          width: paddleWidth,
          height: paddleHeight,
        ),
        const Radius.circular(8),
      ),
      paddlePaint,
    );

    final guestY =
        (isHost ? room.guestPaddle.y : localPaddleY) * size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width - paddleWidth, guestY),
          width: paddleWidth,
          height: paddleHeight,
        ),
        const Radius.circular(8),
      ),
      paddlePaint,
    );

    // Ball.
    final ball = Paint()..color = AppTheme.petalWhite;
    final radius = size.width * _OneVOneGameScreenState._ballRadiusFrac;
    canvas.drawCircle(
      Offset(room.ball.x * size.width, room.ball.y * size.height),
      radius,
      ball,
    );

    // "Your side" hint, top-left.
    final hint = TextPainter(
      text: TextSpan(
        text: isHost ? 'You · top' : 'You · bottom',
        style: TextStyle(
          color: AppTheme.petalWhite.withValues(alpha: 0.35),
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hint.paint(canvas, const Offset(12, 12));
  }

  @override
  bool shouldRepaint(covariant _CourtPainter old) =>
      old.room != room ||
      old.isHost != isHost ||
      old.localPaddleY != localPaddleY;
}

// ----- HUD widgets ------------------------------------------------------

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({
    required this.hostName,
    required this.guestName,
    required this.hostScore,
    required this.guestScore,
  });

  final String hostName;
  final String guestName;
  final int hostScore;
  final int guestScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.blushGold.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ScoreCell(name: hostName, score: hostScore, accent: AppTheme.warmAmber),
          Text(
            '—',
            style: GoogleFonts.cormorantGaramond(
              color: AppTheme.petalWhite.withValues(alpha: 0.5),
              fontSize: 20,
            ),
          ),
          _ScoreCell(
            name: guestName,
            score: guestScore,
            accent: AppTheme.roseQuartz,
            alignEnd: true,
          ),
        ],
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.name,
    required this.score,
    required this.accent,
    this.alignEnd = false,
  });
  final String name;
  final int score;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.6),
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          '$score',
          style: GoogleFonts.cormorantGaramond(
            color: accent,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ----- Match end screen ------------------------------------------------

class _FinishedScreen extends StatelessWidget {
  const _FinishedScreen({
    required this.room,
    required this.isHost,
    required this.onPlayAgain,
    required this.onExit,
  });

  final OneVOneRoom room;
  final bool isHost;
  final VoidCallback? onPlayAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final iAmWinner = isHost
        ? room.winnerUid == room.hostUid
        : room.winnerUid != null && room.winnerUid != room.hostUid;
    final winnerName = room.winnerUid == room.hostUid
        ? room.hostName
        : room.guestName ?? 'Clair';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iAmWinner ? Icons.emoji_events_rounded : Icons.handshake_rounded,
                  size: 72,
                  color: iAmWinner ? AppTheme.warmAmber : AppTheme.deepRose,
                ),
                const SizedBox(height: 12),
                Text(
                  iAmWinner ? 'You win' : '$winnerName wins',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 38,
                    color: AppTheme.petalWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${room.hostScore} – ${room.guestScore}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 30,
                    color: AppTheme.blushGold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onPlayAgain != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FilledButton(
                          onPressed: onPlayAgain,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.warmAmber,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                          ),
                          child: Text(
                            'Play again',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: OutlinedButton(
                        onPressed: onExit,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          side: const BorderSide(color: AppTheme.blushGold),
                        ),
                        child: Text(
                          'Back to hub',
                          style: GoogleFonts.outfit(
                            color: AppTheme.petalWhite,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
