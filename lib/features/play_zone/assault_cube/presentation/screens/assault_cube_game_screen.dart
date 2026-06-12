import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../game/assault_game.dart';
import '../../models/assault_match.dart';
import '../../models/assault_player_state.dart';
import '../../services/assault_match_service.dart';
import '../widgets/assault_game_painter.dart';
import '../widgets/twin_stick_joystick.dart' as tsj;
import 'assault_cube_results_screen.dart';

class AssaultCubeGameScreen extends StatefulWidget {
  final String mode; // 'solo' or 'multi'
  final String? matchId;
  final String? userId;

  const AssaultCubeGameScreen({
    super.key,
    required this.mode,
    this.matchId,
    this.userId,
  });

  @override
  State<AssaultCubeGameScreen> createState() => _AssaultCubeGameScreenState();
}

class _AssaultCubeGameScreenState extends State<AssaultCubeGameScreen>
    with SingleTickerProviderStateMixin {
  late final AssaultGame _game;
  late final Ticker _ticker;
  final AssaultMatchService _matchService = AssaultMatchService();

  late final Player _localPlayer;
  Player? _remotePlayer;

  final JoystickAxis _moveInput = JoystickAxis();
  final JoystickAxis _aimInput = JoystickAxis();
  bool _firePressed = false;

  // Stream subscriptions for multiplayer syncing
  StreamSubscription<DocumentSnapshot>? _opponentStateSub;
  StreamSubscription<QuerySnapshot>? _shotsSub;
  StreamSubscription<DocumentSnapshot>? _matchSub;

  // Syncing timer for uploading local state
  Timer? _stateSyncTimer;
  DateTime? _lastShotSyncTime;

  // Visual effects
  double _damageFlashOpacity = 0.0;
  int _lastPlayerHp = 100;
  final List<List<Offset>> _muzzleFlashes = [];

  bool _initialized = false;
  String? _opponentId;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final isSolo = widget.mode == 'solo';
    _game = AssaultGame(mode: isSolo ? GameMode.solo : GameMode.multiplayer);

    final String localId = widget.userId ?? 'player_local';
    final String localName = widget.mode == 'solo' ? 'Khent' : _getLocalName(localId);
    final isHost = widget.matchId == null || _isHost(localId);

    // Determine colors
    final localColor = localId == AuthService.khentUid ? AppTheme.deepRose : AppTheme.softLavender;
    final localAccent = localId == AuthService.khentUid ? AppTheme.blushGold : AppTheme.roseQuartz;

    // Set starting positions
    final localStartX = isHost ? 150.0 : 850.0;
    final localStartY = isHost ? 150.0 : 850.0;

    _localPlayer = Player(
      id: localId,
      displayName: localName,
      x: localStartX,
      y: localStartY,
      color: localColor,
      accentColor: localAccent,
      isLocal: true,
    );
    _game.addPlayer(_localPlayer);

    _lastPlayerHp = _localPlayer.hp;

    if (!isSolo && widget.matchId != null) {
      _opponentId = _getOpponentId(localId);
      final oppColor = _opponentId == AuthService.khentUid ? AppTheme.deepRose : AppTheme.softLavender;
      final oppAccent = _opponentId == AuthService.khentUid ? AppTheme.blushGold : AppTheme.roseQuartz;
      final oppStartX = isHost ? 850.0 : 150.0;
      final oppStartY = isHost ? 850.0 : 150.0;

      _remotePlayer = Player(
        id: _opponentId!,
        displayName: _opponentId == AuthService.khentUid ? 'Khent' : 'Clair',
        x: oppStartX,
        y: oppStartY,
        color: oppColor,
        accentColor: oppAccent,
        isLocal: false,
      );
      _game.addPlayer(_remotePlayer!);

      _setupMultiplayerSync();
    }

    // Connect bullet shot triggers
    _game.onLocalShotFired = (bullet) {
      // Create muzzle flash particle locally
      final muzzleDistance = _game.config.playerRadius + 4;
      final flashX = _localPlayer.x + math.cos(_localPlayer.angle) * muzzleDistance;
      final flashY = _localPlayer.y + math.sin(_localPlayer.angle) * muzzleDistance;
      _spawnFlash(Offset(flashX, flashY));

      if (widget.mode == 'multi' && widget.matchId != null) {
        final shot = AssaultShot(
          id: '${_localPlayer.id}_${DateTime.now().microsecondsSinceEpoch}',
          shooterId: _localPlayer.id,
          originX: bullet.x,
          originY: bullet.y,
          angle: bullet.angle,
          speed: bullet.speed,
          damage: bullet.damage,
          range: bullet.range,
          createdAt: DateTime.now(),
        );
        _matchService.pushShot(widget.matchId!, shot);
      }
    };

    _game.onLocalDamageDealt = (event) {
      if (widget.mode == 'multi' && widget.matchId != null) {
        final victim = _game.players[event.victimId];
        if (victim != null) {
          _matchService.applyDamage(
            matchId: widget.matchId!,
            victimId: event.victimId,
            newHp: victim.hp,
          );
        }
      }
    };

    // Game loop ticker
    _ticker = createTicker((duration) {
      if (!mounted) return;
      // Calculate delta time
      final dt = 1 / 60.0; 
      setState(() {
        _game.update(
          dt,
          moveInput: _moveInput,
          aimInput: _aimInput,
          firePressed: _firePressed,
          localPlayerId: _localPlayer.id,
        );

        // Check if player took damage
        if (_localPlayer.hp < _lastPlayerHp) {
          _damageFlashOpacity = 0.5;
          _lastPlayerHp = _localPlayer.hp;
        }

        // Fade damage flash
        if (_damageFlashOpacity > 0.05) {
          _damageFlashOpacity -= dt * 3.0;
        } else {
          _damageFlashOpacity = 0.0;
        }

        // Clean stale muzzle flashes
        if (_muzzleFlashes.isNotEmpty) {
          _muzzleFlashes.removeAt(0);
        }
      });

      if (_game.isFinished && widget.mode == 'solo') {
        _ticker.stop();
        _showSoloGameOver();
      }
    });

    _ticker.start();
    _initialized = true;
  }

  void _spawnFlash(Offset pt) {
    setState(() {
      _muzzleFlashes.add([
        pt,
        pt + Offset(math.Random().nextDouble() * 4 - 2, math.Random().nextDouble() * 4 - 2),
      ]);
    });
  }

  bool _isHost(String localId) {
    // If the local player's ID matches the host ID in the match, we are host.
    // By default, Khent is the host or we look up hostId in the match document.
    // Let's assume the host starting position is checked during actual matchmaking.
    return localId == AuthService.khentUid;
  }

  String _getLocalName(String uid) {
    if (uid == AuthService.clairUid) return 'Clair';
    if (uid == AuthService.khentUid) return 'Khent';
    return 'Player';
  }

  String _getOpponentId(String uid) {
    if (uid == AuthService.khentUid) return AuthService.clairUid;
    return AuthService.khentUid;
  }

  void _setupMultiplayerSync() {
    if (widget.matchId == null || _opponentId == null) return;

    // 1. Sync opponent positions/angles/HP
    _opponentStateSub = _matchService.watchOpponentState(widget.matchId!, _opponentId!).listen((snap) {
      if (!mounted || !snap.exists) return;
      final map = snap.data() as Map<String, dynamic>?;
      if (map == null) return;
      final oppState = AssaultPlayerState.fromMap(map);

      setState(() {
        if (_remotePlayer != null) {
          _remotePlayer!.x = oppState.x;
          _remotePlayer!.y = oppState.y;
          _remotePlayer!.angle = oppState.angle;
          _remotePlayer!.hp = oppState.hp;
          _remotePlayer!.kills = oppState.kills;
          _remotePlayer!.alive = oppState.alive;
        }
      });
    });

    // 2. Sync opponent shot bullets
    _lastShotSyncTime = DateTime.now().subtract(const Duration(seconds: 2));
    _shotsSub = _matchService.watchShots(widget.matchId!, since: _lastShotSyncTime).listen((snap) {
      if (!mounted) return;
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final shotMap = change.doc.data() as Map<String, dynamic>?;
          if (shotMap == null) continue;
          final shot = AssaultShot.fromMap(shotMap);
          if (shot.shooterId == _localPlayer.id) continue;

          // Register bullet locally
          _game.registerRemoteShot(
            shooterId: shot.shooterId,
            originX: shot.originX,
            originY: shot.originY,
            angle: shot.angle,
            speed: shot.speed,
            damage: shot.damage,
            range: shot.range,
            createdAtMs: shot.createdAt.millisecondsSinceEpoch,
          );

          // Draw muzzle flash for remote shot
          final muzzleDistance = _game.config.playerRadius + 4;
          final flashX = shot.originX + math.cos(shot.angle) * muzzleDistance;
          final flashY = shot.originY + math.sin(shot.angle) * muzzleDistance;
          _spawnFlash(Offset(flashX, flashY));
        }
      }
    });

    // 3. Listen to match status changes (victory/rematch)
    _matchSub = _matchService.watchMatch(widget.matchId!).listen((snap) {
      if (!mounted || !snap.exists) return;
      final match = AssaultMatch.fromFirestore(snap);

      if (match.status == AssaultMatchStatus.finished) {
        _ticker.stop();
        _goToResults(match);
      } else if (match.status == AssaultMatchStatus.active && _game.isFinished) {
        // Rematch triggered! Reset local simulation.
        setState(() {
          _game.reset();
          _localPlayer.x = _isHost(_localPlayer.id) ? 150.0 : 850.0;
          _localPlayer.y = _isHost(_localPlayer.id) ? 150.0 : 850.0;
          _lastPlayerHp = 100;
          _ticker.start();
        });
      }
    });

    // 4. Timer to upload our state to Firestore periodically
    _stateSyncTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted || _game.isFinished) return;
      final state = AssaultPlayerState(
        userId: _localPlayer.id,
        x: _localPlayer.x,
        y: _localPlayer.y,
        angle: _localPlayer.angle,
        hp: _localPlayer.hp,
        kills: _localPlayer.kills,
        alive: _localPlayer.alive,
        lastUpdate: DateTime.now(),
      );
      _matchService.updatePlayerState(widget.matchId!, state);
    });
  }

  void _goToResults(AssaultMatch match) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AssaultCubeResultsScreen(
          match: match,
          userId: _localPlayer.id,
        ),
      ),
    );
  }

  void _showSoloGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.velvet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
        title: Text(
          'Practice Complete',
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.roseQuartz,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_fixed_rounded, size: 64, color: AppTheme.blushGold),
            const SizedBox(height: 16),
            Text(
              'Targets Destroyed: ${_game.score}',
              style: GoogleFonts.outfit(color: AppTheme.petalWhite, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Exit Hub',
              style: GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _game.reset();
                _ticker.start();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepRose),
            child: Text('Play Again', style: GoogleFonts.outfit(color: AppTheme.petalWhite)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stateSyncTimer?.cancel();
    _opponentStateSub?.cancel();
    _shotsSub?.cancel();
    _matchSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Center camera on local player
    final cameraX = _localPlayer.x;
    final cameraY = _localPlayer.y;

    // Responsive scaling
    final scale = (screenW < screenH ? screenW : screenH) / 360.0;

    return Scaffold(
      body: Stack(
        children: [
          // Game Canvas
          Positioned.fill(
            child: ClipRect(
              child: CustomPaint(
                painter: AssaultGamePainter(
                  game: _game,
                  cameraX: cameraX,
                  cameraY: cameraY,
                  scale: scale.clamp(1.0, 2.0),
                  localId: _localPlayer.id,
                  muzzleFlashes: _muzzleFlashes,
                ),
              ),
            ),
          ),

          // Red Screen Damage Flash
          if (_damageFlashOpacity > 0.0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.red.withValues(alpha: _damageFlashOpacity),
                ),
              ),
            ),

          // HUD & Control Overlays
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar: HP, Kills, Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Side: Close and HP
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (widget.mode == 'multi' && widget.matchId != null) {
                                  _matchService.resignMatch(widget.matchId!);
                                }
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.moonlight.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.moonlight.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: AppTheme.petalWhite, size: 24),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // HP Bar Container
                            Container(
                              width: 140,
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppTheme.moonlight.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.favorite_rounded,
                                      color: AppTheme.deepRose, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (_localPlayer.hp / _localPlayer.maxHp).clamp(0.0, 1.0),
                                        backgroundColor: AppTheme.moonlight.withValues(alpha: 0.2),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _localPlayer.hp > 40
                                              ? AppTheme.softLavender
                                              : AppTheme.deepRose,
                                        ),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_localPlayer.hp}',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.petalWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Right Side: Kills / Score Display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.deepRose, AppTheme.velvet],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.deepRose.withValues(alpha: 0.25),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.mode == 'solo' ? Icons.gps_fixed_rounded : Icons.military_tech_rounded,
                                color: AppTheme.blushGold,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.mode == 'solo'
                                    ? 'SCORE: ${_game.score}'
                                    : 'KILLS: ${_localPlayer.kills}',
                                style: GoogleFonts.outfit(
                                  color: AppTheme.petalWhite,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Center: Game Over / Finish indicator
                    if (_game.isFinished)
                      IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'MATCH FINISHED',
                            style: GoogleFonts.cormorantGaramond(
                              color: AppTheme.roseQuartz,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),

                    // Bottom: Dual Touch Joysticks
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Joystick (Movement)
                          tsj.TwinStickJoystick(
                            icon: Icons.zoom_out_map_rounded,
                            color: AppTheme.softLavender,
                            size: 110,
                            onMove: (axis) {
                              setState(() {
                                _moveInput.x = axis.x;
                                _moveInput.y = axis.y;
                              });
                            },
                          ),

                          // Right Joystick (Aim & Shoot)
                          tsj.TwinStickJoystick(
                            icon: Icons.gps_fixed_rounded,
                            color: AppTheme.deepRose,
                            size: 110,
                            onMove: (axis) {
                              setState(() {
                                _aimInput.x = axis.x;
                                _aimInput.y = axis.y;
                                // Auto fire when aiming stick is pushed in any direction
                                _firePressed = axis.isActive;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
