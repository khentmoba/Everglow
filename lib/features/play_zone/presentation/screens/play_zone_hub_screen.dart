import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/animated_emblem.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/features/play_zone/services/racing_match_service.dart';
import 'package:everglow/features/play_zone/models/racing_match.dart';
import 'package:everglow/features/play_zone/presentation/screens/racing_game_screen.dart';

class PlayZoneHubScreen extends StatefulWidget {
  const PlayZoneHubScreen({super.key});

  @override
  State<PlayZoneHubScreen> createState() => _PlayZoneHubScreenState();

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const PlayZoneHubScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(position: animation.drive(slideTween), child: child),
        );
      },
    );
  }
}

class _PlayZoneHubScreenState extends State<PlayZoneHubScreen> {
  final RacingMatchService _matchService = RacingMatchService();
  bool _isSearching = false;
  String? _statusMessage;
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: AppTheme.roseQuartz),
                    ),
                    Text(
                      'Play Zone',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.roseQuartz,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSearching)
                          _buildSearchingState()
                        else ...[
                          _buildGameCard(
                            icon: Icons.speed_rounded,
                            title: 'Midnight Drive',
                            subtitle: 'Race through the desert together',
                            gradientColors: const [AppTheme.deepRose, AppTheme.softLavender],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(color: AppTheme.roseQuartz, strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text(
          _statusMessage ?? 'Searching...',
          style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.roseQuartz),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            _timeoutTimer?.cancel();
            setState(() => _isSearching = false);
          },
          child: Text(
            'Cancel',
            style: GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
  }) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24.0),
      border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.25), width: 1.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          children: [
            AnimatedEmblem(icon: icon, size: 56, color: gradientColors.first),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.roseQuartz,
                letterSpacing: 0.5,
                shadows: [
                  BoxShadow(
                    color: AppTheme.deepRose.withValues(alpha: 0.4),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            BouncyButton(
              onTap: () => _showModeSelection(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'PLAY',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.petalWhite,
                    letterSpacing: 2.0,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.velvet, AppTheme.twilight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.roseQuartz.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Midnight Drive',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.roseQuartz,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your mode',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            _buildModeOption(
              icon: Icons.person_rounded,
              title: 'Solo Practice',
              subtitle: 'Time trial \u2014 race against the clock',
              onTap: () {
                Navigator.pop(context);
                _startSoloPractice();
              },
            ),
            const SizedBox(height: 16),
            _buildModeOption(
              icon: Icons.people_rounded,
              title: '1v1 Race',
              subtitle: 'Challenge your partner to a race',
              onTap: () {
                Navigator.pop(context);
                _startMultiplayer();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.moonlight.withValues(alpha: 0.18),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.deepRose.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppTheme.roseQuartz, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.petalWhite.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.petalWhite.withValues(alpha: 0.3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _startSoloPractice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RacingGameScreen(mode: 'solo'),
      ),
    );
  }

  void _startMultiplayer() {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Searching for a race...';
    });
    _startMatchmaking();
  }

  void _startMatchmaking() async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser ?? 'guest';

      final match = await _matchService.joinOrCreateMatch(userId);

      if (match.status == 'active') {
        _goToRace(match);
      } else {
        setState(() => _statusMessage = 'Waiting for your partner...');
        _startTimeoutTimer();

        FirebaseFirestore.instance
            .collection('racing_matches')
            .doc(match.matchId)
            .snapshots()
            .listen((snapshot) {
          if (!mounted) return;
          final updatedMatch = RacingMatch.fromFirestore(snapshot);
          if (updatedMatch.status == 'active') {
            _timeoutTimer?.cancel();
            _goToRace(updatedMatch);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _isSearching) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'No partner found. Try Solo Practice?';
        });
        _showTimeoutDialog();
      }
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.velvet,
        title: Text('Matchmaking Timeout', style: GoogleFonts.outfit(color: AppTheme.roseQuartz)),
        content: Text("Your partner didn't join. Try again or play Solo.", style: GoogleFonts.outfit(color: AppTheme.petalWhite)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startSoloPractice();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepRose),
            child: Text('Play Solo', style: GoogleFonts.outfit(color: AppTheme.petalWhite)),
          ),
        ],
      ),
    );
  }

  void _goToRace(RacingMatch match) {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser ?? 'guest';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RacingGameScreen(
          mode: 'multi',
          matchId: match.matchId,
          userId: userId,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isSearching = false);
    });
  }
}
