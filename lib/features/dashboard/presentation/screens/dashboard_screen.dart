import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/utils/logger.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';

import '../../../date_randomizer/presentation/widgets/randomizer_card.dart';
import '../../../date_randomizer/data/services/date_idea_service.dart';
import '../../../../features/guardian/data/services/guardian_service.dart';
import '../../../../features/guardian/presentation/controllers/guardian_controller.dart';
import 'package:everglow/features/daily_bloom/presentation/widgets/daily_bloom.dart';
import 'package:everglow/features/daily_bloom/presentation/providers/garden_provider.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/services/presence_service.dart';
import '../widgets/cinema_preview.dart';
import '../widgets/anime_preview.dart';
import '../widgets/books_preview.dart';
import '../widgets/manga_preview.dart';
import '../widgets/currently_watching_preview.dart';
import 'package:everglow/features/starlight_jar/presentation/screens/starlight_jar_widget.dart';
import 'package:everglow/features/heartbeat/presentation/controllers/mood_controller.dart';
import '../../../academy/widgets/academy_portal_card.dart';
import '../../../../features/play_zone/presentation/widgets/play_zone_portal_card.dart';
import '../../../../features/jukebox/presentation/widgets/jukebox_widget.dart';
import '../../../../features/watch_party/presentation/widgets/watch_party_card.dart';
import '../widgets/gallery_preview.dart';
import '../widgets/calendar_preview.dart';
import '../../../../features/bucket_list/presentation/widgets/bucket_list_preview.dart';
import '../widgets/letterbox_view.dart';
import '../widgets/upcoming_countdowns.dart';
import '../widgets/timeline_view.dart';
import '../widgets/on_this_day_card.dart';

import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';
import 'package:everglow/features/xp/presentation/widgets/xp_progress_bar.dart';
import '../widgets/anniversary_metrics.dart';
import '../widgets/dashboard_overlays.dart';
import 'package:everglow/core/theme/app_typography.dart';

class DashboardScreen extends StatefulWidget {
  final bool animate;
  const DashboardScreen({super.key, this.animate = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  AuthService? _authService;
  PresenceService? _presenceService;
  String? _lastHeartbeatUid;
  String? _lastHeartbeatUsername;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) _registerUnloadHandlers();

    Future.microtask(() {
      if (mounted) {
        final authService = context.read<AuthService>();
        final gardenProvider = context.read<GardenProvider>();

        if (authService.user != null) {
          gardenProvider.updateUserId(authService.user!.uid);
          gardenProvider.recordInteraction();
        }

        context.read<DateIdeaService>().initialize();
        context.read<GuardianService>().initialize();

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
        Logger.i("[Dashboard] Cleanup removed $removed duplicate watchlist entries");
      }
      await prefs.setBool('partner_cleanup_v1', true);
    } catch (e) {
      Logger.e("[Dashboard] Partner cleanup failed", error: e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Timer? _heartbeatRetryTimer;
  int _heartbeatRetryCount = 0;
  static const int _maxHeartbeatRetries = 5;

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

  void _registerUnloadHandlers() {
    web.window.addEventListener(
      'pagehide',
      ((web.Event _) {
        final uid = _lastHeartbeatUid;
        final presence = _presenceService;
        if (uid != null && presence != null) {
          presence.setOffline(uid);
        }
      }).toJS,
    );
    web.window.addEventListener(
      'beforeunload',
      ((web.Event _) {
        final uid = _lastHeartbeatUid;
        final presence = _presenceService;
        if (uid != null && presence != null) {
          presence.setOffline(uid);
        }
      }).toJS,
    );
  }

  /// Wraps a widget in a [FadeInUp] animation when [animate] is enabled.
  Widget _animatedSliver(Widget child, {int delayMs = 900, double heightAfter = 32}) {
    final animated = widget.animate
        ? FadeInUp(delay: Duration(milliseconds: delayMs), child: child)
        : child;
    return SliverToBoxAdapter(child: animated);
  }

  @override
  Widget build(BuildContext context) {
    final isReady = context.select<AuthService, bool>((a) => a.isReady);

    if (!isReady) {
      return Scaffold(
        body: GamifiedBackground(
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.deepRose,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: CustomScrollView(
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                          child: widget.animate
                              ? FadeInDown(
                                  duration: const Duration(milliseconds: 800),
                                  child: _buildHeader(),
                                )
                              : _buildHeader(),
                        ),
                      ),

                      // XP Progress Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Consumer<AuthService>(
                            builder: (context, auth, _) {
                              final uid = auth.user?.uid;
                              if (uid == null || uid.isEmpty) return const SizedBox.shrink();
                              return StreamBuilder<UserProgress?>(
                                stream: XPService().watchProgress(uid),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                                  return XPProgressBar(progress: snapshot.data!);
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      // Anniversary Metrics Grid
                      AnniversaryMetrics(animate: widget.animate),

                      const SliverToBoxAdapter(child: SizedBox(height: 48)),

                      // On This Day — spontaneous nostalgia
                      _animatedSliver(const OnThisDayCard(), delayMs: 800),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                      // Feature content sections
                      _animatedSliver(UpcomingCountdowns(), delayMs: 850, heightAfter: 16),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      _animatedSliver(const LetterboxView(), delayMs: 900),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      _animatedSliver(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: JukeboxWidget(),
                        ),
                        delayMs: 950,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      _animatedSliver(
                        RandomizerCard(service: context.read<DateIdeaService>()),
                        delayMs: 1050,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      _animatedSliver(const CurrentlyWatchingPreview(), delayMs: 1080),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      _animatedSliver(const WatchPartyCard(), delayMs: 1100),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      _animatedSliver(const CinemaPreview(), delayMs: 1100),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      _animatedSliver(const AnimePreview(), delayMs: 1130),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      _animatedSliver(const BooksPreview(), delayMs: 1150),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      _animatedSliver(const GalleryPreview(), delayMs: 1170),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      _animatedSliver(const CalendarPreview(), delayMs: 1175),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      _animatedSliver(const MangaPreview(), delayMs: 1180),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      _animatedSliver(const TimelineView(), delayMs: 1200),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      _animatedSliver(const StarlightJarWidget(), delayMs: 1300),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      _animatedSliver(const DailyBloom(), delayMs: 1350),
                      _animatedSliver(const AcademyPortalCard(), delayMs: 1400),
                      _animatedSliver(const PlayZonePortalCard(), delayMs: 1450),
                      _animatedSliver(const BucketListPreview(), delayMs: 1500),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),

              // Floating overlays
              const DashboardOverlays(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', height: 80),
          const SizedBox(height: 16),
          Text(
            'Forever In Bloom',
            style: AppTypography.cormorantBlack.copyWith(fontSize: 40, letterSpacing: -0.5, shadows: [
                BoxShadow(
                  color: AppTheme.deepRose.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ]),
          ),
          Text(
            'since February 14, 2026',
            style: AppTypography.outfitWhite.copyWith(fontSize: 14, color: AppTheme.petalWhite.withValues(alpha: 0.75), fontWeight: FontWeight.w500, letterSpacing: 2.0),
          ),
        ],
      ),
    );
  }
}
