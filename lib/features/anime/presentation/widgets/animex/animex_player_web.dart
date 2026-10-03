import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../data/services/anilist_service.dart';

import 'animex_buttons.dart';
import 'animex_embed_policy.dart';
import 'animex_tokens.dart';
import 'animex_videasy_progress.dart';

class AnimeXPlayerFrame extends StatefulWidget {
  final String url;
  final double aspectRatio;
  final String referrerPolicy;
  final VoidCallback? onContentError;
  final void Function(VideasyProgress progress)? onProgress;

  /// In-place seek for our Megavid player; other providers ignore it.
  final int? seekSeconds;
  final int seekRequest;

  /// Fires when the embed changes episodes on its own (CineSrc
  /// auto-play or its built-in episode picker), reporting the TMDB
  /// season/episode it moved to. Our embed.html wrapper forwards the
  /// event after origin-checking the upstream, so the app can keep its
  /// episode list on the truth instead of the stale loaded episode.
  final void Function(int season, int episode)? onPlayerEpisodeChanged;

  /// When true the embed runs inside a sandbox that traps popups and
  /// top-frame navigation (the ad engines behind third-party anime
  /// servers rely on both). MegaPlay and AniXo refuse sandboxed iframes
  /// outright, so the frame skips the attribute for them (see
  /// AnimeXEmbedPolicy); every other provider stays caged.
  /// Trailers pass false — YouTube owns its embed and needs no cage.
  final bool sandbox;

  const AnimeXPlayerFrame({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
    this.referrerPolicy = 'no-referrer',
    this.onContentError,
    this.onProgress,
    this.seekSeconds,
    this.seekRequest = 0,
    this.onPlayerEpisodeChanged,
    this.sandbox = true,
  });

  @override
  State<AnimeXPlayerFrame> createState() => _AnimeXPlayerFrameState();
}

class _AnimeXPlayerFrameState extends State<AnimeXPlayerFrame> {
  late final web.HTMLIFrameElement _iframe;

  @visibleForTesting
  web.HTMLIFrameElement get debugIframe => _iframe;
  JSFunction? _onLoad;
  JSFunction? _onMessage;
  bool _loaded = false;
  bool _contentError = false;

  @override
  void initState() {
    super.initState();
    // Per-host policy: MegaPlay/AniXo block sandboxed frames, and all
    // three third-party servers reject referrer-less loads — without
    // this the frame shows their 410/403/Embed-Only cards instead.
    final sandboxed =
        widget.sandbox && AnimeXEmbedPolicy.sandboxAllowed(widget.url);
    final referrer = AnimeXEmbedPolicy.referrerFor(
      widget.url,
      widget.referrerPolicy,
    );
    _iframe = web.HTMLIFrameElement()
      ..src = widget.url
      ..allow =
          'autoplay *; fullscreen *; encrypted-media *; picture-in-picture *; accelerometer *; gyroscope *; clipboard-write *'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..setAttribute('referrerpolicy', referrer)
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    // No `allow-popups` / `allow-top-navigation`: without them the
    // sandbox swallows window.open + top-frame hijacks (the TikTok /
    // YouTube app-open spam) while scripts + same-origin keep the
    // HLS player itself alive. Mirrors web/embed.html and the cinema
    // player, which cage their upstreams the same way.
    if (sandboxed) {
      _iframe.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-presentation allow-pointer-lock',
      );
    }

    _onLoad = (() {
      if (!mounted) return;
      setState(() => _loaded = true);
      _sendSeek();
    }).toJS;
    _iframe.addEventListener('load', _onLoad);

    // No wheel forwarding by design: wheel events inside a
    // cross-origin iframe never reach this document, so a listener on
    // the iframe element can never fire.

    _onMessage = ((web.MessageEvent event) {
      // Origin alone also admits unrelated iframes from the same host.
      // Gate EVERY message, including errors and episode changes.
      if (!mounted ||
          _iframe.contentWindow == null ||
          event.source != _iframe.contentWindow ||
          !animeXPlayerMessageOriginAllowed(widget.url, event.origin)) {
        return;
      }
      final raw = event.data;
      Object? obj;
      try {
        obj = raw?.dartify();
      } catch (_) {
        return;
      }
      final ownedProgress = parseAnimeXProgress(event.origin, widget.url, obj);
      if (ownedProgress != null) {
        widget.onProgress?.call(ownedProgress);
        return;
      }
      // CineSrc episode changes arrive as objects (forwarded by our
      // embed.html wrapper, which already origin-checked the upstream).
      if (raw != null) {
        try {
          if (obj is Map && obj['type'] == 'cinesrc:nextepisode') {
            final season = obj['season'];
            final episode = obj['episode'];
            if (season is num &&
                season.isFinite &&
                season > 0 &&
                season == season.toInt() &&
                episode is num &&
                episode.isFinite &&
                episode > 0 &&
                episode == episode.toInt()) {
              widget.onPlayerEpisodeChanged?.call(
                season.toInt(),
                episode.toInt(),
              );
            }
            return;
          }
        } catch (_) {
          // Not an object message — fall through to string handling.
        }
      }
      final data = obj is String ? obj : '';
      if ((data == 'animex-content-error' ||
              (obj is Map && obj['type'] == 'everglow-embed-failed')) &&
          !_contentError) {
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
  }

  @override
  void didUpdateWidget(covariant AnimeXPlayerFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _loaded = false;
      _contentError = false;
      _iframe.setAttribute(
        'referrerpolicy',
        AnimeXEmbedPolicy.referrerFor(widget.url, widget.referrerPolicy),
      );
      if (widget.sandbox && AnimeXEmbedPolicy.sandboxAllowed(widget.url)) {
        _iframe.setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-forms allow-presentation allow-pointer-lock',
        );
      } else {
        _iframe.removeAttribute('sandbox');
      }
      _iframe.src = widget.url;
    } else if (widget.seekSeconds != oldWidget.seekSeconds ||
        widget.seekRequest != oldWidget.seekRequest) {
      _sendSeek();
    }
  }

  void _sendSeek() {
    final seconds = widget.seekSeconds;
    if (!_loaded ||
        seconds == null ||
        seconds < 0 ||
        !isAnimeXProxyPlayerUrl(widget.url)) {
      return;
    }
    _iframe.contentWindow?.postMessage(
      {'type': 'animex-seek', 'seconds': seconds}.jsify(),
      animeXProxyOrigin.toJS,
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
    _iframe.src = 'about:blank';
    _iframe.remove();
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
            // The built-in factory does not retain a closure over this State
            // for every episode/server change.
            HtmlElementView.fromTagName(
              tagName: 'div',
              onElementCreated: (element) {
                (element as web.HTMLElement).appendChild(_iframe);
              },
            ),
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
