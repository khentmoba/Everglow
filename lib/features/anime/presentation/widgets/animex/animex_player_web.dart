import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../data/services/anilist_service.dart';

import 'animex_buttons.dart';
import 'animex_tokens.dart';

class AnimeXPlayerFrame extends StatefulWidget {
  final String url;
  final double aspectRatio;
  final String referrerPolicy;
  final VoidCallback? onContentError;
  final ScrollController? scrollController;

  const AnimeXPlayerFrame({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
    this.referrerPolicy = 'no-referrer',
    this.onContentError,
    this.scrollController,
  });

  @override
  State<AnimeXPlayerFrame> createState() => _AnimeXPlayerFrameState();
}

class _AnimeXPlayerFrameState extends State<AnimeXPlayerFrame> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final web.HTMLDivElement _wrapper;
  web.HTMLDivElement? _overlay;
  JSFunction? _onLoad;
  JSFunction? _onMessage;
  JSFunction? _onWheel;
  JSFunction? _onIframeWheel;
  JSFunction? _onOverlayMove;
  JSFunction? _onOverlayDown;
  int _overlayTimer = 0;
  double _lastMoveX = -1;
  double _lastMoveY = -1;
  bool _loaded = false;
  bool _contentError = false;

  void _forwardWheel(web.WheelEvent wheel, ScrollController ctrl) {
    if (!ctrl.hasClients) return;
    if (wheel.ctrlKey) return;
    wheel.preventDefault();
    var delta = wheel.deltaY.toDouble();
    switch (wheel.deltaMode) {
      case 1:
        delta *= 20;
        break;
      case 2:
        delta *= 600;
        break;
    }
    if (delta == 0) return;
    final pos = ctrl.position;
    final target = (pos.pixels + delta)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if (target != pos.pixels) pos.jumpTo(target);
  }

  void _punchOverlay(int ms) {
    final o = _overlay;
    if (o == null) return;
    o.style.pointerEvents = 'none';
    web.window.clearTimeout(_overlayTimer);
    _overlayTimer = web.window.setTimeout(
      (() {
        o.style.pointerEvents = 'auto';
      }).toJS,
      ms.toJS,
    );
  }

  @override
  void initState() {
    super.initState();
    _viewType =
        'animex-frame-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    _iframe = web.HTMLIFrameElement()
      ..src = widget.url
      ..allow =
          'autoplay *; fullscreen *; encrypted-media *; picture-in-picture *; accelerometer *; gyroscope *; clipboard-write *'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..setAttribute('referrerpolicy', widget.referrerPolicy)
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    _onLoad = (() {
      if (mounted) setState(() => _loaded = true);
    }).toJS;
    _iframe.addEventListener('load', _onLoad);

    _wrapper = web.document.createElement('div') as web.HTMLDivElement
      ..style.position = 'relative'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden';
    _wrapper.appendChild(_iframe);

    final scrollController = widget.scrollController;
    if (scrollController != null) {
      // Fallback: wheel on the iframe element itself. When the transparent
      // overlay is briefly punched (pointerEvents='none') so clicks/hover
      // can reach the player controls, wheel would otherwise fall into the
      // cross-origin iframe and be lost. This listener keeps page scroll
      // alive even during the punch window.
      _onIframeWheel = ((web.Event e) {
        _forwardWheel(e as web.WheelEvent, scrollController);
      }).toJS;
      _iframe.addEventListener(
        'wheel',
        _onIframeWheel,
        web.AddEventListenerOptions(passive: false),
      );

      final overlay = web.document.createElement('div') as web.HTMLDivElement
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent'
        ..style.zIndex = '2'
        ..style.pointerEvents = 'auto';
      _overlay = overlay;
      _wrapper.appendChild(overlay);

      _onWheel = ((web.Event e) {
        _forwardWheel(e as web.WheelEvent, scrollController);
      }).toJS;
      overlay.addEventListener(
        'wheel',
        _onWheel,
        web.AddEventListenerOptions(passive: false),
      );

      // Let hover/click events reach the iframe's controls (play, volume,
      // quality, seek) by briefly disabling the overlay whenever the cursor
      // actually moves. Durations are kept short so wheel scroll is not
      // perceptibly broken: hover punch 90ms, click punch 400ms. The iframe
      // wheel fallback above covers scroll during the punched window.
      _onOverlayMove = ((web.Event e) {
        final m = e as web.MouseEvent;
        final x = m.clientX.toDouble();
        final y = m.clientY.toDouble();
        final moved = (x - _lastMoveX).abs() > 1 || (y - _lastMoveY).abs() > 1;
        if (!moved) return;
        _lastMoveX = x;
        _lastMoveY = y;
        _punchOverlay(90);
      }).toJS;
      _onOverlayDown = ((web.Event _) {
        _punchOverlay(400);
      }).toJS;
      overlay.addEventListener('mousemove', _onOverlayMove);
      overlay.addEventListener('mousedown', _onOverlayDown);
    }

    _onMessage = ((web.MessageEvent event) {
      final raw = event.data;
      final data = raw == null ? '' : raw.toString();
      if (data == 'animex-content-error' && mounted && !_contentError) {
        setState(() => _contentError = true);
        widget.onContentError?.call();
      }
    }).toJS;
    web.window.addEventListener('message', _onMessage);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _wrapper,
    );
  }

  @override
  void dispose() {
    web.window.clearTimeout(_overlayTimer);
    if (_onLoad != null) {
      _iframe.removeEventListener('load', _onLoad!);
    }
    if (_onMessage != null) {
      web.window.removeEventListener('message', _onMessage!);
    }
    if (_onIframeWheel != null) {
      _iframe.removeEventListener('wheel', _onIframeWheel!);
    }
    if (_onWheel != null && _overlay != null) {
      _overlay!.removeEventListener('wheel', _onWheel!);
    }
    if (_onOverlayMove != null && _overlay != null) {
      _overlay!.removeEventListener('mousemove', _onOverlayMove!);
    }
    if (_onOverlayDown != null && _overlay != null) {
      _overlay!.removeEventListener('mousedown', _onOverlayDown!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            HtmlElementView(viewType: _viewType),
            if (!_loaded)
              const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AnimeXTokens.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAnimexTrailer(
  BuildContext context, {
  String? youtubeId,
  int? anilistId,
  int? malId,
  required String title,
}) async {
  var trailerId = youtubeId;
  if ((trailerId == null || trailerId.isEmpty) &&
      (anilistId != null || malId != null)) {
    final detail = await AniListService().fetchDetailsWithFallback(
      anilistId: anilistId,
      malId: malId,
    );
    trailerId = detail?.trailerYoutubeId;
  }
  if (trailerId == null || trailerId.isEmpty) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierColor: const Color(0xE0000000),
    builder: (_) => AnimeXTrailerModal(title: title, youtubeId: trailerId!),
  );
}

class AnimeXTrailerModal extends StatelessWidget {
  final String title;
  final String youtubeId;

  const AnimeXTrailerModal({
    super.key,
    required this.title,
    required this.youtubeId,
  });

  @override
  Widget build(BuildContext context) {
    final url =
        'https://www.youtube.com/embed/$youtubeId?autoplay=1&rel=0&color=white';
    return Dialog(
      backgroundColor: AnimeXTokens.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl),
        side: const BorderSide(color: AnimeXTokens.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title — Official Trailer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dmSansStyle(
                        size: 14,
                        color: AnimeXTokens.textSecondary,
                      ),
                    ),
                  ),
                  AnimeXIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: AnimeXPlayerFrame(
                url: url,
                referrerPolicy: 'strict-origin-when-cross-origin',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
