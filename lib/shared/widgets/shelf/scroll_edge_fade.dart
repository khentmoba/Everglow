import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Wraps a horizontally-scrolling child and adds a soft fade on the
/// trailing edge — the visual "there's more here" hint that the
/// material/motion-craft guides both call out. Pairs well with
/// horizontal ListView / PageView rows in the four inside screens.
class ScrollEdgeFade extends StatelessWidget {
  final Widget child;
  final double fadeWidth;
  final Color fadeColor;
  final Axis scrollDirection;

  const ScrollEdgeFade({
    super.key,
    required this.child,
    this.fadeWidth = 36,
    this.fadeColor = AppColors.animeBackground,
    this.scrollDirection = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    if (scrollDirection == Axis.vertical) {
      return Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: fadeWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fadeColor, fadeColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: fadeWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [fadeColor, fadeColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              width: fadeWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [fadeColor, fadeColor.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
