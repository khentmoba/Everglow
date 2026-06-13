import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/animated_emblem.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';

import '../../data/piano_audio_service.dart';
import '../../data/piano_song_provider.dart';
import '../../models/piano_note.dart';
import '../widgets/piano_board_painter.dart';

/// Piano-Tiles-style rhythm game with continuous, beat-locked scrolling.
///
/// Architecture:
/// * A [Ticker] increments a `ValueNotifier&lt;double&gt;` called
///   `_currentBeat` every frame in real time. This is the only thing that
///   changes per frame, so nothing in the widget tree rebuilds.
/// * A single [PianoBoardPainter] listens to that notifier and paints all
///   four lanes' tiles in one pass. Tiles below/above the viewport are
///   culled.
/// * Each lane has a transparent [GestureDetector] on top of the canvas
///   for tap input. Taps resolve in O(1) against the "next pending note".
/// * Audio playback is fire-and-forget against a pre-warmed per-note
///   player pool — no awaits on the hot tap path.
class PianoTilesGameScreen extends StatefulWidget {
  final PianoSong song;

  const PianoTilesGameScreen({super.key, required this.song});

  static Route<dynamic> route({required PianoSong song}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          PianoTilesGameScreen(song: song),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<PianoTilesGameScreen> createState() => _PianoTilesGameScreenState();
}

class _PianoTilesGameScreenState extends State<PianoTilesGameScreen>
    with SingleTickerProviderStateMixin {
  static const int _laneCount = 4;
  static const double _judgmentLineFromBottom = 110;
  // Visible beats above the judgment line — controls fall distance/time.
  static const double _visibleBeatsAbove = 4.2;
  // Grace window after a tile crosses the judgment line before we call it a miss.
  static const double _missToleranceBeats = 0.55;

  final PianoAudioService _audio = PianoAudioService();

  // --- Tick state ----------------------------------------------------------
  late final Ticker _ticker;
  // Beat counter, updated every frame. Listened to by the painter.
  final ValueNotifier<double> _currentBeat = ValueNotifier<double>(0.0);
  // Tap-pulse list, updated only when a tap lands.
  final ValueNotifier<List<LanePulse>> _tapPulses =
      ValueNotifier<List<LanePulse>>(const []);
  // Lane to flash red when missing.
  final ValueNotifier<int> _missLane = ValueNotifier<int>(-1);

  // Game state --------------------------------------------------------------
  late List<PianoNote> _notes;
  int _scoringIndex = 0; // index of the next note that needs a tap
  int _points = 0;
  int _streak = 0;
  int _bestStreak = 0;
  bool _hasStarted = false;
  bool _isFinished = false;
  bool _gameOver = false;
  bool _audioReady = false;

  // Time bookkeeping for the ticker — using monotonic Duration from Ticker.
  Duration _startElapsed = Duration.zero;
  double _startBeat = 0;

  // Per-song knobs --------------------------------------------------------
  int get _beatDurationMs => widget.song.beatDurationMs;
  double get _pixelsPerBeat => _cachedPixelsPerBeat;
  double _cachedPixelsPerBeat = 180;
  double _cachedJudgmentY = 600;

  @override
  void initState() {
    super.initState();
    _notes = PianoSongProvider.initNotes(widget.song);

    _ticker = createTicker(_onTick);

    // Start with the very first tile sitting flush at the judgment line so
    // the player can see what to tap first.
    if (_notes.isNotEmpty) {
      _startBeat = _notes.first.hitBeat;
      _currentBeat.value = _startBeat;
    }

    // Pre-warm the audio pool for every pitch the song will use. Doing this
    // up front lets every later [playMidi] return instantly.
    _audio
        .prepareNotes(PianoSongProvider.uniqueMidiNotes(widget.song))
        .then((_) {
      if (mounted) setState(() => _audioReady = true);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _currentBeat.dispose();
    _tapPulses.dispose();
    _missLane.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tick loop
  // ---------------------------------------------------------------------------
  void _onTick(Duration elapsed) {
    if (_gameOver || _isFinished) return;
    final dtMs = (elapsed - _startElapsed).inMicroseconds / 1000.0;
    final beat = _startBeat + dtMs / _beatDurationMs;
    _currentBeat.value = beat;

    _evaluateMisses(beat);

    // Prune expired tap pulses so the painter list stays tiny.
    final now = DateTime.now().millisecondsSinceEpoch;
    final live = _tapPulses.value
        .where((p) => now - p.startMs < LanePulse.lifetimeMs)
        .toList(growable: false);
    if (live.length != _tapPulses.value.length) {
      _tapPulses.value = live;
    }
  }

  void _evaluateMisses(double beat) {
    while (_scoringIndex < _notes.length) {
      final note = _notes[_scoringIndex];
      if (note.state == PianoNoteState.tapped) {
        _scoringIndex++;
        continue;
      }
      // Has this tile drifted past the judgment line by more than tolerance?
      if (beat > note.hitBeat + _missToleranceBeats) {
        _registerMiss(note);
      }
      return;
    }
    // Reached the end of the song with no misses → completed.
    if (!_isFinished) {
      _isFinished = true;
      _ticker.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showFinishDialog(songCompleted: true);
      });
    }
  }

  void _registerMiss(PianoNote note) {
    if (_gameOver) return;
    _gameOver = true;
    note.state = PianoNoteState.missed;
    _streak = 0;
    _missLane.value = note.line;
    _ticker.stop();
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showFinishDialog(songCompleted: false);
    });
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------
  void _onLaneTap(int lane) {
    if (_gameOver || _isFinished) return;

    // Walk forward past any already-tapped notes so we always look at the
    // *current* pending one. Cheap because tapped count grows linearly.
    while (_scoringIndex < _notes.length &&
        _notes[_scoringIndex].state == PianoNoteState.tapped) {
      _scoringIndex++;
    }
    if (_scoringIndex >= _notes.length) return;

    final next = _notes[_scoringIndex];
    if (next.line != lane) {
      // Wrong lane: ignore — the auto-miss on the real pending tile will end
      // the game on its own if the player keeps ignoring it.
      return;
    }

    _registerHit(next, lane);
  }

  void _registerHit(PianoNote note, int lane) {
    note.state = PianoNoteState.tapped;
    _points++;
    _streak++;
    if (_streak > _bestStreak) _bestStreak = _streak;

    _audio.playMidi(note.midiNote);
    HapticFeedback.selectionClick();

    // Push a tap pulse animation.
    final now = DateTime.now().millisecondsSinceEpoch;
    _tapPulses.value = [..._tapPulses.value, LanePulse(lane, now)];

    if (!_hasStarted) {
      _hasStarted = true;
      _startBeat = note.hitBeat; // pin t=0 to this note's hit beat
      _startElapsed = Duration.zero; // Ticker.start() resets elapsed to zero
      _ticker.start();
      // First setState only — flips the start-hint off.
      setState(() {});
    }

    // Surface the new score in the HUD via a lightweight rebuild. The board
    // itself does NOT rebuild — the painter is driven by listenables.
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Lifecycle helpers
  // ---------------------------------------------------------------------------
  void _restart() {
    _ticker.stop();
    setState(() {
      _notes = PianoSongProvider.initNotes(widget.song);
      _scoringIndex = 0;
      _points = 0;
      _streak = 0;
      _bestStreak = 0;
      _hasStarted = false;
      _isFinished = false;
      _gameOver = false;
      _startBeat = _notes.isNotEmpty ? _notes.first.hitBeat : 0;
      _startElapsed = Duration.zero;
      _currentBeat.value = _startBeat;
      _missLane.value = -1;
      _tapPulses.value = const [];
    });
  }

  Future<void> _showFinishDialog({required bool songCompleted}) async {
    final xpEarned = await _awardXp(songCompleted: songCompleted);
    if (!mounted) return;

    final title = songCompleted ? 'Lovely Performance' : 'Note Missed';
    final accent = songCompleted ? AppTheme.blushGold : AppTheme.roseQuartz;
    final icon = songCompleted
        ? Icons.auto_awesome_rounded
        : Icons.favorite_border_rounded;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.blushGold.withValues(alpha: 0.35),
            width: 1.2,
          ),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedEmblem(icon: icon, size: 52, color: accent),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 18),
              _statRow('Score', '$_points'),
              const SizedBox(height: 8),
              _statRow('Best streak', '$_bestStreak'),
              if (xpEarned > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.deepRose, AppTheme.blushGold],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.deepRose.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    '+$xpEarned XP',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: AppTheme.petalWhite,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).maybePop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: AppTheme.moonlight.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      child: Text(
                        'Exit',
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BouncyButton(
                      onTap: () {
                        Navigator.of(context).pop();
                        _restart();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        child: Center(
                          child: Text(
                            'Play Again',
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
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
    );
  }

  Future<int> _awardXp({required bool songCompleted}) async {
    final auth = context.read<AuthService>();
    final uid = auth.uid;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keyScore = 'melody_tiles_highscore_${widget.song.id}';
      final keyStreak = 'melody_tiles_beststreak_${widget.song.id}';
      final currentBestScore = prefs.getInt(keyScore) ?? 0;
      final currentBestStreak = prefs.getInt(keyStreak) ?? 0;
      if (_points > currentBestScore) {
        await prefs.setInt(keyScore, _points);
      }
      if (_bestStreak > currentBestStreak) {
        await prefs.setInt(keyStreak, _bestStreak);
      }
    } catch (_) {}

    if (uid == null) return 0;

    var xp = (_points * 2).clamp(0, 400);
    if (songCompleted) xp += 120;
    if (_bestStreak >= 20) xp += 40;
    if (xp <= 0) return 0;

    try {
      await XPService().addXp(uid, xp);
    } catch (_) {}
    return xp;
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.75),
            fontSize: 15,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.roseQuartz,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              _cachedJudgmentY = height - _judgmentLineFromBottom;
              // Make pixels-per-beat scale with the playfield so that the
              // _visibleBeatsAbove worth of music always fits between the
              // top edge and the judgment line.
              _cachedPixelsPerBeat = _cachedJudgmentY / _visibleBeatsAbove;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Render layer (one CustomPaint, no rebuilds).
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: PianoBoardPainter(
                        currentBeat: _currentBeat,
                        notes: _notes,
                        pixelsPerBeat: _pixelsPerBeat,
                        judgmentY: _cachedJudgmentY,
                        laneCount: _laneCount,
                        tapPulses: _tapPulses,
                        missFlashLane: _missLane,
                      ),
                      isComplex: true,
                      willChange: true,
                      size: Size.infinite,
                    ),
                  ),

                  // Input layer (4 transparent lanes).
                  Row(
                    children: List.generate(
                      _laneCount,
                      (i) => Expanded(
                        child: _LaneTapTarget(
                          onTap: () => _onLaneTap(i),
                        ),
                      ),
                    ),
                  ),

                  // HUD on top.
                  _buildHud(),
                  if (!_hasStarted && !_gameOver && !_isFinished)
                    _buildStartHint(audioReady: _audioReady),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.moonlight.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.moonlight.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppTheme.petalWhite,
                size: 22,
              ),
            ),
          ),
          const Spacer(),
          GlassContainer(
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            border: Border.all(
              color: AppTheme.blushGold.withValues(alpha: 0.3),
              width: 1.0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: AppTheme.blushGold,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_points',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.roseQuartz,
                  ),
                ),
                if (_streak >= 5) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'x$_streak',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.petalWhite,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildStartHint({required bool audioReady}) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.velvet.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.blushGold.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepRose.withValues(alpha: 0.25),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedEmblem(
                icon: Icons.touch_app_rounded,
                size: 36,
                color: AppTheme.blushGold,
              ),
              const SizedBox(height: 10),
              Text(
                widget.song.title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.blushGold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                audioReady
                    ? 'Tap the first tile to begin'
                    : 'Tuning the piano...',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.roseQuartz,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "Don't miss a beat",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.petalWhite.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny stateless tap target so the painter underneath isn't rebuilt by
/// the gesture system.
class _LaneTapTarget extends StatelessWidget {
  final VoidCallback onTap;

  const _LaneTapTarget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTap(),
      child: const SizedBox.expand(),
    );
  }
}
