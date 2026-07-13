import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/services/auth_service.dart';
import '../services/academy_service.dart';
import '../models/game_match.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/router/app_router.dart';
import '../services/academy_sync_service.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_spacing.dart';
import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/core/theme/app_elevation.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/shared/widgets/glass_container.dart';

class AcademyHubScreen extends StatefulWidget {
  const AcademyHubScreen({super.key});

  @override
  State<AcademyHubScreen> createState() => _AcademyHubScreenState();

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const AcademyHubScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var slideTween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
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

  static const List<_CategoryData> _categories = [
    _CategoryData('Engineering', Icons.settings_suggest, 'engineering'),
    _CategoryData('Tourism', Icons.public, 'tourism'),
    _CategoryData('Music', Icons.music_note, 'music'),
    _CategoryData('General', Icons.lightbulb, 'general'),
    _CategoryData('Cartoons', Icons.face_retouching_natural, 'cartoons'),
    _CategoryData('Celebrities', Icons.star, 'celebrities'),
    _CategoryData('Film', Icons.movie, 'film'),
    _CategoryData('Books', Icons.book, 'books'),
  ];

  @override
  void initState() {
    super.initState();
    _checkAndSeedQuestions();
  }

  Future<void> _checkAndSeedQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academy_questions')
          .limit(1)
          .get();
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
        _statusMessage = 'Waiting for partner...';
        _startTimeoutTimer();

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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusX2),
        title: Text(
          'Matchmaking Timeout',
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.roseQuartz,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Text(
          'We couldn\'t find a partner for you right now. Would you like to play Solo instead?',
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.roseQuartz.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deepRose,
            ),
            child: Text(
              'Play Solo',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(ValueChanged<String> onCategorySelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CategoryPickerSheet(
        categories: _categories,
        onCategorySelected: (category) {
          Navigator.pop(context);
          onCategorySelected(category);
        },
      ),
    );
  }

  void _startSoloStudyWithCategory(String category) async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Checking for new study materials...';
    });

    try {
      await _syncService.triggerAutoFill(category: category);

      setState(() {
        _statusMessage = 'Preparing questions...';
      });

      final questions = await _academyService.getQuestions(category);

      if (mounted) {
        setState(() => _isSearching = false);
        context.push(
          '/academy/solo',
          extra: SoloStudyArgs(questions: questions, category: category),
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
      _statusMessage = 'Downloading new study materials...';
    });

    try {
      final authService = context.read<AuthService>();
      final isHost = match.hostId == authService.currentUser;

      if (isHost) {
        await _syncService.triggerAutoFill(
          category: match.category,
          isHost: true,
          matchId: match.matchId,
        );
      }

      final questions = await _academyService.getQuestions(match.category);

      if (mounted) {
        context.pushReplacement(
          '/academy/match',
          extra: GameBoardArgs(
            matchId: match.matchId,
            userId: authService.currentUser ?? 'guest',
            questions: questions,
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
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: AppTheme.roseQuartz,
                      ),
                    ),
                    Text(
                      'Academy Hub',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
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
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSearching) ...[
                          const CircularProgressIndicator(
                            color: AppTheme.deepRose,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            _statusMessage ?? '',
                            style: GoogleFonts.outfit(
                              color: AppTheme.roseQuartz,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextButton(
                            onPressed: () =>
                                setState(() => _isSearching = false),
                            child: Text(
                              'Cancel Search',
                              style: GoogleFonts.outfit(
                                color: AppTheme.blushGold,
                              ),
                            ),
                          ),
                        ] else ...[
                          _buildModeButton(
                            'Solo Study',
                            'Practice on your own',
                            Icons.menu_book_rounded,
                            () => _showCategoryPicker(
                                _startSoloStudyWithCategory),
                          ),
                          const SizedBox(height: AppSpacing.x2),
                          _buildModeButton(
                            '1v1 Challenge',
                            'Race against your partner',
                            Icons.bolt_rounded,
                            () => _showCategoryPicker(_startMatchmaking),
                          ),
                          if (_statusMessage != null) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              _statusMessage!,
                              style: GoogleFonts.outfit(
                                color: AppTheme.blushGold,
                              ),
                            ),
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

  Widget _buildModeButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusX2,
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.xl),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(
          color: AppTheme.blushGold.withValues(alpha: 0.2),
          width: 1.0,
        ),
        opacity: AppTheme.glassOpacity,
        child: Row(
          children: [
            Icon(icon, size: 40, color: AppTheme.deepRose),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.roseQuartz,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.petalWhite.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.blushGold,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Data ────────────────────────────────────────────

class _CategoryData {
  final String label;
  final IconData icon;
  final String key;

  const _CategoryData(this.label, this.icon, this.key);
}

// ── Category Picker Bottom Sheet ─────────────────────────────

class _CategoryPickerSheet extends StatefulWidget {
  final List<_CategoryData> categories;
  final ValueChanged<String> onCategorySelected;

  const _CategoryPickerSheet({
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();

    _fadeAnimations = [];
    _slideAnimations = [];

    if (AppMotion.reduced) {
      _animController = AnimationController(
        duration: Duration.zero,
        vsync: this,
      );
      for (int i = 0; i < widget.categories.length; i++) {
        _fadeAnimations.add(AlwaysStoppedAnimation(1.0));
        _slideAnimations.add(AlwaysStoppedAnimation(Offset.zero));
      }
    } else {
      _animController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );

      for (int i = 0; i < widget.categories.length; i++) {
        final start = i * 0.06;
        final end = start + 0.4;

        _fadeAnimations.add(
          Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animController,
              curve: Interval(start, end, curve: AppMotion.easeOutExpo),
            ),
          ),
        );

        _slideAnimations.add(
          Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animController,
              curve: Interval(start, end, curve: AppMotion.easeOutExpo),
            ),
          ),
        );
      }

      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.x5),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x3,
        0,
        AppSpacing.x3,
        bottomPadding + AppSpacing.x3,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.velvet,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.x3),
          topRight: Radius.circular(AppRadius.x3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Choose Category',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1 / 0.85,
            children: List.generate(widget.categories.length, (index) {
              final category = widget.categories[index];
              return FadeTransition(
                opacity: _fadeAnimations[index],
                child: SlideTransition(
                  position: _slideAnimations[index],
                  child: _CategoryCard(
                    data: category,
                    onTap: () => widget.onCategorySelected(category.key),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: 0.3),
          borderRadius: AppRadius.radiusFull,
        ),
      ),
    );
  }
}

// ── Category Card ────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  final _CategoryData data;
  final VoidCallback onTap;

  const _CategoryCard({required this.data, required this.onTap});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: AppMotion.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppMotion.pressScale,
    ).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: AppMotion.easeOutStrong,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.easeOutStrong,
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppTheme.moonlight.withValues(alpha: 0.15)
                  : AppTheme.twilight,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: _isHovered
                    ? AppTheme.roseQuartz.withValues(alpha: 0.3)
                    : AppTheme.moonlight.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: _isHovered
                  ? AppElevation.glowRose
                  : AppElevation.e1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? AppTheme.deepRose.withValues(alpha: 0.15)
                        : AppTheme.roseQuartz.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.data.icon,
                    size: 26,
                    color: _isHovered
                        ? AppTheme.roseQuartz
                        : AppTheme.roseQuartz.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.data.label,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _isHovered
                        ? AppTheme.petalWhite
                        : AppTheme.petalWhite.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
