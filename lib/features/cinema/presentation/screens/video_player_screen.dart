import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
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
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  final List<Map<String, dynamic>> allVideoProviders = [
    {"name": "VidLink", "adPercentage": null, "movieUrl": "https://vidlink.pro/movie/", "tvUrl": "https://vidlink.pro/tv/"},
    {"name": "AutoEmbed", "adPercentage": null, "movieUrl": "https://player.autoembed.cc/embed/movie/", "tvUrl": "https://player.autoembed.cc/embed/tv/"},
    {"name": "Videasy", "adPercentage": null, "movieUrl": "https://player.videasy.net/movie/", "tvUrl": "https://player.videasy.net/tv/"},
    {"name": "VidSrc", "adPercentage": 90, "movieUrl": "https://vidsrc.me/embed/movie?tmdb=", "tvUrl": "https://vidsrc.me/embed/tv?tmdb="},
    {"name": "VidKing", "adPercentage": 90, "movieUrl": "https://vidking.link/movie/", "tvUrl": "https://vidking.link/tv/"},
    {"name": "VidSrc CC", "adPercentage": 90, "movieUrl": "https://vidsrc.cc/v2/embed/movie/", "tvUrl": "https://vidsrc.cc/v2/embed/tv/"},
    {"name": "SuperEmbed", "adPercentage": 85, "movieUrl": "https://multiembed.mov/directstream.php?video_id=", "tvUrl": "https://multiembed.mov/directstream.php?video_id="},
    {"name": "VsEmbed", "adPercentage": 85, "movieUrl": "https://vsembed.cc/movie/", "tvUrl": "https://vsembed.cc/tv/"},
    {"name": "111Movies", "adPercentage": 80, "movieUrl": "https://111movies.com/movie/", "tvUrl": "https://111movies.com/tv/"},
    {"name": "Vidify", "adPercentage": 80, "movieUrl": "https://vidify.org/embed/", "tvUrl": "https://vidify.org/embed/"},
    {"name": "Vidzee", "adPercentage": 80, "movieUrl": "https://vidzee.vip/embed/movie/", "tvUrl": "https://vidzee.vip/embed/tv/"},
    {"name": "Filmu", "adPercentage": 80, "movieUrl": "https://filmu.xyz/embed/", "tvUrl": "https://filmu.xyz/embed/"},
    {"name": "Vares Player", "adPercentage": 80, "movieUrl": "https://vares.xyz/movie/", "tvUrl": "https://vares.xyz/tv/"},
    {"name": "VidFast", "adPercentage": 75, "movieUrl": "https://vidfast.pro/movie/", "tvUrl": "https://vidfast.pro/tv/"},
    {"name": "VidRock", "adPercentage": 75, "movieUrl": "https://vidrock.one/embed/", "tvUrl": "https://vidrock.one/embed/"},
    {"name": "VixSrc", "adPercentage": 75, "movieUrl": "https://vixsrc.xyz/embed/", "tvUrl": "https://vixsrc.xyz/embed/"},
    {"name": "VidGod", "adPercentage": 75, "movieUrl": "https://vidgod.xyz/embed/", "tvUrl": "https://vidgod.xyz/embed/"},
  ];

  late Map<String, dynamic> selectedProvider;

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
    'onclick',
    'onclickperformance',
  ];

  @override
  void initState() {
    super.initState();
    selectedProvider = allVideoProviders[0];
    
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
        return '$tvBase${widget.tmdbId}&s=$seasonNum&e=$epNum';
      } else if (tvBase.contains('embed') && !tvBase.endsWith('/')) {
        return '$tvBase${widget.tmdbId}&season=$seasonNum&episode=$epNum';
      } else {
        final separator = tvBase.endsWith('/') ? '' : '/';
        return '$tvBase$separator${widget.tmdbId}/$seasonNum/$epNum';
      }
    } else {
      final separator = movieBase.endsWith('/') || movieBase.contains('?') || movieBase.contains('=') ? '' : '/';
      return '$movieBase$separator${widget.tmdbId}';
    }
  }

  String _getSandboxBypassScript() {
    return '''
    (function() {
      if (window.__sandboxBypassApplied) return;
      window.__sandboxBypassApplied = true;

      function applyOverrides() {
        try {
          Object.defineProperty(window, 'frameElement', {
            get: function() { return null; },
            configurable: true
          });
        } catch(e) {}
        try {
          var desc = Object.getOwnPropertyDescriptor(Document.prototype, 'domain');
          if (desc && desc.set) {
            Object.defineProperty(Document.prototype, 'domain', {
              get: function() { return window.location.hostname; },
              set: function() { return true; },
              configurable: true
            });
          }
        } catch(e) {}
        try {
          if (navigator.plugins && typeof navigator.plugins.namedItem !== 'function') {
            Object.defineProperty(navigator, 'plugins', {
              get: function() {
                var list = [1];
                list.namedItem = function(name) {
                  if (name === 'Chrome PDF Viewer') {
                    return { name: 'Chrome PDF Viewer', filename: 'internal-pdf-viewer', description: 'Portable Document Format', length: 1 };
                  }
                  return null;
                };
                list.item = function(i) { return null; };
                list.refresh = function() {};
                return list;
              },
              configurable: true
            });
          } else if (navigator.plugins && !navigator.plugins.namedItem('Chrome PDF Viewer')) {
            try {
              var plugins = navigator.plugins;
              var fake = document.createElement('embed');
              fake.type = 'application/pdf';
              if (plugins.refresh) plugins.refresh();
            } catch(e) {}
          }
        } catch(e) {}
      }

      applyOverrides();

      setInterval(applyOverrides, 2000);

      try {
        var observer = new MutationObserver(function(mutations) {
          for (var i = 0; i < mutations.length; i++) {
            var added = mutations[i].addedNodes;
            for (var j = 0; j < added.length; j++) {
              if (added[j].nodeType === 1) {
                var text = added[j].textContent || '';
                if (text.indexOf('Please Disable Sandbox') !== -1 || text.indexOf('Sandboxed iframe') !== -1) {
                  added[j].remove();
                }
              }
            }
          }
          var h1s = document.querySelectorAll('h1');
          for (var k = 0; k < h1s.length; k++) {
            if ((h1s[k].textContent || '').indexOf('Please Disable Sandbox') !== -1) {
              h1s[k].parentElement && h1s[k].parentElement.remove();
            }
          }
        });
        observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
      } catch(e) {}
    })();
    ''';
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

  bool _isAllowedHost(String? urlString) {
    if (urlString == null) return false;
    final uri = Uri.tryParse(urlString);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();

    // Check if loading one of the providers
    for (var provider in allVideoProviders) {
      final movieUrl = provider['movieUrl'] as String;
      final providerUri = Uri.tryParse(movieUrl);
      if (providerUri != null && host.contains(providerUri.host.toLowerCase())) {
        return true;
      }
    }

    // Always allow common trusted/CDN domains
    if (host.contains('vidlink.pro') ||
        host.contains('autoembed.cc') ||
        host.contains('videasy.net') ||
        host.contains('vidsrc.xyz') ||
        host.contains('vidsrc.stream') ||
        host.contains('vidsrc.pm') ||
        host.contains('filemoon') ||
        host.contains('vidplay') ||
        host.contains('mycloud') ||
        host.contains('cloudflare') ||
        host.contains('google') ||
        host.contains('tmdb')) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final playerUrl = _getPlayerUrl(selectedProvider);

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
                domStorageEnabled: true, // Enables local storage to avoid sandbox exceptions
                databaseEnabled: true, // Enables database storage to avoid sandbox exceptions
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllowFullscreen: true,
                supportMultipleWindows: false,
                javaScriptCanOpenWindowsAutomatically: false,
                useShouldOverrideUrlLoading: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) async {
                setState(() => _isLoading = true);
                await controller.evaluateJavascript(source: _getSandboxBypassScript());
              },
              onLoadStop: (controller, url) async {
                await controller.evaluateJavascript(source: _getSandboxBypassScript());
                setState(() => _isLoading = false);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final requestUrl = navigationAction.request.url?.toString();
                if (requestUrl == null) return NavigationActionPolicy.ALLOW;

                // 1. Block ad networks
                if (_isAdUrl(requestUrl)) {
                  print("Ad Blocked: $requestUrl");
                  return NavigationActionPolicy.CANCEL;
                }

                // 2. Prevent top-level mainframe redirection to untrusted domains
                if (navigationAction.isForMainFrame) {
                  if (!_isAllowedHost(requestUrl)) {
                    print("Redirection blocked on main frame: $requestUrl");
                    return NavigationActionPolicy.CANCEL;
                  }
                }

                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),

          // Loading Indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.deepRose),
            ),

          // Back button, title overlay & provider dropdown UI
          Positioned(
            top: 15,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
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

                  // Title of Video
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

                  // Embedded Dropdown and Conditional Warning Block
                  Container(
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
                                setState(() {
                                  selectedProvider = newValue!;
                                  _isLoading = true;
                                });
                                // Trigger WebView controller source string reload
                                _webViewController?.loadUrl(
                                  urlRequest: URLRequest(url: WebUri(_getPlayerUrl(selectedProvider))),
                                );
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
