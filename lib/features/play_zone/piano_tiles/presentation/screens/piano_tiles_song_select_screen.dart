import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';

import '../../data/piano_song_provider.dart';

class PianoTilesSongSelectScreen extends StatefulWidget {
  const PianoTilesSongSelectScreen({super.key});

  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PianoTilesSongSelectScreen(),
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
  State<PianoTilesSongSelectScreen> createState() =>
      _PianoTilesSongSelectScreenState();
}

class _PianoTilesSongSelectScreenState
    extends State<PianoTilesSongSelectScreen> {
  final Map<String, int> _highScores = {};
  final Map<String, int> _bestStreaks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHighScores();
  }

  Future<void> _loadHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final song in PianoSongProvider.songs) {
        _highScores[song.id] = prefs.getInt('melody_tiles_highscore_${song.id}') ?? 0;
        _bestStreaks[song.id] = prefs.getInt('melody_tiles_beststreak_${song.id}') ?? 0;
      }
      _isLoading = false;
    });
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.tealAccent;
      case 'medium':
        return AppTheme.blushGold;
      case 'hard':
      default:
        return AppTheme.roseQuartz;
    }
  }

  void _startSong(PianoSong song) {
    context.push('/play-zone/piano', extra: song).then((_) => _loadHighScores());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.blushGold,
                        ),
                      )
                    : _buildSongList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
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
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.petalWhite,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Melody Tiles',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.roseQuartz,
                  ),
                ),
                Text(
                  'Select a melody and tap in rhythm',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.petalWhite.withValues(alpha: 0.65),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: PianoSongProvider.songs.length,
      itemBuilder: (context, index) {
        final song = PianoSongProvider.songs[index];
        final highscore = _highScores[song.id] ?? 0;
        final beststreak = _bestStreaks[song.id] ?? 0;
        final diffColor = _getDifficultyColor(song.difficulty);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.blushGold.withValues(alpha: 0.25),
              width: 1.2,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: diffColor.withValues(alpha: 0.45),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        song.difficulty.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: diffColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.music_note_rounded,
                          color: AppTheme.blushGold,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${song.notes.length} Notes',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  song.title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.roseQuartz,
                  ),
                ),
                Text(
                  song.artist,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.petalWhite.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HIGH SCORE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.petalWhite.withValues(alpha: 0.4),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            highscore > 0 ? '$highscore' : '-',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.petalWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BEST STREAK',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.petalWhite.withValues(alpha: 0.4),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            beststreak > 0 ? 'x$beststreak' : '-',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.petalWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BouncyButton(
                      onTap: () => _startSong(song),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.deepRose, AppTheme.softLavender],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.deepRose.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PLAY',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: AppTheme.petalWhite,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: AppTheme.petalWhite,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
