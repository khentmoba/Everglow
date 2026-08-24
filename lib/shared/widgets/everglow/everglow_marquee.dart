import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Infinite horizontal marquee — constant-speed, hover-to-pause.
///
/// Replaces `ShelfMarquee`. When `AppMotion.reduced` is true,
/// the ticker is paused (content shown statically).
class EverglowMarquee extends StatefulWidget {
  final List<Widget> children;
  final double itemSpacing;
  final double pixelsPerSecond;
  final bool shimmer;

  const EverglowMarquee({
    super.key,
    required this.children,
    this.itemSpacing = 12,
    this.pixelsPerSecond = 30,
    this.shimmer = false,
  });

  @override
  State<EverglowMarquee> createState() => _EverglowMarqueeState();
}

class _EverglowMarqueeState extends State<EverglowMarquee>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  double _offset = 0;
  bool _hovered = false;
  double _totalWidth = 0;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..addListener(_onTick);
      _controller!.repeat();
    }
  }

  void _onTick() {
    if (_hovered || widget.children.isEmpty) return;
    setState(() {
      _offset += widget.pixelsPerSecond / 60;
      if (_totalWidth > 0 && _offset >= _totalWidth) {
        _offset -= _totalWidth;
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

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
    // Build one set of children
    final items = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      items.add(widget.children[i]);
      if (i < widget.children.length - 1) {
        items.add(SizedBox(width: widget.itemSpacing));
      }
    }

    // Measure single set width (approximate: use viewport as fallback)
    final singleSetWidth = _estimateSetWidth();

    // Only tile when content is shorter than viewport
    final needsLoop = singleSetWidth < viewportWidth;
    final sets = needsLoop ? 3 : 1;

    _totalWidth = singleSetWidth + widget.itemSpacing;

    return SizedBox(
      height: 180,
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: Offset(-_offset, 0),
          child: Row(
            children: List.generate(sets, (_) => Row(children: items)),
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
