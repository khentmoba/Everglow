import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../../../../shared/widgets/animated_emblem.dart';
import '../../../../../shared/widgets/bouncy_button.dart';
import '../../../../../shared/widgets/glass_container.dart';
import '../../models/hexgl_challenge.dart';
import '../../models/hexgl_race_result.dart';
import '../../services/hexgl_service.dart';
import '../utils/hexgl_bridge.dart';
import 'hexgl_game_screen.dart';

class HexGLResultsScreen extends StatefulWidget {
  const HexGLResultsScreen({
    super.key,
    required this.result,
    this.savedBest,
    this.challenge,
    this.ghostReplay,
  });

  final HexGLRaceResult result;
  final HexGLRaceResult? savedBest;
  final HexGLChallenge? challenge;
  final HexGLRaceResult? ghostReplay;

  @override
  State<HexGLResultsScreen> createState() => _HexGLResultsScreenState();
}

class _HexGLResultsScreenState extends State<HexGLResultsScreen> {
  final HexGLService _service = HexGLService();
  HexGLRaceResult? _partnerBest;
  bool _loadingPartner = true;
  bool _sendingChallenge = false;
  bool _challengeSent = false;
  String? _localName;
  String? _partnerName;

  // Watch mode
  bool _watchingReplay = false;
  final String _watchViewType =
      'hexgl-replay-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';
  HexGLBridge? _watchBridge;
  StreamSubscription<HexGLMessage>? _watchSub;
  List<List<double>>? _watchReplay;

  @override
  void initState() {
    super.initState();
    _loadIdentities();
    _loadPartnerBest();
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    _watchBridge?.dispose();
    super.dispose();
  }

  void _loadIdentities() {
    final auth = context.read<AuthService>();
    _localName = auth.partnerName == 'Partner'
        ? (auth.currentUser ?? 'You')
        : (auth.partnerName == 'Khent' ? 'Clair' : 'Khent');
    if (auth.partnerName == 'Partner') {
      _localName = auth.currentUser ?? 'You';
      _partnerName = 'Partner';
    } else if (auth.uid == AuthService.khentUid) {
      _localName = 'Khent';
      _partnerName = 'Clair';
    } else if (auth.uid == AuthService.clairUid) {
      _localName = 'Clair';
      _partnerName = 'Khent';
    } else {
      _localName = auth.currentUser ?? 'You';
      _partnerName = 'Partner';
    }
  }

  Future<void> _loadPartnerBest() async {
    final auth = context.read<AuthService>();
    final partner = auth.partnerUid;
    if (partner == null) {
      setState(() => _loadingPartner = false);
      return;
    }
    try {
      final best = await _service.getBestTime(
        userId: partner,
        trackId: widget.result.trackId,
      );
      if (mounted) {
        setState(() {
          _partnerBest = best;
          _loadingPartner = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HexGL load partner best error: $e');
      if (mounted) setState(() => _loadingPartner = false);
    }
  }

  Future<void> _sendChallenge() async {
    if (_challengeSent || _sendingChallenge) return;
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) return;
    if (!widget.result.isFinished) return;

    setState(() => _sendingChallenge = true);
    try {
      await _service.openChallenge(
        challengerId: uid,
        trackId: widget.result.trackId,
        challengerResult: widget.result,
      );
      if (mounted) {
        setState(() {
          _challengeSent = true;
          _sendingChallenge = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HexGL sendChallenge error: $e');
      if (mounted) setState(() => _sendingChallenge = false);
    }
  }

  void _enterWatchReplayMode() {
    final replay = widget.ghostReplay?.replay ??
        widget.challenge?.challengerResult?.replay ??
        _partnerBest?.replay;
    if (replay == null || replay.isEmpty) return;
    setState(() {
      _watchReplay = replay;
      _watchingReplay = true;
    });
    _buildWatchBridge();
  }

  void _exitWatchReplayMode() {
    _watchSub?.cancel();
    _watchSub = null;
    _watchBridge?.dispose();
    _watchBridge = null;
    setState(() {
      _watchingReplay = false;
      _watchReplay = null;
    });
  }

  void _buildWatchBridge() {
    final src =
        'hexgl/index.html?mode=embed&player=${Uri.encodeComponent(_localName ?? 'You')}&replayMode=1';
    final bridge = HexGLBridge.create(src: src, viewId: _watchViewType);
    _watchBridge = bridge;
    _watchSub = bridge.messages.listen((m) {
      if (m.type == 'ready' && _watchReplay != null) {
        bridge.loadAndStartReplay(_watchReplay);
      } else if (m.type == 'finish') {
        // Replay ended; do nothing, just sit.
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_watchingReplay) {
      return _buildWatchView();
    }

    final saved = widget.savedBest;
    final isFinished = widget.result.isFinished;
    final isNewBest = saved != null &&
        saved.userId == widget.result.userId &&
        saved.finishTimeMs == widget.result.finishTimeMs &&
        saved.createdAt == widget.result.createdAt;

    final partnerBest = _partnerBest;
    final showChallengeCta = widget.challenge == null &&
        isFinished &&
        partnerBest != null;

    final delta = (partnerBest != null && isFinished)
        ? widget.result.finishTimeMs - partnerBest.finishTimeMs
        : null;
    final youWin = delta != null && delta < 0;
    final tie = delta == 0;
    final accent = isFinished
        ? (delta == null
            ? AppTheme.softLavender
            : (tie
                ? AppTheme.warmAmber
                : (youWin ? AppTheme.softLavender : AppTheme.deepRose)))
        : AppTheme.deepRose;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.twilight, AppTheme.velvet, AppTheme.deepRose],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(accent, delta, partnerBest),
                const SizedBox(height: 16),
                _buildScoreRow(
                  leftName: _localName ?? 'You',
                  leftTimeMs: widget.result.finishTimeMs,
                  leftStatus: widget.result.status,
                  rightName: _partnerName ?? 'Partner',
                  rightTimeMs: partnerBest?.finishTimeMs,
                  rightLoading: _loadingPartner,
                  accent: accent,
                ),
                const SizedBox(height: 16),
                if (widget.result.lapTimesMs.isNotEmpty)
                  _buildLapBreakdown(),
                const SizedBox(height: 16),
                _buildActionRow(showChallengeCta: showChallengeCta),
                const SizedBox(height: 12),
                if (isNewBest)
                  _buildPersonalBestBadge(),
                if (!isFinished)
                  _buildDestroyedNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatchView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (kIsWeb && _watchBridge != null)
            Positioned.fill(child: HtmlElementView(viewType: _watchViewType)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: _exitWatchReplayMode,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.petalWhite.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: const Icon(Icons.close_rounded,
                    color: AppTheme.petalWhite, size: 22),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.blushGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Watching ${_partnerName ?? "partner"} replay',
                  style: GoogleFonts.outfit(
                    color: AppTheme.blushGold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color accent, int? delta, HexGLRaceResult? partnerBest) {
    final title = !widget.result.isFinished
        ? 'Race Over'
        : (delta == null
            ? 'Race Complete'
            : (delta == 0
                ? 'Photo Finish'
                : (delta < 0 ? 'You Beat Them' : 'They Lead')));
    final subtitle = !widget.result.isFinished
        ? 'Your ship was destroyed before the final lap'
        : (delta == null
            ? 'Your best time is on the board'
            : (delta == 0
                ? 'Identical times — a true tie'
                : '${delta < 0 ? "ahead" : "behind"} by ${HexGLService.formatDelta(delta)}'));
    return Column(
      children: [
        AnimatedEmblem(
          icon: !widget.result.isFinished
              ? Icons.dangerous_rounded
              : (delta == null
                  ? Icons.flag_rounded
                  : (delta < 0
                      ? Icons.emoji_events_rounded
                      : Icons.heart_broken_rounded)),
          size: 60,
          color: accent,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: accent,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreRow({
    required String leftName,
    required int leftTimeMs,
    required HexGLResultStatus leftStatus,
    required String rightName,
    required int? rightTimeMs,
    required bool rightLoading,
    required Color accent,
  }) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      border: Border.all(
        color: accent.withValues(alpha: 0.35),
        width: 1.2,
      ),
      child: Row(
        children: [
          Expanded(
            child: _scoreColumn(
              name: leftName,
              timeMs: leftTimeMs,
              status: leftStatus,
              highlight: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'vs',
              style: GoogleFonts.cormorantGaramond(
                color: AppTheme.petalWhite.withValues(alpha: 0.5),
                fontSize: 24,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(
            child: _scoreColumn(
              name: rightName,
              timeMs: rightTimeMs,
              loading: rightLoading,
              highlight: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreColumn({
    required String name,
    required int? timeMs,
    HexGLResultStatus? status,
    bool loading = false,
    bool highlight = false,
  }) {
    final color = highlight ? AppTheme.roseQuartz : AppTheme.blushGold;
    return Column(
      children: [
        Text(
          name,
          style: GoogleFonts.outfit(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppTheme.blushGold,
              strokeWidth: 2,
            ),
          )
        else
          Text(
            timeMs == null || timeMs == 0 ? '—' : HexGLService.formatTime(timeMs),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.petalWhite,
            ),
          ),
        if (status != null && status != HexGLResultStatus.finished)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              status == HexGLResultStatus.destroyed ? 'Destroyed' : 'Abandoned',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.deepRose,
                letterSpacing: 1.0,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLapBreakdown() {
    final l = widget.result.lapTimesMs;
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lap Times',
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite.withValues(alpha: 0.7),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < l.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Lap ${i + 1}',
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    HexGLService.formatTime(l[i]),
                    style: GoogleFonts.cormorantGaramond(
                      color: AppTheme.blushGold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionRow({required bool showChallengeCta}) {
    final hasGhost = widget.ghostReplay?.replay != null ||
        widget.challenge?.challengerResult?.replay != null ||
        (_partnerBest?.replay != null);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        BouncyButton(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.moonlight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.moonlight.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Text(
              'Back to Hub',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        BouncyButton(
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HexGLGameScreen(
                  ghostReplay: _partnerBest,
                ),
              ),
            );
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.deepRose, AppTheme.softLavender],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepRose.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Race Again',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        if (hasGhost)
          BouncyButton(
            onTap: _enterWatchReplayMode,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.warmAmber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.warmAmber.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: AppTheme.warmAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Watch Replay',
                    style: GoogleFonts.outfit(
                      color: AppTheme.warmAmber,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (showChallengeCta)
          BouncyButton(
            onTap: _sendChallenge,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.blushGold, AppTheme.warmAmber],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warmAmber.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _challengeSent
                        ? Icons.check_rounded
                        : Icons.send_rounded,
                    color: AppTheme.twilight,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _challengeSent ? 'Challenge Sent' : 'Challenge Them',
                    style: GoogleFonts.outfit(
                      color: AppTheme.twilight,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalBestBadge() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.blushGold, AppTheme.warmAmber],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded,
                color: AppTheme.twilight, size: 18),
            const SizedBox(width: 6),
            Text(
              'NEW PERSONAL BEST',
              style: GoogleFonts.outfit(
                color: AppTheme.twilight,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestroyedNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Try again — and watch out for the walls.',
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
