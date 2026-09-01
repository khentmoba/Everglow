import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
/// Keeps a heavy dashboard section out of the tree until the scroll view
/// brings it near the viewport, so its Firestore streams and image loads only
/// start when the user actually approaches it.
///
/// A per-section [deferMs] staggers below-the-fold subscriptions so the
/// critical first paint (XP, Coming Up, Letterbox) gets the Firestore
/// WebChannel first. Without staggering, 13+ `snapshots()` all contend for
/// the single WebChannel + rule `get(/users/{uid})` in the same tick.
class DeferredSection extends StatefulWidget {
  final Widget child;
  final double placeholderHeight;
  final int deferMs;

  const DeferredSection({
    super.key,
    required this.child,
    this.placeholderHeight = 220,
    this.deferMs = 0,
  });

  @override
  State<DeferredSection> createState() => _DeferredSectionState();
}

class _DeferredSectionState extends State<DeferredSection> {
  final GlobalKey _key = GlobalKey();
  ScrollableState? _scrollable;
  bool _visible = false;
  bool _checkScheduled = false;
  Timer? _deferTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _visible = true;
      return;
    }
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb) return;
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
    _deferTimer?.cancel();
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
    if (kIsWeb) {
      if (!_visible && mounted) setState(() => _visible = true);
      return;
    }
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !mounted) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    // Wider pre-load margin (900) keeps scroll smooth, but `deferMs` ensures
    // far-below-fold sections don't all subscribe in the same microtask as
    // the critical first-fold sections.
    if (top < viewportHeight + 900 && bottom > -500) {
      _scrollable?.position.removeListener(_onScroll);
      if (widget.deferMs > 0) {
        _deferTimer = Timer(Duration(milliseconds: widget.deferMs), () {
          if (mounted) setState(() => _visible = true);
        });
      } else {
        setState(() => _visible = true);
      }
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
