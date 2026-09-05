import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/anniversary_counter.dart';
import '../widgets/metric_card.dart';

/// Distilled counter — ticks live every second via a lightweight
/// ValueNotifier, no pulse glow or heavy shadows. Whole grid animates
/// as one fade instead of 6 staggered slides.
class AnniversaryMetrics extends StatefulWidget {
  final bool animate;
  const AnniversaryMetrics({super.key, this.animate = true});

  @override
  State<AnniversaryMetrics> createState() => _AnniversaryMetricsState();
}

class _AnniversaryMetricsState extends State<AnniversaryMetrics> with WidgetsBindingObserver {
  late final ValueNotifier<AnniversaryCounter> _notifier;
  late Timer _timer;
  late AnniversaryCounter _prev;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prev = AnniversaryCounter.calculate(
      AnniversaryCounter.anniversaryDate,
      DateTime.now(),
    );
    _notifier = ValueNotifier(_prev);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  void _emit() {
    final next = AnniversaryCounter.calculate(
      AnniversaryCounter.anniversaryDate,
      DateTime.now(),
    );
    if (next.years != _prev.years ||
        next.months != _prev.months ||
        next.days != _prev.days ||
        next.hours != _prev.hours ||
        next.minutes != _prev.minutes ||
        next.seconds != _prev.seconds) {
      _prev = next;
      _notifier.value = next;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _timer.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _timer.cancel();
      // recreate timer
      // ignore: unused_field
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _notifier.dispose();
    super.dispose();
  }

  Widget _maybeAnimate({required Widget child}) {
    if (!widget.animate || AppMotion.reduced) return child;
    return FadeInUp(
      delay: const Duration(milliseconds: 160),
      duration: const Duration(milliseconds: 500),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionEyebrow(animate: widget.animate, notifier: _notifier),
            const SizedBox(height: 14),
            _maybeAnimate(
              child: Column(
                children: [
                  // Hero — Years locket, centered like a keepsake
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 252),
                      child: SizedBox(
                        height: 188,
                        width: double.infinity,
                        child: _MetricCardAnimated(
                          label: 'Years',
                          listenable: _notifier,
                          selector: (c) => c.years,
                          hero: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: SizedBox(height: 130, child: _MetricCardAnimated(label: 'Months', listenable: _notifier, selector: (c) => c.months))),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(height: 130, child: _MetricCardAnimated(label: 'Days', listenable: _notifier, selector: (c) => c.days))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: SizedBox(height: 118, child: _MetricCardAnimated(label: 'Hours', listenable: _notifier, selector: (c) => c.hours))),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(height: 118, child: _MetricCardAnimated(label: 'Minutes', listenable: _notifier, selector: (c) => c.minutes))),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(height: 118, child: _MetricCardAnimated(label: 'Seconds', listenable: _notifier, selector: (c) => c.seconds, isLive: true))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<AnniversaryCounter>(
              valueListenable: _notifier,
              builder: (context, c, _) {
                final totalDays = DateTime.now()
                    .difference(AnniversaryCounter.anniversaryDate)
                    .inDays;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.moonlight.withValues(alpha: 0.08),
                        AppColors.auroraRose.withValues(alpha: 0.07),
                      ],
                    ),
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.inkDeep.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 11,
                        color: AppColors.auroraRose.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$totalDays days of us  ·  since Feb 14, 2026',
                          textAlign: TextAlign.center,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w500,
                            color: AppColors.petalWhite.withValues(alpha: 0.74),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.favorite_rounded,
                        size: 11,
                        color: AppColors.auroraRose.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}

class _SectionEyebrow extends StatelessWidget {
  final bool animate;
  final ValueNotifier<AnniversaryCounter> notifier;

  const _SectionEyebrow({required this.animate, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: 20,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.auroraGold.withValues(alpha: 0.12),
                AppColors.auroraRose.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 11,
                color: AppColors.auroraRose.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Text(
                'TIME TOGETHER',
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  color: AppColors.blushGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 20,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blushGold.withValues(alpha: 0.55),
                AppColors.blushGold.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ValueListenableBuilder<AnniversaryCounter>(
            valueListenable: notifier,
            builder: (context, c, _) {
              final tag = c.years == 0
                  ? (c.months == 1 ? '1 MONTH' : '${c.months} MONTHS')
                  : (c.years == 1 ? '1 YEAR' : '${c.years} YEARS');
              return Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.moonlight.withValues(alpha: 0.06),
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.petalWhite.withValues(alpha: 0.58),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
    if (!animate || AppMotion.reduced) return row;
    return FadeInUp(
      delay: const Duration(milliseconds: 90),
      duration: const Duration(milliseconds: 400),
      child: row,
    );
  }
}

class _MetricCardAnimated extends StatelessWidget {
  final String label;
  final ValueNotifier<AnniversaryCounter> listenable;
  final int Function(AnniversaryCounter) selector;
  final bool hero;
  final bool isLive;

  const _MetricCardAnimated({
    required this.label,
    required this.listenable,
    required this.selector,
    this.hero = false,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AnniversaryCounter>(
      valueListenable: listenable,
      builder: (context, counter, _) {
        final v = selector(counter);
        if (hero) {
          return Semantics(
            container: true,
            label:
                'Years together: $v, since February 14, 2026. ${v == 1 ? "1 year" : "$v years"} of us',
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.plum.withValues(alpha: 0.95),
                    AppColors.velvet.withValues(alpha: 0.96),
                    AppColors.inkDeep.withValues(alpha: 0.72),
                  ],
                ),
                borderRadius: AppRadius.radiusX2,
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.inkDeep.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppColors.auroraGold.withValues(alpha: 0.10),
                    blurRadius: 28,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Faint keepsake hearts — static, no blur, cheap.
                  Positioned(
                    left: -14,
                    bottom: -10,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 74,
                      color: AppColors.auroraRose.withValues(alpha: 0.07),
                    ),
                  ),
                  Positioned(
                    right: -12,
                    top: -8,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 56,
                      color: AppColors.blushGold.withValues(alpha: 0.08),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 28,
                    right: 28,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.blushGold.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.auroraRose.withValues(alpha: 0.14),
                            border: Border.all(
                              color: AppColors.auroraRose.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 13,
                            color: AppColors.auroraRose.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'YEARS TOGETHER',
                          style: AppTypography.outfitHeading.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: AppColors.blushGold.withValues(alpha: 0.92),
                          ),
                        ),
                        const SizedBox(height: 2),
                        ExcludeSemantics(
                          child: Text(
                            v.toString().padLeft(2, '0'),
                            style: AppTypography.cormorantExtraBold.copyWith(
                              color: AppColors.auroraGold.withValues(
                                alpha: 0.99,
                              ),
                              fontSize: 60,
                              height: 1.0,
                              letterSpacing: -1.0,
                              shadows: [
                                Shadow(
                                  color: AppColors.goldShadow.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppColors.blushGold.withValues(alpha: 0.45),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.blushGold.withValues(
                                  alpha: 0.7,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 26,
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.blushGold.withValues(alpha: 0.45),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'since Feb 14, 2026',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.2,
                            color: AppColors.petalWhite.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return MetricCard(label: label, value: v, isLive: isLive);
      },
    );
  }
}
