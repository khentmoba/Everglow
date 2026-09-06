import "package:flutter/material.dart";

import "../../../core/theme/app_motion.dart";

/// Infinite horizontal marquee — constant-speed, hover-to-pause.
///
/// Replaces `ShelfMarquee`. When `AppMotion.reduced` is true,
/// the ticker is paused (content shown statically).
///
/// Rows that fit the viewport render statically with each child shown
/// exactly once. Only rows that overflow the viewport auto-scroll, using
/// a second copy of the set for a seamless wrap. Tiling short rows to
/// fill the viewport reads as duplicate data (the same cover N times),
/// so it is deliberately not done.
///
/// Performance notes (why this file looks the way it does):
/// - The offset is a [ValueNotifier] consumed by a single [AnimatedBuilder]
///   around the [Transform] only. Older code called `setState` 60x/sec, which
///   rebuilt the ENTIRE child list (posters, badges, text) every frame and
///   tanked scroll FPS wherever a marquee was on screen. Now only the
///   transform repaints; children build once per widget update.
/// - Estimated item width (`122.0`) matches the previous heuristic so loop
///   timing is unchanged. Callers with below-the-fold marquees should still
///   wrap this in `DeferredSection` so its ticker starts near the viewport.
/// - The ticker pauses on app background via [WidgetsBindingObserver] and
///   respects [TickerMode] (e.g. paused routes) through the controller.
class EverglowMarquee extends StatefulWidget {
  final List<Widget> children;
  final double itemSpacing;
  final double pixelsPerSecond;
  final bool shimmer;
  final double height;

  const EverglowMarquee({
    super.key,
    required this.children,
    this.itemSpacing = 12,
    this.pixelsPerSecond = 30,
    this.shimmer = false,
    this.height = 180,
  });

  @override
  State<EverglowMarquee> createState() => _EverglowMarqueeState();
}

class _EverglowMarqueeState extends State<EverglowMarquee>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _controller;
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);
  bool _hovered = false;
  bool _canScroll = true;
  List<Widget> _items = const [];
  double _loopWidth = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rebuildItems();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..addListener(_onTick);
      _controller!.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant EverglowMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.children, widget.children) ||
        oldWidget.itemSpacing != widget.itemSpacing) {
      _rebuildItems();
    }
  }

  void _rebuildItems() {
    final items = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      items.add(widget.children[i]);
      if (i < widget.children.length - 1) {
        items.add(SizedBox(width: widget.itemSpacing));
      }
    }
    _items = items;
    // Wrap point for the translate loop; matches previous
    // `_totalWidth = singleSetWidth + itemSpacing` behavior.
    _loopWidth = _estimateSetWidth() + widget.itemSpacing;
    if (_loopWidth <= 0) _loopWidth = 1;
  }

  void _onTick() {
    if (_hovered || !_canScroll || widget.children.isEmpty) return;
    // No setState: only the AnimatedBuilder around Transform rebuilds.
    var next = _offset.value + widget.pixelsPerSecond / 60;
    // Modulo (not a single subtraction) so a stale offset stays in range
    // even when the item list — and therefore _loopWidth — shrinks.
    if (next >= _loopWidth) next %= _loopWidth;
    _offset.value = next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    if (state == AppLifecycleState.resumed) {
      if (!c.isAnimating && !_hovered) c.repeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      c.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    // Reduced motion: static row, no ticker, no per-frame work at all.
    if (AppMotion.reduced || _controller == null) {
      return RepaintBoundary(
        child: ClipRect(
          child: SizedBox(
            height: widget.height,
            child: Row(children: _items),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _buildContent(constraints.maxWidth);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double viewportWidth) {
    final singleSetWidth = _estimateSetWidth();

    // Short rows fit entirely on screen: show each child exactly once
    // with no auto-scroll. (An unbounded viewport trivially fits.)
    final overflows =
        viewportWidth.isFinite && singleSetWidth > viewportWidth;
    // Plain field write — no setState — consumed by the ticker only.
    _canScroll = overflows;
    if (!overflows) {
      return SizedBox(
        height: widget.height,
        child: Row(children: _items),
      );
    }

    // Overflowing rows keep the infinite marquee. Two copies plus the
    // inter-set gap form one seamless wrap period of exactly _loopWidth,
    // so the second set slides in as the first slides out (no blank gap).
    return SizedBox(
      height: widget.height,
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) => Transform.translate(
            offset: Offset(-_offset.value, 0),
            child: child,
          ),
          child: Row(
            children: [
              Row(children: _items),
              SizedBox(width: widget.itemSpacing),
              Row(children: _items),
            ],
          ),
        ),
      ),
    );
  }

  double _estimateSetWidth() {
    // Pitch model for the dashboard shelves: a 128-wide ShelfCard plus
    // the caller's 12px right padding plus the 12px inter-item spacer,
    // minus the trailing spacer the final card omits. Over-counting
    // generic children is the safe direction: a wrongly-static row would
    // clip its tail with no way to reach it, while a wrongly-scrolling
    // row still shows every child.
    // In production, use a GlobalKey + RenderBox for precise measurement
    if (widget.children.isEmpty) return 0;
    return widget.children.length * 152.0 - widget.itemSpacing;
  }
}