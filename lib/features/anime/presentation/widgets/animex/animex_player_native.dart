import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../../core/utils/logger.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/services/anilist_service.dart';
import '../../../data/services/aniskip_service.dart';
import '../../../../cinema/presentation/widgets/embed_webview.dart';
import 'animex_buttons.dart';
import 'animex_tokens.dart';
import 'animex_videasy_progress.dart';

/// Opens the reference-style trailer for an anime inside the app.
///
/// The web implementation shows a modal with a YouTube iframe; Android runs
/// the same embed in a WebView instead of handing the user off to YouTube.
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
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
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
              child: EmbedWebView(
                url: url,
                aspectRatio: 16 / 9,
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Native embed surface for the AnimeX player.
///
/// Android runs the provider embed inside an in-app WebView. A main-frame
/// load failure reports [onContentError] so callers can auto-advance to the
/// next server just like the web player.
class AnimeXPlayerFrame extends StatefulWidget {
  final String url;
  final double aspectRatio;
  final String referrerPolicy;
  final VoidCallback? onContentError;
  final void Function(VideasyProgress progress)? onProgress;

  /// In-place seek for our Megavid player; other providers ignore it.
  final int? seekSeconds;
  final int seekRequest;
  final AniSkipTimes? skipTimes;

  /// Destination token the player prints beside its next action (`EP 20`),
  /// or null when nothing follows (a film, or the last episode of the last
  /// season). The player only shows that action during the ending or the
  /// last 90 seconds. [nextIsSeason] switches the wording to "Next season".
  final String? nextToken;
  final bool nextIsSeason;
  final VoidCallback? onNextEpisode;
  final ValueChanged<String>? onAudioChanged;

  /// Fires when the embed changes episodes on its own (CineSrc
  /// auto-play or its built-in episode picker), reporting the TMDB
  /// season/episode it moved to. Mirrors the web frame's postMessage
  /// path; on native the event arrives through the `EverglowPlayer`
  /// JS channel instead.
  final void Function(int season, int episode)? onPlayerEpisodeChanged;

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
    this.onAudioChanged,
    this.onPlayerEpisodeChanged,
  });

  @override
  State<AnimeXPlayerFrame> createState() => _AnimeXPlayerFrameState();
}

class _AnimeXPlayerFrameState extends State<AnimeXPlayerFrame> {
  /// Hosts the anime servers are allowed to top-navigate to. Anything
  /// else (app-store pages, tiktok:// / youtube:// app-open intents,
  /// redirect farms) is the ad engine talking, so the WebView drops it.
  static const _allowedHosts = {
    'megaplay.buzz',
    'anixo.buzz',
    'megavid.buzz',
    'everglow-1c6db.web.app',
    'cinesrc.st',
    'everglow-stream.khentplaysmoba.workers.dev',
  };

  WebViewController? _controller;
  Timer? _loadTimer;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (isAnimeXProxyPlayerUrl(widget.url)) _loadOwnedPlayer();
  }

  @override
  void didUpdateWidget(covariant AnimeXPlayerFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _loadTimer?.cancel();
      _controller = null;
      _loaded = false;
      _failed = false;
      if (isAnimeXProxyPlayerUrl(widget.url)) _loadOwnedPlayer();
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

  Future<void> _loadOwnedPlayer() async {
    final url = widget.url;
    final controller = WebViewController();
    _controller = controller;
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);
      await controller.addJavaScriptChannel(
        'EverglowPlayer',
        onMessageReceived: (message) {
          if (!mounted ||
              _failed ||
              _controller != controller ||
              widget.url != url) {
            return;
          }
          if (message.message == 'animex-content-error') {
            _fail();
            return;
          }
          final progress = parseAnimeXProgress(
            animeXProxyOrigin,
            url,
            message.message,
          );
          if (progress != null) widget.onProgress?.call(progress);
        },
      );
      if (controller.platform is AndroidWebViewController) {
        final android = controller.platform as AndroidWebViewController;
        await android.setMediaPlaybackRequiresUserGesture(false);
        await android.setMixedContentMode(MixedContentMode.compatibilityMode);
        await android.setAllowFileAccess(false);
      }
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              !request.isMainFrame || request.url == url
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (loadedUrl) {
            if (!mounted || _controller != controller || loadedUrl != url) {
              return;
            }
            _loadTimer?.cancel();
            setState(() => _loaded = true);
            _sendSeek();
            _sendPlayerState();
          },
          onWebResourceError: (error) {
            if (_controller == controller && error.isForMainFrame == true) {
              _fail();
            }
          },
        ),
      );
      await controller.loadRequest(
        Uri.parse(url),
        headers: const {'Referer': 'https://everglow-1c6db.web.app'},
      );
      if (!mounted || _controller != controller || _loaded || _failed) return;
      _loadTimer = Timer(const Duration(seconds: 15), _fail);
    } catch (e) {
      Logger.e('AnimeX native player failed to load', error: e);
      if (_controller == controller) _fail();
    }
  }

  Future<void> _sendSeek() async {
    final seconds = widget.seekSeconds;
    final controller = _controller;
    if (!_loaded ||
        _failed ||
        controller == null ||
        seconds == null ||
        seconds < 0 ||
        !isAnimeXProxyPlayerUrl(widget.url)) {
      return;
    }
    try {
      // The owned top-level page accepts self messages only when the
      // native EverglowPlayer channel exists; browser parents still need
      // their exact app origin AND window.parent as the source.
      await controller.runJavaScript(
        'window.postMessage({type:"animex-seek",seconds:$seconds},'
        '"$animeXProxyOrigin");',
      );
    } catch (e) {
      Logger.e('AnimeX native player seek failed', error: e);
    }
  }

  /// Sends the opening/ending windows and the next-episode label. Sent on
  /// load and on every change, even with no skip times, so the player can
  /// clear a label that no longer applies.
  Future<void> _sendPlayerState() async {
    final controller = _controller;
    if (!_loaded ||
        _failed ||
        controller == null ||
        !isAnimeXProxyPlayerUrl(widget.url)) {
      return;
    }
    final op = widget.skipTimes?.opening;
    final ed = widget.skipTimes?.ending;
    final opJson = op != null ? '[${op.start},${op.end}]' : 'null';
    final edJson = ed != null ? '[${ed.start},${ed.end}]' : 'null';
    final next = widget.nextToken;
    final nextJson = next != null ? jsonEncode(next) : 'null';
    final kind = widget.nextIsSeason ? 'season' : 'episode';
    try {
      await controller.runJavaScript(
        'window.postMessage({type:"animex-player-state",op:$opJson,ed:$edJson,'
        'next:$nextJson,nextKind:"$kind"},"$animeXProxyOrigin");',
      );
    } catch (e) {
      Logger.e('AnimeX native player state failed', error: e);
    }
  }

  void _fail() {
    if (!mounted || _failed) return;
    _loadTimer?.cancel();
    setState(() => _failed = true);
    widget.onContentError?.call();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isAnimeXProxyPlayerUrl(widget.url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              if (!_failed && _controller != null)
                WebViewWidget(controller: _controller!),
              if (!_loaded && !_failed)
                const Center(child: CircularProgressIndicator()),
              if (_failed)
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _loaded = false;
                        _failed = false;
                      });
                      _loadOwnedPlayer();
                    },
                    child: const Text('This source couldn’t load — try again'),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return EmbedWebView(
      key: ValueKey(widget.url),
      url: widget.url,
      aspectRatio: widget.aspectRatio,
      borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
      onError: widget.onContentError,
      allowedHosts: _allowedHosts,
      onPlayerMessage: widget.onPlayerEpisodeChanged == null
          ? null
          : (raw) {
              final ep = EmbedWebView.parsePlayerEpisode(raw);
              if (ep != null) {
                widget.onPlayerEpisodeChanged?.call(ep.$1, ep.$2);
              }
            },
    );
  }
}
