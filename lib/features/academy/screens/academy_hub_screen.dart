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
        title: const Text('Matchmaking Timeout'),
        content: const Text('We couldn\'t find a partner for you right now. Would you like to play Solo instead?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to Solo Mode (T018)
            },
            child: const Text('Play Solo'),
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
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Category', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pink)),
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
      backgroundColor: const Color(0xFFFFE6F2),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFFF69B4)),
                  ),
                  Text(
                    'Academy Hub',
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFFFF69B4)),
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
                        const CircularProgressIndicator(color: Color(0xFFFF69B4)),
                        const SizedBox(height: 20),
                        Text(_statusMessage ?? '', style: GoogleFonts.outfit(color: Colors.pink[300])),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => setState(() => _isSearching = false),
                          child: const Text('Cancel Search'),
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
                          Text(_statusMessage!, style: GoogleFonts.outfit(color: Colors.pink[300])),
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
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Category', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pink)),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: const Color(0xFFFF69B4)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink[50],
        foregroundColor: Colors.pink,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
      child: Column(
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
