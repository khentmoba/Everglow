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
      if (flag != null && flag.isA<JSBoolean>() && (flag as JSBoolean).toDart) {
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
    return probeSafeAreaPadding().top;
  }

  /// All system overlaps, so navigation backgrounds reach the home indicator
  /// while controls also clear the notch when the phone rotates.
  static EdgeInsets safeAreaPadding() {
    if (!isStandalone()) return EdgeInsets.zero;
    final padding = probeSafeAreaPadding();
    return padding.copyWith(top: math.max(padding.top, safeAreaTop()));
  }

  @visibleForTesting
  static EdgeInsets probeSafeAreaPadding() {
    try {
      final body = web.document.body;
      if (body == null) return EdgeInsets.zero;
      final probe = web.document.createElement('div') as web.HTMLDivElement;
      probe.style.position = 'fixed';
      probe.style.top = '0px';
      probe.style.left = '0px';
      probe.style.width = '0px';
      probe.style.height = '0px';
      probe.style.paddingTop = 'env(safe-area-inset-top)';
      probe.style.paddingRight = 'env(safe-area-inset-right)';
      probe.style.paddingBottom = 'env(safe-area-inset-bottom)';
      probe.style.paddingLeft = 'env(safe-area-inset-left)';
      probe.style.visibility = 'hidden';
      probe.style.pointerEvents = 'none';
      body.append(probe);
      try {
        final style = web.window.getComputedStyle(probe);
        double inset(String raw) {
          final value = double.tryParse(raw.replaceFirst('px', ''));
          return value != null && value.isFinite && value >= 0 && value < 200
              ? value
              : 0;
        }

        return EdgeInsets.fromLTRB(
          inset(style.paddingLeft),
          inset(style.paddingTop),
          inset(style.paddingRight),
          inset(style.paddingBottom),
        );
      } finally {
        probe.remove();
      }
    } catch (_) {
      // DOM unavailable or env() unsupported: no inset.
    }
    return EdgeInsets.zero;
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
/// a pixel. Insets protect content only; route and navigation backgrounds
/// still paint all the way to the screen edges.
class WebStandaloneInsets extends StatefulWidget {
  final Widget child;

  const WebStandaloneInsets({super.key, required this.child});

  @override
  State<WebStandaloneInsets> createState() => _WebStandaloneInsetsState();
}

class _WebStandaloneInsetsState extends State<WebStandaloneInsets> {
  EdgeInsets _padding = EdgeInsets.zero;
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
    final value = WebStandalone.safeAreaPadding();
    if (mounted && value != _padding) {
      setState(() => _padding = value);
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
    if (_padding == EdgeInsets.zero) return widget.child;
    final mq = MediaQuery.of(context);
    final viewPadding = EdgeInsets.fromLTRB(
      math.max(mq.viewPadding.left, _padding.left),
      math.max(mq.viewPadding.top, _padding.top),
      math.max(mq.viewPadding.right, _padding.right),
      math.max(mq.viewPadding.bottom, _padding.bottom),
    );
    // Embedded mode already shortens the host above the keyboard.
    final hostBottom =
        double.tryParse(
          ((web.document.getElementById('eg-app') as web.HTMLElement?)
                      ?.style
                      .bottom ??
                  '')
              .replaceFirst('px', ''),
        ) ??
        0;
    // A visible keyboard already covers the home indicator.
    final padding = EdgeInsets.fromLTRB(
      math.max(
        mq.padding.left,
        math.max(0, viewPadding.left - mq.viewInsets.left),
      ),
      math.max(
        mq.padding.top,
        math.max(0, viewPadding.top - mq.viewInsets.top),
      ),
      math.max(
        mq.padding.right,
        math.max(0, viewPadding.right - mq.viewInsets.right),
      ),
      math.max(
        mq.padding.bottom,
        hostBottom > 0
            ? 0
            : math.max(0, viewPadding.bottom - mq.viewInsets.bottom),
      ),
    );
    return MediaQuery(
      data: mq.copyWith(padding: padding, viewPadding: viewPadding),
      child: widget.child,
    );
  }
}
