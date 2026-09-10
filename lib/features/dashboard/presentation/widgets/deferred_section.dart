import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/logger.dart';

/// Keeps a heavy dashboard section out of the tree until the scroll view brings
/// it near the viewport, so its Firestore streams, images, painters and tickers
/// only exist when the user actually approaches them.
///
/// Why this matters so much on web: a `CustomScrollView` builds **every** sliver
/// at once — `SliverToBoxAdapter` mounts all of its children eagerly, and the
/// framework only skips laying out and painting the ones outside the viewport
/// (`test/deferred_section_test.dart` pins that down). The dashboard is built
/// from 21 such slivers, so without this gate all 21 sections — and their ~25
/// `snapshots()` streams, image decodes and animation controllers — exist from
/// the first frame, even eight screens below the fold. On Flutter Web build,
/// layout, draw and raster share one thread, which makes that mount burst the
/// first-load freeze and keeps every offscreen ticker re-recording its layer on
/// every later frame.
///
/// One code path for every platform. The old web branch skipped the visibility
/// check entirely and just waited `deferMs`, which mounted everything anyway.
///
/// Progress is guaranteed three ways, because a section that never appears is
/// far worse than one that appears early:
/// * a geometry check right after the frame that built the placeholder,
/// * the scroll position listener,
/// * a slow safety-net timer, used only while the scroll position is not
///   available yet.
///
/// Nothing here may ever throw: a broken check would take the whole dashboard
/// down with it (that is how the "Together zone" grey slab happened), so every
/// read is guarded and a failed check simply means "try again later".
class DeferredSection extends StatefulWidget {
  const DeferredSection({
    super.key,
    required this.child,
    this.placeholderHeight = 220,
    this.deferMs = 0,
  });

  final Widget child;

  /// Height reserved before the real section exists, so the scrollbar and the
  /// jump-to-zone anchors keep roughly the right extent while it is deferred.
  final double placeholderHeight;

  /// Stagger applied *after* the section is found to be near the viewport.
  ///
  /// The first screenful of sections all qualify at once; without this they
  /// would all build in the same frame and hand Firestore's single WebChannel
  /// a burst of subscriptions plus a `get(/users/{uid})` rule check each. Keep
  /// it small — it delays real content.
  final int deferMs;

  /// How far beyond the viewport still counts as "close enough". Wide enough to
  /// build a section before it is visible (no blank flash when scrolling into
  /// it), narrow enough that far-below sections stay unmounted.
  static const double preloadMargin = 900;

  /// How long a section may sit above the viewport and still be worth building.
  static const double keepAboveMargin = 500;

  @override
  State<DeferredSection> createState() => _DeferredSectionState();
}

class _DeferredSectionState extends State<DeferredSection> {
  final GlobalKey _key = GlobalKey();

  ScrollPosition? _position;
  bool _visible = false;
  bool _checkScheduled = false;
  bool _warnedNoPosition = false;
  Timer? _deferTimer;
  Timer? _safetyNet;

  /// Cached in [didChangeDependencies] so the check never has to look up an
  /// inherited widget from a timer callback.
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    // The placeholder is built by this frame; its geometry is only readable
    // from a post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    // Always on, not just as a fallback for a missing scroll position: this
    // screen has been broken twice by a visibility check that silently stopped
    // firing, and a section that never appears is far worse than one that
    // appears early. It costs one geometry read per unmounted section every
    // 400ms and stops as soon as the section is revealed.
    _safetyNet = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _check(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visible) return;
    _viewportHeight = MediaQuery.sizeOf(context).height;
    _syncScrollListener();
    _scheduleCheck();
  }

  @override
  void dispose() {
    _deferTimer?.cancel();
    _safetyNet?.cancel();
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _scheduleCheck() {
    if (_visible || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _check();
    });
  }

  /// Watches the enclosing scroll view so a section builds as it comes into
  /// range instead of waiting for the safety-net tick.
  void _syncScrollListener() {
    final position = _positionOf(Scrollable.maybeOf(context));
    if (position == _position) return;
    _position?.removeListener(_onScroll);
    _position = position;
    _position?.addListener(_onScroll);
  }

  ScrollPosition? _positionOf(ScrollableState? scrollable) {
    try {
      return scrollable?.position;
    } catch (e) {
      if (!_warnedNoPosition) {
        _warnedNoPosition = true;
        Logger.e('[DeferredSection] scroll position not ready yet', error: e);
      }
      return null;
    }
  }

  /// Reveals as soon as the section is near, and again after the layout that
  /// this scroll produced. Without the second pass a *programmatic* jump (the
  /// dashboard's jump-to-zone anchors) would scroll past sections that were not
  /// laid out yet at notification time, and leave their placeholders behind
  /// until the user happened to scroll again.
  void _onScroll() {
    _check();
    _scheduleCheck();
  }

  void _check() {
    if (_visible || !mounted) return;
    if (!_isNearViewport()) return;
    if (widget.deferMs > 0) {
      _deferTimer ??= Timer(
        Duration(milliseconds: widget.deferMs),
        _reveal,
      );
      return;
    }
    _reveal();
  }

  bool _isNearViewport() {
    if (_viewportHeight <= 0) return false;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    // Never laid out (beyond the viewport's cache extent) or already gone.
    if (box == null || !box.attached || !box.hasSize) return false;
    final double top;
    try {
      top = box.localToGlobal(Offset.zero).dy;
    } catch (e) {
      Logger.e('[DeferredSection] could not read section position', error: e);
      return false;
    }
    final bottom = top + box.size.height;
    return top < _viewportHeight + DeferredSection.preloadMargin &&
        bottom > -DeferredSection.keepAboveMargin;
  }

  void _reveal() {
    if (!mounted || _visible) return;
    _deferTimer?.cancel();
    _deferTimer = null;
    _safetyNet?.cancel();
    _safetyNet = null;
    _position?.removeListener(_onScroll);
    _position = null;
    setState(() => _visible = true);
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
