import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../data/services/anilist_service.dart';
import '../../../data/services/aniskip_service.dart';

import 'animex_buttons.dart';
import 'animex_embed_policy.dart';
import 'animex_tokens.dart';
import 'animex_videasy_progress.dart';

bool _fullscreenExitSettling = false;

bool isPlayerFullscreenActive() =>
    _fullscreenExitSettling || web.document.fullscreenElement != null;

class AnimeXPlayerFrame extends StatefulWidget {
  final String url;
  final double aspectRatio;
  final String referrerPolicy;
  final VoidCallback? onContentError;
  final void Function(VideasyProgress progress)? onProgress;

  final int? seekSeconds;
  final int seekRequest;
  final AniSkipTimes? skipTimes;

  final String? nextToken;
  final bool nextIsSeason;
  final VoidCallback? onNextEpisode;

  final bool autoAdvance;

  final ValueChanged<String>? onAudioChanged;

  final void Function(int season, int episode)? onPlayerEpisodeChanged;

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
    this.skipTimes,
    this.nextToken,
    this.nextIsSeason = false,
    this.onNextEpisode,
    this.autoAdvance = true,
    this.onAudioChanged,
    this.onPlayerEpisodeChanged,
    this.sandbox = true,
  });

  @override
  State<AnimeXPlayerFrame> createState() => _AnimeXPlayerFrameState();
}

class _AnimeXPlayerFrameState extends State<AnimeXPlayerFrame> {
  late final web.HTMLIFrameElement _iframe;
  web.HTMLVideoElement? _videoElement;
  JSFunction? _videoLoadedListener;
  JSFunction? _videoTimeUpdateListener;
  JSFunction? _videoEndedListener;
  JSFunction? _videoErrorListener;
  JSFunction? _videoWheelListener;
  JSFunction? _onFullscreenChange;
  Timer? _fullscreenSettleTimer;

  bool get _isDirectVideo =>
      widget.url.endsWith('.mp4') ||
      widget.url.endsWith('.webm') ||
      widget.url.startsWith('blob:') ||
      widget.url.startsWith('offline:');

  @visibleForTesting
  web.HTMLIFrameElement get debugIframe => _iframe;
  JSFunction? _onLoad;
  JSFunction? _onMessage;
  bool _loaded = false;
  bool _contentError = false;

  @override
  void initState() {
    super.initState();
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
      _sendPlayerState();
    }).toJS;
    _iframe.addEventListener('load', _onLoad);

    _onMessage = ((web.MessageEvent event) {
      if (!mounted ||
          _iframe.contentWindow == null ||
          !identical(event.source, _iframe.contentWindow) ||
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
      final scrollDelta = parseEverglowEmbedScrollDelta(obj);
      if (scrollDelta != null) {
        _applyEmbedScroll(scrollDelta);
        return;
      }
      if (raw != null) {
        try {
          if (obj is Map && obj['type'] == 'animex-action') {
            final act = obj['action'];
            if (act == 'next-episode') {
              widget.onNextEpisode?.call();
            } else if (act == 'audio') {
              final audio = obj['audio'];
              if (audio == 'sub' || audio == 'dub') {
                widget.onAudioChanged?.call(audio as String);
              }
            }
            return;
          }
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
      final progress = parseVideasyProgress(event.origin, data);
      if (progress != null && mounted) widget.onProgress?.call(progress);
    }).toJS;
    web.window.addEventListener('message', _onMessage);
    _onFullscreenChange = ((web.Event _) {
      _fullscreenSettleTimer?.cancel();
      if (web.document.fullscreenElement != null) {
        _fullscreenExitSettling = false;
      } else {
        _fullscreenExitSettling = true;
        _fullscreenSettleTimer = Timer(const Duration(milliseconds: 260), () {
          _fullscreenExitSettling = false;
          if (mounted) setState(() {});
        });
      }
    }).toJS;
    web.document.addEventListener('fullscreenchange', _onFullscreenChange);
  }

  void _applyEmbedScroll(double dy) {
    if (!mounted || web.document.fullscreenElement != null) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions) {
      return;
    }
    final next = (position.pixels + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      position.jumpTo(next);
    }
  }

  @override
  void didUpdateWidget(covariant AnimeXPlayerFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _loaded = false;
      _contentError = false;
      if (_isDirectVideo && _videoElement != null) {
        _videoElement!.src = widget.url;
        _videoElement!.play();
      } else {
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
      }
    } else {
      if (widget.seekSeconds != oldWidget.seekSeconds ||
          widget.seekRequest != oldWidget.seekRequest) {
        _sendSeek();
      }
      if (widget.skipTimes != oldWidget.skipTimes ||
          widget.nextToken != oldWidget.nextToken ||
          widget.nextIsSeason != oldWidget.nextIsSeason) {
        _sendPlayerState();
      }
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

  void _sendPlayerState() {
    if (!_loaded || !isAnimeXProxyPlayerUrl(widget.url)) return;
    final op = widget.skipTimes?.opening;
    final ed = widget.skipTimes?.ending;
    _iframe.contentWindow?.postMessage(
      {
        'type': 'animex-player-state',
        if (op != null) 'op': [op.start, op.end],
        if (ed != null) 'ed': [ed.start, ed.end],
        'next': widget.nextToken,
        'nextKind': widget.nextIsSeason ? 'season' : 'episode',
      }.jsify(),
      animeXProxyOrigin.toJS,
    );
  }

  @override
  void dispose() {
    _fullscreenSettleTimer?.cancel();
    _fullscreenExitSettling = false;
    if (_onFullscreenChange != null) {
      web.document.removeEventListener('fullscreenchange', _onFullscreenChange!);
    }
    if (_videoElement != null) {
      _videoElement!.pause();
      if (_videoLoadedListener != null) {
        _videoElement!.removeEventListener('loadeddata', _videoLoadedListener);
      }
      if (_videoTimeUpdateListener != null) {
        _videoElement!.removeEventListener('timeupdate', _videoTimeUpdateListener);
      }
      if (_videoEndedListener != null) {
        _videoElement!.removeEventListener('ended', _videoEndedListener);
      }
      if (_videoErrorListener != null) {
        _videoElement!.removeEventListener('error', _videoErrorListener);
      }
      if (_videoWheelListener != null) {
        _videoElement!.removeEventListener('wheel', _videoWheelListener);
      }
      _videoElement = null;
    }
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            HtmlElementView.fromTagName(
              tagName: 'div',
              onElementCreated: (element) {
                final host = element as web.HTMLElement;
                host.style
                  ..borderRadius = '${AnimeXTokens.radiusLg}px'
                  ..overflow = 'hidden';
                if (_isDirectVideo) {
                  _videoElement = web.HTMLVideoElement()
                    ..controls = true
                    ..autoplay = true
                    ..style.border = 'none'
                    ..style.width = '100%'
                    ..style.height = '100%'
                    ..style.backgroundColor = '#000'
                    ..setAttribute('playsinline', 'true')
                    ..setAttribute('webkit-playsinline', 'true');
                  _videoElement!.src = widget.url;

                  _videoLoadedListener = ((web.Event _) {
                    if (mounted) setState(() => _loaded = true);
                  }).toJS;
                  _videoTimeUpdateListener = ((web.Event _) {
                    if (!mounted || _videoElement == null) return;
                    widget.onProgress?.call(
                      VideasyProgress(
                        positionSeconds: _videoElement!.currentTime,
                        durationSeconds: _videoElement!.duration.isFinite
                            ? _videoElement!.duration
                            : 0,
                      ),
                    );
                  }).toJS;
                  _videoEndedListener = ((web.Event _) {
                    if (mounted && widget.autoAdvance) {
                      widget.onNextEpisode?.call();
                    }
                  }).toJS;
                  _videoErrorListener = ((web.Event _) {
                    if (mounted) {
                      setState(() {
                        _loaded = true;
                        _contentError = true;
                      });
                      widget.onContentError?.call();
                    }
                  }).toJS;
                  _videoWheelListener = ((web.Event event) {
                    final wheel = event as web.WheelEvent;
                    final delta = parseEverglowEmbedScrollDelta({
                      'type': 'everglow-embed-scroll',
                      'deltaY': wheel.deltaY,
                      'deltaMode': wheel.deltaMode,
                    });
                    if (delta != null) _applyEmbedScroll(delta);
                  }).toJS;

                  _videoElement!.addEventListener('loadeddata', _videoLoadedListener);
                  _videoElement!.addEventListener('timeupdate', _videoTimeUpdateListener);
                  _videoElement!.addEventListener('ended', _videoEndedListener);
                  _videoElement!.addEventListener('error', _videoErrorListener);
                  _videoElement!.addEventListener('wheel', _videoWheelListener);
                  host.appendChild(_videoElement!);
                } else {
                  host.appendChild(_iframe);
                }
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
                sandbox: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
