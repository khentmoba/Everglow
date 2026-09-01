import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/anniversary_counter.dart';
import '../widgets/metric_card.dart';

/// Distilled counter — rebuilds once per minute, not per second.
/// Seconds still tick via a lightweight ValueNotifier but without
/// pulse glow or heavy shadows. Whole grid animates as one fade
/// instead of 6 staggered slides.
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
    // Distill: tick every 60s. Seconds value still updates but without
    // per-second rebuild cost; minutes/hours are the meaningful unit
    // for a love story. If you want live seconds, swap to 1s locally.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _emit());
    // One immediate second-tick so landing still feels alive, then settle.
    Future.delayed(const Duration(seconds: 1), _emit);
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
        next.minutes != _prev.minutes) {
      _prev = next;
      _notifier.value = next;
    } else if (next.seconds != _prev.seconds) {
      // still update seconds display without marking stale for defer
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cross = _crossAxisCount(context);
                  final gap = 12.0;
                  final w = (constraints.maxWidth - gap * (cross - 1)) / cross;
                  final h = w / 1.35;
                  return GridView.count(
                    crossAxisCount: cross,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: w / h,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MetricCardAnimated(
                        label: 'Years',
                        listenable: _notifier,
                        selector: (c) => c.years,
                      ),
                      _MetricCardAnimated(
                        label: 'Months',
                        listenable: _notifier,
                        selector: (c) => c.months,
                      ),
                      _MetricCardAnimated(
                        label: 'Days',
                        listenable: _notifier,
                        selector: (c) => c.days,
                      ),
                      _MetricCardAnimated(
                        label: 'Hours',
                        listenable: _notifier,
                        selector: (c) => c.hours,
                      ),
                      _MetricCardAnimated(
                        label: 'Minutes',
                        listenable: _notifier,
                        selector: (c) => c.minutes,
                      ),
                      _MetricCardAnimated(
                        label: 'Seconds',
                        listenable: _notifier,
                        selector: (c) => c.seconds,
                      ),
                    ].map((c) => SizedBox(height: h, child: c)).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<AnniversaryCounter>(
              valueListenable: _notifier,
              builder: (context, c, _) {
                final totalDays = DateTime.now()
                    .difference(AnniversaryCounter.anniversaryDate)
                    .inDays;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.moonlight.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.auroraRose,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.auroraRose.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$totalDays days of us  ·  since Feb 14, 2026',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.petalWhite.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.favorite_rounded,
                        size: 11,
                        color: AppColors.auroraRose.withValues(alpha: 0.75),
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
                AppColors.blushGold.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.auroraGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 11,
                color: AppColors.auroraRose.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                'TIME TOGETHER',
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.1,
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
                AppColors.blushGold.withValues(alpha: 0.55),
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
                  ? (c.months == 1 ? '1 MONTH' : ' MONTHS')
                  : (c.years == 1 ? '1 YEAR' : ' YEARS');
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  tag,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.petalWhite.withValues(alpha: 0.45),
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

  const _MetricCardAnimated({
    required this.label,
    required this.listenable,
    required this.selector,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AnniversaryCounter>(
      valueListenable: listenable,
      builder: (context, counter, _) {
        return MetricCard(label: label, value: selector(counter));
      },
    );
  }
}
