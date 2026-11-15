import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/utils/logger.dart';

class DeferredSection extends StatefulWidget {
  const DeferredSection({
    super.key,
    required this.child,
    this.placeholderHeight = 220,
    this.deferMs = 0,
    this.warmWhenIdle = false,
  });

  final Widget child;

  final double placeholderHeight;

  final int deferMs;

  final bool warmWhenIdle;

  static const Duration warmIdleDelay = Duration(milliseconds: 250);

  static const Duration warmGap = Duration(milliseconds: 16);

  static const double preloadMargin = 280;

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
  static bool _mountPending = false;
  bool _warnedNoPosition = false;
  Timer? _deferTimer;
  Timer? _safetyNet;
  bool _appActive = true;
  bool _pageActive = true;

  bool get _active => _appActive && _pageActive;

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
    if (next == null) return;
    if (_mountPending) {
      _armWarm(DeferredSection.warmGap);
      return;
    }
    next._reveal(idle: true);
    _armWarm(DeferredSection.warmGap);
  }

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

  void _syncScrollListener() {
    final position = _positionOf(Scrollable.maybeOf(context));
    if (position == _position) return;
    _position?.removeListener(_onScroll);
    _position?.isScrollingNotifier.removeListener(_onScroll);
    _position = position;
    _position?.addListener(_onScroll);
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

  void _onScroll() {
    _scheduleCheck();
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
    final delay = _phone ? widget.deferMs.clamp(0, 120) : widget.deferMs;
    if (delay > 0) {
      _deferTimer ??= Timer(Duration(milliseconds: delay), _reveal);
      return;
    }
    _reveal();
  }

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
