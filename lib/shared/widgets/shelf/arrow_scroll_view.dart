import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_breakpoints.dart';
import 'motion.dart';

/// Wraps a horizontal-scrolling child with optional left/right arrow
/// navigation buttons visible on desktop hover, inspired by cineby's
/// section navigation.
///
/// On desktop: shows left/right arrow buttons on hover or when the
/// section is focused. Buttons auto-hide when scrolled to the start/end.
///
/// On mobile: no arrows, swipe as normal.
class ArrowScrollView extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final double arrowSize;

  const ArrowScrollView({
    super.key,
    required this.child,
    required this.controller,
    this.arrowSize = 36,
  });

  @override
  State<ArrowScrollView> createState() => _ArrowScrollViewState();
}

class _ArrowScrollViewState extends State<ArrowScrollView> {
  bool _hovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    // Check initial state after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant ArrowScrollView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final pos = widget.controller.position;
    setState(() {
      _canScrollLeft = pos.pixels > pos.minScrollExtent + 5;
      _canScrollRight = pos.pixels < pos.maxScrollExtent - 5;
    });
  }

  void _scrollBy(double delta) {
    if (!widget.controller.hasClients) return;
    widget.controller.animateTo(
      widget.controller.offset + delta,
      duration: ShelfMotion.orZero(const Duration(milliseconds: 400)),
      curve: ShelfMotion.easeOutStrong,
    );
  }

  void _onEnter(_) {
    _hideTimer?.cancel();
    setState(() => _hovered = true);
  }

  void _onExit(_) {
    // Small delay to avoid flickering when moving between arrow and content
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _hovered = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    if (!isDesktop) return widget.child;

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: Stack(
        children: [
          widget.child,

          // Left arrow
          if (_hovered && _canScrollLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _ScrollArrow(
                direction: -1,
                onTap: () => _scrollBy(-280),
                onHoverStart: () {
                  _hideTimer?.cancel();
                },
                onHoverEnd: () {},
              ),
            ),

          // Right arrow
          if (_hovered && _canScrollRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _ScrollArrow(
                direction: 1,
                onTap: () => _scrollBy(280),
                onHoverStart: () {
                  _hideTimer?.cancel();
                },
                onHoverEnd: () {},
              ),
            ),
        ],
      ),
    );
  }
}

class _ScrollArrow extends StatefulWidget {
  final int direction; // -1 left, 1 right
  final VoidCallback onTap;
  final VoidCallback onHoverStart;
  final VoidCallback onHoverEnd;

  const _ScrollArrow({
    required this.direction,
    required this.onTap,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  @override
  State<_ScrollArrow> createState() => _ScrollArrowState();
}

class _ScrollArrowState extends State<_ScrollArrow> {
  bool _arrowHovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Center(
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _arrowHovered = true);
            widget.onHoverStart();
          },
          onExit: (_) {
            setState(() => _arrowHovered = false);
            widget.onHoverEnd();
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: ShelfMotion.orZero(ShelfMotion.fast),
              curve: ShelfMotion.easeOutStrong,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _arrowHovered
                    ? AppColors.petalWhite.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.roseQuartz.withValues(alpha: 0.3),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.direction < 0
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: _arrowHovered
                    ? AppColors.petalWhite
                    : AppColors.roseQuartz,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
