import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/anniversary_counter.dart';
import '../widgets/metric_card.dart';

/// Time Together — one keepsake clock instead of six loose boxes.
///
/// A single locket card holds the years hero, a quiet months/days +
/// hours/minutes/seconds grid behind hairline dividers, and a total-days
/// ribbon overlapping the bottom edge like a wax seal. Ticks live every
/// second via a lightweight ValueNotifier; no pulse glow, no heavy
/// shadows, no blur-over-big-area. The whole card animates as one fade.
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
    // 1s cadence only because the seconds cell is live; the ribbon
    // below diffs DateTime.now() off the same notifier, so no second
    // timer is needed anywhere in this subtree.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  // Cached at second granularity: the builder runs every second off the
  // same notifier, and total days only flips at midnight.
  int? _cachedTotalDays;
  int _cachedTotalDaysSecond = -1;

  int _totalDaysSinceAnniversary() {
    final second = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_cachedTotalDays != null && second == _cachedTotalDaysSecond) {
      return _cachedTotalDays!;
    }
    _cachedTotalDaysSecond = second;
    _cachedTotalDays = DateTime.now()
        .difference(AnniversaryCounter.anniversaryDate)
        .inDays;
    return _cachedTotalDays!;
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ValueListenableBuilder<AnniversaryCounter>(
                    valueListenable: _notifier,
                    builder: (context, c, _) => _KeepsakeClock(
                      counter: c,
                      totalDays: _totalDaysSinceAnniversary(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a hardware-accelerated frosted blur on native platforms where
/// [BackdropFilter] is smooth and performant. On web or reduced motion,
/// falls back to direct translucent rendering to prevent web gray-screen
/// artifacts and overhead.
Widget _wrapGlass({
  required BorderRadius borderRadius,
  required Widget child,
}) {
  if (kIsWeb || AppMotion.reduced) return child;
  return RepaintBoundary(
    child: ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: child,
      ),
    ),
  );
}

/// Centered eyebrow — one quiet pill pair, matching the centered
/// "EST. FEBRUARY 14" pill in the header above. Wraps gracefully on
/// narrow phones instead of squeezing edge to edge.
class _SectionEyebrow extends StatelessWidget {
  final bool animate;
  final ValueNotifier<AnniversaryCounter> notifier;

  const _SectionEyebrow({required this.animate, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final row = Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _wrapGlass(
            borderRadius: AppRadius.radiusFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.moonlight.withValues(alpha: 0.14),
                    AppColors.auroraRose.withValues(alpha: 0.10),
                    AppColors.inkDeep.withValues(alpha: 0.30),
                  ],
                ),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.32),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: AppColors.auroraRose.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
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
                      fontWeight: FontWeight.w700,
                      color: AppColors.blushGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<AnniversaryCounter>(
            valueListenable: notifier,
            builder: (context, c, _) {
              final tag = c.years == 0
                  ? (c.months == 1 ? '1 MONTH' : '${c.months} MONTHS')
                  : (c.years == 1 ? '1 YEAR' : '${c.years} YEARS');
              return _wrapGlass(
                borderRadius: AppRadius.radiusFull,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.moonlight.withValues(alpha: 0.12),
                        AppColors.inkDeep.withValues(alpha: 0.28),
                      ],
                    ),
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(
                      color: AppColors.moonlight.withValues(alpha: 0.20),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.petalWhite.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
    if (!animate || AppMotion.reduced) return row;
    return FadeInUp(
      delay: const Duration(milliseconds: 90),
      duration: const Duration(milliseconds: 400),
      child: row,
    );
  }
}

/// The unified locket: years hero on top, counter grid in the middle,
/// total-days ribbon overlapping the bottom edge like a seal.
class _KeepsakeClock extends StatelessWidget {
  final AnniversaryCounter counter;
  final int totalDays;

  const _KeepsakeClock({required this.counter, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Time together: ${counter.years} years, ${counter.months} months, '
          '${counter.days} days, since February 14, 2026. '
          '$totalDays days of us',
      child: Stack(
        children: [
          Padding(
            // Bottom padding reserves room for the overlapping ribbon.
            padding: const EdgeInsets.only(bottom: 18),
            child: _wrapGlass(
              borderRadius: AppRadius.radiusX3,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.moonlight.withValues(alpha: 0.15),
                      AppColors.velvet.withValues(alpha: 0.32),
                      AppColors.inkDeep.withValues(alpha: 0.48),
                      AppColors.plum.withValues(alpha: 0.24),
                    ],
                    stops: const [0.0, 0.30, 0.70, 1.0],
                  ),
                  borderRadius: AppRadius.radiusX3,
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.30),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: AppColors.auroraRose.withValues(alpha: 0.08),
                      blurRadius: 32,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.auroraGold.withValues(alpha: 0.06),
                      blurRadius: 24,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Specular light wash along upper card curve
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 150,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.petalWhite.withValues(alpha: 0.12),
                                AppColors.petalWhite.withValues(alpha: 0.02),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Faint keepsake hearts watermark — etched into glass
                    Positioned(
                      left: -16,
                      bottom: 60,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 78,
                          color: AppColors.auroraRose.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -14,
                      top: -10,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 60,
                          color: AppColors.blushGold.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    // Top hairline edge highlight
                    Positioned(
                      top: 0,
                      left: 32,
                      right: 32,
                      child: Container(
                        height: 1.2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.blushGold.withValues(alpha: 0.40),
                              AppColors.petalWhite.withValues(alpha: 0.75),
                              AppColors.blushGold.withValues(alpha: 0.40),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.20, 0.50, 0.80, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                      child: Column(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.auroraRose.withValues(alpha: 0.28),
                                  AppColors.deepRose.withValues(alpha: 0.12),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.auroraRose.withValues(alpha: 0.50),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.auroraRose.withValues(alpha: 0.30),
                                  blurRadius: 14,
                                  spreadRadius: -1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 15,
                              color: AppColors.auroraRose,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'YEARS TOGETHER',
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 10.5,
                              letterSpacing: 2.4,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blushGold.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ExcludeSemantics(
                            child: Text(
                              counter.years.toString().padLeft(2, '0'),
                              style: AppTypography.cormorantExtraBold.copyWith(
                                color: AppColors.auroraGold,
                                fontSize: 66,
                                height: 1.0,
                                letterSpacing: -1.0,
                                shadows: [
                                  Shadow(
                                    color: AppColors.auroraGold.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 2),
                                  ),
                                  Shadow(
                                    color: AppColors.goldShadow.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _DiamondDivider(),
                          const SizedBox(height: 10),
                          Text(
                            'since Feb 14, 2026',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12.5,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                              color: AppColors.petalWhite.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Sunken crystal console panel for the counter grid
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.moonlight.withValues(alpha: 0.09),
                                  AppColors.inkDeep.withValues(alpha: 0.34),
                                  AppColors.velvet.withValues(alpha: 0.20),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              borderRadius: AppRadius.radiusXl,
                              border: Border.all(
                                color: AppColors.moonlight.withValues(alpha: 0.16),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.20),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Inner top rim specular highlight
                                Positioned(
                                  top: 0,
                                  left: 20,
                                  right: 20,
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          AppColors.petalWhite.withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  children: [
                                    SizedBox(
                                      height: 112,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: MetricCard(
                                              label: 'Months',
                                              value: counter.months,
                                              flat: true,
                                            ),
                                          ),
                                          const _VDivider(),
                                          Expanded(
                                            child: MetricCard(
                                              label: 'Days',
                                              value: counter.days,
                                              flat: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const _HDivider(),
                                    SizedBox(
                                      height: 108,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: MetricCard(
                                              label: 'Hours',
                                              value: counter.hours,
                                              flat: true,
                                            ),
                                          ),
                                          const _VDivider(),
                                          Expanded(
                                            child: MetricCard(
                                              label: 'Minutes',
                                              value: counter.minutes,
                                              flat: true,
                                            ),
                                          ),
                                          const _VDivider(),
                                          Expanded(
                                            child: MetricCard(
                                              label: 'Seconds',
                                              value: counter.seconds,
                                              isLive: true,
                                              flat: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: Center(
              child: _TotalDaysRibbon(totalDays: totalDays),
            ),
          ),
        ],
      ),
    );
  }
}

/// Line — diamond — line ornament under the years numeral.
class _DiamondDivider extends StatelessWidget {
  const _DiamondDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.blushGold.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Transform.rotate(
            angle: 0.785398, // 45 degrees in radians
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.auroraGold,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.auroraGold.withValues(alpha: 0.60),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 36,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blushGold.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hairline divider between grid columns — fixed height comes from the
/// surrounding SizedBox row, so no IntrinsicHeight cost.
class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.moonlight.withValues(alpha: 0.20),
            AppColors.petalWhite.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        ),
      ),
    );
  }
}

/// Hairline divider between the two grid rows.
class _HDivider extends StatelessWidget {
  const _HDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.moonlight.withValues(alpha: 0.20),
            AppColors.petalWhite.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        ),
      ),
    );
  }
}

/// Wax-seal ribbon overlapping the card's bottom edge: the count Clair
/// actually feels ("206 days of us") in bright type, the date quiet.
class _TotalDaysRibbon extends StatelessWidget {
  final int totalDays;

  const _TotalDaysRibbon({required this.totalDays});

  @override
  Widget build(BuildContext context) {
    return _wrapGlass(
      borderRadius: AppRadius.radiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.moonlight.withValues(alpha: 0.16),
              AppColors.velvet.withValues(alpha: 0.62),
              AppColors.inkDeep.withValues(alpha: 0.72),
            ],
          ),
          borderRadius: AppRadius.radiusFull,
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.auroraRose.withValues(alpha: 0.15),
              blurRadius: 14,
              spreadRadius: -2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 14,
              right: 14,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.petalWhite.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 11,
                  color: AppColors.auroraRose,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$totalDays days of us',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w600,
                            color: AppColors.petalWhite,
                          ),
                        ),
                        TextSpan(
                          text: '  ·  since Feb 14, 2026',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w500,
                            color: AppColors.petalWhite.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.favorite_rounded,
                  size: 11,
                  color: AppColors.auroraRose,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
