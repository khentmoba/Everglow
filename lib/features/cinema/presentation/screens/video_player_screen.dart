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
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;

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
  /// when the primary is blocked or down. We avoid providers that need
  /// TMDB ids for anime (most general embeds) because Jikan doesn't
  /// hand us a TMDB cross-reference.
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

  /// Called when the user picks a different provider from the dropdown.
  /// Re-points the iframe at the new URL and flips the loader back on
  /// until the new page's `load` event fires.
  void _selectProvider(VideoProvider provider) {
    if (!widget.isAnime) return; // non-anime is locked to Videasy
    if (provider.id == _selectedProvider.id) return;
    setState(() {
      _selectedProvider = provider;
      _isLoading = true;
    });
    _iframe.src = _buildPlayerUrl(provider);
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

  /// The id we hand to the embed. For anime items this is the MAL id
  /// (either passed via [widget.malId] or, for backwards compat, the
  /// `tmdbId` slot which Jikan's mapper reuses for MAL ids). For
  /// non-anime items it's the TMDB id.
  int get _externalId => widget.isAnime
      ? (widget.malId ?? widget.tmdbId)
      : widget.tmdbId;

  String _buildPlayerUrl(VideoProvider provider) {
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
}

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
