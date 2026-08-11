import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:everglow/core/theme/app_breakpoints.dart';
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
    if (!widget.animate) return child;
    return animation(child);
  }

  @override
  Widget build(BuildContext context) {
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
            animation: (child) => FadeInLeft(delay: const Duration(milliseconds: 200), child: child),
            child: _MetricCardAnimated(label: 'Years', listenable: _notifier, selector: (c) => c.years),
          ),
          _maybeAnimate(
            animation: (child) => FadeInRight(delay: const Duration(milliseconds: 300), child: child),
            child: _MetricCardAnimated(label: 'Months', listenable: _notifier, selector: (c) => c.months),
          ),
          _maybeAnimate(
            animation: (child) => FadeInLeft(delay: const Duration(milliseconds: 400), child: child),
            child: _MetricCardAnimated(label: 'Days', listenable: _notifier, selector: (c) => c.days),
          ),
          _maybeAnimate(
            animation: (child) => FadeInRight(delay: const Duration(milliseconds: 500), child: child),
            child: _MetricCardAnimated(label: 'Hours', listenable: _notifier, selector: (c) => c.hours),
          ),
          _maybeAnimate(
            animation: (child) => FadeInLeft(delay: const Duration(milliseconds: 600), child: child),
            child: _MetricCardAnimated(label: 'Minutes', listenable: _notifier, selector: (c) => c.minutes),
          ),
          _maybeAnimate(
            animation: (child) => FadeInRight(delay: const Duration(milliseconds: 700), child: child),
            child: _MetricCardAnimated(label: 'Seconds', listenable: _notifier, selector: (c) => c.seconds),
          ),
        ]),
      ),
    );
  }
}

/// Listens to an [AnniversaryCounter] notifier but only rebuilds
/// [MetricCard] when the selected field actually changes.
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