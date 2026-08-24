import 'package:flutter/material.dart';

/// Keeps a heavy dashboard section out of the tree until the scroll view
/// brings it near the viewport, so its Firestore streams and image loads only
/// start when the user actually approaches it.
class DeferredSection extends StatefulWidget {
  final Widget child;
  final double placeholderHeight;

  const DeferredSection({
    super.key,
    required this.child,
    this.placeholderHeight = 220,
  });

  @override
  State<DeferredSection> createState() => _DeferredSectionState();
}

class _DeferredSectionState extends State<DeferredSection> {
  final GlobalKey _key = GlobalKey();
  ScrollableState? _scrollable;
  bool _visible = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != _scrollable) {
      _scrollable?.position.removeListener(_onScroll);
      _scrollable = scrollable;
      scrollable?.position.addListener(_onScroll);
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _scrollable?.position.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _scheduleCheck();

  void _scheduleCheck() {
    if (_visible || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _check();
    });
  }

  void _check() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !mounted) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (top < viewportHeight + 500 && bottom > -500) {
      _scrollable?.position.removeListener(_onScroll);
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: _visible
          ? widget.child
          : SizedBox(height: widget.placeholderHeight),
    );
  }
}
