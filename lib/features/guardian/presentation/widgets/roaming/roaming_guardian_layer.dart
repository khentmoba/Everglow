import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'roaming_guardian_cat.dart';
import 'roaming_guardian_controller.dart';

/// One paint layer of the roaming Guardian.
///
/// Mount two of these in the dashboard's root stack at different depths: one
/// with [RoamingGuardianLayer.depth] == [CatDepth.behind] underneath the page
/// content, and one with [CatDepth.front] on top of every overlay. Both layers
/// share a single [RoamingGuardianController], so the cat cross-fades between
/// them seamlessly whenever its depth changes.
class RoamingGuardianLayer extends StatefulWidget {
  const RoamingGuardianLayer({
    super.key,
    required this.controller,
    required this.depth,
    this.visualBuilder,
  });

  final RoamingGuardianController controller;
  final CatDepth depth;
  final RoamingGuardianVisualBuilder? visualBuilder;

  @override
  State<RoamingGuardianLayer> createState() => _RoamingGuardianLayerState();
}

class _RoamingGuardianLayerState extends State<RoamingGuardianLayer> {
  /// Whether this layer currently hosts the cat element. Kept alive through
  /// the fade-out so the platform view can animate away before disposal.
  bool _rendering = false;
  bool _syncScheduled = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _rendering = widget.controller.depth == widget.depth;
    widget.controller.addListener(_scheduleSync);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleSync);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  void _sync() {
    final active = widget.controller.depth == widget.depth;
    if (active) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (!_rendering) {
        setState(() => _rendering = true);
      }
      return;
    }
    // Only start the fade-out timer once; a timer that is reset on every
    // controller tick (30x/s) would never fire.
    if (!_rendering || _hideTimer != null) return;
    _hideTimer = Timer(const Duration(milliseconds: 380), () {
      _hideTimer = null;
      if (mounted && widget.controller.depth != widget.depth) {
        setState(() => _rendering = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controller in sync with the viewport without rebuilding during
    // build; attach() is silent by design.
    widget.controller.attach(MediaQuery.sizeOf(context));
    final active = widget.controller.depth == widget.depth;

    return IgnorePointer(
      ignoring: !active,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: active ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
        },
        child: _rendering
            ? RoamingGuardianCat(
                controller: widget.controller,
                visualBuilder: widget.visualBuilder ?? _placeholderVisual,
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// VM-safe fallback used when no visual is injected (tests).
  static Widget _placeholderVisual(
    BuildContext context,
    RoamingCatFrame frame,
  ) {
    return Container(
      width: frame.catSize,
      height: frame.catSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.deepRose.withValues(alpha: 0.2),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: const Icon(Icons.pets, color: AppColors.blushGold),
    );
  }
}
