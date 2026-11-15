import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

class EverglowMarquee extends StatefulWidget {
  final List<Widget> children;
  final double itemSpacing;
  final double pixelsPerSecond;
  final bool shimmer;
  final double height;

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
  bool _reduceAmbient = false;
  bool _tickerEnabled = true;
  bool _scrollDirty = false;
  ScrollPosition? _scrollPosition;
  List<Widget> _items = const [];
  double _loopWidth = 1;
  Timer? _scrollSettle;

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
    _loopWidth = _estimateSetWidth() + widget.itemSpacing;
    if (_loopWidth <= 0) _loopWidth = 1;
  }

  void _onTick() {
    if (_hovered || !_canScroll || widget.children.isEmpty) return;
    var next = _offset.value + widget.pixelsPerSecond / 60;
    if (next >= _loopWidth) next %= _loopWidth;
    _offset.value = next;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceAmbient = AppMotion.reduceAmbientMotion(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_reduceAmbient || _controller == null) {
      _scrollPosition?.removeListener(_onScroll);
      _scrollPosition = null;
      _scrollSettle?.cancel();
      _controller?.stop();
      return;
    }
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _scrollPosition) {
      _scrollPosition?.removeListener(_onScroll);
      _scrollPosition = pos;
      _scrollPosition?.addListener(_onScroll);
    }
    _syncTicker();
  }

  void _onScroll() {
    if (_reduceAmbient || _controller == null) return;
    final c = _controller;
    if (c != null && c.isAnimating) c.stop();
    if (_scrollSettle?.isActive ?? false) {
      _scrollDirty = true;
      return;
    }
    _scrollDirty = false;
    _armSettleTimer(const Duration(milliseconds: 400));
  }

  void _armSettleTimer(Duration delay) {
    _scrollSettle = Timer(delay, () {
      if (!mounted || _reduceAmbient) return;
      if (_scrollDirty) {
        _scrollDirty = false;
        _armSettleTimer(const Duration(milliseconds: 80));
        return;
      }
      _checkVisibility();
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

  void _syncTicker() {
    final c = _controller;
    if (c == null) return;
    final shouldRun =
        _appActive &&
        _canScroll &&
        !_hovered &&
        _isVisible &&
        _tickerEnabled &&
        !_reduceAmbient &&
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
    if (_reduceAmbient || _controller == null) {
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
    if (widget.children.isEmpty) return 0;
    return widget.children.length * 152.0 - widget.itemSpacing;
  }
}
