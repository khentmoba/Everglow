import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/anniversary_counter.dart';
import '../widgets/metric_card.dart';

/// Animated anniversary counter grid — rebuilds only the metric cards
/// whose values actually change each second.
class AnniversaryMetrics extends StatefulWidget {
  final bool animate;
  const AnniversaryMetrics({super.key, this.animate = true});

  @override
  State<AnniversaryMetrics> createState() => _AnniversaryMetricsState();
}

class _AnniversaryMetricsState extends State<AnniversaryMetrics> {
  late final ValueNotifier<AnniversaryCounter> _notifier;
  late final Timer _timer;
  late AnniversaryCounter _prev;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _timer.cancel();
    _notifier.dispose();
    super.dispose();
  }

  Widget _maybeAnimate({
    required Widget child,
    required Widget Function(Widget) animation,
  }) {
    if (!widget.animate || AppMotion.reduced) return child;
    return animation(child);
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
            LayoutBuilder(
              builder: (context, constraints) {
                final cross = _crossAxisCount(context);
                final gap = 14.0;
                final w = (constraints.maxWidth - gap * (cross - 1)) / cross;
                final h = w / 1.22;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _maybeAnimate(
                      animation: (c) => FadeInLeft(
                        delay: const Duration(milliseconds: 140),
                        child: c,
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: _MetricCardAnimated(
                          label: 'Years',
                          listenable: _notifier,
                          selector: (c) => c.years,
                        ),
                      ),
                    ),
                    _maybeAnimate(
                      animation: (c) => FadeInLeft(
                        delay: const Duration(milliseconds: 190),
                        child: c,
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: _MetricCardAnimated(
                          label: 'Months',
                          listenable: _notifier,
                          selector: (c) => c.months,
                        ),
                      ),
                    ),
                    _maybeAnimate(
                      animation: (c) => FadeInLeft(
                        delay: const Duration(milliseconds: 240),
                        child: c,
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: _MetricCardAnimated(
                          label: 'Days',
                          listenable: _notifier,
                          selector: (c) => c.days,
                        ),
                      ),
                    ),
                    _maybeAnimate(
                      animation: (c) => FadeInRight(
                        delay: const Duration(milliseconds: 290),
                        child: c,
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: _MetricCardAnimated(
                          label: 'Hours',
                          listenable: _notifier,
                          selector: (c) => c.hours,
                        ),
                      ),
                    ),
                    _maybeAnimate(
                      animation: (c) => FadeInRight(
                        delay: const Duration(milliseconds: 340),
                        child: c,
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: _MetricCardAnimated(
                          label: 'Minutes',
                          listenable: _notifier,
                          selector: (c) => c.minutes,
                        ),
                      ),
                    ),
                    _maybeAnimate(
                      animation: (c) => FadeInRight(
                        delay: const Duration(milliseconds: 390),
                        child: c,
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: _MetricCardAnimated(
                          label: 'Seconds',
                          listenable: _notifier,
                          selector: (c) => c.seconds,
                          pulse: true,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<AnniversaryCounter>(
              valueListenable: _notifier,
              builder: (context, c, _) {
                final totalDays = DateTime.now()
                    .difference(AnniversaryCounter.anniversaryDate)
                    .inDays;
                return Opacity(
                  opacity: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.moonlight.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.moonlight.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.auroraRose,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.auroraRose.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$totalDays days of us  ·  since Feb 14, 2026',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: AppColors.petalWhite.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.favorite_rounded,
                          size: 12,
                          color: AppColors.auroraRose.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) return 3;
    return 2;
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
          width: 22,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blushGold.withValues(alpha: 0.0),
                AppColors.blushGold.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.auroraGold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
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
                  fontSize: 10,
                  letterSpacing: 2.2,
                  color: AppColors.blushGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 22,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blushGold.withValues(alpha: 0.7),
                AppColors.blushGold.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<AnniversaryCounter>(
            valueListenable: notifier,
            builder: (context, c, _) {
              final tag = c.years == 0
                  ? (c.months == 1 ? '1 MONTH' : '${c.months} MONTHS')
                  : (c.years == 1 ? '1 YEAR' : '${c.years} YEARS');
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  tag,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.petalWhite.withValues(alpha: 0.55),
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
      duration: const Duration(milliseconds: 500),
      child: row,
    );
  }
}

/// Listens to an [AnniversaryCounter] notifier but only rebuilds
/// [MetricCard] when the selected field actually changes.
class _MetricCardAnimated extends StatelessWidget {
  final String label;
  final ValueNotifier<AnniversaryCounter> listenable;
  final int Function(AnniversaryCounter) selector;
  final bool pulse;

  const _MetricCardAnimated({
    required this.label,
    required this.listenable,
    required this.selector,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AnniversaryCounter>(
      valueListenable: listenable,
      builder: (context, counter, _) {
        return MetricCard(label: label, value: selector(counter), pulse: pulse);
      },
    );
  }
}
