import 'dart:async';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class CatVisuals extends StatefulWidget {
  final double size;
  final bool autoRotate;
  final String? orientation;
  final bool clip;
  final Duration initDelay;
  final void Function(Object? element)? onElementCreated;

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
  bool _ready = false;
  Timer? _initTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initDelay == Duration.zero) {
      _ready = true;
    } else {
      _initTimer = Timer(widget.initDelay, () {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return IgnorePointer(
        child: ClipOval(
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              'assets/images/motchi_avatar.webp',
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: ClipOval(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ModelViewer(
            src: 'assets/models/chibi_cat.glb',
            alt: 'Everglow Guardian Cat',
            backgroundColor: Colors.transparent,
            autoRotate: widget.autoRotate,
            autoRotateDelay: 2000,
            rotationPerSecond: '18deg',
            orientation: widget.orientation ?? '',
            cameraControls: false,
            disablePan: true,
            disableTap: true,
            disableZoom: true,
            autoPlay: true,
            shadowIntensity: 0.8,
            shadowSoftness: 1.0,
            interactionPrompt: InteractionPrompt.none,
            loading: Loading.eager,
            reveal: Reveal.auto,
          ),
        ),
      ),
    );
  }
}
