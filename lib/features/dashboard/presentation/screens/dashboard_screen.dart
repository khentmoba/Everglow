import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/utils/logger.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';

import '../../../date_randomizer/presentation/widgets/randomizer_card.dart';
import '../../../date_randomizer/data/services/date_idea_service.dart';
import '../../../../features/guardian/data/services/guardian_service.dart';
import '../../../../features/guardian/presentation/controllers/guardian_controller.dart';
import 'dashboard_lifecycle.dart';
import '../../../daily_bloom/presentation/widgets/daily_bloom.dart';
import '../../../daily_bloom/presentation/providers/garden_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/presence_service.dart';
import '../widgets/cinema_preview.dart';
import '../widgets/anime_preview.dart';
import '../widgets/books_preview.dart';
import '../widgets/manga_preview.dart';
import '../widgets/currently_watching_preview.dart';
import '../../../starlight_jar/presentation/screens/starlight_jar_widget.dart';
import '../../../heartbeat/presentation/controllers/mood_controller.dart';
import '../../../academy/widgets/academy_portal_card.dart';
import '../../../../features/play_zone/presentation/widgets/play_zone_portal_card.dart';
import '../../../../features/jukebox/presentation/widgets/jukebox_widget.dart';
import '../../../../features/jukebox/presentation/widgets/music_stats_section.dart';
import '../../../../features/watch_party/presentation/widgets/watch_party_card.dart';
import '../widgets/gallery_preview.dart';
import '../widgets/calendar_preview.dart';
import '../../../../features/bucket_list/presentation/widgets/bucket_list_preview.dart';
import '../widgets/letterbox_view.dart';
import '../widgets/upcoming_countdowns.dart';
import '../widgets/timeline_view.dart';
import '../widgets/on_this_day_card.dart';

import '../../../xp/data/services/xp_service.dart';
import '../../../xp/domain/models/user_progress.dart';
import '../../../xp/presentation/widgets/xp_progress_bar.dart';
import '../widgets/anniversary_metrics.dart';
import '../widgets/dashboard_overlays.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../widgets/dashboard_motion.dart';

class DashboardScreen extends StatefulWidget {
  final bool animate;
  const DashboardScreen({super.key, this.animate = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final DashboardLifecycle _lifecycle = DashboardLifecycle();
  AuthService? _authService;
  PresenceService? _presenceService;
  String? _lastHeartbeatUid;
  String? _lastHeartbeatUsername;
  Timer? _heartbeatRetryTimer;
  int _heartbeatRetryCount = 0;
  static const int _maxHeartbeatRetries = 5;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'coming-up': GlobalKey(),
    'watching': GlobalKey(),
    'shelves': GlobalKey(),
    'timeline': GlobalKey(),
    'moments': GlobalKey(),
  };

  void _jumpTo(String id) {
    final ctx = _sectionKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: AppMotion.orZero(const Duration(milliseconds: 420)),
        curve: AppMotion.easeOutStrong,
        alignment: 0.05,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle.install(_setOfflineFromHeartbeat);

    Future.microtask(() {
      if (mounted) {
        final authService = context.read<AuthService>();
        final gardenProvider = context.read<GardenProvider>();

        if (authService.user != null) {
          gardenProvider.updateUserId(authService.user!.uid);
          gardenProvider.recordInteraction();
        }

        // These Firestore reads need a signed-in session. Guarding them
        // prevents permission-denied errors when the dashboard is opened
        // as a deep link before the gateway has authenticated the user.
        if (authService.isReady) {
          context.read<DateIdeaService>().initialize().catchError((Object e) {
            Logger.e('Date ideas init failed', error: e);
          });
          context.read<GuardianService>().initialize().catchError((Object e) {
            Logger.e('Guardian init failed', error: e);
          });
        }

        final moodController = context.read<MoodController>();
        final currentUsername = authService.currentUser;
        if (currentUsername != null) {
          moodController.checkTodayStatus(currentUsername).then((_) {
            if (!mounted) return;
            if (!moodController.hasSubmittedToday) {
              context.read<GuardianController>().triggerMoodPrompt();
            }
          });
        }

        _runPartnerCleanupIfNeeded(authService);
        _syncPresenceHeartbeat();
      }
    });
  }

  Future<void> _runPartnerCleanupIfNeeded(AuthService auth) async {
    if (auth.currentUser != 'khentsgdz') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('partner_cleanup_v1') == true) return;
      final tmdbService = TMDBService();
      final removed = await tmdbService.cleanupDuplicatePartnerEntries();
      if (removed > 0) {
        Logger.i(
          "[Dashboard] Cleanup removed $removed duplicate watchlist entries",
        );
      }
      await prefs.setBool('partner_cleanup_v1', true);
    } catch (e) {
      Logger.e("[Dashboard] Partner cleanup failed", error: e);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.uninstall();
    _heartbeatRetryTimer?.cancel();
    final presence = _presenceService;
    final uid = _lastHeartbeatUid;
    if (presence != null && uid != null && uid.isNotEmpty) {
      presence.stopHeartbeat();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final presence = _presenceService;
    final auth = _authService;
    final uid = auth?.uid;
    if (presence == null || uid == null || uid.isEmpty) return;

    if (state == AppLifecycleState.resumed) {
      presence.startHeartbeat(uid: uid, username: auth!.currentUser ?? '');
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      presence.setOffline(uid);
    }
  }

  void _syncPresenceHeartbeat() {
    final auth = context.read<AuthService>();
    final presence = context.read<PresenceService>();
    _authService = auth;
    _presenceService = presence;
    final uid = auth.uid;
    final username = auth.currentUser ?? '';

    if (uid == null || uid.isEmpty) {
      if (_lastHeartbeatUid != null) {
        presence.stopHeartbeat();
        _lastHeartbeatUid = null;
        _lastHeartbeatUsername = null;
      }
      if (_heartbeatRetryCount < _maxHeartbeatRetries) {
        _heartbeatRetryCount++;
        final delay = Duration(seconds: 1 + _heartbeatRetryCount);
        _heartbeatRetryTimer?.cancel();
        _heartbeatRetryTimer = Timer(delay, () {
          if (mounted) _syncPresenceHeartbeat();
        });
      }
      return;
    }

    _heartbeatRetryTimer?.cancel();
    _heartbeatRetryCount = 0;

    if (uid != _lastHeartbeatUid || username != _lastHeartbeatUsername) {
      presence.startHeartbeat(uid: uid, username: username);
      _lastHeartbeatUid = uid;
      _lastHeartbeatUsername = username;
    }
  }

  void _setOfflineFromHeartbeat() {
    final uid = _lastHeartbeatUid;
    final presence = _presenceService;
    if (uid != null && presence != null) {
      presence.setOffline(uid);
    }
  }

  /// Wraps a widget in a [FadeInUp] animation when [animate] is enabled.
  /// Respects reduced-motion: fades in place with no translation.
  Widget _animatedSliver(
    Widget child, {
    int delayMs = 900,
    double heightAfter = 32,
    double placeholderHeight = 220,
  }) {
    final Widget animated;
    if (!widget.animate) {
      animated = child;
    } else if (AppMotion.reduced) {
      animated = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        builder: (_, opacity, c) => Opacity(opacity: opacity, child: c),
        child: child,
      );
    } else {
      animated = FadeInUp(
        delay: Duration(milliseconds: delayMs),
        child: child,
      );
    }
    return SliverToBoxAdapter(
      child: _DeferredSection(
        placeholderHeight: placeholderHeight,
        child: animated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReady = context.select<AuthService, bool>((a) => a.isReady);

    if (!isReady) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: EverglowBackground(baseColor: AppColors.inkDeep),
            ),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.deepRose,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final contentMaxWidth = ResponsiveValue<double>(
      mobile: 600,
      tablet: 820,
      desktop: 980,
    ).of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: const [
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(-0.7, -0.85),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.softLavender,
                  alignment: Alignment(0.85, 0.95),
                  size: 0.8,
                  opacity: 0.10,
                ),
                RadialGlow(
                  color: AppColors.auroraGold,
                  alignment: Alignment(0.1, 0.45),
                  size: 0.6,
                  opacity: 0.05,
                ),
              ],
              showPetals: false,
            ),
          ),
          // Ambient dusk-bloom layer (dashboard only).
          const Positioned.fill(child: DashboardAmbience()),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
                            child: widget.animate
                                ? (AppMotion.reduced
                                    ? _buildHeader(context)
                                    : FadeInDown(
                                        duration: const Duration(milliseconds: 800),
                                        child: _buildHeader(context),
                                      ))
                                : _buildHeader(context),
                          ),
                        ),

                        // XP Progress Bar
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Selector<AuthService, String?>(
                              selector: (_, auth) => auth.user?.uid,
                              builder: (context, uid, _) =>
                                  _XpProgressSection(uid: uid),
                            ),
                          ),
                        ),

                        // Quick access rail
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                            child: widget.animate
                                ? (AppMotion.reduced
                                    ? _buildQuickActions(context)
                                    : FadeInUp(
                                        delay: const Duration(milliseconds: 250),
                                        child: _buildQuickActions(context),
                                      ))
                                : _buildQuickActions(context),
                          ),
                        ),

                        // Anniversary Metrics Grid
                        AnniversaryMetrics(animate: widget.animate),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                            child: _DashboardJumpBar(onJump: _jumpTo),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 26)),

                        // On This Day
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['coming-up'], height: 0),
                        ),
                        _animatedSliver(
                          const OnThisDayCard(),
                          delayMs: 800,
                          placeholderHeight: 190,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        // Feature content sections
                        _animatedSliver(
                          UpcomingCountdowns(),
                          delayMs: 850,
                          heightAfter: 16,
                          placeholderHeight: 300,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        _animatedSliver(
                          const LetterboxView(),
                          delayMs: 900,
                          placeholderHeight: 210,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        _animatedSliver(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: JukeboxWidget(),
                          ),
                          delayMs: 950,
                          placeholderHeight: 320,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        _animatedSliver(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: const MusicStatsSection(),
                          ),
                          delayMs: 1000,
                          placeholderHeight: 420,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        _animatedSliver(
                          RandomizerCard(
                            service: context.read<DateIdeaService>(),
                          ),
                          delayMs: 1050,
                          placeholderHeight: 280,
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['watching'], height: 0),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        _animatedSliver(
                          const CurrentlyWatchingPreview(),
                          delayMs: 1080,
                          placeholderHeight: 260,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        _animatedSliver(
                          const WatchPartyCard(),
                          delayMs: 1100,
                          placeholderHeight: 190,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        _animatedSliver(
                          const CinemaPreview(),
                          delayMs: 1100,
                          placeholderHeight: 300,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        _animatedSliver(
                          const AnimePreview(),
                          delayMs: 1130,
                          placeholderHeight: 300,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        _animatedSliver(
                          const BooksPreview(),
                          delayMs: 1150,
                          placeholderHeight: 300,
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['shelves'], height: 0),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 2)),
                        _animatedSliver(
                          const GalleryPreview(),
                          delayMs: 1170,
                          placeholderHeight: 200,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        _animatedSliver(
                          const CalendarPreview(),
                          delayMs: 1175,
                          placeholderHeight: 220,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        _animatedSliver(
                          const MangaPreview(),
                          delayMs: 1180,
                          placeholderHeight: 300,
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['timeline'], height: 0),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        _animatedSliver(
                          const TimelineView(),
                          delayMs: 1200,
                          placeholderHeight: 620,
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['moments'], height: 0),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        _animatedSliver(
                          const StarlightJarWidget(),
                          delayMs: 1300,
                          placeholderHeight: 640,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        _animatedSliver(
                          const DailyBloom(),
                          delayMs: 1350,
                          placeholderHeight: 320,
                        ),
                        _animatedSliver(
                          const AcademyPortalCard(),
                          delayMs: 1400,
                          placeholderHeight: 200,
                        ),
                        _animatedSliver(
                          const PlayZonePortalCard(),
                          delayMs: 1450,
                          placeholderHeight: 200,
                        ),
                        _animatedSliver(
                          const BucketListPreview(),
                          delayMs: 1500,
                          placeholderHeight: 280,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 110)),
                      ],
                    ),
                  ),
                ),

                // Soft ember trail that follows the mouse.
                const Positioned.fill(child: DashboardCursorGlow()),

                // Floating overlays
                const DashboardOverlays(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 400 ? 38.0 : 48.0;
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.blushGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.auroraRose,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.auroraRose.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'EST.  FEBRUARY 14, 2026  —  KHENT  &  CLAIR',
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 2.0,
                    color: AppColors.blushGold.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BreathingEmblem(
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.moonlight.withValues(alpha: 0.18),
                    AppColors.deepRose.withValues(alpha: 0.12),
                    AppColors.inkDeep.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.52),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.30),
                    blurRadius: 36,
                    spreadRadius: -6,
                  ),
                  BoxShadow(
                    color: AppColors.blushGold.withValues(alpha: 0.14),
                    blurRadius: 22,
                    spreadRadius: -10,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(13),
              child: ClipOval(
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'welcome home',
            style: AppTypography.handwrittenBody().copyWith(
              fontSize: 23,
              color: AppColors.blushGold.withValues(alpha: 0.92),
              height: 1.0,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          ShimmerTitle(
            child: Text(
              'Forever In Bloom',
              textAlign: TextAlign.center,
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: titleSize,
                height: 1.0,
                letterSpacing: -1.0,
                shadows: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.45),
                    blurRadius: 28,
                  ),
                  BoxShadow(
                    color: AppColors.blushGold.withValues(alpha: 0.30),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'since  February  14,  2026',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 12.5,
                  color: AppColors.petalWhite.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.blushGold.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const PulseHeart(
                child: Icon(
                  Icons.favorite_rounded,
                  color: AppColors.auroraRose,
                  size: 14,
                ),
              ),
              Container(
                width: 3,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 42,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blushGold.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        label: 'Gallery',
        icon: Icons.photo_library_rounded,
        route: '/gallery',
        hue: AppColors.roseQuartz,
        caption: 'Memories',
      ),
      _QuickAction(
        label: 'Sanctuary',
        icon: Icons.chat_bubble_rounded,
        route: '/sanctuary',
        hue: AppColors.auroraRose,
        caption: 'Chat',
      ),
      _QuickAction(
        label: 'Canvas',
        icon: Icons.brush_rounded,
        route: '/canvas',
        hue: AppColors.softLavender,
        caption: 'Draw',
      ),
      _QuickAction(
        label: 'Mochi',
        icon: Icons.auto_awesome_rounded,
        route: '/mochi',
        hue: AppColors.auroraGold,
        caption: 'AI companion',
      ),
      _QuickAction(
        label: 'Calendar',
        icon: Icons.calendar_month_rounded,
        route: '/calendar',
        hue: AppColors.warmAmber,
        caption: 'Dates',
      ),
      _QuickAction(
        label: 'Starlight',
        icon: Icons.auto_awesome_mosaic_rounded,
        route: '/starlight',
        hue: AppColors.auroraLilac,
        caption: 'Gratitude',
      ),
      _QuickAction(
        label: 'Bucket List',
        icon: Icons.card_travel_rounded,
        route: '/bucket-list',
        hue: AppColors.auroraTeal,
        caption: 'Dreams',
      ),
      _QuickAction(
        label: 'Letterbox',
        icon: Icons.mail_outline_rounded,
        route: '/letterbox',
        hue: AppColors.blushGold,
        caption: 'Letters',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blushGold.withValues(alpha: 0.0),
                    AppColors.blushGold.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.moonlight.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 11,
                    color: AppColors.blushGold.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'QUICK ACCESS',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 10,
                      letterSpacing: 2.0,
                      color: AppColors.blushGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blushGold.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 300 ? 3 : 4;
            final tileWidth =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: tileWidth,
                    child: _QuickActionTile(action: action),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Keeps a heavy dashboard section out of the tree until the scroll view
/// brings it near the viewport, so its Firestore streams and image loads only
/// start when the user actually approaches it.
class _DeferredSection extends StatefulWidget {
  final Widget child;
  final double placeholderHeight;

  const _DeferredSection({
    required this.child,
    this.placeholderHeight = 220,
  });

  @override
  State<_DeferredSection> createState() => _DeferredSectionState();
}

class _DeferredSectionState extends State<_DeferredSection> {
  final GlobalKey _key = GlobalKey();
  ScrollableState? _scrollable;
  bool _visible = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != _scrollable) {
      _scrollable?.position.removeListener(_onScroll);
      _scrollable = scrollable;
      scrollable?.position.addListener(_onScroll);
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _scrollable?.position.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _scheduleCheck();

  void _scheduleCheck() {
    if (_visible || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _check();
    });
  }

  void _check() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !mounted) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (top < viewportHeight + 500 && bottom > -500) {
      _scrollable?.position.removeListener(_onScroll);
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: _visible
          ? widget.child
          : SizedBox(height: widget.placeholderHeight),
    );
  }
}

/// Binds the XP progress stream to the current uid without re-creating the
/// Firestore listener on every unrelated auth notification.
class _XpProgressSection extends StatefulWidget {
  final String? uid;
  const _XpProgressSection({required this.uid});

  @override
  State<_XpProgressSection> createState() => _XpProgressSectionState();
}

class _XpProgressSectionState extends State<_XpProgressSection> {
  final XPService _service = XPService();
  Stream<UserProgress?>? _stream;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant _XpProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _bind();
  }

  void _bind() {
    final uid = widget.uid;
    _stream = (uid == null || uid.isEmpty) ? null : _service.watchProgress(uid);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<UserProgress?>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return XPProgressBar(progress: snapshot.data!);
      },
    );
  }
}

class _QuickAction {
  final String label;
  final String caption;
  final IconData icon;
  final String route;
  final Color hue;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.hue,
    this.caption = '',
  });
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;

  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return Semantics(
      button: true,
      label: action.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            context.push(action.route);
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0)
              ..scaleByDouble(
                _pressed ? 0.94 : 1.0,
                _pressed ? 0.94 : 1.0,
                _pressed ? 0.94 : 1.0,
                1.0,
              ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.fromLTRB(10, 13, 10, 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.velvet.withValues(alpha: _hovered ? 0.92 : 0.78),
                  AppColors.inkDeep.withValues(alpha: 0.92),
                ],
              ),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: _hovered
                    ? action.hue.withValues(alpha: 0.42)
                    : AppColors.moonlight.withValues(alpha: 0.13),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: action.hue.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.inkDeep.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.inkDeep.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 6,
                  right: 6,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          (_hovered ? action.hue : AppColors.blushGold)
                              .withValues(alpha: _hovered ? 0.45 : 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            action.hue.withValues(alpha: 0.26),
                            action.hue.withValues(alpha: 0.07),
                          ],
                        ),
                        border: Border.all(
                          color: action.hue.withValues(
                            alpha: _hovered ? 0.52 : 0.32,
                          ),
                          width: 1,
                        ),
                        boxShadow: _hovered
                            ? [
                                BoxShadow(
                                  color: action.hue.withValues(alpha: 0.22),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(action.icon, size: 18, color: action.hue),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      action.label,
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 11,
                        color: _hovered
                            ? AppColors.petalWhite
                            : AppColors.petalWhite.withValues(alpha: 0.92),
                        letterSpacing: 0.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (action.caption.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.caption.toUpperCase(),
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 1.1,
                          color: (_hovered ? action.hue : AppColors.roseQuartz)
                              .withValues(alpha: 0.62),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardJumpBar extends StatelessWidget {
  const _DashboardJumpBar({required this.onJump});
  final void Function(String id) onJump;

  @override
  Widget build(BuildContext context) {
    final items = [
      _JumpItem('Today', Icons.auto_awesome_rounded, AppColors.auroraGold, 'coming-up'),
      _JumpItem('Watching', Icons.play_circle_rounded, AppColors.auroraRose, 'watching'),
      _JumpItem('Shelves', Icons.local_movies_rounded, AppColors.softLavender, 'shelves'),
      _JumpItem('Timeline', Icons.timeline_rounded, AppColors.blushGold, 'timeline'),
      _JumpItem('Moments', Icons.favorite_rounded, AppColors.deepRose, 'moments'),
    ];
    return Semantics(
      label: 'Jump to section',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.62),
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 22, height: 1, color: AppColors.blushGold.withValues(alpha: 0.35)),
                const SizedBox(width: 10),
                Text('JUMP TO', style: AppTypography.outfitHeading.copyWith(fontSize: 10, letterSpacing: 1.8, color: AppColors.blushGold.withValues(alpha: 0.85))),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: AppColors.moonlight.withValues(alpha: 0.08))),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((it) {
                return _JumpChip(item: it, onJump: onJump);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _JumpItem {
  final String label;
  final IconData icon;
  final Color hue;
  final String targetId;
  const _JumpItem(this.label, this.icon, this.hue, this.targetId);
}

class _JumpChip extends StatefulWidget {
  const _JumpChip({required this.item, required this.onJump});
  final _JumpItem item;
  final void Function(String) onJump;
  @override
  State<_JumpChip> createState() => _JumpChipState();
}

class _JumpChipState extends State<_JumpChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return Semantics(
      button: true,
      label: 'Jump to ${it.label}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onJump(it.targetId),
          child: AnimatedContainer(
            duration: AppMotion.orZero(const Duration(milliseconds: 180)),
            curve: AppMotion.easeOutStrong,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [it.hue.withValues(alpha: _hovered ? 0.22 : 0.12), it.hue.withValues(alpha: 0.04)]),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: it.hue.withValues(alpha: _hovered ? 0.45 : 0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: it.hue.withValues(alpha: 0.18), border: Border.all(color: it.hue.withValues(alpha: 0.35))),
                  child: Icon(it.icon, size: 12, color: it.hue),
                ),
                const SizedBox(width: 7),
                Text(it.label, style: AppTypography.outfitHeading.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: _hovered ? 0.95 : 0.82))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
