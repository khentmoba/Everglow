import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/core/theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final int? season;
  final int? episode;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.season,
    this.episode,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;

  final Map<String, dynamic> selectedProvider = const {
    "name": "Videasy",
    "tier": "top",
    "adPercentage": null,
    "movieUrl": "https://player.videasy.net/movie/",
    "tvUrl": "https://player.videasy.net/tv/"
  };

  @override
  void initState() {
    super.initState();

    _viewType =
        'everglow-cinema-player-${widget.tmdbId}-${widget.mediaType}-${widget.season ?? 0}-${widget.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..src = _getPlayerUrl(selectedProvider)
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; clipboard-write'
      ..allowFullscreen = true
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no')
      ..removeAttribute('sandbox');
    _iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = '#000';

    _onLoadListener = ((web.Event _) {
      if (mounted) setState(() => _isLoading = false);
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (_onLoadListener != null) {
      _iframe.removeEventListener('load', _onLoadListener);
    }
    _iframe.src = 'about:blank';

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _getPlayerUrl(Map<String, dynamic> provider) {
    final isTv = widget.mediaType == 'tv';
    final seasonNum = widget.season ?? 1;
    final epNum = widget.episode ?? 1;
    final movieBase = provider['movieUrl'] as String;
    final tvBase = provider['tvUrl'] as String;
    final isVideasy =
        movieBase.contains('videasy') || tvBase.contains('videasy');

    if (isTv) {
      if (tvBase.contains('vidsrc.me')) {
        return '$tvBase${widget.tmdbId}&season=$seasonNum&episode=$epNum';
      } else if (tvBase.contains('multiembed.mov')) {
        return '$tvBase${widget.tmdbId}&tmdb=1&s=$seasonNum&e=$epNum';
      } else if (tvBase.contains('embed') && !tvBase.endsWith('/')) {
        return '$tvBase${widget.tmdbId}&season=$seasonNum&episode=$epNum';
      } else {
        final separator = tvBase.endsWith('/') ? '' : '/';
        final base = '$tvBase$separator${widget.tmdbId}/$seasonNum/$epNum';
        return isVideasy
            ? '$base?autoplay=true&nextButton=true&episodeSelector=true'
            : base;
      }
    } else {
      if (movieBase.contains('multiembed.mov')) {
        return '$movieBase${widget.tmdbId}&tmdb=1';
      }
      final separator = movieBase.endsWith('/') || movieBase.contains('?') || movieBase.contains('=') ? '' : '/';
      final base = '$movieBase$separator${widget.tmdbId}';
      return isVideasy ? '$base?autoplay=true' : base;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top control & details bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[900]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Back',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.deepRose.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.deepRose,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Videasy Server",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Player iframe area
            Expanded(
              child: Stack(
                children: [
                  HtmlElementView(viewType: _viewType),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: AppTheme.deepRose),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
