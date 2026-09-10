import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// 3D chibi cat guardian rendered via the `<model-viewer>` web component.
///
/// Load behavior (dashboard performance): the platform view is created
/// [initDelay] after mount so the GLB fetch + WebGL boot never contend with
/// the dashboard's Firestore stream burst on cold start. Until then — and
/// while the model downloads — the Motchi avatar shows (already bundled, and
/// already on-screen via the AI button, so it costs zero new bytes).
class CatVisuals extends StatefulWidget {
  final double size;
  final bool autoRotate;
  final String? orientation;
  final bool clip;
  final Duration initDelay;
  final void Function(web.HTMLElement element)? onElementCreated;

  const CatVisuals({
    super.key,
    this.size = 80,
    this.autoRotate = true,
    this.orientation,
    this.clip = true,
    this.initDelay = const Duration(milliseconds: 1500),
    this.onElementCreated,
  });

  @override
  State<CatVisuals> createState() => CatVisualsState();
}

class CatVisualsState extends State<CatVisuals> {
  late final String _viewType;
  web.HTMLElement? _element;
  bool _ready = false;
  Timer? _initTimer;

  @override
  void initState() {
    super.initState();
    _viewType = 'model-viewer-${identityHashCode(this)}';
    // The factory below is cheap (no load until the platform view lays
    // out), so register now but mount the view after the delay.
    if (widget.initDelay == Duration.zero) {
      _ready = true;
    } else {
      _initTimer = Timer(widget.initDelay, () {
        if (mounted) setState(() => _ready = true);
      });
    }

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = web.document.createElement('model-viewer') as web.HTMLElement;
      el
        // Web-relative path (the pubspec asset key gains an extra
        // `assets/` prefix in the compiled web bundle).
        ..setAttribute('src', 'assets/assets/models/chibi_cat.glb')
        ..setAttribute('poster', 'assets/assets/images/motchi_avatar.png')
        ..setAttribute('alt', 'Everglow Guardian Cat')
        ..setAttribute('camera-controls', 'false')
        ..setAttribute('disable-zoom', '')
        ..setAttribute('shadow-intensity', '0.8')
        ..setAttribute('shadow-softness', '1.0')
        ..setAttribute('auto-play', '')
        ..setAttribute('interaction-prompt', 'none')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
      _element = el;
      widget.onElementCreated?.call(el);
      _syncAttributes(el);
      return el;
    });
  }

  void _syncAttributes(web.HTMLElement el) {
    if (widget.autoRotate) {
      el.setAttribute('auto-rotate', '');
      el.setAttribute('auto-rotate-delay', '2000');
      el.setAttribute('rotation-per-second', '18deg');
    } else {
      el.removeAttribute('auto-rotate');
      el.removeAttribute('auto-rotate-delay');
      el.removeAttribute('rotation-per-second');
    }
    final orientation = widget.orientation;
    if (orientation != null && orientation.isNotEmpty) {
      el.setAttribute('orientation', orientation);
    } else {
      el.removeAttribute('orientation');
    }
  }

  /// Stops the model-viewer's render loop before the element is removed,
  /// avoiding a race in the model-viewer library on disposal.
  void suspend() {
    final el = _element;
    if (el != null && el.style.display != 'none') {
      el.style.display = 'none';
    }
  }

  void resume() {
    final el = _element;
    if (el != null && el.style.display == 'none') {
      el.style.display = '';
    }
  }

  @override
  void didUpdateWidget(covariant CatVisuals oldWidget) {
    super.didUpdateWidget(oldWidget);
    final el = _element;
    if (el != null &&
        (oldWidget.autoRotate != widget.autoRotate ||
            oldWidget.orientation != widget.orientation)) {
      _syncAttributes(el);
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    // Stop the model-viewer render loop before the platform view element is
    // removed, avoiding a race inside the model-viewer library.
    final el = _element;
    if (el != null) {
      el.style.display = 'none';
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget inner = _ready
        ? HtmlElementView(viewType: _viewType)
        : Image.asset(
            'assets/images/motchi_avatar.png',
            fit: BoxFit.cover,
          );
    final viewer = SizedBox(
      width: widget.size,
      height: widget.size,
      child: inner,
    );
    if (!widget.clip) return viewer;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.2),
      child: viewer,
    );
  }
}
