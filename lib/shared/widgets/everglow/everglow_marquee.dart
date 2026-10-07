import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Infinite horizontal marquee — constant-speed, hover-to-pause.
///
/// When `AppMotion.reduced` is true, the ticker is paused (content shown statically).
/// For short rows where content does not overflow the viewport (such as 1 or 2 items),
/// an inter-set spacer keeps the next set off-screen so the row carousels normally
/// without showing repeated duplicate covers side-by-side. For overflowing rows,
/// sets tile seamlessly with standard spacing to loop infinitely without visual gaps.
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
/// Overflowing rows also fade both clip edges ([edgeFade]): without it a
/// drifting card is hard-sliced mid-glyph at the viewport bounds (see the
/// Watched shelf, where titles like "…rden" were cut at both edges), which
/// reads as a broken list. The fade dissolves edge cards into the dark
/// backdrop instead, so the drift reads as an intentional rail.
class EverglowMarquee extends StatefulWidget {
  final List<Widget> children;
  final double itemSpacing;
  final double pixelsPerSecond;
  final bool shimmer;
  final double height;

  /// Soften the left/right clip bounds on overflowing (scrolling) rows.
  /// Static rows render no fade. Disable for light backgrounds where a
  /// fade-to-black would read as a smudge.
  final bool edgeFade;

  const EverglowMarquee({
    super.key,
    required this.children,
    this.itemSpacing = 12,
    this.pixelsPerSecond = 30,
    this.shimmer = false,
    this.height = 180,
    this.edgeFade = true,
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
  bool _isVisible = true;
  bool _appActive = true;
  ScrollPosition? _scrollPosition;
  List<Widget> _items = const [];
  double _loopWidth = 1;
  // While the enclosing vertical list is scrolling, the drift pauses so the
  // single web thread spends its 16ms on scroll raster instead of also
  // repainting this row 60x/sec. Resumes shortly after the scroll settles.
  Timer? _scrollSettle;

  /// Test hook: true while the drift ticker is running.
  @visibleForTesting
  bool get isDrifting => _controller?.isAnimating ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _rebuildItems();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..addListener(_onTick);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _scrollPosition) {
      _scrollPosition?.removeListener(_onScroll);
      _scrollPosition = pos;
      _scrollPosition?.addListener(_onScroll);
    }
    _syncTicker();
  }

  void _onScroll() {
    _checkVisibility();
    // Pause drift for the scroll duration: each tick repaints 2x card sets
    // plus a ShaderMask saveLayer, which competes directly with the vertical
    // scroll raster on Flutter Web's single thread (PWA jank).
    final c = _controller;
    if (c != null && c.isAnimating) c.stop();
    _scrollSettle?.cancel();
    _scrollSettle = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _checkVisibility(); // Scroll listeners can fire before layout has moved.
      _syncTicker();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (viewportHeight <= 0) return;
    try {
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      final isVisible = top < viewportHeight + 150 && bottom > -150;
      if (_isVisible != isVisible) {
        _isVisible = isVisible;
        _syncTicker();
      }
    } catch (_) {
      // Element unmounted or geometry not readable during layout transition.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  /// Runs the metronome only while the row can actually drift.
  void _syncTicker() {
    final c = _controller;
    if (c == null) return;
    final shouldRun =
        _appActive &&
        _canScroll &&
        !_hovered &&
        _isVisible &&
        TickerMode.valuesOf(context).enabled &&
        !AppMotion.reduceAmbientMotion(context) &&
        !(_scrollSettle?.isActive ?? false);
    if (shouldRun && !c.isAnimating) {
      c.repeat();
    } else if (!shouldRun && c.isAnimating) {
      c.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollSettle?.cancel();
    _scrollPosition?.removeListener(_onScroll);
    _controller?.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    // One lazy, swipeable copy on phones. Every card remains reachable without
    // continuously repainting a duplicated track or its edge shader.
    if (AppMotion.reduceAmbientMotion(context) || _controller == null) {
      return RepaintBoundary(
        child: ClipRect(
          child: SizedBox(
            height: widget.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.children.length,
              separatorBuilder: (_, _) => SizedBox(width: widget.itemSpacing),
              itemBuilder: (_, index) => widget.children[index],
            ),
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
    _canScroll = widget.children.isNotEmpty;
    _syncTicker();

    final setWidth = _estimateSetWidth();
    // For short rows that do not overflow the viewport (e.g. 1 or 2 items),
    // set the inter-set gap so the next set starts off-screen. This allows
    // the shelf to carousel normally without showing duplicate covers side-by-side.
    final isShort =
        viewportWidth.isFinite && viewportWidth > 0 && setWidth < viewportWidth;
    final interSetGap = isShort
        ? (viewportWidth - setWidth + widget.itemSpacing)
        : widget.itemSpacing;

    _loopWidth = setWidth + interSetGap;
    if (_loopWidth <= 0) _loopWidth = 1;

    final sets = isShort
        ? 2
        : (viewportWidth.isFinite && viewportWidth > 0 && _loopWidth > 0)
        ? (1 + (viewportWidth / _loopWidth).ceil()).clamp(2, 30)
        : 2;

    Widget row = SizedBox(
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
              for (var s = 0; s < sets; s++) ...[
                if (s > 0) SizedBox(width: interSetGap),
                Row(children: _items),
              ],
            ],
          ),
        ),
      ),
    );
    // Dissolve drifting cards at the clip bounds instead of slicing them
    // mid-glyph. A ShaderMask with dstIn fades the cards' own alpha to
    // transparent at the edges, so the dissolve matches ANY background
    // (the old foreground gradient painted pure black, which read as a
    // dark bar on the dashboard's purple glow). The mask itself is static
    // — only the Transform underneath moves — and the RepaintBoundary
    // above keeps the saveLayer cost inside this row.
    if (widget.edgeFade) {
      row = ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.035, 0.965, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: row,
      );
    }
    return row;
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
