import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';

enum PlayerSource { vidLink, autoEmbed, videasy }

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
  PlayerSource _currentSource = PlayerSource.vidLink;
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  // List of known ad network keywords to block
  final List<String> _adKeywords = [
    'popads.net',
    'exoclick.com',
    'juicyads.com',
    'doubleclick.net',
    'adserver',
    'adsystem',
    'popcash',
    'onclickads',
    'adsterra',
    'yepads',
    'propellerads',
    'a.shifen.com',
    'google-analytics',
    'googletagmanager',
    'adservice',
    'adtracker',
    'popunder',
    'bet365',
    '1xbet',
    'vidoza',
    'doodstream',
    'fembed',
    'streamtape',
  ];

  @override
  void initState() {
    super.initState();
    // Force landscape mode for immersive player experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide status bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Reset screen orientation back to normal on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _getPlayerUrl() {
    final isTv = widget.mediaType == 'tv';
    final seasonNum = widget.season ?? 1;
    final epNum = widget.episode ?? 1;

    switch (_currentSource) {
      case PlayerSource.vidLink:
        return isTv
            ? 'https://vidlink.pro/tv/${widget.tmdbId}/$seasonNum/$epNum'
            : 'https://vidlink.pro/movie/${widget.tmdbId}';
      case PlayerSource.autoEmbed:
        return isTv
            ? 'https://player.autoembed.cc/embed/tv/${widget.tmdbId}/$seasonNum/$epNum'
            : 'https://player.autoembed.cc/embed/movie/${widget.tmdbId}';
      case PlayerSource.videasy:
        return isTv
            ? 'https://player.videasy.net/tv/${widget.tmdbId}/$seasonNum/$epNum'
            : 'https://player.videasy.net/movie/${widget.tmdbId}';
    }
  }

  String _getSourceLabel(PlayerSource source) {
    switch (source) {
      case PlayerSource.vidLink:
        return 'VidLink (Default)';
      case PlayerSource.autoEmbed:
        return 'AutoEmbed';
      case PlayerSource.videasy:
        return 'Videasy';
    }
  }

  bool _isAdUrl(String url) {
    final lowerUrl = url.toLowerCase();
    for (final keyword in _adKeywords) {
      if (lowerUrl.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  // Verify if the host matches the expected streaming provider host
  bool _isAllowedHost(String? urlString) {
    if (urlString == null) return false;
    final uri = Uri.tryParse(urlString);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();

    // Check if loading the core streaming websites
    if (host.contains('vidlink.pro') ||
        host.contains('autoembed.cc') ||
        host.contains('videasy.net')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final playerUrl = _getPlayerUrl();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen InAppWebView
          Positioned.fill(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(playerUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllowFullscreen: true,
                // Block popups and multiwindow hijacks natively
                supportMultipleWindows: false,
                javaScriptCanOpenWindowsAutomatically: false,
                useShouldOverrideUrlLoading: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() => _isLoading = true);
              },
              onLoadStop: (controller, url) {
                setState(() => _isLoading = false);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final requestUrl = navigationAction.request.url?.toString();
                if (requestUrl == null) return NavigationActionPolicy.ALLOW;

                // 1. Intercept known ad domains
                if (_isAdUrl(requestUrl)) {
                  print("Native Adblocker blocked: $requestUrl");
                  return NavigationActionPolicy.CANCEL;
                }

                // 2. Prevent Top-Level Redirection hijacks:
                // If the mainframe attempts to load an untrusted external page, cancel it.
                if (navigationAction.isForMainFrame) {
                  // Allow the initial load and any relative/subdomain loads of the player itself
                  if (!_isAllowedHost(requestUrl)) {
                    print("Top-level mainframe redirection block: $requestUrl");
                    return NavigationActionPolicy.CANCEL;
                  }
                }

                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),

          // Loading Indicator Overlay
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRose),
            ),

          // Custom Transparent Bar overlay (Back & Source switcher)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Back',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Title of the item playing
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            const Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Source Switcher Button
                  PopupMenuButton<PlayerSource>(
                    onSelected: (source) {
                      setState(() {
                        _currentSource = source;
                        _isLoading = true;
                      });
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(_getPlayerUrl())),
                      );
                    },
                    itemBuilder: (context) => PlayerSource.values.map((src) {
                      return PopupMenuItem<PlayerSource>(
                        value: src,
                        child: Text(
                          _getSourceLabel(src),
                          style: GoogleFonts.outfit(
                            fontWeight: _currentSource == src ? FontWeight.bold : FontWeight.normal,
                            color: _currentSource == src ? AppTheme.deepRose : Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                    color: AppTheme.velvet,
                    offset: const Offset(0, 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.roseQuartz.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _getSourceLabel(_currentSource),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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
