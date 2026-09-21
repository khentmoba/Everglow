import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

/// Full-screen loading veil with a 1% incremental progress counter, shown
/// exclusively after passcode entry for Khent or Clair on the gateway.
///
/// Counts smoothly from 1% to 100% with a determinate progress bar and
/// warm status lines that guide Clair and Khent into their sanctuary.
///
/// It never appears when opening the site for the first time or reloading;
/// it is requested strictly via [requestPasscodeLoader] when either Khent
/// or Clair inputs their passcode at the entry door.
class DashboardLoadVeil extends StatefulWidget {
  const DashboardLoadVeil({
    super.key,
    required this.visible,
    this.onSkip,
    this.onComplete,
    this.duration = const Duration(milliseconds: 2200),
  });

  final bool visible;

  /// Called when Clair or Khent taps Skip, or when the 1% count completes.
  final VoidCallback? onSkip;

  /// Optional completion hook called alongside [onSkip] when 100% is reached.
  final VoidCallback? onComplete;

  /// Duration of the 1% to 100% incremental count animation.
  final Duration duration;

  static bool _requestedAfterPasscode = false;

  /// Request the 1% incremental loading veil to appear after passcode entry.
  static void requestPasscodeLoader() {
    _requestedAfterPasscode = true;
  }

  /// Consumes the request. Returns true only once per passcode entry.
  static bool consumePasscodeLoaderRequest() {
    final requested = _requestedAfterPasscode;
    _requestedAfterPasscode = false;
    return requested;
  }

  /// For testing: inspect whether a request is pending.
  @visibleForTesting
  static bool get hasPendingPasscodeLoaderRequest => _requestedAfterPasscode;

  /// For testing: reset state between tests.
  @visibleForTesting
  static void resetPasscodeLoaderRequest() {
    _requestedAfterPasscode = false;
  }

  /// Warm status message tied to progress percentage.
  static String labelForPercent(int percent) {
    if (percent < 18) {
      return 'opening the door…';
    } else if (percent < 36) {
      return 'gathering memories…';
    } else if (percent < 54) {
      return 'checking your dates…';
    } else if (percent < 72) {
      return 'unsealing letters…';
    } else if (percent < 88) {
      return 'waking the garden…';
    } else if (percent < 100) {
      return 'counting your stars…';
    } else {
      return 'opening your story…';
    }
  }

  @override
  State<DashboardLoadVeil> createState() => _DashboardLoadVeilState();
}

class _DashboardLoadVeilState extends State<DashboardLoadVeil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnimation;
  Timer? _completeTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.orZero(widget.duration),
    );
    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Hold 100% briefly so they see it complete, then dismiss
        _completeTimer = Timer(
          AppMotion.orZero(const Duration(milliseconds: 250)),
          () {
            if (mounted) {
              widget.onComplete?.call();
              widget.onSkip?.call();
            }
          },
        );
      }
    });

    if (widget.visible) {
      _startProgress();
    }
  }

  void _startProgress() {
    if (_controller.isAnimating || _controller.isCompleted) return;
    _controller.forward(from: 0.01);
  }

  @override
  void didUpdateWidget(DashboardLoadVeil oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _startProgress();
    } else if (!widget.visible && oldWidget.visible) {
      _controller.stop();
      _completeTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, _) {
              final double progress = widget.visible
                  ? _progressAnimation.value.clamp(0.01, 1.0)
                  : 1.0;
              final int percent = (progress * 100).clamp(1, 100).round();
              final String percentText = '$percent%';
              final String label = DashboardLoadVeil.labelForPercent(percent);

              return Semantics(
                container: true,
                label: 'Loading your story, $percentText',
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
                        percentText,
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
                            value: progress,
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
                          const Duration(milliseconds: 250),
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
                          onPressed: () {
                            _controller.stop();
                            _completeTimer?.cancel();
                            widget.onSkip!();
                          },
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
                                color: AppColors.blushGold.withValues(
                                  alpha: 0.3,
                                ),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
