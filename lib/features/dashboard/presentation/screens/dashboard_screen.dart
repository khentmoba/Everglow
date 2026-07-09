import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/anniversary_counter.dart';
import '../widgets/metric_card.dart';
import '../widgets/letterbox_view.dart';
import '../widgets/timeline_view.dart';
import '../../../date_randomizer/presentation/widgets/randomizer_card.dart';
import '../../../date_randomizer/data/services/date_idea_service.dart';
import '../../../../features/guardian/data/services/guardian_service.dart';
import '../../../../features/guardian/presentation/controllers/guardian_controller.dart';
import '../../../../features/guardian/presentation/widgets/everglow_guardian.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/daily_bloom/presentation/widgets/daily_bloom.dart';
import 'package:everglow/features/daily_bloom/presentation/providers/garden_provider.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/services/presence_service.dart';
import '../../../chat/presentation/screens/sanctuary_chat_screen.dart';
import '../widgets/creator_modal.dart';
import '../widgets/dashboard_actions.dart';
import '../widgets/cinema_preview.dart';
import '../widgets/anime_preview.dart';
import '../widgets/books_preview.dart';
import '../widgets/manga_preview.dart';
import '../widgets/currently_watching_preview.dart';
import 'package:everglow/features/canvas/presentation/screens/canvas_screen.dart';
import 'package:everglow/features/starlight_jar/presentation/screens/starlight_jar_widget.dart';
import 'package:everglow/features/heartbeat/presentation/controllers/mood_controller.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/partner_status_indicator.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/mood_picker.dart';
import 'package:everglow/features/heartbeat/data/services/mood_service.dart';
import '../../../academy/widgets/academy_portal_card.dart';
import '../../../../features/play_zone/presentation/widgets/play_zone_portal_card.dart';
import '../../../../features/jukebox/presentation/widgets/jukebox_widget.dart';
import '../../../../features/watch_party/presentation/widgets/watch_party_card.dart';
import '../../../../features/ai/data/services/ai_service.dart';

import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';
import 'package:everglow/features/xp/presentation/widgets/xp_progress_bar.dart';

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

    // Initialize services
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

        // Heartbeat Sync: Check for daily mood
        final moodController = context.read<MoodController>();
        final currentUsername = authService.currentUser;
        if (currentUsername != null) {
          moodController.checkTodayStatus(currentUsername).then((_) {
            if (!moodController.hasSubmittedToday) {
              context.read<GuardianController>().triggerMoodPrompt();
            }
          });
        }

        _syncPresenceHeartbeat();
      }
    });
  }

  Widget _maybeAnimate({
    required Widget child,
    required Widget Function(Widget) animation,
  }) {
    if (!widget.animate) return child;
    return animation(child);
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
      // Retry with exponential backoff, capped at max attempts
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Auth-readiness gate: don't render the dashboard until both
    // Firebase Auth and SharedPreferences have resolved.
    if (!auth.isReady) {
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
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                          child: _maybeAnimate(
                            animation: (child) => FadeInDown(
                              duration: const Duration(milliseconds: 800),
                              child: child,
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/images/logo.png',
                                    height: 80,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Forever In Bloom',
                                    style: GoogleFonts.cormorantGaramond(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.roseQuartz,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        BoxShadow(
                                          color: AppTheme.deepRose.withValues(alpha: 0.5),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'since February 14, 2026',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: AppTheme.petalWhite.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
                      _AnniversaryMetrics(animate: widget.animate),
                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 900),
                                  child: child,
                                ),
                                child: const LetterboxView(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 950),
                                  child: child,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: JukeboxWidget(),
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1050),
                                  child: child,
                                ),
                                child: RandomizerCard(
                                  service: context.read<DateIdeaService>(),
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1080),
                                  child: child,
                                ),
                                child: const CurrentlyWatchingPreview(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1100),
                                  child: child,
                                ),
                                child: const WatchPartyCard(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1100),
                                  child: child,
                                ),
                                child: const CinemaPreview(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1130),
                                  child: child,
                                ),
                                child: const AnimePreview(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1150),
                                  child: child,
                                ),
                                child: const BooksPreview(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1180),
                                  child: child,
                                ),
                                child: const MangaPreview(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1200),
                                  child: child,
                                ),
                                child: const TimelineView(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1300),
                                  child: child,
                                ),
                                child: const StarlightJarWidget(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1350),
                                  child: child,
                                ),
                                child: const DailyBloom(),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1400),
                                  child: child,
                                ),
                                child: const AcademyPortalCard(),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _maybeAnimate(
                                animation: (child) => FadeInUp(
                                  delay: const Duration(milliseconds: 1450),
                                  child: child,
                                ),
                                child: const PlayZonePortalCard(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
                      ),
                    ),
                
                // AI Assistant & Guardian Overlay
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Mochi cat button
                      Consumer<AIService>(
                        builder: (context, ai, _) {
                          return GestureDetector(
                            onTap: () => context.push('/mochi'),
                            child: Container(
                              width: 48,
                              height: 48,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.blushGold.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.deepRose.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/mochi_avatar.png',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      EverglowGuardian(),
                    ],
                  ),
                ),


                // Creator Mode Button (Admin Only)
                if (context.watch<AuthService>().currentUser == 'khentsgdz')
                Positioned(
                  top: 24,
                  left: 24,
                  child: FadeInDown(
                    delay: const Duration(milliseconds: 1500),
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreatorModal(),
                       ),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.deepRose.withValues(alpha: 0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppTheme.roseQuartz,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),

                // Everglow Canvas Button
                Positioned(
                  top: 24,
                  right: 96,
                  child: FadeInDown(
                    delay: const Duration(milliseconds: 1500),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PartnerStatusIndicator(),
                        const SizedBox(width: 16),
                        const DashboardActions(),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => context.push('/canvas'),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.deepRose.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.brush_rounded,
                              color: AppTheme.roseQuartz,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sanctuary Chat Button
                Positioned(
                  top: 24,
                  right: 24,
                  child: FadeInDown(
                    delay: const Duration(milliseconds: 1500),
                    child: GestureDetector(
                      onTap: () => context.push('/sanctuary'),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.deepRose,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.deepRose.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppTheme.petalWhite,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                // Mood Picker (Absolute Top Overlay)
                Consumer<GuardianController>(
                  builder: (context, controller, child) {
                    if (!controller.isMoodPromptVisible) return const SizedBox.shrink();
                    return Positioned(
                      top: 100,
                      right: 24,
                      child: const MoodPicker(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Localized anniversary counter that rebuilds only the metric grid
/// every second instead of the entire dashboard scroll view.
class _AnniversaryMetrics extends StatefulWidget {
  final bool animate;
  const _AnniversaryMetrics({required this.animate});

  @override
  State<_AnniversaryMetrics> createState() => _AnniversaryMetricsState();
}

class _AnniversaryMetricsState extends State<_AnniversaryMetrics> {
  late final StreamController<AnniversaryCounter> _controller;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _controller = StreamController<AnniversaryCounter>();
    _emit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  void _emit() {
    final counter = AnniversaryCounter.calculate(
      AnniversaryCounter.anniversaryDate,
      DateTime.now(),
    );
    _controller.add(counter);
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.close();
    super.dispose();
  }

  Widget _maybeAnimate({
    required Widget child,
    required Widget Function(Widget) animation,
  }) {
    if (!widget.animate) return child;
    return animation(child);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AnniversaryCounter>(
      stream: _controller.stream,
      initialData: AnniversaryCounter.calculate(
        AnniversaryCounter.anniversaryDate,
        DateTime.now(),
      ),
      builder: (context, snapshot) {
        final counter = snapshot.data!;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppBreakpoint.isDesktop(context) ? 3 : 2,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 1.3,
            ),
            delegate: SliverChildListDelegate([
              _maybeAnimate(
                animation: (child) => FadeInLeft(
                  delay: const Duration(milliseconds: 200),
                  child: child,
                ),
                child: MetricCard(label: 'Years', value: counter.years),
              ),
              _maybeAnimate(
                animation: (child) => FadeInRight(
                  delay: const Duration(milliseconds: 300),
                  child: child,
                ),
                child: MetricCard(label: 'Months', value: counter.months),
              ),
              _maybeAnimate(
                animation: (child) => FadeInLeft(
                  delay: const Duration(milliseconds: 400),
                  child: child,
                ),
                child: MetricCard(label: 'Days', value: counter.days),
              ),
              _maybeAnimate(
                animation: (child) => FadeInRight(
                  delay: const Duration(milliseconds: 500),
                  child: child,
                ),
                child: MetricCard(label: 'Hours', value: counter.hours),
              ),
              _maybeAnimate(
                animation: (child) => FadeInLeft(
                  delay: const Duration(milliseconds: 600),
                  child: child,
                ),
                child: MetricCard(label: 'Minutes', value: counter.minutes),
              ),
              _maybeAnimate(
                animation: (child) => FadeInRight(
                  delay: const Duration(milliseconds: 700),
                  child: child,
                ),
                child: MetricCard(label: 'Seconds', value: counter.seconds),
              ),
            ]),
          ),
        );
      },
    );
  }
}
