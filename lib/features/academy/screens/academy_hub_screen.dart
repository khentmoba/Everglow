import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/services/auth_service.dart';
import '../services/academy_service.dart';
import '../models/game_match.dart';
import 'game_board_screen.dart';
import 'solo_study_screen.dart';
import '../services/academy_sync_service.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/shared/widgets/glass_container.dart';

class AcademyHubScreen extends StatefulWidget {
  const AcademyHubScreen({super.key});

  @override
  State<AcademyHubScreen> createState() => _AcademyHubScreenState();

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const AcademyHubScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        return FadeTransition(opacity: animation.drive(fadeTween), child: SlideTransition(position: animation.drive(slideTween), child: child));
      },
    );
  }
}

class _AcademyHubScreenState extends State<AcademyHubScreen> {
  final AcademyService _academyService = AcademyService();
  final AcademySyncService _syncService = AcademySyncService();
  bool _isSearching = false;
  String? _statusMessage;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _checkAndSeedQuestions();
  }

  Future<void> _checkAndSeedQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('academy_questions').limit(1).get();
      if (snapshot.docs.isEmpty) {
        await _academyService.seedQuestions();
      }
    } catch (e) {
      print('Error checking and seeding questions: $e');
    }
  }

  void _startMatchmaking(String category) async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Searching for $category match...';
    });

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser ?? 'guest';
      
      final match = await _academyService.joinOrCreateMatch(userId, category);
      
      if (match.status == 'active') {
        _goToGame(match);
      } else {
        // Waiting for someone to join
        _statusMessage = 'Waiting for partner...';
        _startTimeoutTimer();
        
        // Listen for match updates
        FirebaseFirestore.instance
            .collection('active_matches')
            .doc(match.matchId)
            .snapshots()
            .listen((snapshot) {
          if (!mounted) return;
          final updatedMatch = GameMatch.fromFirestore(snapshot);
          if (updatedMatch.status == 'active') {
            _timeoutTimer?.cancel();
            _goToGame(updatedMatch);
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
          _statusMessage = 'No partner found. Try Solo Study?';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Matchmaking Timeout',
          style: GoogleFonts.cormorantGaramond(color: AppTheme.roseQuartz, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        content: Text(
          'We couldn\'t find a partner for you right now. Would you like to play Solo instead?',
          style: GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepRose),
            child: Text('Play Solo', style: GoogleFonts.outfit(color: AppTheme.petalWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startSoloStudy() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Category', style: GoogleFonts.cormorantGaramond(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.roseQuartz)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                children: [
                  _buildCategoryButton('Engineering', Icons.settings_suggest, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('engineering');
                  }),
                  _buildCategoryButton('Tourism', Icons.public, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('tourism');
                  }),
                  _buildCategoryButton('Music', Icons.music_note, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('music');
                  }),
                  _buildCategoryButton('General', Icons.lightbulb, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('general');
                  }),
                  _buildCategoryButton('Cartoons', Icons.face_retouching_natural, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('cartoons');
                  }),
                  _buildCategoryButton('Celebrities', Icons.star, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('celebrities');
                  }),
                  _buildCategoryButton('Film', Icons.movie, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('film');
                  }),
                  _buildCategoryButton('Books', Icons.book, () {
                    Navigator.pop(context);
                    _startSoloStudyWithCategory('books');
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSoloStudyWithCategory(String category) async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Checking for new study materials... 📚';
    });

    try {
      await _syncService.triggerAutoFill(category: category);

      setState(() {
        _statusMessage = 'Preparing questions...';
      });
      
      final questions = await _academyService.getQuestions(category);
      
      if (mounted) {
        setState(() => _isSearching = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SoloStudyScreen(
              questions: questions,
              category: category,
            ),
          ),
        );
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

  void _goToGame(GameMatch match) async {
    setState(() {
      _statusMessage = 'Downloading new study materials... 📚';
    });

    try {
      final authService = context.read<AuthService>();
      final isHost = match.hostId == authService.currentUser;

      // Host triggers the sync if questions are low
      if (isHost) {
        await _syncService.triggerAutoFill(
          category: match.category,
          isHost: true,
          matchId: match.matchId,
        );
      }

      final questions = await _academyService.getQuestions(match.category);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameBoardScreen(
              matchId: match.matchId,
              userId: authService.currentUser ?? 'guest',
              questions: questions,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'Sync Error: $e';
        });
      }
    }
  }

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
                      'Academy Hub',
                      style: GoogleFonts.cormorantGaramond(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.roseQuartz),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSearching) ...[
                          const CircularProgressIndicator(color: AppTheme.deepRose),
                          const SizedBox(height: 20),
                          Text(_statusMessage ?? '', style: GoogleFonts.outfit(color: AppTheme.roseQuartz)),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => setState(() => _isSearching = false),
                            child: Text('Cancel Search', style: GoogleFonts.outfit(color: AppTheme.blushGold)),
                          ),
                        ] else ...[
                          _buildModeButton(
                            'Solo Study',
                            'Practice on your own',
                            Icons.menu_book_rounded,
                            () => _startSoloStudy(),
                          ),
                          const SizedBox(height: 24),
                          _buildModeButton(
                            '1v1 Challenge',
                            'Race against your partner',
                            Icons.bolt_rounded,
                            () => _showCategoryPicker(),
                          ),
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 20),
                            Text(_statusMessage!, style: GoogleFonts.outfit(color: AppTheme.blushGold)),
                          ],
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

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Category', style: GoogleFonts.cormorantGaramond(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.roseQuartz)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                children: [
                  _buildCategoryButton('Engineering', Icons.settings_suggest, () {
                    Navigator.pop(context);
                    _startMatchmaking('engineering');
                  }),
                  _buildCategoryButton('Tourism', Icons.public, () {
                    Navigator.pop(context);
                    _startMatchmaking('tourism');
                  }),
                  _buildCategoryButton('Music', Icons.music_note, () {
                    Navigator.pop(context);
                    _startMatchmaking('music');
                  }),
                  _buildCategoryButton('General', Icons.lightbulb, () {
                    Navigator.pop(context);
                    _startMatchmaking('general');
                  }),
                  _buildCategoryButton('Cartoons', Icons.face_retouching_natural, () {
                    Navigator.pop(context);
                    _startMatchmaking('cartoons');
                  }),
                  _buildCategoryButton('Celebrities', Icons.star, () {
                    Navigator.pop(context);
                    _startMatchmaking('celebrities');
                  }),
                  _buildCategoryButton('Film', Icons.movie, () {
                    Navigator.pop(context);
                    _startMatchmaking('film');
                  }),
                  _buildCategoryButton('Books', Icons.book, () {
                    Navigator.pop(context);
                    _startMatchmaking('books');
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.2), width: 1.0),
        opacity: AppTheme.glassOpacity,
        child: Row(
          children: [
            Icon(icon, size: 40, color: AppTheme.deepRose),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.roseQuartz)),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.petalWhite.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.blushGold, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.twilight,
        foregroundColor: AppTheme.blushGold,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: AppTheme.roseQuartz),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.petalWhite)),
        ],
      ),
    );
  }
}
