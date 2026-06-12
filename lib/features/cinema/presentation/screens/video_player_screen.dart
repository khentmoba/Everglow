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
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    this.season,
    this.episode,
    required this.title,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;

  final List<Map<String, dynamic>> allVideoProviders = [
    {"name": "VidFast", "adPercentage": null, "movieUrl": "https://vidfast.pro/movie/", "tvUrl": "https://vidfast.pro/tv/"},
    {"name": "VixSrc", "adPercentage": null, "movieUrl": "https://vixsrc.to/movie/", "tvUrl": "https://vixsrc.to/tv/"},
    {"name": "VidLink", "adPercentage": null, "movieUrl": "https://vidlink.pro/movie/", "tvUrl": "https://vidlink.pro/tv/"},
    {"name": "AutoEmbed", "adPercentage": null, "movieUrl": "https://player.autoembed.co/embed/movie/", "tvUrl": "https://player.autoembed.co/embed/tv/"},
    {"name": "Videasy", "adPercentage": null, "movieUrl": "https://player.videasy.net/movie/", "tvUrl": "https://player.videasy.net/tv/"},
    {"name": "VidSrc", "adPercentage": 90, "movieUrl": "https://vidsrc.me/embed/movie?tmdb=", "tvUrl": "https://vidsrc.me/embed/tv?tmdb="},
    {"name": "VidKing", "adPercentage": 90, "movieUrl": "https://www.vidking.net/embed/movie/", "tvUrl": "https://www.vidking.net/embed/tv/"},
    {"name": "SuperEmbed", "adPercentage": 85, "movieUrl": "https://multiembed.mov/?video_id=", "tvUrl": "https://multiembed.mov/?video_id="},
    {"name": "111Movies", "adPercentage": 80, "movieUrl": "https://www.111movies.com/movie/", "tvUrl": "https://www.111movies.com/tv/"},
    {"name": "Vidzee", "adPercentage": 80, "movieUrl": "https://player.vidzee.wtf/embed/movie/", "tvUrl": "https://player.vidzee.wtf/embed/tv/"},
    {"name": "VidRock", "adPercentage": 75, "movieUrl": "https://vidrock.net/movie/", "tvUrl": "https://vidrock.net/tv/"},
  ];

  late Map<String, dynamic> selectedProvider;

  @override
  void initState() {
    super.initState();
    selectedProvider = allVideoProviders[0];

    _viewType =
        'everglow-cinema-player-${widget.tmdbId}-${widget.mediaType}-${widget.season ?? 0}-${widget.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..src = _getPlayerUrl(selectedProvider)
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; clipboard-write'
      ..allowFullscreen = true
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no')
      ..setAttribute('sandbox',
          'allow-scripts allow-same-origin allow-forms allow-presentation allow-orientation-lock');
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

    if (isTv) {
      if (tvBase.contains('vidsrc.me')) {
        return '$tvBase${widget.tmdbId}&season=$seasonNum&episode=$epNum';
      } else if (tvBase.contains('multiembed.mov')) {
        return '$tvBase${widget.tmdbId}&tmdb=1&s=$seasonNum&e=$epNum';
      } else if (tvBase.contains('embed') && !tvBase.endsWith('/')) {
        return '$tvBase${widget.tmdbId}&season=$seasonNum&episode=$epNum';
      } else {
        final separator = tvBase.endsWith('/') ? '' : '/';
        return '$tvBase$separator${widget.tmdbId}/$seasonNum/$epNum';
      }
    } else {
      if (movieBase.contains('multiembed.mov')) {
        return '$movieBase${widget.tmdbId}&tmdb=1';
      }
      final separator = movieBase.endsWith('/') || movieBase.contains('?') || movieBase.contains('=') ? '' : '/';
      return '$movieBase$separator${widget.tmdbId}';
    }
  }

  void _changeProvider(Map<String, dynamic> newProvider) {
    setState(() {
      selectedProvider = newProvider;
      _isLoading = true;
    });
    _iframe.src = _getPlayerUrl(selectedProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: HtmlElementView(viewType: _viewType),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRose),
            ),

          Positioned(
            top: 15,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
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

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            const Shadow(blurRadius: 6, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: selectedProvider,
                              dropdownColor: Colors.grey[900],
                              isExpanded: true,
                              items: allVideoProviders.map((provider) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: provider,
                                  child: Text(
                                    provider["name"],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue == null || newValue == selectedProvider) return;
                                _changeProvider(newValue);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selectedProvider["adPercentage"] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              "it might have ${selectedProvider["adPercentage"]}% chance of ads baby",
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
