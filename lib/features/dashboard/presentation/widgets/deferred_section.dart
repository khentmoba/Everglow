import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/utils/logger.dart';

/// Keeps a heavy dashboard section out of the tree on first frame until
/// either the scroll view brings it near the viewport or (when [warmWhenIdle]
/// is true) the page sits still long enough to warm it one frame at a time.
///
/// Why this matters so much on web: a `CustomScrollView` builds **every** sliver
/// at once — `SliverToBoxAdapter` mounts all of its children eagerly, and the
/// framework only skips laying out and painting the ones outside the viewport
/// (`test/deferred_section_test.dart` pins that down). The dashboard is built
/// from 21 such slivers, so mounting all 21 sections — and their ~25
/// `snapshots()` streams, image decodes and animation controllers — on the
/// first frame would freeze the boot. Deferring them keeps frame 1 light, and
/// [warmWhenIdle] then builds below-viewport sections one-by-one while idle so
/// a fast scroll does not hit a cold-build burst.
///
/// One code path for every platform. The old web branch skipped the visibility
/// check entirely and just waited `deferMs`, which mounted everything anyway.
///
/// Progress is guaranteed three ways, because a section that never appears is
/// far worse than one that appears early:
/// * a geometry check right after the frame that built the placeholder,
/// * the scroll position listener,
/// * a slow safety-net timer while unrevealed sections belong to an active page.
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
    this.warmWhenIdle = false,
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

  /// Also builds this section in the background once the page has been still
  /// for a moment, top to bottom, one section at a time.
  ///
  /// Why: a section's first build runs cold code and first-time drawing work.
  /// Paid during the first swipe, that is the freeze on a fresh open. Paid
  /// while nobody is touching the screen, it is invisible, and the first swipe
  /// lands on sections that already exist. Sections never unload, so this only
  /// reaches the state one full scroll would reach anyway, just sooner.
  /// Any scroll pauses the warm-up until the page is still again.
  final bool warmWhenIdle;

  /// Stillness required after first build or after a scroll before warming.
  static const Duration warmIdleDelay = Duration(milliseconds: 250);

  /// Gap between two background builds, so each gets its own quiet frame.
  static const Duration warmGap = Duration(milliseconds: 16);

  /// How far beyond the viewport still counts as "close enough". Wide enough to
  /// build a section before it is visible (no blank flash when scrolling into
  /// it), narrow enough that far-below sections stay unmounted.
  static const double preloadMargin = 280;

  /// How long a section may sit above the viewport and still be worth building.
  static const double keepAboveMargin = 500;

  @override
  State<DeferredSection> createState() => _DeferredSectionState();
}

class _DeferredSectionState extends State<DeferredSection>
    with WidgetsBindingObserver {
  final GlobalKey _key = GlobalKey();

  ScrollPosition? _position;
  bool _visible = false;
  bool _checkScheduled = false;
  bool _revealRetryScheduled = false;
  // Nearby sections often share a timer deadline. Give each mount its own frame.
  static bool _mountPending = false;
  bool _warnedNoPosition = false;
  Timer? _deferTimer;
  Timer? _safetyNet;
  bool _appActive = true;
  bool _pageActive = true;

  bool get _active => _appActive && _pageActive;

  // Background warm-up shared by every section that opted in, in build order.
  static final List<_DeferredSectionState> _warmQueue = [];
  static Timer? _warmTimer;

  static void _armWarm(Duration delay) {
    _warmTimer?.cancel();
    _warmTimer = null;
    if (_warmQueue.isEmpty) return;
    _warmTimer = Timer(delay, _warmNext);
  }

  static void _warmNext() {
    _warmTimer = null;
    _warmQueue.removeWhere((s) => !s.mounted || s._visible);
    _DeferredSectionState? next;
    var seenBelowTop = false;
    for (final s in _warmQueue) {
      if (!s._active) continue;
      if (s._position?.isScrollingNotifier.value ?? false) {
        // Never compete with a live swipe; try again once it settles.
        _armWarm(DeferredSection.warmIdleDelay);
        return;
      }
      final atOrBelowTop = s._isAtOrBelowViewportTop(
        assumeBelowIfUnlaid: seenBelowTop || (s._position?.pixels ?? 0) <= 0,
      );
      if (!atOrBelowTop) continue;
      seenBelowTop = true;
      next ??= s;
    }
    // Nothing active or only above-viewport sections left: stop without
    // re-arming so we never shift visible content or spin a 16ms timer.
    if (next == null) return;
    if (_mountPending) {
      _armWarm(DeferredSection.warmGap);
      return;
    }
    next._reveal(idle: true);
    _armWarm(DeferredSection.warmGap);
  }

  /// Cached in [didChangeDependencies] so the check never has to look up an
  /// inherited widget from a timer callback.
  double _viewportHeight = 0;
  bool _phone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (widget.warmWhenIdle) {
      _warmQueue.add(this);
      _armWarm(DeferredSection.warmIdleDelay);
    }
    // The placeholder is built by this frame; its geometry is only readable
    // from a post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _syncSafetyNet() {
    if (widget.warmWhenIdle && _active && !_visible && _warmTimer == null) {
      _armWarm(DeferredSection.warmIdleDelay);
    }
    if (!_active || _visible) {
      _safetyNet?.cancel();
      _safetyNet = null;
      _deferTimer?.cancel();
      _deferTimer = null;
      return;
    }
    // Keep recovery active while Clair is using the page: a missing geometry
    // notification must never leave a section blank. Hidden pages need no polls.
    _safetyNet ??= Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _check(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visible) return;
    _pageActive = TickerMode.valuesOf(context).enabled;
    _syncSafetyNet();
    final size = MediaQuery.sizeOf(context);
    _viewportHeight = size.height;
    _phone = size.width < AppBreakpoint.mobile;
    _syncScrollListener();
    _scheduleCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_warmQueue.remove(this) && _warmQueue.isEmpty) {
      _warmTimer?.cancel();
      _warmTimer = null;
    }
    _deferTimer?.cancel();
    _safetyNet?.cancel();
    _position?.removeListener(_onScroll);
    _position?.isScrollingNotifier.removeListener(_onScroll);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncSafetyNet();
    if (_active) _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_visible || _checkScheduled || !_active) return;
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
    _position?.isScrollingNotifier.removeListener(_onScroll);
    _position = position;
    _position?.addListener(_onScroll);
    // Stopping a fling need not change pixels. Reveal the landing cards then,
    // rather than leaving placeholders until the next safety-net tick.
    _position?.isScrollingNotifier.addListener(_onScroll);
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
    // One geometry read per frame max: during a fast scroll this fires per
    // pixel across ~20 sections, and each localToGlobal walks the render
    // tree on the single web thread. The post-frame pass + 400ms safety net
    // still reveal within a frame of entering the preload margin.
    _scheduleCheck();
    // Any movement restarts the stillness wait before background builds.
    if (widget.warmWhenIdle && _warmTimer != null) {
      _armWarm(DeferredSection.warmIdleDelay);
    }
  }

  void _check() {
    if (_visible || !mounted || !_active) return;
    if (_deferForFastScroll || !_isNearViewport()) {
      _deferTimer?.cancel();
      _deferTimer = null;
      return;
    }
    // Long entrance staggers let a phone swipe outrun the reserved space.
    final delay = _phone ? widget.deferMs.clamp(0, 120) : widget.deferMs;
    if (delay > 0) {
      _deferTimer ??= Timer(Duration(milliseconds: delay), _reveal);
      return;
    }
    _reveal();
  }

  // Use Flutter's velocity heuristic, also used for deferred image loading.
  // Already mounted cards stay visible; only new, expensive mounts wait.
  bool get _deferForFastScroll =>
      (_position?.isScrollingNotifier.value ?? false) &&
      (_position?.recommendDeferredLoading(context) ?? false);

  bool _isAtOrBelowViewportTop({required bool assumeBelowIfUnlaid}) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      return assumeBelowIfUnlaid;
    }
    try {
      return box.localToGlobal(Offset.zero).dy + box.size.height > 0;
    } catch (_) {
      return assumeBelowIfUnlaid;
    }
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
    final margin = _phone ? 500.0 : DeferredSection.preloadMargin;
    return top < _viewportHeight + margin &&
        bottom > -DeferredSection.keepAboveMargin;
  }

  void _reveal({bool idle = false}) {
    if (!mounted || _visible || !_active) return;
    _deferTimer?.cancel();
    _deferTimer = null;
    // A quick swipe can leave the section behind before its timer fires.
    if (_deferForFastScroll || (!idle && !_isNearViewport())) return;
    if (_mountPending) {
      if (!_revealRetryScheduled) {
        _revealRetryScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _revealRetryScheduled = false;
          _reveal();
        });
        WidgetsBinding.instance.scheduleFrame();
      }
      return;
    }
    _mountPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _mountPending = false);
    _safetyNet?.cancel();
    _safetyNet = null;
    _position?.removeListener(_onScroll);
    _position?.isScrollingNotifier.removeListener(_onScroll);
    _position = null;
    setState(() => _visible = true);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: _visible
          ? RepaintBoundary(child: widget.child)
          : SizedBox(height: widget.placeholderHeight),
    );
  }
}
