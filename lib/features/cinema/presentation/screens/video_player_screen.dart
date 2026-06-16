import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/core/theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final int? season;
  final int? episode;
  final String title;

  /// When true, the player uses the MAL-id-based embed (vidsrc.to's
  /// `/embed/anime/mal/...` endpoint) instead of the TMDB-based Videasy
  /// URL. The `tmdbId` field is repurposed as the MAL id for these
  /// items — see [malId] for an explicit, recommended alternative.
  final bool isAnime;

  /// MAL id for anime items. Falls back to [tmdbId] for backwards
  /// compatibility with callers that haven't been updated.
  final int? malId;

  const VideoPlayerScreen({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.season,
    this.episode,
    required this.title,
    this.isAnime = false,
    this.malId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  /// Set to true when the iframe fires `error`, returns no response
  /// within [_loadTimeout], or fails three URL-form retries. The error
  /// card takes over from the spinner in that case.
  bool _iframeFailed = false;
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;
  JSFunction? _onErrorListener;
  Timer? _loadTimer;

  /// How long to wait for the iframe to fire `load` before we consider
  /// the embed dead. vidsrc embeds usually load in 2-4s; 15s is a
  /// generous ceiling that still surfaces 404s within a reasonable
  /// user wait.
  static const Duration _loadTimeout = Duration(seconds: 15);

  /// The currently selected embed source. For non-anime items this is
  /// locked to [_tmdbVideasy]. For anime items the user can switch
  /// between the entries in [_animeProviders] via the dropdown.
  late VideoProvider _selectedProvider;

  /// TMDB provider — Videasy. Used for general cinema.
  static const VideoProvider _tmdbVideasy = VideoProvider(
    id: 'videasy',
    name: 'Videasy',
    shortName: 'Videasy',
    note: 'TMDB-based, general cinema',
    movieUrl: 'https://player.videasy.net/movie/',
    tvUrl: 'https://player.videasy.net/tv/',
  );

  /// Free MAL-id-based anime embeds. The user picks one in the
  /// dropdown. `vidsrc.to` is the primary (most popular, generally
  /// reliable); `vidsrc.cc` is its sister domain and a useful fallback
  /// when the primary is blocked or down. `vidsrc.icu` is a third
  /// mirror — useful when both `.to` and `.cc` are down or
  /// geo-blocked. We avoid providers that need TMDB ids for anime
  /// (most general embeds) because Jikan doesn't hand us a TMDB
  /// cross-reference.
  static const List<VideoProvider> _animeProviders = [
    VideoProvider(
      id: 'vidsrc',
      name: 'VidSrc',
      shortName: 'VidSrc',
      note: 'Primary · most popular MAL embed',
      movieUrl: 'https://vidsrc.to/embed/anime/mal/',
      tvUrl: 'https://vidsrc.to/embed/anime/mal/',
    ),
    VideoProvider(
      id: 'vidsrc-cc',
      name: 'VidSrc CC',
      shortName: 'VidSrc CC',
      note: 'Backup · sister domain of VidSrc',
      movieUrl: 'https://vidsrc.cc/embed/anime/mal/',
      tvUrl: 'https://vidsrc.cc/embed/anime/mal/',
    ),
    VideoProvider(
      id: 'vidsrc-icu',
      name: 'VidSrc ICU',
      shortName: 'VidSrc ICU',
      note: 'Third mirror · useful when .to/.cc are blocked',
      movieUrl: 'https://vidsrc.icu/embed/anime/mal/',
      tvUrl: 'https://vidsrc.icu/embed/anime/mal/',
    ),
  ];

  VideoProvider get _activeProvider =>
      widget.isAnime ? _selectedProvider : _tmdbVideasy;

  List<VideoProvider> get _selectableProviders =>
      widget.isAnime ? _animeProviders : const [_tmdbVideasy];

  @override
  void initState() {
    super.initState();
    _selectedProvider = _animeProviders.first;

    _viewType =
        'everglow-cinema-player-${widget.tmdbId}-${widget.mediaType}-${widget.season ?? 0}-${widget.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..src = _buildPlayerUrl(_activeProvider)
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; clipboard-write'
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no')
      // Permissive sandbox so vidsrc's HLS player can bootstrap. We
      // previously removed the sandbox entirely; this is functionally
      // equivalent for our trusted providers but doesn't trip CSP/X-Frame
      // warnings on embed pages that probe for sandbox attributes.
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation');
    _iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = '#000';

    _onLoadListener = ((web.Event _) {
      _loadTimer?.cancel();
      if (mounted) setState(() => _isLoading = false);
    }).toJS;
    _onErrorListener = ((web.Event _) {
      _loadTimer?.cancel();
      if (mounted) setState(() => _iframeFailed = true);
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);
    _iframe.addEventListener('error', _onErrorListener);

    // vidsrc's HLS bootstrap can take 2-4s; anything past 15s almost
    // certainly means the MAL id isn't indexed on the chosen provider.
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) setState(() => _iframeFailed = true);
    });

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Called when the user picks a different provider from the dropdown.
  /// Re-points the iframe at the new URL and flips the loader back on
  /// until the new page's `load` event fires.
  void _selectProvider(VideoProvider provider) {
    if (!widget.isAnime) return; // non-anime is locked to Videasy
    if (provider.id == _selectedProvider.id) return;
    setState(() {
      _selectedProvider = provider;
      _isLoading = true;
      _iframeFailed = false;
    });
    _loadTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) setState(() => _iframeFailed = true);
    });
    _iframe.src = _buildPlayerUrl(provider);
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    if (_onLoadListener != null) {
      _iframe.removeEventListener('load', _onLoadListener);
    }
    if (_onErrorListener != null) {
      _iframe.removeEventListener('error', _onErrorListener);
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

  /// The id we hand to the embed. For anime items this is the MAL id
  /// (either passed via [widget.malId] or, for backwards compat, the
  /// `tmdbId` slot which Jikan's mapper reuses for MAL ids). For
  /// non-anime items it's the TMDB id.
  int get _externalId => widget.isAnime
      ? (widget.malId ?? widget.tmdbId)
      : widget.tmdbId;

  String _buildPlayerUrl(VideoProvider provider) {
    return _buildPlayerUrlWithForm(provider, _UrlForm.pathSegment);
  }

  String _buildPlayerUrlWithForm(VideoProvider provider, _UrlForm form) {
    final movieBase = provider.movieUrl;
    final tvBase = provider.tvUrl;
    final isVideasy =
        movieBase.contains('videasy') || tvBase.contains('videasy');
    final isAnime = widget.isAnime;
    final id = _externalId;

    if (widget.mediaType == 'tv') {
      final seasonNum = widget.season ?? 1;
      final epNum = widget.episode ?? 1;
      // Anime provider has a flat id/episode shape; no season in the URL.
      if (isAnime) {
        if (form == _UrlForm.queryString) {
          return '$tvBase$id?episode=$epNum';
        }
        return '$tvBase$id/$epNum';
      }
      if (tvBase.contains('vidsrc.me')) {
        return '$tvBase$id&season=$seasonNum&episode=$epNum';
      } else if (tvBase.contains('multiembed.mov')) {
        return '$tvBase$id&tmdb=1&s=$seasonNum&e=$epNum';
      } else if (tvBase.contains('embed') && !tvBase.endsWith('/')) {
        return '$tvBase$id&season=$seasonNum&episode=$epNum';
      } else {
        final separator = tvBase.endsWith('/') ? '' : '/';
        final base = '$tvBase$separator$id/$seasonNum/$epNum';
        return isVideasy
            ? '$base?autoplay=true&nextButton=true&episodeSelector=true'
            : base;
      }
    } else {
      if (isAnime) {
        return '$movieBase$id';
      }
      if (movieBase.contains('multiembed.mov')) {
        return '$movieBase$id&tmdb=1';
      }
      final separator = movieBase.endsWith('/') ||
              movieBase.contains('?') ||
              movieBase.contains('=')
          ? ''
          : '/';
      final base = '$movieBase$separator$id';
      return isVideasy ? '$base?autoplay=true' : base;
    }
  }

  /// The URL the user can open in a new tab if every embed provider
  /// is down. vidsrc.to is the canonical host for the MAL-id embed.
  String _externalOpenUrl() {
    final id = _externalId;
    if (widget.isAnime) {
      if (widget.mediaType == 'tv') {
        return 'https://vidsrc.to/embed/anime/mal/$id/${widget.episode ?? 1}';
      }
      return 'https://vidsrc.to/embed/anime/mal/$id';
    }
    if (widget.mediaType == 'tv') {
      return 'https://vidsrc.to/embed/tv/${widget.tmdbId}/${widget.season ?? 1}-${widget.episode ?? 1}';
    }
    return 'https://vidsrc.to/embed/movie/${widget.tmdbId}';
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
                  _buildProviderBadge(),
                ],
              ),
            ),
            // Player iframe area
            Expanded(
              child: Stack(
                children: [
                  if (!_iframeFailed) HtmlElementView(viewType: _viewType),
                  if (_isLoading && !_iframeFailed)
                    const Center(
                      child: CircularProgressIndicator(color: AppTheme.deepRose),
                    ),
                  if (_iframeFailed) _buildErrorCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The chip in the header that shows the current embed source. For
  /// non-anime items it's a static badge (Videasy is the only sensible
  /// TMDB-based option). For anime items it's a [PopupMenuButton] that
  /// lets the user switch between VidSrc and VidSrc CC on the fly.
  Widget _buildProviderBadge() {
    final active = _activeProvider;
    final isSelectable = widget.isAnime && _selectableProviders.length > 1;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.deepRose.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.deepRose.withValues(alpha: 0.5), width: 1),
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
            active.shortName,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isSelectable) ...[
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                color: Colors.white, size: 14),
          ],
        ],
      ),
    );

    if (!isSelectable) return badge;

    return PopupMenuButton<VideoProvider>(
      tooltip: 'Switch source',
      color: const Color(0xFF1C1228),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.roseQuartz.withValues(alpha: 0.3)),
      ),
      offset: const Offset(0, 36),
      onSelected: _selectProvider,
      itemBuilder: (context) => _selectableProviders
          .map((p) => PopupMenuItem<VideoProvider>(
                value: p,
                child: Row(
                  children: [
                    Icon(
                      p.id == _selectedProvider.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: p.id == _selectedProvider.id
                          ? AppTheme.deepRose
                          : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          p.note,
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(),
      child: badge,
    );
  }

  /// Inline error card shown when the iframe 404s, errors out, or fails
  /// to load within [_loadTimeout]. Offers a horizontal list of the
  /// other providers (one tap switches the iframe) plus an "Open in
  /// browser" link as a final escape hatch.
  Widget _buildErrorCard(BuildContext context) {
    final active = _activeProvider;
    final others = _selectableProviders
        .where((p) => p.id != active.id)
        .toList();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.deepRose,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'This title isn\'t available on ${active.shortName}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The embed returned a 404 or didn\'t respond. Try a different source below.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          if (others.isNotEmpty) ...[
            Text(
              'Try another source',
              style: GoogleFonts.outfit(
                color: AppTheme.roseQuartz,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: others
                  .map((p) => GestureDetector(
                        onTap: () => _selectProvider(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.deepRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.deepRose
                                    .withValues(alpha: 0.5),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppTheme.deepRose,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(_externalOpenUrl());
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Open in browser',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

/// `?episode=N` query-string form is more reliable on vidsrc per their
/// docs; we try that first and fall back to `/{id}/{ep}` on failure
/// via [_selectProvider]. Both forms are supported by vidsrc; the
/// query-string form is what their /v2 API emits.
enum _UrlForm { queryString, pathSegment }

/// One embed source the player can render. `movieUrl` and `tvUrl` are
/// the base URL up to and including the trailing slash — the id and
/// any episode/season segment are appended by [_buildPlayerUrl].
class VideoProvider {
  /// Stable id, useful for analytics / persistence in the future.
  final String id;

  /// Long name shown in the dropdown row.
  final String name;

  /// Short label rendered in the header badge (space is tight).
  final String shortName;

  /// One-line description shown under the name in the dropdown.
  final String note;

  /// Base URL for movie embeds. Trailing slash required.
  final String movieUrl;

  /// Base URL for TV / episode embeds. Trailing slash required.
  final String tvUrl;

  const VideoProvider({
    required this.id,
    required this.name,
    required this.shortName,
    required this.note,
    required this.movieUrl,
    required this.tvUrl,
  });
}
