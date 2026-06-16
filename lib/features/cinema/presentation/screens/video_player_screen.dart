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
  Timer? _contentCheckTimer;
  JSFunction? _messageListener;

  /// How long to wait for the iframe to fire `load` before we consider
  /// the embed dead. vidsrc embeds usually load in 2-4s; 15s is a
  /// generous ceiling that still surfaces 404s within a reasonable
  /// user wait.
  static const Duration _loadTimeout = Duration(seconds: 15);

  /// How long to wait for VidLink to send a `MEDIA_DATA` postMessage
  /// event after the iframe loads. If the event never arrives the
  /// provider likely showed "content not available", so we fall back.
  static const Duration _contentCheckTimeout = Duration(seconds: 8);

  /// The currently selected embed source. Starts at the first entry
  /// in [_providers]; auto-fallback cycles through the list when one
  /// embed fails to load within [_loadTimeout].
  late VideoProvider _selectedProvider;

  /// Tracks which providers have already been tried and failed during
  /// this session so auto-fallback doesn't re-try a dead source.
  final Set<String> _failedProviderIds = {};

  /// Free embed providers that accept a TMDB id. The player tries
  /// each one in order, auto-falling back when an embed 404s or
  /// doesn't respond within [_loadTimeout].
  static const List<VideoProvider> _providers = [
    VideoProvider(
      id: 'vidlink',
      name: 'VidLink',
      shortName: 'VidLink',
      note: 'Solid, actively maintained',
      movieUrl: 'https://vidlink.pro/movie/',
      tvUrl: 'https://vidlink.pro/tv/',
    ),
    VideoProvider(
      id: 'multiembed',
      name: 'MultiEmbed',
      shortName: 'MultiEmbed',
      note: 'Multi-source fallback',
      movieUrl: 'https://multiembed.mov/?video_id=',
      tvUrl: 'https://multiembed.mov/?video_id=',
    ),
    VideoProvider(
      id: '2embed.cc',
      name: '2Embed',
      shortName: '2Embed',
      note: 'Direct TMDB-based source',
      movieUrl: 'https://www.2embed.cc/embed/',
      tvUrl: 'https://www.2embed.cc/embedtv/',
    ),
    VideoProvider(
      id: 'videasy',
      name: 'Videasy',
      shortName: 'Videasy',
      note: 'Alternative source',
      movieUrl: 'https://player.videasy.net/movie/',
      tvUrl: 'https://player.videasy.net/tv/',
    ),
    VideoProvider(
      id: 'vidsrc',
      name: 'VidSrc',
      shortName: 'VidSrc',
      note: 'Last resort, ad-heavy',
      movieUrl: 'https://vidsrc.to/embed/movie/',
      tvUrl: 'https://vidsrc.to/embed/tv/',
    ),
  ];

  VideoProvider get _activeProvider => _selectedProvider;

  List<VideoProvider> get _selectableProviders => _providers;

  @override
  void initState() {
    super.initState();
    _selectedProvider = _providers.first;

    _viewType =
        'everglow-cinema-player-${widget.tmdbId}-${widget.mediaType}-${widget.season ?? 0}-${widget.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; clipboard-write'
      ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade')
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
      _startContentCheck();
    }).toJS;
    _onErrorListener = ((web.Event _) {
      _onIframeLoadError();
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);
    _iframe.addEventListener('error', _onErrorListener);

    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });

    _messageListener = _buildMessageListener();
    web.window.addEventListener('message', _messageListener);

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

    // VidLink anime uses MAL id directly — start loading immediately
    // without waiting for the ani.zip TMDB resolution.
    if (_selectedProvider.id == 'vidlink') {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }

    final tmdbId = await AniZipService().fetchTmdbId(malId);
    if (!mounted) return;
    if (tmdbId == null) {
      if (_selectedProvider.id != 'vidlink') {
        setState(() => _iframeFailed = true);
        _loadTimer?.cancel();
      }
      return;
    }
    _externalTmdbId = tmdbId;
    if (_selectedProvider.id != 'vidlink') {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }
  }

  /// Called when the iframe fires `error` or the [_loadTimeout] fires
  /// while still loading. Marks the current provider as failed and
  /// automatically tries the next untried provider in [_providers].
  void _onIframeLoadError() {
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    if (!mounted) return;
    _failedProviderIds.add(_selectedProvider.id);
    _tryNextProvider();
  }

  /// Starts the content availability check timer. Only applies to
  /// VidLink, which sends a `MEDIA_DATA` postMessage when content is
  /// actually playable. If the event doesn't arrive within
  /// [_contentCheckTimeout], the embed likely showed "content not
  /// available" and we fall back to the next provider.
  void _startContentCheck() {
    if (_selectedProvider.id != 'vidlink') return;
    _contentCheckTimer?.cancel();
    _contentCheckTimer = Timer(_contentCheckTimeout, () {
      if (!mounted) return;
      _onIframeLoadError();
    });
  }

  /// Builds the postMessage listener for VidLink's `MEDIA_DATA` event.
  /// When received, it confirms the content is playable and cancels
  /// the content check timer.
  JSFunction _buildMessageListener() {
    return ((web.Event e) {
      try {
        final data = (e as web.MessageEvent).data;
        if (data == null) return;
        final map = data.dartify();
        if (map is! Map) return;
        if (map['type'] == 'MEDIA_DATA') {
          _contentCheckTimer?.cancel();
        }
      } catch (_) {} // ignore cross-origin / parse errors
    }).toJS;
  }

  /// Find the next untried provider and switch to it. If every
  /// provider has been tried, show the error card.
  void _tryNextProvider() {
    final next = _providers.cast<VideoProvider?>().firstWhere(
      (p) => !_failedProviderIds.contains(p!.id),
      orElse: () => null,
    );
    if (next != null) {
      setState(() {
        _selectedProvider = next;
        _isLoading = true;
        _iframeFailed = false;
      });
      _loadTimer = Timer(_loadTimeout, () {
        if (!mounted) return;
        if (_isLoading) _onIframeLoadError();
      });
      _iframe.src = _buildPlayerUrl(next);
    } else {
      setState(() => _iframeFailed = true);
    }
  }

  /// Called when the user picks a different provider from the dropdown
  /// or error card. Clears the failed set so the chosen provider gets
  /// a fresh attempt.
  void _selectProvider(VideoProvider provider) {
    if (provider.id == _selectedProvider.id) return;
    _failedProviderIds.clear();
    setState(() {
      _selectedProvider = provider;
      _isLoading = true;
      _iframeFailed = false;
    });
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _iframe.src = _buildPlayerUrl(provider);
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    if (_onLoadListener != null) {
      _iframe.removeEventListener('load', _onLoadListener);
    }
    if (_onErrorListener != null) {
      _iframe.removeEventListener('error', _onErrorListener);
    }
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
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
    // VidLink anime endpoint uses MAL id directly. We always request sub
    // and include ?fallback=true so VidLink falls back to dub if the sub
    // stream isn't available for this particular episode.
    if (provider.id == 'vidlink' && widget.isAnime && widget.mediaType == 'tv') {
      final malId = _externalId;
      final epNum = widget.episode ?? 1;
      return 'https://vidlink.pro/anime/$malId/$epNum/sub?fallback=true';
    }

    final movieBase = provider.movieUrl;
    final tvBase = provider.tvUrl;
    final isVideasy =
        movieBase.contains('videasy') || tvBase.contains('videasy');
    final isAnime = widget.isAnime;
    final id = isAnime ? (_activeTmdbId ?? _externalId) : _externalId;

    if (widget.mediaType == 'tv') {
      final seasonNum = widget.season ?? 1;
      final epNum = widget.episode ?? 1;
      if (tvBase.contains('vidsrc.to')) {
        return '$tvBase$id&season=$seasonNum&episode=$epNum';
      } else if (tvBase.contains('multiembed.mov')) {
        return '$tvBase$id&tmdb=1&s=$seasonNum&e=$epNum';
      } else if (tvBase.contains('2embed.cc')) {
        return '$tvBase$id&s=$seasonNum&e=$epNum';
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

  /// The URL the user can open in a new tab. Uses the same URL the
  /// iframe would use for the current provider — if every embed has
  /// failed, this gives the user a manual escape hatch.
  String _externalOpenUrl() {
    return _buildPlayerUrl(_activeProvider);
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
                  if (!_isLoading && !_iframeFailed) ...[
                    GestureDetector(
                      onTap: _onIframeLoadError,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.deepRose.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Try Another Source',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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

  /// The chip in the header that shows the current embed source. A
  /// [PopupMenuButton] that lets the user switch providers manually.
  Widget _buildProviderBadge() {
    final active = _activeProvider;
    final isSelectable = _selectableProviders.length > 1;

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

    return GestureDetector(
      onTap: () => _showProviderSheet(),
      child: badge,
    );
  }

  void _showProviderSheet() {
    _iframe.style.setProperty('pointer-events', 'none');
    showModalBottomSheet<VideoProvider>(
      context: context,
      backgroundColor: const Color(0xFF1C1228),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Switch Source',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a streaming provider',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ..._selectableProviders.map((p) {
              final isSelected = p.id == _selectedProvider.id;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.deepRose : Colors.white54,
                  size: 20,
                ),
                title: Text(
                  p.name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  p.note,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.deepRose, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(ctx, p);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((provider) {
      _iframe.style.setProperty('pointer-events', 'auto');
      if (provider != null) _selectProvider(provider);
    });
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
