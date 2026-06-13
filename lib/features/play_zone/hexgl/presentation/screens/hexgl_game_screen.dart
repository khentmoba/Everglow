import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../models/hexgl_challenge.dart';
import '../../models/hexgl_race_result.dart';
import '../../services/hexgl_service.dart';
import '../utils/hexgl_bridge.dart';
import '../widgets/hexgl_touch_controls.dart';
import 'hexgl_results_screen.dart';

class HexGLGameScreen extends StatefulWidget {
  const HexGLGameScreen({
    super.key,
    this.challenge,
    this.ghostReplay,
  });

  /// If set, the user is responding to a challenge from their partner. The
  /// screen will auto-navigate to results once the race finishes.
  final HexGLChallenge? challenge;

  /// If set, the user is racing against their partner's ghost replay.
  final HexGLRaceResult? ghostReplay;

  @override
  State<HexGLGameScreen> createState() => _HexGLGameScreenState();
}

class _HexGLGameScreenState extends State<HexGLGameScreen> {
  final HexGLService _service = HexGLService();
  final String _viewType =
      'hexgl-iframe-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  HexGLBridge? _bridge;
  StreamSubscription<HexGLMessage>? _messageSub;

  bool _iframeReady = false;
  bool _booted = false;
  String? _loadError;
  bool _isMobile = false;
  bool _showStartHint = false;
  bool _iframeTouchGuard = false;
  String _statusText = 'Loading Cityscape...';
  Timer? _pingTimer;
  Timer? _startGuardTimer;

  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    _activeUserId = context.read<AuthService>().uid;
    _isMobile = _detectMobile();
    _iframeTouchGuard = _isMobile;
    _buildBridge();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _startGuardTimer?.cancel();
    _messageSub?.cancel();
    _bridge?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool _detectMobile() {
    if (kIsWeb) {
      try {
        return web.window.matchMedia('(pointer: coarse)').matches ||
            web.window.matchMedia('(max-width: 900px)').matches;
      } catch (_) {
        return false;
      }
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _buildBridge() {
    final auth = context.read<AuthService>();
    final player = auth.partnerName == 'Partner'
        ? (auth.currentUser ?? 'Driver')
        : (auth.currentUser ?? 'Driver');
    final params = <String, String>{
      'mode': 'embed',
      'player': Uri.encodeComponent(player),
      // Cache-buster: bump when web/hexgl/index.html changes so users don't
      // get a stale iframe HTML from the 1-hour CDN cache.
      'v': '3',
    };
    final query = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final src = 'hexgl/index.html?$query';

    if (kIsWeb) {
      final bridge = HexGLBridge.create(src: src, viewId: _viewType);
      _bridge = bridge;
      _messageSub = bridge.messages.listen(_onMessage);
      _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        bridge.ping();
      });
    }
  }

  void _onMessage(HexGLMessage message) {
    if (!mounted) return;
    switch (message.type) {
      case 'boot':
        setState(() {
          _statusText = 'Initializing 3D engine...';
        });
        break;
      case 'ready':
        setState(() {
          _iframeReady = true;
          _statusText = '';
        });
        // If a ghost replay was passed in, push it now.
        if (widget.ghostReplay?.replay != null) {
          _bridge?.loadReplay(widget.ghostReplay!.replay);
        }
        if (widget.challenge?.challengerResult?.replay != null) {
          _bridge?.loadReplay(widget.challenge!.challengerResult!.replay);
        }
        // Auto-start the race immediately.
        _bridge?.loadAndStartReplay(null);
        _startGuardTimer?.cancel();
        _startGuardTimer = Timer(
          const Duration(milliseconds: 800),
          () {
            if (mounted) {
              setState(() {
                _iframeTouchGuard = false;
                _booted = true;
              });
            }
          },
        );
        break;
      case 'progress':
        // Surface texture/geometry loading progress so the user knows we're
        // not just hung. We only update the spinner text; once 'ready' has
        // fired we leave the tap-to-start hint alone.
        if (!_iframeReady) {
          final loaded = message.progressLoaded;
          final total = message.progressTotal;
          if (loaded != null && total != null && total > 0) {
            setState(() {
              _statusText = 'Loading assets... $loaded / $total';
            });
          }
        }
        break;
      case 'loaded':
        // Textures + geometry fully loaded. Race is ready to start as soon
        // as the user taps.
        break;
      case 'started':
        setState(() {
          _showStartHint = false;
          _booted = true;
        });
        _startGuardTimer?.cancel();
        break;
      case 'finish':
        _handleFinish(message);
        break;
      case 'error':
        setState(() => _loadError = message.errorMessage ?? 'Unknown error');
        break;
      case 'replayLoaded':
      case 'replayCleared':
      case 'restarted':
      case 'userStart':
      case 'startQueued':
      case 'pong':
        break;
    }
  }

  Future<void> _handleFinish(HexGLMessage message) async {
    final auth = context.read<AuthService>();
    final uid = _activeUserId ?? auth.uid ?? 'guest';
    final finishTime = message.finishTimeMs ?? 0;
    final lapTimes = message.lapTimesMs;
    final label = message.resultLabel ?? 'other';
    final replay = message.replay;

    final result = HexGLRaceResult(
      userId: uid,
      finishTimeMs: finishTime,
      lapTimesMs: lapTimes,
      status: HexGLResultStatus.fromLabel(label),
      trackId: HexGLTrack.cityscape.id,
      replay: replay,
      createdAt: DateTime.now(),
    );

    HexGLRaceResult? savedBest;
    try {
      savedBest = await _service.submitResult(result: result);
    } catch (e) {
      if (kDebugMode) debugPrint('HexGL submitResult error: $e');
    }

    // If responding to a challenge, close it.
    if (widget.challenge != null) {
      try {
        await _service.respondToChallenge(
          challenge: widget.challenge!,
          defenderResult: result,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('HexGL respondToChallenge error: $e');
      }
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HexGLResultsScreen(
          result: result,
          savedBest: savedBest,
          challenge: widget.challenge,
          ghostReplay: widget.ghostReplay,
        ),
      ),
    );
  }

  void _restart() {
    _bridge?.restart();
  }

  void _close() {
    if (widget.challenge != null) {
      // Treat close as abandoning the challenge; mark closed with no defender
      // result so the partner can see you skipped.
      _service.closeChallengeAsDestroyed(
        challenge: widget.challenge!,
        userId: _activeUserId ?? 'guest',
      );
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isPortrait = mq.size.height > mq.size.width;
    final mobilePortraitBlocked = _isMobile && isPortrait;

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // The HexGL iframe (web only)
            if (kIsWeb && _bridge != null)
              Positioned.fill(
                child: HtmlElementView(viewType: _viewType),
              )
            else
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    'HexGL is only available in the web build.',
                    style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                  ),
                ),
              ),

            // Touch controls overlay (mobile only)
            if (_isMobile && _booted && !_showStartHint)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_iframeTouchGuard,
                  child: HexGLTouchControls(onInput: _onLocalInput),
                ),
              ),

            // Pre-game dark overlay with start hint
            if (!_booted && _loadError != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'HEXGL',
                        style: GoogleFonts.cormorantGaramond(
                          color: AppTheme.roseQuartz,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cityscape · Casual',
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite.withValues(alpha: 0.7),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Icon(Icons.error_outline_rounded,
                          color: AppTheme.deepRose, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        _loadError!,
                        style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).maybePop(),
                        child: Text(
                          'Back to hub',
                          style: GoogleFonts.outfit(
                            color: AppTheme.petalWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_booted && _loadError == null && !_iframeReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'HEXGL',
                        style: GoogleFonts.cormorantGaramond(
                          color: AppTheme.roseQuartz,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cityscape · Casual',
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite.withValues(alpha: 0.7),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: AppTheme.roseQuartz,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusText,
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite.withValues(alpha: 0.65),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // HUD (close + restart) — only shown once booted
            if (_booted)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _hudButton(
                      icon: Icons.close_rounded,
                      onTap: _close,
                    ),
                    const Spacer(),
                    if (widget.ghostReplay != null ||
                        widget.challenge?.challengerResult?.replay != null)
                      _hudButton(
                        icon: Icons.replay_rounded,
                        onTap: _restart,
                        tooltip: 'Restart race',
                      ),
                  ],
                ),
              ),

            // Mobile-portrait rotate prompt
            if (mobilePortraitBlocked)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.screen_rotation_rounded,
                        color: AppTheme.roseQuartz,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Rotate your device',
                        style: GoogleFonts.cormorantGaramond(
                          color: AppTheme.petalWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HexGL runs in landscape.',
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _close,
                        child: Text(
                          'Back',
                          style: GoogleFonts.outfit(
                            color: AppTheme.petalWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hudButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.petalWhite.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: AppTheme.petalWhite, size: 22),
        ),
      ),
    );
  }

  void _onLocalInput(String key, bool value) {
    if (!_iframeTouchGuard) {
      _bridge?.sendInput(key, value: value);
    }
  }
}
