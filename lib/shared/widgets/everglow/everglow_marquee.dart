import "package:flutter/material.dart";

import "../../../core/theme/app_motion.dart";

/// Infinite horizontal marquee — constant-speed, hover-to-pause.
///
/// Replaces `ShelfMarquee`. When `AppMotion.reduced` is true,
/// the ticker is paused (content shown statically).
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
    if (_hovered || widget.children.isEmpty) return;
    // No setState: only the AnimatedBuilder around Transform rebuilds.
    var next = _offset.value + widget.pixelsPerSecond / 60;
    if (next >= _loopWidth) next -= _loopWidth;
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

    // Only tile when content is shorter than viewport.
    final needsLoop = singleSetWidth < viewportWidth;
    final sets = needsLoop ? 3 : 1;

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
            children: List.generate(
              sets,
              (_) => Row(children: _items),
              growable: false,
            ),
          ),
        ),
      ),
    );
  }

  double _estimateSetWidth() {
    // Rough estimate based on item count and typical widths
    // In production, use a GlobalKey + RenderBox for precise measurement
    return widget.children.length * 122.0;
  }
}