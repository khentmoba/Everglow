import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/auth_service.dart';
import '../services/academy_service.dart';
import '../models/game_match.dart';
import 'package:go_router/go_router.dart';
import '../presentation/routes/academy_routes.dart';
import '../services/academy_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../shared/widgets/everglow/everglow_background.dart';
import '../../../shared/widgets/everglow/everglow_card.dart';
import '../../../shared/widgets/everglow/everglow_section_header.dart';
import '../../../core/utils/logger.dart';
import '../../../core/theme/app_typography.dart';

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
        var slideTween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
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
  StreamSubscription<DocumentSnapshot>? _matchSub;

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
      // Skip in widget tests / before Firebase init.
      if (Firebase.apps.isEmpty) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('academy_questions')
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        await _academyService.seedQuestions();
      }
    } catch (e) {
      Logger.e('Error checking and seeding questions', error: e);
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

        _matchSub?.cancel();
        _matchSub = FirebaseFirestore.instance
            .collection('active_matches')
            .doc(match.matchId)
            .snapshots()
            .listen((snapshot) {
              if (!mounted) return;
              if (!snapshot.exists) return;
              final updatedMatch = GameMatch.fromFirestore(snapshot);
              if (updatedMatch.status == 'active') {
                _timeoutTimer?.cancel();
                _matchSub?.cancel();
                _matchSub = null;
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
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusX2),
        title: Text(
          'Matchmaking Timeout',
          style: AppTypography.cormorantBold.copyWith(fontSize: 24),
        ),
        content: Text(
          'We couldn\'t find a partner for you right now. Would you like to play Solo instead?',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.roseQuartz.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepRose),
            child: Text(
              'Play Solo',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.petalWhite,
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
    _matchSub?.cancel();
    _matchSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.softLavender,
                  alignment: Alignment(-0.7, -0.85),
                  size: 0.8,
                  opacity: 0.10,
                ),
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(0.85, 0.9),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const EverglowFeatureHeader(
                  title: 'Academy Hub',
                  subtitle: 'play \u00b7 learn \u00b7 compete together',
                  icon: Icons.school_rounded,
                  hue: AppColors.softLavender,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageH(context),
                      AppSpacing.md,
                      AppSpacing.pageH(context),
                      AppSpacing.x3,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildWelcome(),
                            const SizedBox(height: AppSpacing.xl),
                            const EverglowSectionHeader(
                              label: 'Choose a mode',
                              icon: Icons.sports_esports_rounded,
                              hue: AppColors.auroraRose,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (_isSearching) ...[
                              const EverglowSkeleton(
                                height: 24,
                                width: 24,
                                radius: 12,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                _statusMessage ?? '',
                                textAlign: TextAlign.center,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 14,
                                  color: AppColors.roseQuartz,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Center(
                                child: TextButton(
                                  onPressed: () => setState(
                                    () => _isSearching = false,
                                  ),
                                  child: Text(
                                    'Cancel Search',
                                    style: AppTypography.outfitWhite.copyWith(
                                      color: AppColors.blushGold,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              AcademyModeCard(
                                title: '1v1 Challenge',
                                subtitle: 'Race your love in real time',
                                badge: 'LIVE \u00b7 TOGETHER',
                                icon: Icons.bolt_rounded,
                                accent: AppColors.deepRose,
                                onTap: () =>
                                    _showCategoryPicker(_startMatchmaking),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AcademyModeCard(
                                title: 'Solo Study',
                                subtitle: 'Quiet questions, no timer',
                                badge: 'CALM PRACTICE',
                                icon: Icons.menu_book_rounded,
                                accent: AppColors.auroraGold,
                                onTap: () => _showCategoryPicker(
                                  _startSoloStudyWithCategory,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AcademyModeCard(
                                title: 'Study with Mochi',
                                subtitle: 'Ask about your PDFs',
                                badge: 'AI HELPER',
                                icon: Icons.picture_as_pdf_rounded,
                                accent: AppColors.softLavender,
                                onTap: () => context.push('/study'),
                              ),
                              if (_statusMessage != null) ...[
                                const SizedBox(height: AppSpacing.xl),
                                Text(
                                  _statusMessage!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 13,
                                    color: AppColors.blushGold,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.85),
            AppColors.inkDeep.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.x2),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What shall we learn today?',
            style: AppTypography.cormorantBold.copyWith(
              fontSize: 24,
              height: 1.1,
              color: AppColors.roseQuartz,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Solo for quiet practice, 1v1 to race your love, Mochi for PDFs.',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              height: 1.45,
              color: AppColors.petalWhite.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

/// Warm, tappable mode row — extracted so layout tests can pump it
/// without Firebase, Auth, or GoRouter.
class AcademyModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const AcademyModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return EverglowCard(
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(icon, size: 24, color: accent),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      badge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 21,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.petalWhite.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.moonlight.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: accent,
              size: 14,
            ),
          ),
        ],
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
        _fadeAnimations.add(const AlwaysStoppedAnimation(1.0));
        _slideAnimations.add(const AlwaysStoppedAnimation(Offset.zero));
      }
    } else {
      _animController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );

      for (int i = 0; i < widget.categories.length; i++) {
        final start = (i * 0.06).clamp(0.0, 1.0);
        final end = (start + 0.4).clamp(0.0, 1.0);

        _fadeAnimations.add(
          Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animController,
              curve: Interval(start, end, curve: AppMotion.easeOutExpo),
            ),
          ),
        );

        _slideAnimations.add(
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
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
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.x5),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x3,
        0,
        AppSpacing.x3,
        bottomPadding + AppSpacing.x3,
      ),
      decoration: const BoxDecoration(
        color: AppColors.velvet,
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
            style: AppTypography.cormorantBold.copyWith(fontSize: 26),
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
          color: AppColors.moonlight.withValues(alpha: 0.3),
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: AppMotion.pressScale)
        .animate(
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
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.easeOutStrong,
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppColors.moonlight.withValues(alpha: 0.15)
                  : AppColors.twilight,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: _isHovered
                    ? AppColors.roseQuartz.withValues(alpha: 0.3)
                    : AppColors.moonlight.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: _isHovered ? AppElevation.glowRose : AppElevation.e1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? AppColors.deepRose.withValues(alpha: 0.15)
                        : AppColors.roseQuartz.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.data.icon,
                    size: 26,
                    color: _isHovered
                        ? AppColors.roseQuartz
                        : AppColors.roseQuartz.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.data.label,
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: _isHovered
                        ? AppColors.petalWhite
                        : AppColors.petalWhite.withValues(alpha: 0.85),
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
