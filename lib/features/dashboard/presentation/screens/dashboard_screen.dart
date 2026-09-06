import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
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
import '../widgets/keepsakes_cluster.dart';
import '../widgets/letterbox_view.dart';
import '../widgets/upcoming_countdowns.dart';
import '../widgets/timeline_view.dart';
import '../widgets/on_this_day_card.dart';

import '../widgets/anniversary_metrics.dart';
import '../widgets/dashboard_overlays.dart';
import '../widgets/deferred_section.dart';
import '../widgets/xp_progress_section.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/dashboard_jump_bar.dart';
import '../widgets/dashboard_zone_header.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_section_header.dart';
import '../widgets/dashboard_motion.dart';
part 'dashboard_screen_sections.dart';

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
  String? _lastGardenUid;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'zone-today': GlobalKey(),
    'zone-together': GlobalKey(),
    'zone-world': GlobalKey(),
    'zone-play': GlobalKey(),
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
        // Session facts for the console: pairs every permission-denied
        // shelf report with the UID, guest flag, and user-doc sync state
        // so the cause is readable without opening the Firebase console.
        // Raw print: Logger is silent in release builds.
        // ignore: avoid_print
        print('[AuthDiag] ${authService.diagLine}');
        // Garden sync rides along with _syncPresenceHeartbeat below so it
        // retries while the UID is unavailable instead of running once.

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
    _syncGarden(uid);
  }

  /// Starts the DailyBloom garden stream for [uid]. Runs inside the heartbeat
  /// retry loop so a cold start (UID not restored yet on the first tick)
  /// still picks up the garden a moment later instead of leaving DailyBloom
  /// permanently empty. The visit is recorded once per UID per session.
  void _syncGarden(String uid) {
    if (!mounted) return;
    final garden = context.read<GardenProvider>();
    garden.updateUserId(uid);
    if (_lastGardenUid != uid) {
      _lastGardenUid = uid;
      garden.recordInteraction();
    }
  }

  void _setOfflineFromHeartbeat() {
    final uid = _lastHeartbeatUid;
    final presence = _presenceService;
    if (uid != null && presence != null) {
      presence.setOffline(uid);
    }
  }

  /// Distilled: hero sections keep timed entrance, zone content
  /// fades quickly via intersection (DeferredSection).
  Widget _animatedSliver(
    Widget child, {
    int delayMs = 900,

    double placeholderHeight = 220,
    int deferMs = 0,
    bool hero = false,
  }) {
    // Product motion: hero gets single FadeInDown, zone content defers via DeferredSection only (no per-sliver stagger)
    final Widget animated;
    if (!widget.animate || !hero) {
      animated = child;
    } else if (AppMotion.reduced) {
      animated = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        builder: (_, opacity, c) => Opacity(opacity: opacity, child: c),
        child: child,
      );
    } else {
      animated = FadeInDown(duration: const Duration(milliseconds: 700), child: child);
    }
    return SliverToBoxAdapter(
      child: DeferredSection(
        placeholderHeight: placeholderHeight,
        deferMs: deferMs,
        child: animated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReady = context.select<AuthService, bool>((a) => a.isReady);

    if (!isReady) {
      return const Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: EverglowBackground(baseColor: AppColors.inkDeep),
            ),
            Center(
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

    final contentMaxWidth = const ResponsiveValue<double>(
      mobile: 600,
      tablet: 820,
      desktop: 980,
    ).of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
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
                            padding: EdgeInsets.fromLTRB(AppSpacing.pageH(context), 48, AppSpacing.pageH(context), 24),
                            child: widget.animate
                                ? (AppMotion.reduced
                                      ? _buildHeader(context)
                                      : FadeInDown(
                                          duration: const Duration(
                                            milliseconds: 800,
                                          ),
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
                              selector: (_, auth) => auth.uid,
                              builder: (context, uid, _) =>
                                  XpProgressSection(uid: uid),
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
                                          delay: const Duration(
                                            milliseconds: 250,
                                          ),
                                          child: _buildQuickActions(context),
                                        ))
                                : _buildQuickActions(context),
                          ),
                        ),

                        // Anniversary Metrics Grid
                        AnniversaryMetrics(animate: widget.animate),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                            child: DashboardJumpBar(onJump: _jumpTo),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 12)),

                        // ── ZONE: TODAY — what is alive today ──
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['zone-today'], height: 0),
                        ),
                        _animatedSliver(
                          const DashboardZoneHeader(
                            label: 'Today',
                            title: 'Alive today',
                            subtitle: 'memories, dates & letters waiting for you',
                            icon: Icons.wb_twilight_rounded,
                            hue: AppColors.auroraGold,
                          ),
                          delayMs: 400,
                          placeholderHeight: 68,
                          hero: true,
                        ),
                        _animatedSliver(
                          const OnThisDayCard(),
                          delayMs: 420,
                          placeholderHeight: 190,
                          deferMs: 0,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        _animatedSliver(
                          const DashboardPair(
                            left: UpcomingCountdowns(),
                            right: LetterboxView(),
                          ),
                          delayMs: 440,
                          placeholderHeight: 320,
                          deferMs: 60,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        _animatedSliver(
                          const DailyBloom(),
                          delayMs: 460,
                          placeholderHeight: 320,
                          deferMs: 120,
                        ),

                        // ── ZONE: TOGETHER — gentle, intimate ──
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['zone-together'], height: 0),
                        ),
                        _animatedSliver(
                          const DashboardZoneHeader(
                            label: 'Together',
                            title: 'Just us',
                            subtitle: 'gratitude, words & the long story of us',
                            icon: Icons.favorite_rounded,
                            hue: AppColors.auroraRose,
                          ),
                          delayMs: 480,
                          placeholderHeight: 68,
                        ),
                        _animatedSliver(
                          const StarlightJarWidget(),
                          delayMs: 500,
                          placeholderHeight: 520,
                          deferMs: 160,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        _animatedSliver(
                          const TimelineView(),
                          delayMs: 520,
                          placeholderHeight: 620,
                          deferMs: 260,
                        ),

                        // ── ZONE: OUR WORLD — places & keepsakes ──
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['zone-world'], height: 0),
                        ),
                        _animatedSliver(
                          const DashboardZoneHeader(
                            label: 'Our World',
                            title: 'Places & keepsakes',
                            subtitle: 'photos, plans & little universes you built',
                            icon: Icons.public_rounded,
                            hue: AppColors.auroraTeal,
                          ),
                          delayMs: 540,
                          placeholderHeight: 68,
                        ),
                        _animatedSliver(
                          const DashboardPair(
                            left: GalleryPreview(),
                            right: CalendarPreview(),
                          ),
                          delayMs: 560,
                          placeholderHeight: 220,
                          deferMs: 320,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        _animatedSliver(
                          const KeepsakesCluster(),
                          delayMs: 580,
                          placeholderHeight: 520,
                          deferMs: 380,
                        ),

                        // ── ZONE: PLAY — sound, screen & games ──
                        SliverToBoxAdapter(
                          child: SizedBox(key: _sectionKeys['zone-play'], height: 0),
                        ),
                        _animatedSliver(
                          const DashboardZoneHeader(
                            label: 'Play',
                            title: 'Sound & screen',
                            subtitle: 'jukebox, watch party, shelves & games',
                            icon: Icons.videogame_asset_rounded,
                            hue: AppColors.softLavender,
                          ),
                          delayMs: 600,
                          placeholderHeight: 68,
                        ),
                        _animatedSliver(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 640),
                                child: const JukeboxWidget(),
                              ),
                            ),
                          ),
                          delayMs: 620,
                          placeholderHeight: 380,
                          deferMs: 420,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        _animatedSliver(
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: MusicStatsSection(),
                          ),
                          delayMs: 625,
                          placeholderHeight: 560,
                          deferMs: 440,
                        ),
                        _animatedSliver(
                          RandomizerCard(
                              service: context.read<DateIdeaService>(),
                            ),
                            delayMs: 640,
                            placeholderHeight: 280,
                            deferMs: 460,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          _animatedSliver(
                            const DashboardPair(
                              left: CurrentlyWatchingPreview(),
                              right: WatchPartyCard(),
                            ),
                            delayMs: 660,
                            placeholderHeight: 260,
                            deferMs: 500,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          _animatedSliver(
                            const CinemaPreview(),
                            delayMs: 680,
                            placeholderHeight: 300,
                            deferMs: 540,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          _animatedSliver(
                            const AnimePreview(),
                            delayMs: 700,
                            placeholderHeight: 300,
                            deferMs: 580,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          _animatedSliver(
                            const BooksPreview(),
                            delayMs: 720,
                            placeholderHeight: 300,
                            deferMs: 620,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          _animatedSliver(
                            const MangaPreview(),
                            delayMs: 740,
                            placeholderHeight: 300,
                            deferMs: 660,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          _animatedSliver(
                            const DashboardPair(
                              left: AcademyPortalCard(),
                              right: PlayZonePortalCard(),
                            ),
                            delayMs: 760,
                            placeholderHeight: 200,
                            deferMs: 700,
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

}
