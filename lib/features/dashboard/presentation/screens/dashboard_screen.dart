import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:animate_do/animate_do.dart';
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
import '../../../chat/presentation/screens/sanctuary_chat_screen.dart';
import '../widgets/creator_modal.dart';
import '../widgets/dashboard_actions.dart';
import '../widgets/cinema_preview.dart';
import 'package:everglow/features/canvas/presentation/screens/canvas_screen.dart';
import 'package:everglow/features/starlight_jar/presentation/screens/starlight_jar_widget.dart';
import 'package:everglow/features/heartbeat/presentation/controllers/mood_controller.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/partner_status_indicator.dart';
import 'package:everglow/features/heartbeat/presentation/widgets/mood_picker.dart';
import 'package:everglow/features/heartbeat/data/services/mood_service.dart';
import '../../../academy/widgets/academy_portal_card.dart';
import '../../../../features/play_zone/presentation/widgets/play_zone_portal_card.dart';
import '../../../../features/jukebox/presentation/widgets/jukebox_widget.dart';
import '../../../../features/jukebox/presentation/providers/jukebox_provider.dart';

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

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamController<AnniversaryCounter> _counterController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _counterController = StreamController<AnniversaryCounter>();
    _updateCounter();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCounter();
    });

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
      }
    });
  }

  void _updateCounter() {
    final now = DateTime.now();
    final counter = AnniversaryCounter.calculate(
      AnniversaryCounter.anniversaryDate,
      now,
    );
    _counterController.add(counter);
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
    _timer.cancel();
    _counterController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (context) => GuardianController(
                  context.read<GuardianService>(),
                  moodService: context.read<MoodService>(),
                  authService: context.read<AuthService>(),
                ),
              ),
              ChangeNotifierProvider(create: (context) => MoodController(context.read<MoodService>())),
            ],
            child: Stack(
              children: [
                StreamBuilder<AnniversaryCounter>(
                  stream: _counterController.stream,
                  initialData: AnniversaryCounter.calculate(
                    AnniversaryCounter.anniversaryDate,
                    DateTime.now(),
                  ),
                    builder: (context, snapshot) {
                    final counter = snapshot.data!;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: CustomScrollView(
                          slivers: [
                            // ... existing slivers ...
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
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
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
                            ),
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
                                  delay: const Duration(milliseconds: 1100),
                                  child: child,
                                ),
                                child: const CinemaPreview(),
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
                    );
                  },
                ),
                
                // Persistent Guardian Overlay
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: EverglowGuardian(),
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
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => 
                                  const CanvasScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
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
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => 
                              const SanctuaryChatScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            var begin = const Offset(1.0, 0.0);
                            var end = Offset.zero;
                            var curve = Curves.easeOutQuint;
                            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                            return SlideTransition(position: animation.drive(tween), child: child);
                          },
                        ),
                      ),
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
      ),
    );
  }
}
