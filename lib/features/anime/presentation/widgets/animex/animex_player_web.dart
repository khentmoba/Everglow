import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../data/services/anilist_service.dart';

import 'animex_buttons.dart';
import 'animex_tokens.dart';
import 'animex_videasy_progress.dart';

class AnimeXPlayerFrame extends StatefulWidget {
  final String url;
  final double aspectRatio;
  final String referrerPolicy;
  final VoidCallback? onContentError;
  final void Function(VideasyProgress progress)? onProgress;
  final ScrollController? scrollController;

  /// When true the embed runs inside a sandbox that traps popups and
  /// top-frame navigation (the ad engines behind third-party anime
  /// servers rely on both). Provider playback only needs scripts +
  /// same-origin, so video keeps working while popunders die silently.
  /// Trailers pass false — YouTube owns its embed and needs no cage.
  final bool sandbox;

  const AnimeXPlayerFrame({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
    this.referrerPolicy = 'no-referrer',
    this.onContentError,
    this.onProgress,
    this.scrollController,
    this.sandbox = true,
  });

  @override
  State<AnimeXPlayerFrame> createState() => _AnimeXPlayerFrameState();
}

class _AnimeXPlayerFrameState extends State<AnimeXPlayerFrame> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoad;
  JSFunction? _onMessage;
  JSFunction? _onIframeWheel;
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
    // No `allow-popups` / `allow-top-navigation`: without them the
    // sandbox swallows window.open + top-frame hijacks (the TikTok /
    // YouTube app-open spam) while scripts + same-origin keep the
    // HLS player itself alive. Mirrors web/embed.html and the cinema
    // player, which cage their upstreams the same way.
    if (widget.sandbox) {
      _iframe.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-presentation allow-pointer-lock',
      );
    }

    _onLoad = (() {
      if (mounted) setState(() => _loaded = true);
    }).toJS;
    _iframe.addEventListener('load', _onLoad);

    final scrollController = widget.scrollController;
    if (scrollController != null) {
      _onIframeWheel = ((web.Event e) {
        _forwardWheel(e as web.WheelEvent, scrollController);
      }).toJS;
      _iframe.addEventListener(
        'wheel',
        _onIframeWheel,
        web.AddEventListenerOptions(capture: true, passive: false),
      );
    }

    _onMessage = ((web.MessageEvent event) {
      final raw = event.data;
      final data = raw == null ? '' : raw.toString();
      if (data == 'animex-content-error' && mounted && !_contentError) {
        setState(() => _contentError = true);
        widget.onContentError?.call();
        return;
      }
      // Videasy progress ticks (other servers stay silent — their skip
      // buttons simply remain manual). Origin-checked inside the parser.
      final progress = parseVideasyProgress(event.origin, data);
      if (progress != null && mounted) widget.onProgress?.call(progress);
    }).toJS;
    web.window.addEventListener('message', _onMessage);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
  }

  @override
  void dispose() {
    if (_onLoad != null) {
      _iframe.removeEventListener('load', _onLoad!);
    }
    if (_onMessage != null) {
      web.window.removeEventListener('message', _onMessage!);
    }
    if (_onIframeWheel != null) {
      _iframe.removeEventListener('wheel', _onIframeWheel!);
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
                // YouTube owns this embed — caging it could break its
                // player API / fullscreen, and it serves no popunders.
                sandbox: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
