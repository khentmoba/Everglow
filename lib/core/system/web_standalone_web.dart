import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('navigator.standalone')
external JSAny? get _iosNavigatorStandalone;

@JS('__everglowSafeAreaTop')
external JSNumber? _egSafeAreaTopBridge();

class WebStandalone {
  WebStandalone._();

  static void openPaintControl() {
    web.window.location.href = Uri.base
        .resolve('/screen_test.html?paint=1')
        .toString();
  }

  static String viewportReport() {
    String bounds(String selector) {
      final element = web.document.querySelector(selector);
      if (element == null) return '$selector: absent';
      final rect = element.getBoundingClientRect();
      return '$selector: y=${rect.top.toStringAsFixed(0)}..'
          '${rect.bottom.toStringAsFixed(0)}, h=${rect.height.toStringAsFixed(0)}';
    }

    final viewport = web.window.visualViewport;
    final host = web.document.getElementById('eg-app') as web.HTMLElement?;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final engine = views.isEmpty ? null : views.first;
    final logicalSize = engine == null
        ? null
        : engine.physicalSize / engine.devicePixelRatio;
    final canvas =
        web.document
                .querySelector('flutter-view')
                ?.querySelector('flt-glass-pane')
                ?.shadowRoot
                ?.querySelector('canvas')
            as web.HTMLCanvasElement?;
    final canvasRect = canvas?.getBoundingClientRect();
    final insets = safeAreaPadding();
    final meta = web.document.querySelector('meta[name="viewport"]');
    final status = web.document.querySelector(
      'meta[name="apple-mobile-web-app-status-bar-style"]',
    );
    return [
      'Screen measurement 2 (CSS pixels)',
      'Installed: ${isStandalone()}',
      'Screen: ${web.window.screen.width} x ${web.window.screen.height}',
      'Window: ${web.window.innerWidth} x ${web.window.innerHeight}',
      'Visual: ${viewport?.height.toStringAsFixed(0)} '
          'offset=${viewport?.offsetTop.toStringAsFixed(0)} scale=${viewport?.scale}',
      'Flutter drawing: ${logicalSize?.width.toStringAsFixed(0)} x '
          '${logicalSize?.height.toStringAsFixed(0)}',
      'Host client: ${host?.clientWidth} x ${host?.clientHeight}; '
          '${host?.getAttribute('flt-embedding')}',
      'Canvas CSS: ${canvasRect?.width.toStringAsFixed(0)} x '
          '${canvasRect?.height.toStringAsFixed(0)}; '
          'backing: ${canvas?.width} x ${canvas?.height}',
      bounds('html'),
      bounds('body'),
      bounds('#eg-app'),
      bounds('flutter-view'),
      'Safe top/bottom: ${insets.top} / ${insets.bottom}',
      'Installed CSS: ${web.document.documentElement?.classList.contains('eg-standalone')}',
      'Status: ${status?.getAttribute('content')}',
      'Viewport: ${meta?.getAttribute('content')}',
    ].join('\n');
  }

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
      if (web.document.fullscreenElement == null &&
          web.window.matchMedia('(display-mode: fullscreen)').matches) {
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

  @visibleForTesting
  static double probeSafeAreaTop() {
    return probeSafeAreaPadding().top;
  }

  static EdgeInsets safeAreaPadding() {
    if (!isStandalone()) return EdgeInsets.zero;
    final padding = probeSafeAreaPadding();
    return padding.copyWith(top: math.max(padding.top, safeAreaTop()));
  }

  static double keyboardInset() {
    final host = web.document.getElementById('eg-app');
    final viewport = web.window.visualViewport;
    final active = web.document.activeElement;
    if (!isStandalone() ||
        host?.getAttribute('flt-embedding') != 'custom-element' ||
        viewport == null ||
        viewport.scale != 1 ||
        active == null ||
        (active.tagName != 'INPUT' &&
            active.tagName != 'TEXTAREA' &&
            active.getAttribute('contenteditable') != 'true')) {
      return 0;
    }
    final bounds = host!.getBoundingClientRect();
    return (bounds.bottom - viewport.height - viewport.offsetTop)
        .clamp(0, bounds.height)
        .toDouble();
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

class WebStandaloneInsets extends StatefulWidget {
  final Widget child;

  const WebStandaloneInsets({super.key, required this.child});

  @override
  State<WebStandaloneInsets> createState() => _WebStandaloneInsetsState();
}

class _WebStandaloneInsetsState extends State<WebStandaloneInsets> {
  EdgeInsets _padding = EdgeInsets.zero;
  double _keyboard = 0;
  web.EventListener? _resizeListener;
  web.EventListener? _blurListener;

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
      web.window.visualViewport?.addEventListener('resize', _resizeListener!);
      web.window.visualViewport?.addEventListener('scroll', _resizeListener!);
      web.document.addEventListener('focusin', _resizeListener!);
      _blurListener =
          ((web.Event _) {
                Future.delayed(Duration.zero, () {
                  if (mounted) _refresh();
                });
              }).toJS
              as web.EventListener;
      web.document.addEventListener('focusout', _blurListener!);
    } catch (_) {
      _resizeListener = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _refresh();
      });
    });
  }

  void _refresh() {
    if (web.document.fullscreenElement != null) return;
    final value = WebStandalone.safeAreaPadding();
    final keyboard = WebStandalone.keyboardInset();
    if (mounted && (value != _padding || keyboard != _keyboard)) {
      setState(() {
        _padding = value;
        _keyboard = keyboard;
      });
    }
  }

  @override
  void dispose() {
    try {
      final listener = _resizeListener;
      if (listener != null) {
        web.window.removeEventListener('resize', listener);
        web.window.removeEventListener('orientationchange', listener);
        web.window.visualViewport?.removeEventListener('resize', listener);
        web.window.visualViewport?.removeEventListener('scroll', listener);
        web.document.removeEventListener('focusin', listener);
      }
      if (_blurListener != null) {
        web.document.removeEventListener('focusout', _blurListener!);
      }
    } catch (_) {
      // Page tearing down: nothing to clean up.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_padding == EdgeInsets.zero && _keyboard == 0) return widget.child;
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.copyWith(
      bottom: math.max(mq.viewInsets.bottom, _keyboard),
    );
    final viewPadding = EdgeInsets.fromLTRB(
      math.max(mq.viewPadding.left, _padding.left),
      math.max(mq.viewPadding.top, _padding.top),
      math.max(mq.viewPadding.right, _padding.right),
      math.max(mq.viewPadding.bottom, _padding.bottom),
    );
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
        0,
        math.max(mq.padding.bottom, viewPadding.bottom) - viewInsets.bottom,
      ),
    );
    return MediaQuery(
      data: mq.copyWith(
        padding: padding,
        viewPadding: viewPadding,
        viewInsets: viewInsets,
      ),
      child: widget.child,
    );
  }
}
