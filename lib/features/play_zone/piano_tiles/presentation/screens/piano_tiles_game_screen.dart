import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
import '../widgets/piano_lane_divider.dart';
import '../widgets/piano_line.dart';

class PianoTilesGameScreen extends StatefulWidget {
  const PianoTilesGameScreen({super.key});

  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PianoTilesGameScreen(),
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
  final PianoAudioService _audio = PianoAudioService();

  late AnimationController _controller;
  List<PianoNote> _notes = PianoSongProvider.initNotes();
  int _currentIndex = 0;
  int _points = 0;
  int _streak = 0;
  int _bestStreak = 0;
  bool _hasStarted = false;
  bool _isPlaying = true;
  bool _hasFinishedSong = false;

  static const int _tilesAhead = 5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _controller.addStatusListener(_onAnimationStatus);
    _audio.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isPlaying) return;

    final currentNote = _notes[_currentIndex];

    if (currentNote.state != PianoNoteState.tapped) {
      setState(() {
        _isPlaying = false;
        currentNote.state = PianoNoteState.missed;
        _streak = 0;
      });
      _controller.reverse().then((_) => _showFinishDialog(songCompleted: false));
      return;
    }

    if (_currentIndex == _notes.length - _tilesAhead) {
      _hasFinishedSong = true;
      _showFinishDialog(songCompleted: true);
      return;
    }

    setState(() => _currentIndex++);
    _controller.forward(from: 0);
  }

  void _onTap(PianoNote note) {
    final allPreviousTapped = _notes
        .sublist(0, note.orderNumber)
        .every((n) => n.state == PianoNoteState.tapped);
    if (!allPreviousTapped) return;

    if (!_hasStarted) {
      setState(() => _hasStarted = true);
      _controller.forward();
    }

    _audio.play(note.line);

    setState(() {
      note.state = PianoNoteState.tapped;
      _points++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
    });
  }

  void _restart() {
    setState(() {
      _notes = PianoSongProvider.initNotes();
      _currentIndex = 0;
      _points = 0;
      _streak = 0;
      _bestStreak = 0;
      _hasStarted = false;
      _isPlaying = true;
      _hasFinishedSong = false;
    });
    _controller.reset();
  }

  Future<void> _showFinishDialog({required bool songCompleted}) async {
    final xpEarned = await _awardXp(songCompleted: songCompleted);
    if (!mounted) return;

    final title = songCompleted ? 'Lovely Performance' : 'Note Missed';
    final accent =
        songCompleted ? AppTheme.blushGold : AppTheme.roseQuartz;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileHeight = constraints.maxHeight / 4;
              final upcoming = _notes
                  .sublist(_currentIndex, _currentIndex + _tilesAhead)
                  .toList();
              return Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildLine(0, upcoming, tileHeight)),
                      const PianoLaneDivider(),
                      Expanded(child: _buildLine(1, upcoming, tileHeight)),
                      const PianoLaneDivider(),
                      Expanded(child: _buildLine(2, upcoming, tileHeight)),
                      const PianoLaneDivider(),
                      Expanded(child: _buildLine(3, upcoming, tileHeight)),
                    ],
                  ),
                  _buildHud(),
                  if (!_hasStarted && _isPlaying && !_hasFinishedSong)
                    _buildStartHint(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLine(int lineNumber, List<PianoNote> upcoming, double tileHeight) {
    return PianoLine(
      lineNumber: lineNumber,
      currentNotes: upcoming,
      tileHeight: tileHeight,
      onTileTap: _onTap,
      animation: _controller,
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

  Widget _buildStartHint() {
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
                'Tap the dark petals as they fall',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
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
