import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';
import 'package:everglow/features/play_zone/services/racing_match_service.dart';
import 'package:everglow/features/play_zone/models/racing_match.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/play_zone/presentation/screens/racing_results_screen.dart';
import 'package:everglow/features/play_zone/presentation/widgets/race_celebration.dart';
import 'package:google_fonts/google_fonts.dart';

class RacingGameScreen extends StatefulWidget {
  final String mode;
  final String? matchId;
  final String? userId;

  const RacingGameScreen({
    super.key,
    this.mode = 'solo',
    this.matchId,
    this.userId,
  });

  @override
  State<RacingGameScreen> createState() => _RacingGameScreenState();
}

class _RacingGameScreenState extends State<RacingGameScreen> {
  html.IFrameElement? _iframeElement;
  html.DivElement? _containerElement;
  bool _gameReady = false;
  bool _loadError = false;
  int _xpEarned = 0;
  bool _showingXp = false;

  final RacingMatchService _matchService = RacingMatchService();
  bool _isRacing = false;
  String? _opponentId;
  StreamSubscription<DocumentSnapshot>? _matchSub;
  StreamSubscription<DocumentSnapshot>? _opponentPosSub;

  @override
  void initState() {
    super.initState();
    _createIframe();
    _setupMessageListener();

    if (widget.mode == 'multi' && widget.matchId != null) {
      _setupMultiplayerListeners();
    }
  }

  void _setupMultiplayerListeners() {
    final uid = context.read<AuthService>().uid;
    if (uid == null) return;

    _matchSub = _matchService.watchMatch(widget.matchId!).listen((snapshot) {
      if (!mounted) return;
      final match = RacingMatch.fromFirestore(snapshot);

      if (match.status == 'finished') {
        _isRacing = false;
        _onRaceFinished(match);
      }
    });

    _opponentId = _getOpponentId(uid);
    if (_opponentId == null) return;

    _opponentPosSub = _matchService.watchPosition(widget.matchId!, _opponentId!).listen((snapshot) {
      if (!mounted || !_isRacing || !snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;
      _sendToGame({
        'type': 'OPPONENT_POSITION',
        'x': data['x'] ?? 0,
        'y': data['y'] ?? 0,
        'z': data['z'] ?? 0,
        'speed': data['speed'] ?? 0,
        'boost': data['boost'] ?? 0,
      });
    });
  }

  String? _getOpponentId(String uid) {
    if (uid == AuthService.khentUid) return AuthService.clairUid;
    if (uid == AuthService.clairUid) return AuthService.khentUid;
    return null;
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _opponentPosSub?.cancel();
    _containerElement?.remove();
    html.document.body?.style.removeProperty('overflow');
    super.dispose();
  }

  void _createIframe() {
    _containerElement = html.DivElement()
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.zIndex = '0'
      ..style.overflow = 'hidden';

    _iframeElement = html.IFrameElement()
      ..src = '/racing/index.html'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden'
      ..allow = 'autoplay; accelerometer; gyroscope'
      ..onLoad.listen((_) => _onIframeLoaded());

    _containerElement!.append(_iframeElement!);
    html.document.body?.append(_containerElement!);
    html.document.body?.style.setProperty('overflow', 'hidden');
  }

  void _onIframeLoaded() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_gameReady) {
        setState(() => _loadError = true);
      }
    });
  }

  void _sendToGame(Map<String, dynamic> data) {
    _iframeElement?.contentWindow?.postMessage(data, '*');
  }

  void _setupMessageListener() {
    html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is Map) {
        _handleGameMessage(Map<String, dynamic>.from(data));
      }
    });
  }

  void _handleGameMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'READY':
        _onGameReady();
      case 'RACE_START':
        _onRaceStart();
      case 'POSITION':
        if (widget.mode == 'multi') _onPosition(data);
      case 'RACE_COMPLETE':
        _onRaceComplete(data);
      case 'REQUEST_CLOSE':
        _onRequestClose();
    }
  }

  void _onGameReady() {
    final authService = context.read<AuthService>();
    final uid = authService.uid;
    final displayName = authService.currentUser ?? 'Player';
    final carColor = uid == AuthService.khentUid ? '#C2185B' : '#D4B5D6';

    setState(() => _gameReady = true);

    _sendToGame({
      'type': 'INIT',
      'userId': uid,
      'displayName': displayName,
      'carColor': carColor,
      'mode': widget.mode,
      'matchId': widget.matchId,
      'mute': false,
    });
  }

  void _onRaceStart() {
    _isRacing = true;
    if (widget.mode == 'multi' && widget.matchId != null) {
      _matchService.setMatchStatus(widget.matchId!, 'racing');
    }
  }

  void _onPosition(Map<String, dynamic> data) {
    if (_isRacing && widget.matchId != null) {
      final uid = context.read<AuthService>().uid;
      if (uid != null) {
        _matchService.updatePosition(widget.matchId!, uid, data);
      }
    }
  }

  void _onRaceComplete(Map<String, dynamic> data) async {
    _isRacing = false;
    final totalTime = data['totalTime'] as num? ?? 0;

    int xpAmount = 100;
    if (totalTime <= 60000) xpAmount = 200;

    final authService = context.read<AuthService>();
    final uid = authService.uid;

    if (widget.mode == 'multi' && widget.matchId != null && uid != null) {
      await _matchService.submitFinishTime(widget.matchId!, uid, totalTime);
    }

    if (uid != null) {
      await XPService().addXp(uid, xpAmount);
    }

    if (mounted) {
      setState(() {
        _xpEarned = xpAmount;
        _showingXp = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showingXp = false);
      });
    }
  }

  void _onRaceFinished(RacingMatch match) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RacingResultsScreen(match: match),
      ),
    );
  }

  void _onRequestClose() {
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (!_gameReady && !_loadError)
            _buildLoadingState()
          else if (_loadError)
            _buildErrorState(),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.moonlight.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.moonlight.withValues(alpha: 0.3), width: 1.0),
                ),
                child: const Icon(Icons.close_rounded, color: AppTheme.petalWhite, size: 24),
              ),
            ),
          ),

          if (_showingXp)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.deepRose, AppTheme.blushGold],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.deepRose.withValues(alpha: 0.4),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Text(
                      '+$_xpEarned XP',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.petalWhite,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          RaceCelebration(isVisible: _showingXp),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return GamifiedBackground(
      child: SafeArea(
        child: _AnimatedLoadingContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return GamifiedBackground(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.speed_rounded, size: 64, color: AppTheme.roseQuartz),
              const SizedBox(height: 24),
              Text(
                'Midnight Drive',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Could not load the game.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppTheme.petalWhite.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Run npm run build in racing-game/, redeploy.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.petalWhite.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deepRose,
                  foregroundColor: AppTheme.petalWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedLoadingContent extends StatefulWidget {
  @override
  State<_AnimatedLoadingContent> createState() => _AnimatedLoadingContentState();
}

class _AnimatedLoadingContentState extends State<_AnimatedLoadingContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.roseQuartz.withValues(alpha: 0.3),
                        blurRadius: 20 * _pulseAnimation.value,
                        spreadRadius: 5 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.speed_rounded, size: 64, color: AppTheme.roseQuartz),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Midnight Drive',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppTheme.roseQuartz,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading game...',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppTheme.petalWhite.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
