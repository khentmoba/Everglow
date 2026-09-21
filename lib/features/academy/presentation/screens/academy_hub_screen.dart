import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/auth_service.dart';
import '../../data/services/academy_service.dart';
import '../../data/models/game_match.dart';
import 'package:go_router/go_router.dart';
import '../routes/academy_routes.dart';
import '../../data/services/academy_sync_service.dart';
import '../../data/services/study_set_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_card.dart';
import '../../../../shared/widgets/everglow/everglow_section_header.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/theme/app_typography.dart';

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
  final StudySetService _studySets = StudySetService();
  bool _isSearching = false;
  String? _statusMessage;
  Timer? _timeoutTimer;
  StreamSubscription<DocumentSnapshot>? _matchSub;
  String? _pendingMatchId;

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
      final snapshot = await withGetTimeout(
        FirebaseFirestore.instance
            .collection('academy_questions')
            .limit(1)
            .get(),
        label: 'academy seed check',
      );
      if (snapshot.docs.isEmpty) {
        await _academyService.seedQuestions();
      }
    } catch (e) {
      Logger.e('Error checking and seeding questions', error: e);
    }
  }

  static String _labelFor(String key) {
    for (final c in _categories) {
      if (c.key == key) return c.label;
    }
    return key;
  }

  void _startMatchmaking(String category) async {
    final authService = context.read<AuthService>();
    final uid = authService.uid;
    final username = authService.currentUser;
    if (uid == null || username == null) {
      setState(() {
        _statusMessage = 'Log in to race your love in 1v1.';
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _statusMessage = 'Searching for ${_labelFor(category)} match...';
    });

    try {
      final match = await _academyService.joinOrCreateMatch(
        userUid: uid,
        username: username,
        category: category,
      );

      if (match.status == 'active') {
        // Joined as guest — the host's shared set is ready, no AI spent.
        _goToGame(match);
      } else {
        _pendingMatchId = match.matchId;
        if (mounted) {
          setState(() => _statusMessage = 'Waiting for partner...');
        }
        _startTimeoutTimer();

        // While waiting, Motchi writes a fresh shared set for the match.
        // Fail-soft: the cached order stands when she is resting.
        _studySets
            .buildMatchSet(category: category)
            .then(
              (ids) => _academyService.upgradeWaitingMatchQuestions(
                matchId: match.matchId,
                questionIds: ids,
              ),
            )
            .ignore();

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
                _pendingMatchId = null;
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

  Future<void> _cancelSearch() async {
    _timeoutTimer?.cancel();
    _matchSub?.cancel();
    _matchSub = null;
    final pending = _pendingMatchId;
    _pendingMatchId = null;
    if (pending != null) {
      await _academyService.cancelWaitingMatch(pending);
    }
    if (mounted) {
      setState(() {
        _isSearching = false;
        _statusMessage = null;
      });
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 60), () async {
      if (mounted && _isSearching) {
        final pending = _pendingMatchId;
        _pendingMatchId = null;
        _matchSub?.cancel();
        _matchSub = null;
        if (pending != null) {
          await _academyService.cancelWaitingMatch(pending);
        }
        if (!mounted) return;
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
            onPressed: () {
              Navigator.pop(context);
              _showCategoryPicker(allowTopic: true, onPick: _startSoloStudy);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepRose,
            ),
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

  void _showCategoryPicker({
    bool allowTopic = false,
    required void Function(String category, String topic) onPick,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CategoryPickerSheet(
        categories: _categories,
        allowTopic: allowTopic,
        onPick: (category, topic) {
          Navigator.pop(context);
          onPick(category, topic);
        },
      ),
    );
  }

  void _startSoloStudy(String category, String topic) async {
    setState(() {
      _isSearching = true;
      _statusMessage = topic.isEmpty
          ? 'Motchi is writing ${_labelFor(category)} questions...'
          : 'Motchi is writing about "$topic"...';
    });

    try {
      final questions = await _studySets.buildSoloSet(
        category: category,
        topic: topic,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'No questions right now — try again in a bit.';
        });
        return;
      }
      setState(() => _isSearching = false);
      final result = await context.push(
        '/academy/solo',
        extra: SoloStudyArgs(
          questions: questions,
          category: category,
          topic: topic,
        ),
      );
      // Solo results can send Clair straight into a 1v1 challenge.
      if (result == 'challenge' && mounted) {
        _showCategoryPicker(onPick: (picked, _) => _startMatchmaking(picked));
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
      _statusMessage = 'Loading the shared questions...';
    });

    try {
      final authService = context.read<AuthService>();
      final username = authService.currentUser ?? 'guest';
      final isHost = match.hostId == authService.uid;

      if (isHost) {
        await _syncService.triggerAutoFill(
          category: match.category,
          isHost: true,
          matchId: match.matchId,
        );
      }

      // Both phones load the SAME snapshotted order. Legacy matches
      // without one fall back to a fresh random pull (best effort).
      final questions = match.questionIds.isNotEmpty
          ? await _academyService.getQuestionsByIds(match.questionIds)
          : await _academyService.getQuestions(match.category);

      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'No questions right now — try again in a bit.';
        });
        return;
      }
      context.pushReplacement(
        '/academy/match',
        extra: GameBoardArgs(
          matchId: match.matchId,
          username: username,
          questions: questions,
        ),
      );
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
    final pending = _pendingMatchId;
    _pendingMatchId = null;
    if (pending != null) {
      // Best effort: don't strand a waiting match we walked away from.
      _academyService.cancelWaitingMatch(pending).ignore();
    }
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
                                  onPressed: _cancelSearch,
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
                                onTap: () => _showCategoryPicker(
                                  onPick: (category, _) =>
                                      _startMatchmaking(category),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              StreamBuilder<SoloStats?>(
                                stream: _studySets.watchSoloStats(),
                                builder: (context, snapshot) {
                                  return AcademyModeCard(
                                    title: 'Solo Study',
                                    subtitle: _soloSubtitle(snapshot.data),
                                    badge: 'CALM PRACTICE',
                                    icon: Icons.menu_book_rounded,
                                    accent: AppColors.auroraGold,
                                    onTap: () => _showCategoryPicker(
                                      allowTopic: true,
                                      onPick: _startSoloStudy,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AcademyModeCard(
                                title: 'Study with Motchi',
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

  String _soloSubtitle(SoloStats? stats) {
    final last = stats?.lastCategory;
    if (last == null) return 'Quiet questions, no timer';
    final best = stats!.bestByCategory[last];
    if (best == null) return '${_labelFor(last)} · Quiet, no timer';
    return '${_labelFor(last)} · Best $best';
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
        border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.22)),
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
            'Solo for quiet practice, 1v1 to race your love, Motchi for PDFs.',
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
              border: Border.all(color: accent.withValues(alpha: 0.35)),
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
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
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
  final bool allowTopic;
  final void Function(String category, String topic) onPick;

  const _CategoryPickerSheet({
    required this.categories,
    required this.onPick,
    this.allowTopic = false,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  final TextEditingController _topicController = TextEditingController();

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
    _topicController.dispose();
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Choose Category',
              style: AppTypography.cormorantBold.copyWith(fontSize: 26),
            ),
            if (widget.allowTopic) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _topicController,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                style: AppTypography.outfitWhite.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask Motchi about... (optional)',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    fontSize: 13,
                    color: AppColors.petalWhite.withValues(alpha: 0.4),
                  ),
                  prefixIcon: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: AppColors.auroraGold,
                  ),
                  filled: true,
                  fillColor: AppColors.moonlight.withValues(alpha: 0.07),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg,
                    borderSide: BorderSide(
                      color: AppColors.auroraGold.withValues(alpha: 0.25),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg,
                    borderSide: BorderSide(
                      color: AppColors.auroraGold.withValues(alpha: 0.25),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg,
                    borderSide: const BorderSide(
                      color: AppColors.auroraGold,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
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
                      onTap: () => widget.onPick(
                        category.key,
                        _topicController.text.trim(),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
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
