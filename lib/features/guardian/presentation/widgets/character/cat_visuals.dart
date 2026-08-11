import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// 3D chibi cat guardian rendered via the `<model-viewer>` web component.
class CatVisuals extends StatefulWidget {
  final double size;

  const CatVisuals({
    super.key,
    this.size = 80,
  });

  @override
  State<CatVisuals> createState() => _CatVisualsState();
}

class _CatVisualsState extends State<CatVisuals> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'model-viewer-${identityHashCode(this)}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = web.document.createElement('model-viewer') as web.HTMLElement;
      el
        // Web-relative path (the pubspec asset key gains an extra
        // `assets/` prefix in the compiled web bundle).
        ..setAttribute('src', 'assets/assets/models/chibi_cat.glb')
        ..setAttribute('alt', 'Everglow Guardian Cat')
        ..setAttribute('auto-rotate', '')
        ..setAttribute('auto-rotate-delay', '2000')
        ..setAttribute('rotation-per-second', '20deg')
        ..setAttribute('camera-controls', 'false')
        ..setAttribute('disable-zoom', '')
        ..setAttribute('shadow-intensity', '0.8')
        ..setAttribute('shadow-softness', '1.0')
        ..setAttribute('auto-play', '')
        ..setAttribute('interaction-prompt', 'none')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
      return el;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.2),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
