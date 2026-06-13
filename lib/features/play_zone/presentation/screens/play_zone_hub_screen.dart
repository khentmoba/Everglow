import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/animated_emblem.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';

import '../../hexgl/models/hexgl_challenge.dart';
import '../../hexgl/presentation/screens/hexgl_game_screen.dart';
import '../../hexgl/services/hexgl_service.dart';
import '../../piano_tiles/presentation/screens/piano_tiles_song_select_screen.dart';
import '../../table_tennis/presentation/screens/table_tennis_game_screen.dart';
import '../../fun_race_3d/presentation/screens/fun_race_3d_game_screen.dart';
import '../../fun_race_3d/presentation/screens/fun_race_3d_lobby_screen.dart';
import '../../one_v_one/presentation/screens/one_v_one_lobby_screen.dart';

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
  final HexGLService _hexglService = HexGLService();

  StreamSubscription<List<HexGLChallenge>>? _openChallengesSub;
  List<HexGLChallenge> _openChallengesForMe = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeOpenChallenges();
    });
  }

  void _subscribeOpenChallenges() {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) return;
    if (!_hexglService.isAllowedPlayer(uid)) return;
    _openChallengesSub?.cancel();
    _openChallengesSub =
        _hexglService.watchOpenChallengesFor(uid).listen((list) {
      if (!mounted) return;
      setState(() => _openChallengesForMe = list);
    }, onError: (e) {
      if (kDebugMode) debugPrint('HexGL open challenges sub error: $e');
    });
  }

  @override
  void dispose() {
    _openChallengesSub?.cancel();
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGameCard(
                          icon: Icons.music_note_rounded,
                          title: 'Melody Tiles',
                          subtitle: 'Tap the dark falling petals in rhythm',
                          gradientColors: const [AppTheme.deepRose, AppTheme.softLavender],
                          onPlayTap: () => _startPianoTiles(),
                        ),
                        const SizedBox(height: 20),
                        _buildTableTennisCard(),
                        const SizedBox(height: 20),
                        _buildOneVOneCard(),
                        const SizedBox(height: 20),
                        _buildFunRace3DCard(),
                        const SizedBox(height: 20),
                        _buildHexGLCard(),
                        const SizedBox(height: 20),
                        if (_openChallengesForMe.isNotEmpty)
                          _buildChallengeBanner(_openChallengesForMe.first),
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

  Widget _buildGameCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onPlayTap,
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
              onTap: onPlayTap,
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

  Widget _buildTableTennisCard() {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24.0),
      border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.25), width: 1.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          children: [
            const AnimatedEmblem(
              icon: Icons.sports_tennis_rounded,
              size: 56,
              color: AppTheme.warmAmber,
            ),
            const SizedBox(height: 16),
            Text(
              'Table Tennis World Tour',
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
              'Smash your way through the world tournament bracket',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            BouncyButton(
              onTap: () => _startTableTennis(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.warmAmber, AppTheme.deepRose],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warmAmber.withValues(alpha: 0.3),
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

  void _startTableTennis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TableTennisGameScreen(),
      ),
    );
  }

  Widget _buildOneVOneCard() {
    final auth = context.watch<AuthService>();
    final isCouple = auth.isCoupleUser;
    final subtitle = isCouple
        ? 'You vs Clair · create a room and share the code'
        : 'Private match — sign in to unlock';
    return _buildGameCard(
      icon: Icons.sports_handball_rounded,
      title: '1v1 Match',
      subtitle: subtitle,
      gradientColors: const [AppTheme.deepRose, AppTheme.warmAmber],
      onPlayTap: () => _startOneVOne(),
    );
  }

  void _startOneVOne() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OneVOneLobbyScreen(),
      ),
    );
  }

  Widget _buildFunRace3DCard() {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24.0),
      border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.25), width: 1.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          children: [
            const AnimatedEmblem(
              icon: Icons.directions_run_rounded,
              size: 56,
              color: AppTheme.softLavender,
            ),
            const SizedBox(height: 16),
            Text(
              'Fun Race 3D',
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
              'Sprint, dodge, and slide past the obstacle gauntlet',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BouncyButton(
                  onTap: () => _startFunRace3D(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.softLavender, AppTheme.deepRose],
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.softLavender.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'SOLO',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.petalWhite,
                        letterSpacing: 2.0,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BouncyButton(
                  onTap: () => _startFunRace3D1v1(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.warmAmber, AppTheme.deepRose],
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.warmAmber.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_rounded,
                            color: AppTheme.petalWhite, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '1v1',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.petalWhite,
                            letterSpacing: 2.0,
                            fontSize: 14,
                          ),
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
  }

  void _startFunRace3D() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FunRace3DGameScreen(),
      ),
    );
  }

  void _startFunRace3D1v1() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FunRace3DLobbyScreen(),
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

  void _startPianoTiles() {
    Navigator.push(
      context,
      PianoTilesSongSelectScreen.route(),
    );
  }

  Widget _buildHexGLCard() {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24.0),
      border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.25), width: 1.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          children: [
            const AnimatedEmblem(
              icon: Icons.rocket_launch_rounded,
              size: 56,
              color: AppTheme.softLavender,
            ),
            const SizedBox(height: 16),
            Text(
              'HexGL Drift',
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
              'Race solo, then send a time-trial challenge to your partner',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            BouncyButton(
              onTap: () => _showHexGLModeSelection(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.deepRose, AppTheme.softLavender],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.deepRose.withValues(alpha: 0.3),
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

  Widget _buildChallengeBanner(HexGLChallenge challenge) {
    final auth = context.read<AuthService>();
    final isKhent = auth.uid == AuthService.khentUid;
    final opponent = isKhent ? 'Clair' : 'Khent';
    return BouncyButton(
      onTap: () => _respondToHexGLChallenge(challenge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warmAmber.withValues(alpha: 0.4),
              AppTheme.deepRose.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.warmAmber.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warmAmber.withValues(alpha: 0.25),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sports_kabaddi_rounded,
              color: AppTheme.warmAmber,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$opponent sent you a challenge!',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.petalWhite,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to accept and race',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.petalWhite.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.petalWhite,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showHexGLModeSelection(BuildContext context) {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    final allowed = uid != null && _hexglService.isAllowedPlayer(uid);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
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
              'HexGL Drift',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.roseQuartz,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cityscape · 3 laps · Casual',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            _buildModeOption(
              icon: Icons.timer_rounded,
              title: 'Solo Time Trial',
              subtitle: 'Race the clock and set a personal best',
              onTap: () {
                Navigator.pop(sheetContext);
                _startHexGLSolo();
              },
            ),
            const SizedBox(height: 16),
            if (allowed)
              _buildModeOption(
                icon: Icons.sports_kabaddi_rounded,
                title: 'Challenge ${auth.partnerName}',
                subtitle: 'Race against your partner\'s best ghost',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startHexGLChallengePartner();
                },
              )
            else
              _buildModeOption(
                icon: Icons.lock_outline_rounded,
                title: 'Challenge Partner',
                subtitle: 'Available for Khent and Clair only',
                onTap: () {
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _startHexGLSolo() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HexGLGameScreen(),
      ),
    );
  }

  Future<void> _startHexGLChallengePartner() async {
    final auth = context.read<AuthService>();
    final partner = auth.partnerUid;
    if (partner == null) return;
    try {
      final best =
          await _hexglService.getBestTime(userId: partner, trackId: 'cityscape');
      if (!mounted) return;
      if (best == null || !best.isFinished) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.velvet,
            content: Text(
              '${auth.partnerName} hasn\'t raced yet. Solo race first!',
              style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            ),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HexGLGameScreen(ghostReplay: best),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HexGL challenge partner error: $e');
    }
  }

  Future<void> _respondToHexGLChallenge(HexGLChallenge challenge) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HexGLGameScreen(
          challenge: challenge,
          ghostReplay: challenge.challengerResult,
        ),
      ),
    );
  }
}
