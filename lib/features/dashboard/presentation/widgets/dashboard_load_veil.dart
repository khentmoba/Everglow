import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import 'dashboard_load_tracker.dart';

/// Full-screen loading veil with a REAL percent, shown briefly on cold
/// start while the dashboard's first screen reports ready.
///
/// Matches the web splash (`web/index.html`) — heart, `EVERGLOW`,
/// determinate bar, big percent, warm status line — so going from the
/// door to the dashboard feels like one continuous handoff, and Clair
/// always sees how far along her story is instead of an endless spinner.
///
/// This is the ONE percent loader in the app: the gateway reveal behind
/// the door shows no number on purpose (a fixed animation has nothing
/// honest to count), so the percent here never resets backwards.
///
/// The veil is purely visual except for its Skip button: it fades out via
/// [visible] and ignores input once hidden. The number is honest —
/// [DashboardLoadTracker.progress] climbs only as each first-screen card
/// reports its own load settled (data, cache, or settled error).
/// The displayed number eases toward the real number in smooth 1% ticks
/// (never past it), so Clair sees 34, 35, 36… instead of a jump.
/// [DashboardScreen] owns dismissal: the moment the tracker completes
/// (100%), when Clair taps Skip, or on a generous failsafe so a wedged
/// stream can never trap her — cards keep loading underneath.
class DashboardLoadVeil extends StatefulWidget {
  const DashboardLoadVeil({super.key, required this.visible, this.onSkip});

  final bool visible;

  /// Called when Clair taps Skip. Null hides the button (tests).
  final VoidCallback? onSkip;

  @override
  State<DashboardLoadVeil> createState() => _DashboardLoadVeilState();
}

class _DashboardLoadVeilState extends State<DashboardLoadVeil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _displayed = 0.0;
  double _target = 0.0;
  double _from = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_onTick);
  }

  void _onTick() {
    final t = AppMotion.reduced
        ? 1.0
        : Curves.easeOut.transform(_controller.value);
    setState(() {
      _displayed = _from + (_target - _from) * t;
    });
  }

  /// Eases the shown number toward the real [target], ticking through
  /// every 1% on the way. Never displays past the real progress.
  void _animateTo(double target) {
    if (target == _target) return;
    if (target < _displayed) {
      _target = target;
      _from = target;
      _controller.stop();
      setState(() => _displayed = target);
      return;
    }
    _from = _displayed;
    _target = target;
    if (AppMotion.reduced) {
      _controller.stop();
      setState(() => _displayed = target);
      return;
    }
    // One tracker step (~17%) takes ~600ms, so each 1% ticks about
    // every 35ms — visible counting without feeling slow.
    final distance = (target - _from).abs();
    final ms = (600 * distance / (1 / 6)).clamp(150, 900).round();
    _controller.duration = Duration(milliseconds: ms);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.select<DashboardLoadTracker, double>(
      (t) => t.progress,
    );
    if (progress != _target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(progress);
      });
    }
    final label = context.select<DashboardLoadTracker, String>(
      (t) => t.currentLabel,
    );
    final percent = '${(_displayed * 100).round()}%';
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: AppMotion.orZero(const Duration(milliseconds: 500)),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.inkDeep, AppColors.twilight, AppColors.velvet],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Semantics(
            container: true,
            label: 'Loading your story, $percent',
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.auroraRose,
                    size: 26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'EVERGLOW',
                    style: TextStyle(
                      color: AppColors.petalWhite.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    percent,
                    style: TextStyle(
                      color: AppColors.petalWhite.withValues(alpha: 0.9),
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        value: _displayed,
                        backgroundColor: const Color(0x26F5EFE6),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.blushGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: AppMotion.orZero(
                      const Duration(milliseconds: 300),
                    ),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: TextStyle(
                        color: AppColors.petalWhite.withValues(alpha: 0.45),
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (widget.onSkip != null) ...[
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: widget.onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.petalWhite.withValues(
                          alpha: 0.7,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: AppColors.blushGold.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
