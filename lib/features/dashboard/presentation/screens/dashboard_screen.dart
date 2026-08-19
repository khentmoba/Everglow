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
  Widget _animatedSliver(
    Widget child, {
    int delayMs = 900,
    double heightAfter = 32,
    double placeholderHeight = 220,
  }) {
    final animated = widget.animate
        ? FadeInUp(
            delay: Duration(milliseconds: delayMs),
            child: child,
          )
        : child;
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
      mobile: 520,
      tablet: 720,
      desktop: 900,
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
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
                            child: widget.animate
                                ? FadeInDown(
                                    duration: const Duration(milliseconds: 800),
                                    child: _buildHeader(context),
                                  )
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
                                ? FadeInUp(
                                    delay: const Duration(milliseconds: 250),
                                    child: _buildQuickActions(context),
                                  )
                                : _buildQuickActions(context),
                          ),
                        ),

                        // Anniversary Metrics Grid
                        AnniversaryMetrics(animate: widget.animate),

                        const SliverToBoxAdapter(child: SizedBox(height: 40)),

                        // On This Day
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
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        _animatedSliver(
                          const TimelineView(),
                          delayMs: 1200,
                          placeholderHeight: 620,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    final titleSize = width < 400 ? 40.0 : 46.0;
    return Center(
      child: Column(
        children: [
          // Emblem in a soft glass ring.
          BreathingEmblem(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.moonlight.withValues(alpha: 0.16),
                    AppColors.deepRose.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.5),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.28),
                    blurRadius: 34,
                    spreadRadius: -4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: ClipOval(
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'welcome home',
            style: AppTypography.handwrittenBody().copyWith(
              fontSize: 22,
              color: AppColors.blushGold.withValues(alpha: 0.9),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          ShimmerTitle(
            child: Text(
              'Forever In Bloom',
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: titleSize,
                letterSpacing: -0.5,
                shadows: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.5),
                    blurRadius: 24,
                  ),
                  BoxShadow(
                    color: AppColors.blushGold.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'since February 14, 2026',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              color: AppColors.petalWhite.withValues(alpha: 0.72),
              fontWeight: FontWeight.w500,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 18),
          // Gold hairline divider with a heart.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.blushGold.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: PulseHeart(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.auroraRose,
                    size: 15,
                  ),
                ),
              ),
              Container(
                width: 56,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blushGold.withValues(alpha: 0.7),
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
      ),
      _QuickAction(
        label: 'Sanctuary',
        icon: Icons.chat_bubble_rounded,
        route: '/sanctuary',
        hue: AppColors.auroraRose,
      ),
      _QuickAction(
        label: 'Canvas',
        icon: Icons.brush_rounded,
        route: '/canvas',
        hue: AppColors.softLavender,
      ),
      _QuickAction(
        label: 'Mochi',
        icon: Icons.auto_awesome_rounded,
        route: '/mochi',
        hue: AppColors.auroraGold,
      ),
      _QuickAction(
        label: 'Calendar',
        icon: Icons.calendar_month_rounded,
        route: '/calendar',
        hue: AppColors.warmAmber,
      ),
      _QuickAction(
        label: 'Starlight',
        icon: Icons.auto_awesome_mosaic_rounded,
        route: '/starlight',
        hue: AppColors.auroraLilac,
      ),
      _QuickAction(
        label: 'Bucket List',
        icon: Icons.card_travel_rounded,
        route: '/bucket-list',
        hue: AppColors.auroraTeal,
      ),
      _QuickAction(
        label: 'Letterbox',
        icon: Icons.mail_outline_rounded,
        route: '/letterbox',
        hue: AppColors.blushGold,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 300 ? 3 : 4;
        final tileWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final action in actions)
              SizedBox(
                width: tileWidth,
                child: _QuickActionTile(action: action),
              ),
          ],
        );
      },
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
  final IconData icon;
  final String route;
  final Color hue;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.hue,
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: _hovered
                    ? action.hue.withValues(alpha: 0.55)
                    : AppColors.border,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: action.hue.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        action.hue.withValues(alpha: 0.24),
                        action.hue.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: action.hue.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Icon(action.icon, size: 19, color: action.hue),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _hovered
                        ? AppColors.petalWhite
                        : AppColors.textMedium,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
