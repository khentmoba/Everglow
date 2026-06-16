import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/services/ani_zip_service.dart';

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
  /// locked to [_tmdbVideasy]. For anime items it's also locked to
  /// Videasy once we've resolved the MAL→TMDB id; if the id can't be
  /// resolved the provider list shows an empty state and the error
  /// card is what the user sees.
  late VideoProvider _selectedProvider;

  /// TMDB provider — Videasy. Used for general cinema AND anime (after
  /// we resolve the MAL id to a TMDB id via ani.zip). The old MAL-id
  /// anime embeds were dropped by vidsrc (see commit history: their
  /// FAQ explicitly states they don't support anime), so we hand
  /// every anime that has a TMDB cross-reference off to Videasy on
  /// the same shape as non-anime content.
  static const VideoProvider _tmdbVideasy = VideoProvider(
    id: 'videasy',
    name: 'Videasy',
    shortName: 'Videasy',
    note: 'TMDB-based, general cinema',
    movieUrl: 'https://player.videasy.net/movie/',
    tvUrl: 'https://player.videasy.net/tv/',
  );

  /// Anime used to offer three VidSrc mirrors here. vidsrc.to
  /// officially removed anime support (their FAQ: "Currently we do
  /// not support anime"), and the .cc / .icu mirrors were never
  /// stable for anime either. The single-provider setup is correct
  /// now that we resolve MAL→TMDB and reuse the non-anime Videasy
  /// player. Keeping the [_animeProviders] slot around as an empty
  /// list so the dropdown code path still has something to iterate
  /// when (eventually) we want to re-introduce a fallback.
  static const List<VideoProvider> _animeProviders = [];

  VideoProvider get _activeProvider =>
      widget.isAnime ? _selectedProvider : _tmdbVideasy;

  List<VideoProvider> get _selectableProviders =>
      widget.isAnime ? _animeProviders : const [_tmdbVideasy];

  @override
  void initState() {
    super.initState();
    _selectedProvider = _tmdbVideasy;

    _viewType =
        'everglow-cinema-player-${widget.tmdbId}-${widget.mediaType}-${widget.season ?? 0}-${widget.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; clipboard-write'
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no');
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

    // For anime we don't have a TMDB id on the MediaItem — the slot
    // holds the MAL id. Resolve MAL→TMDB via ani.zip, then set the
    // iframe's src once. If the lookup fails (no cross-reference
    // exists) we land in the error card and offer external links.
    if (widget.isAnime) {
      _bootstrapAnime();
    } else {
      _iframe.src = _buildPlayerUrl(_activeProvider);
    }

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Anime bootstrap: look up the TMDB id for the MAL id, then point
  /// the iframe at the same Videasy player non-anime content uses.
  /// On lookup failure the iframe is left at `about:blank`, the load
  /// timer fires after [_loadTimeout], and the user sees the error
  /// card with "Open in browser" / "Watch on external site" actions.
  Future<void> _bootstrapAnime() async {
    final malId = widget.malId ?? widget.tmdbId;
    final tmdbId = await AniZipService().fetchTmdbId(malId);
    if (!mounted) return;
    if (tmdbId == null) {
      // No TMDB cross-reference — show the error card. We deliberately
      // don't leave the user on a blank black screen.
      setState(() => _iframeFailed = true);
      _loadTimer?.cancel();
      return;
    }
    setState(() {
      _externalTmdbId = tmdbId;
    });
    _iframe.src = _buildPlayerUrl(_activeProvider);
  }

  /// Called when the user picks a different provider from the dropdown.
  /// Re-points the iframe at the new URL and flips the loader back on
  /// until the new page's `load` event fires.
  ///
  /// Both anime and non-anime are locked to a single provider right
  /// now (Videasy for both, after the MAL→TMDB resolution for anime).
  /// The method is kept as a no-op-friendly stub so future providers
  /// can be dropped in without rewiring the header chip.
  void _selectProvider(VideoProvider provider) {
    if (_selectableProviders.length <= 1) return;
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

  /// The TMDB id we resolved from the MAL id for anime playback.
  /// Populated by [_bootstrapAnime] on init; null when the lookup
  /// failed or the item isn't anime. The URL builder uses this so
  /// anime hands the same Videasy URL off as non-anime.
  int? _externalTmdbId;

  /// Resolved TMDB id for the active item. Non-anime: the widget's
  /// TMDB id. Anime: the TMDB id we looked up via ani.zip, or null
  /// when the lookup failed (the error card takes over in that case).
  int? get _activeTmdbId => widget.isAnime ? _externalTmdbId : widget.tmdbId;

  String _buildPlayerUrl(VideoProvider provider) {
    // Default to the query-string form (the v2 shape) which is what
    // Videasy emits and what their docs recommend. The path-segment
    // form is preserved as a future fallback for any non-Videasy
    // provider that doesn't accept `?episode=N`.
    final form = _UrlForm.queryString;
    return _buildPlayerUrlWithForm(provider, form);
  }

  String _buildPlayerUrlWithForm(VideoProvider provider, _UrlForm form) {
    final movieBase = provider.movieUrl;
    final tvBase = provider.tvUrl;
    final isVideasy =
        movieBase.contains('videasy') || tvBase.contains('videasy');
    final isAnime = widget.isAnime;
    // For anime we always go through the TMDB id we resolved in
    // [_bootstrapAnime] — never the raw MAL id, since the dead
    // VidSrc MAL embeds used to be the alternative and we've since
    // removed them.
    final id = isAnime ? (_activeTmdbId ?? _externalId) : _externalId;

    if (widget.mediaType == 'tv') {
      final seasonNum = widget.season ?? 1;
      final epNum = widget.episode ?? 1;
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
  /// is down. For anime we hand off to Crunchyroll's search-by-MAL
  /// (which works because MAL ids are in the slug) and fall back to
  /// the resolved TMDB id on Videasy's own homepage so the user
  /// always has a real, working destination.
  String _externalOpenUrl() {
    final id = _externalId;
    if (widget.isAnime) {
      // Prefer Crunchyroll — it's the canonical legal stream for most
      // licensed anime and has a MAL-id routing that works for
      // Western-licensed shows. The TMDB id also works as a fallback.
      final tmdb = _activeTmdbId;
      if (tmdb != null) {
        // Videasy's own shareable URL uses the same shape as the
        // embed; it opens in a new tab and is reliable.
        if (widget.mediaType == 'tv') {
          return 'https://player.videasy.net/tv/$tmdb/${widget.season ?? 1}/${widget.episode ?? 1}';
        }
        return 'https://player.videasy.net/movie/$tmdb';
      }
      // No TMDB id — send the user to the MAL page so they can pick
      // a streaming source themselves.
      return 'https://myanimelist.net/anime/$id';
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

/// URL shape handed to the embed. The query-string form
/// (`?episode=N`) is the modern v2 shape and is what Videasy emits
/// by default; we keep the type around so a future fallback to
/// path-segment (`/{id}/{ep}`) is a one-line change.
// ignore: unused_field
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
