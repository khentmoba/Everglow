import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'package:everglow/features/cinema/data/services/anilist_service.dart';

import 'animex_buttons.dart';
import 'animex_tokens.dart';

/// Embedded iframe player used for episodes and trailers. Registers a
/// unique platform view per URL so multiple players can coexist.
class AnimeXPlayerFrame extends StatefulWidget {
  final String url;
  final double aspectRatio;

  const AnimeXPlayerFrame({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<AnimeXPlayerFrame> createState() => _AnimeXPlayerFrameState();
}

class _AnimeXPlayerFrameState extends State<AnimeXPlayerFrame> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoad;
  bool _loaded = false;

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
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    _onLoad = (() {
      if (mounted) setState(() => _loaded = true);
    }).toJS;
    _iframe.addEventListener('load', _onLoad);
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);
  }

  @override
  void dispose() {
    if (_onLoad != null) {
      _iframe.removeEventListener('load', _onLoad!);
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

/// Opens the reference-style trailer modal for an anime. Fetches the
/// AniList detail to resolve the YouTube trailer key when needed.
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
    builder: (_) => AnimeXTrailerModal(
      title: title,
      youtubeId: trailerId!,
    ),
  );
}

/// Trailer overlay dialog with a 16:9 YouTube player and close button.
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
              child: AnimeXPlayerFrame(url: url),
            ),
          ],
        ),
      ),
    );
  }
}
