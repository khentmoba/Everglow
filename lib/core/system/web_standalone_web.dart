import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// iOS "Add to Home Screen" flag. Non-standard, so it is read through
/// plain JS interop instead of `package:web`'s typed `Navigator`.
@JS('navigator.standalone')
external JSAny? get _iosNavigatorStandalone;

/// Optional bridge published by `web/index.html`. Present on fresh deploys;
/// missing on cached old shells, so every caller treats it as best-effort.
@JS('__everglowSafeAreaTop')
external JSNumber? _egSafeAreaTopBridge();

/// Helpers for the installed-web-app case (Add to Home Screen / PWA).
///
/// Why this exists: with `viewport-fit=cover` the standalone web view
/// stretches underneath the iPhone status bar (time / WiFi / battery).
/// Flutter's `SafeArea` reports zero padding on web, so dashboard content
/// started at y=0 and the top row rendered half-cut underneath the status
/// bar. Normal mobile Safari is unaffected — Safari owns the top area and
/// the viewport starts below it — so every member here returns false/zero
/// outside standalone and leaves that path pixel-identical.
class WebStandalone {
  WebStandalone._();

  /// True only when running as an installed web app.
  ///
  /// Covers iOS Home Screen apps (`navigator.standalone`, including older
  /// iOS that never fires `display-mode` queries) and Chromium-based
  /// installed apps (`display-mode: standalone/fullscreen`). Plain browser
  /// tabs — including mobile Safari — return false.
  static bool isStandalone() {
    if (!kIsWeb) return false;
    try {
      if (web.window.matchMedia('(display-mode: standalone)').matches) {
        return true;
      }
    } catch (_) {
      // matchMedia unavailable (very old browser): fall through.
    }
    try {
      if (web.window.matchMedia('(display-mode: fullscreen)').matches) {
        return true;
      }
    } catch (_) {
      // Same: fall through to the iOS flag.
    }
    try {
      final flag = _iosNavigatorStandalone;
      if (flag != null &&
          flag.isA<JSBoolean>() &&
          (flag as JSBoolean).toDart) {
        return true;
      }
    } catch (_) {
      // Property missing on non-iOS browsers.
    }
    return false;
  }

  /// Live iPhone status-bar overlap in logical pixels, standalone only.
  ///
  /// Returns 0 in browsers, on native, and when the inset cannot be read.
  /// Reads the `index.html` bridge first, then falls back to measuring
  /// `env(safe-area-inset-top)` directly so cached old shells (without the
  /// bridge) still get the inset. Clamped to a sane range so a bogus value
  /// can never shove content off-screen.
  static double safeAreaTop() {
    if (!isStandalone()) return 0;
    try {
      final bridged = _egSafeAreaTopBridge()?.toDartDouble ?? 0;
      if (bridged.isFinite && bridged > 0 && bridged < 200) return bridged;
    } catch (_) {
      // Bridge missing (cached shell) or threw: use the probe below.
    }
    return probeSafeAreaTop();
  }

  /// Measures `env(safe-area-inset-top)` with a throwaway probe node.
  @visibleForTesting
  static double probeSafeAreaTop() {
    try {
      final body = web.document.body;
      if (body == null) return 0;
      final probe = web.document.createElement('div') as web.HTMLDivElement;
      probe.style.position = 'fixed';
      probe.style.top = '0px';
      probe.style.left = '0px';
      probe.style.width = '0px';
      probe.style.height = '0px';
      probe.style.paddingTop = 'env(safe-area-inset-top)';
      probe.style.visibility = 'hidden';
      probe.style.pointerEvents = 'none';
      body.append(probe);
      try {
        final raw = web.window.getComputedStyle(probe).paddingTop;
        final match = RegExp(r'([\d.]+)').firstMatch(raw);
        if (match != null) {
          final value = double.tryParse(match.group(1) ?? '');
          if (value != null && value.isFinite && value >= 0 && value < 200) {
            return value;
          }
        }
      } finally {
        probe.remove();
      }
    } catch (_) {
      // DOM unavailable or env() unsupported: no inset.
    }
    return 0;
  }
}

/// Teaches the widget tree the iPhone status-bar overlap, standalone-web
/// only. Applied once at the app root: the measured inset is injected
/// into [MediaQuery] padding, so every [SafeArea], [AppBar], and
/// `MediaQuery.paddingOf` reader in the app clears the status bar
/// automatically — including screens added in the future. Page backgrounds
/// stay full-bleed (they live below the padding, outside any SafeArea).
/// Everywhere else — Safari tabs, native, tests — the measured inset is 0
/// and the tree is returned untouched, so those paths cannot shift by even
/// a pixel. Bottom is deliberately left alone: scrolling stays
/// edge-to-edge down to the home indicator, exactly as Clair sees it today.
class WebStandaloneInsets extends StatefulWidget {
  final Widget child;

  const WebStandaloneInsets({super.key, required this.child});

  @override
  State<WebStandaloneInsets> createState() => _WebStandaloneInsetsState();
}

class _WebStandaloneInsetsState extends State<WebStandaloneInsets> {
  double _top = 0;
  web.EventListener? _resizeListener;

  @override
  void initState() {
    super.initState();
    _refresh();
    try {
      _resizeListener =
          ((web.Event _) {
                _refresh();
              }).toJS
              as web.EventListener;
      web.window.addEventListener('resize', _resizeListener!);
      web.window.addEventListener('orientationchange', _resizeListener!);
    } catch (_) {
      _resizeListener = null;
    }
    // env() resolves after first layout in some standalone shells;
    // re-read once the first frame and shortly after has landed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _refresh();
      });
    });
  }

  void _refresh() {
    final value = WebStandalone.safeAreaTop();
    if (mounted && (value - _top).abs() > 0.5) {
      setState(() => _top = value);
    }
  }

  @override
  void dispose() {
    try {
      final listener = _resizeListener;
      if (listener != null) {
        web.window.removeEventListener('resize', listener);
        web.window.removeEventListener('orientationchange', listener);
      }
    } catch (_) {
      // Page tearing down: nothing to clean up.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_top <= 0) return widget.child;
    final mq = MediaQuery.of(context);
    final top = math.max(mq.padding.top, _top);
    final viewTop = math.max(mq.viewPadding.top, _top);
    if (top <= mq.padding.top && viewTop <= mq.viewPadding.top) {
      return widget.child;
    }
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(top: top),
        viewPadding: mq.viewPadding.copyWith(top: viewTop),
      ),
      child: widget.child,
    );
  }
}
