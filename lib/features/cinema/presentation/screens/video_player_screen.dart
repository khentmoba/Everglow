import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_spacing.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/features/cinema/data/services/ani_zip_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/data/services/video_source_service.dart';
import 'package:everglow/features/cinema/data/models/video_source_config.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_navigator.dart';
import 'package:everglow/services/auth_service.dart';

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

  /// When false, the player shows a confirmation card instead of the
  /// iframe. The user must tap "Start Watching" to actually load the
  /// embed — mimicking FluxTV's "Before you continue" gate which
  /// prevents auto-firing ad scripts from triggering on iframe load.
  bool _embedReady = false;

  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;
  JSFunction? _onErrorListener;
  Timer? _loadTimer;
  Timer? _contentCheckTimer;
  JSFunction? _messageListener;

  /// Tracks whether we've saved the initial "watching" status for this
  /// playback session so we don't spam Firestore on every rebuild.
  bool _hasSavedWatchProgress = false;

  /// Current season/episode state — updated by [EpisodeNavigator] for TV
  /// content so the iframe URL rebuilds when the user switches episodes.
  late int _currentSeason;
  late int _currentEpisode;

  /// Cached username to avoid [context.read] from JS interop callbacks
  /// where the widget tree traversal can silently fail.
  String _currentUserName = '';

  // ── Metadata state ─────────────────────────────────────────────────
  Map<String, dynamic>? _details;
  List<MediaItem> _similar = [];
  bool _isLoadingDetails = true;
  bool _isLoadingSimilar = true;

  /// How long to wait for the iframe to fire `load` before we consider
  /// the embed dead. vidsrc embeds usually load in 2-4s; 15s is a
  /// generous ceiling that still surfaces 404s within a reasonable
  /// user wait.
  static const Duration _loadTimeout = Duration(seconds: 15);

  /// How long to wait for VidLink to send a `MEDIA_DATA` postMessage
  /// event after the iframe loads. If the event never arrives the
  /// provider likely showed "content not available", so we fall back.
  static const Duration _contentCheckTimeout = Duration(seconds: 8);

  /// The currently selected embed source. Starts at the user's saved
  /// default (or the first entry from VideoSourceService); auto-fallback
  /// cycles through the list when an embed fails.
  late VideoSourceConfig _selectedProvider;

  /// Tracks which providers have already been tried and failed during
  /// this session so auto-fallback doesn't re-try a dead source.
  final Set<String> _failedProviderIds = {};

  /// Shared embed-provider service. Sources are loaded from Firestore
  /// with a hardcoded fallback.
  final VideoSourceService _sourceService = VideoSourceService();

  VideoSourceConfig get _activeProvider => _selectedProvider;

  List<VideoSourceConfig> get _selectableProviders =>
      _sourceService.providers;

  @override
  void initState() {
    super.initState();
    // Load the user's saved default source, or fall back to the
    // first recommended source from the service.
    final srcList = _sourceService.providers;
    _selectedProvider = srcList.isNotEmpty ? srcList.first : _sourceService.defaultSource;
    _loadSavedDefaultSource();
    _currentUserName = context.read<AuthService>().currentUser ?? '';

    _viewType =
        'everglow-cinema-player-${widget.tmdbId}-${widget.mediaType}-${widget.season ?? 0}-${widget.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; clipboard-write'
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no');
    // NOTE: We intentionally do NOT add a sandbox attribute. Some embed
    // providers (like Videasy) detect sandbox and refuse to load. FluxTV
    // achieves ad containment through other means: referrerpolicy strips
    // the Referer header, CSS containment isolates rendering, and the
    // confirmation gate delays embed loading to break ad timing.
    _iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = '#000';
    // CSS containment isolates the iframe's rendering from the parent
    // page — prevents ad scripts from measuring or manipulating the
    // parent DOM layout.
    _iframe.style.setProperty('contain', 'layout style');

    _onLoadListener = ((web.Event _) {
      _loadTimer?.cancel();
      if (mounted) setState(() => _isLoading = false);
      _startContentCheck();
      _saveWatchProgress();
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

_currentSeason = widget.season ?? 1;
    _currentEpisode = widget.episode ?? 1;

    // Fetch metadata in parallel (non-blocking for player)
    _fetchDetails();
    _fetchSimilar();

    // NOTE: We intentionally do NOT set _iframe.src here.
    // The embed only loads after the user taps "Start Watching" on the
    // confirmation card (see _embedReady). This FluxTV-style gate
    // prevents auto-firing ad scripts from triggering on iframe load.

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Called when the user taps "Start Watching" on the confirmation card.
  /// Actually loads the embed into the iframe and starts the load timer.
  void _startPlayback() {
    setState(() {
      _embedReady = true;
      _isLoading = true;
    });

    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });

    // For anime we don't have a TMDB id on the MediaItem — the slot
    // holds the MAL id. Resolve MAL→TMDB via ani.zip, then set the
    // iframe's src once. If the lookup fails (no cross-reference
    // exists) we land in the error card and offer external links.
    if (widget.isAnime) {
      _bootstrapAnime();
    } else {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }
  }

  /// Anime bootstrap: look up the TMDB id for the MAL id via ani.zip,
  /// then point the iframe at the player URL. VidLink has a dedicated
  /// MAL-based anime endpoint, so the TMDB id is only needed when VidLink
  /// fails and the player falls back to other providers.
  Future<void> _bootstrapAnime() async {
    final malId = widget.malId ?? widget.tmdbId;

    final tmdbId = await AniZipService().fetchTmdbId(malId);
    if (!mounted) return;
    if (tmdbId == null) {
      setState(() => _iframeFailed = true);
      _loadTimer?.cancel();
      return;
    }
    _externalTmdbId = tmdbId;
    _iframe.src = _buildPlayerUrl(_selectedProvider);
  }

  // ── Metadata fetching ─────────────────────────────────────────────

  Future<void> _fetchDetails() async {
    final tmdb = TMDBService();
    final details = await tmdb.fetchMediaDetails(
        widget.tmdbId, widget.mediaType);
    if (!mounted) return;
    setState(() {
      _details = details;
      _isLoadingDetails = false;
    });
  }

  Future<void> _fetchSimilar() async {
    final tmdb = TMDBService();
    final results = await tmdb.fetchSimilar(
        widget.tmdbId, widget.mediaType);
    if (!mounted) return;
    setState(() {
      _similar = results;
      _isLoadingSimilar = false;
    });
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

  /// Called when the user picks a different episode from [EpisodeNavigator].
  /// Rebuilds the iframe URL for the new episode and resets loading state.
  void _onEpisodeChanged(int episode) {
    if (episode == _currentEpisode) return;
    setState(() {
      _currentEpisode = episode;
      _isLoading = true;
      _iframeFailed = false;
    });
    _failedProviderIds.clear();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _iframe.src = _buildPlayerUrl(_selectedProvider);
  }

  /// Called when the user picks a different season from [EpisodeNavigator].
  void _onSeasonChanged(int season) {
    if (season == _currentSeason) return;
    setState(() {
      _currentSeason = season;
      _currentEpisode = 1;
      _isLoading = true;
      _iframeFailed = false;
    });
    _failedProviderIds.clear();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _iframe.src = _buildPlayerUrl(_selectedProvider);
  }

  /// Saves or updates the watch progress in Firestore so the
  /// "Currently Watching" shelves across the app reflect what the
  /// user is watching right now. Runs once per playback session.
  void _saveWatchProgress() {
    if (_hasSavedWatchProgress) return;
    _hasSavedWatchProgress = true;

    // If the cached username is empty (shouldn't happen since we capture
    // it in initState, but be defensive), attempt a direct read.
    String userName = _currentUserName;
    if (userName.isEmpty) {
      try {
        userName = context.read<AuthService>().currentUser ?? '';
      } catch (_) {}
    }
    if (userName.isEmpty) return;

    final tmdb = TMDBService();
    final status = _watchingStatusFor(userName);

    tmdb.updateProgress(
      MediaItem(
        id: '',
        tmdbId: widget.tmdbId,
        title: widget.title,
        mediaType: widget.mediaType,
        posterPath: '',
        status: status,
        isAnime: widget.isAnime,
        userName: userName,
        addedAt: DateTime.now(),
        source: widget.isAnime ? 'jikan' : 'tmdb',
      ),
      userName,
      season: _currentSeason,
      episode: _currentEpisode,
      timestamp: 0,
      status: status,
    );
  }

  /// Returns the correct watching status value for the user.
  String _watchingStatusFor(String userName) {
    switch (userName) {
      case 'khentsgdz':
        return 'watching-khent';
      case 'clairjassen':
        return 'watching-clair';
      default:
        return 'watching-self';
    }
  }

  /// Starts the content availability check timer. Only applies to
  /// VidLink, which sends a `MEDIA_DATA` or `PLAYER_EVENT` postMessage
  /// when content is actually playable. If the event doesn't arrive
  /// within [_contentCheckTimeout], the embed likely showed "content not
  /// available" and we fall back to the next provider.
  void _startContentCheck() {
    if (_selectedProvider.id != 'vidlink') return;
    _contentCheckTimer?.cancel();
    _contentCheckTimer = Timer(_contentCheckTimeout, () {
      if (!mounted) return;
      _onIframeLoadError();
    });
  }

  /// Builds the postMessage listener for embed provider events.
  /// Confirms content is playable and cancels the content check timer.
  /// Only accepts messages from the currently active provider's origin
  /// to avoid cross-provider interference.
  JSFunction _buildMessageListener() {
    return ((web.Event e) {
      try {
        final msg = e as web.MessageEvent;
        final origin = msg.origin;
        final data = msg.data;
        if (data == null) return;

        // Only accept messages from the active provider's origin
        final activeOrigin = _originForProvider(_selectedProvider.id);
        if (origin != activeOrigin) return;

        final map = data.dartify();
        if (map is! Map) return;
        final type = map['type'];
        if (type == 'MEDIA_DATA' || type == 'PLAYER_EVENT') {
          _contentCheckTimer?.cancel();
        }
      } catch (_) {} // ignore cross-origin / parse errors
    }).toJS;
  }

  /// Returns the expected postMessage origin for a given provider.
  /// Derives the origin from the provider's movie URL (the host portion).
  String _originForProvider(String providerId) {
    final cfg = _sourceService.byId(providerId);
    if (cfg == null) return '';
    try {
      final uri = Uri.parse(cfg.movieUrl);
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return '';
    }
  }

  /// Load the user's saved default source from SharedPreferences.
  Future<void> _loadSavedDefaultSource() async {
    final savedId = await _sourceService.loadDefaultSourceId();
    if (savedId != null && mounted) {
      final match = _sourceService.byId(savedId);
      if (match != null) {
        setState(() => _selectedProvider = match);
      }
    }
  }

  /// Find the next untried provider and switch to it. If every
  /// provider has been tried, show the error card.
  void _tryNextProvider() {
    final next = _selectableProviders.cast<VideoSourceConfig?>().firstWhere(
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
  void _selectProvider(VideoSourceConfig provider) {
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

  String _buildPlayerUrl(VideoSourceConfig provider) {
    // Default to the query-string form (the v2 shape) which is what
    // Videasy emits and what their docs recommend. The path-segment
    // form is preserved as a future fallback for any non-Videasy
    // provider that doesn't accept `?episode=N`.
    final form = _UrlForm.queryString;
    return _buildPlayerUrlWithForm(provider, form);
  }

  String _buildPlayerUrlWithForm(VideoSourceConfig provider, _UrlForm form) {
    final movieBase = provider.movieUrl;
    final tvBase = provider.tvUrl;
    final isVideasy =
        movieBase.contains('videasy') || tvBase.contains('videasy');
    final isAnime = widget.isAnime;
    final id = isAnime ? (_activeTmdbId ?? _externalId) : _externalId;

    if (widget.mediaType == 'tv') {
      final seasonNum = _currentSeason;
      final epNum = _currentEpisode;

      if (tvBase.contains('vidsrc.to')) {
        return '$tvBase$id&season=$seasonNum&episode=$epNum';
      } else if (tvBase.contains('multiembed.mov')) {
        return '$tvBase$id&tmdb=1&s=$seasonNum&e=$epNum';
      } else if (tvBase.contains('2embed.cc')) {
        return '$tvBase$id&s=$seasonNum&e=$epNum';
      } else if (provider.id == 'vsembed') {
        return '$tvBase$id?season=$seasonNum&episode=$epNum';
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
    final screenWidth = MediaQuery.of(context).size.width;
    // On mobile, cap the player height so the confirmation card and
    // metadata are visible without excessive scrolling. On desktop,
    // use the standard 16:9 ratio.
    final playerHeight = screenWidth < 600 ? screenWidth * 9 / 16 : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ClipRect(
                      child: playerHeight != null
                          ? SizedBox(
                              height: playerHeight,
                              child: _buildPlayerStack(),
                            )
                          : AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _buildPlayerStack(),
                            ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildMetadataSection()),
                  SliverToBoxAdapter(child: _buildServerSelectorSection()),
                  if (widget.mediaType == 'tv' && !widget.isAnime)
                    SliverToBoxAdapter(
                      child: EpisodeNavigator(
                        tmdbId: widget.tmdbId,
                        initialSeason: _currentSeason,
                        initialEpisode: _currentEpisode,
                        onSeasonChanged: _onSeasonChanged,
                        onEpisodeChanged: _onEpisodeChanged,
                      ),
                    ),
                  SliverToBoxAdapter(child: _buildMoreLikeThisSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStack() {
    return Stack(
      children: [
        if (_embedReady && !_iframeFailed)
          HtmlElementView(viewType: _viewType),
        if (_embedReady && _isLoading && !_iframeFailed)
          const Center(
            child: CircularProgressIndicator(color: AppTheme.deepRose),
          ),
        if (_embedReady && _iframeFailed) _buildErrorCard(context),
        if (!_embedReady) _buildConfirmationCard(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TOP BAR
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.deepBlack,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.velvet,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.petalWhite, size: 12),
                  const SizedBox(width: 4),
                  Text('Back',
                      style: GoogleFonts.outfit(
                          color: AppColors.petalWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    color: AppColors.petalWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          if (_embedReady && !_isLoading && !_iframeFailed) ...[
            GestureDetector(
              onTap: _onIframeLoadError,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.velvet,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                      color: AppColors.deepRose.withValues(alpha: 0.4),
                      width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('Try Another Source',
                        style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _buildProviderBadge(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // METADATA SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMetadataSection() {
    // Extract genres from fetched details
    final genres = _details?['genres'] as List?;
    final genreNames = genres
        ?.map((g) => g is Map ? (g['name']?.toString() ?? '') : g.toString())
        .where((n) => n.isNotEmpty)
        .toList();

    // Overview / synopsis
    final overview = (_details?['overview'] ?? '') as String;

    // Rating
    final ratingNum = _details?['vote_average'] as num?;
    final rating = ratingNum != null ? ratingNum.toDouble().toStringAsFixed(1) : null;

    // Runtime
    final runtime = _details?['runtime'] as int?;
    final episodeRunTimes = _details?['episode_run_time'] as List?;
    final effectiveRuntime = runtime ??
        (episodeRunTimes != null && episodeRunTimes.isNotEmpty
            ? episodeRunTimes.first as int?
            : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: GoogleFonts.cormorantGaramond(
                  color: AppColors.petalWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // Meta badges row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetaBadge(
                  Icons.source_rounded, _selectedProvider.shortName,
                  accent: true),
              _buildMetaBadge(
                  widget.mediaType == 'movie'
                      ? Icons.movie_rounded
                      : Icons.tv_rounded,
                  widget.mediaType == 'movie' ? 'Movie' : 'TV Show'),
              if (widget.mediaType == 'tv')
                _buildMetaBadge(Icons.layers_rounded,
                    'S${_currentSeason} E${_currentEpisode}'),
              if (rating != null)
                _buildMetaBadge(Icons.star_rounded, '$rating/10'),
              if (effectiveRuntime != null && effectiveRuntime > 0)
                _buildMetaBadge(Icons.schedule_rounded, '${effectiveRuntime}m'),
            ],
          ),
          // Genre chips
          if (genreNames != null && genreNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: genreNames
                  .take(5)
                  .map((g) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(g,
                            style: GoogleFonts.outfit(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
          ],
          // Synopsis
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(overview,
                style: GoogleFonts.outfit(
                    color: AppColors.textMedium,
                    fontSize: 13,
                    height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String label,
      {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.deepRose.withValues(alpha: 0.15)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: accent
            ? Border.all(
                color: AppColors.deepRose.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: accent ? AppColors.deepRose : AppColors.textMuted, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.outfit(
                  color: accent ? AppColors.deepRose : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: accent ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SERVER SELECTOR
  // ---------------------------------------------------------------------------

  Widget _buildServerSelectorSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: GestureDetector(
        onTap: () => _showProviderSheet(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.velvet.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.deepRose,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.deepRose.withValues(alpha: 0.5),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Server: ${_selectedProvider.name}',
                        style: GoogleFonts.outfit(
                            color: AppColors.petalWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text(_selectedProvider.desc,
                        style: GoogleFonts.outfit(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.swap_horiz_rounded,
                  color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MORE LIKE THIS
  // ---------------------------------------------------------------------------

  Widget _buildMoreLikeThisSection() {
    if (_isLoadingSimilar) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(
              color: AppTheme.deepRose, strokeWidth: 2),
        ),
      );
    }
    if (_similar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('More Like This',
                style: GoogleFonts.cormorantGaramond(
                    color: AppColors.petalWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _similar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = _similar[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    final id =
                        item.isAnime ? (item.anilistId ?? item.tmdbId) : item.tmdbId;
                    final malIdParam =
                        item.isAnime ? '&malId=${item.tmdbId}' : '';
                    context.push(
                        '/cinema/video/$id?type=${item.mediaType}&title=${Uri.encodeComponent(item.title)}&anime=${item.isAnime}$malIdParam');
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 110,
                          height: 140,
                          color: Colors.white.withValues(alpha: 0.06),
                          child: item.posterPath.isNotEmpty
                              ? Image.network(
                                  item.posterPath.startsWith('http')
                                      ? item.posterPath
                                      : 'https://image.tmdb.org/t/p/w342${item.posterPath}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.movie_rounded,
                                          color: Colors.white24, size: 32)),
                                )
                              : const Center(
                                  child: Icon(Icons.movie_rounded,
                                      color: Colors.white24, size: 32)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 110,
                        child: Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
    showModalBottomSheet<VideoSourceConfig>(
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
                  p.desc,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check_circle, color: AppTheme.deepRose, size: 20)
                    else ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          _sourceService.saveDefaultSourceId(p.id);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('${p.name} set as default'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppTheme.deepRose,
                              ),
                            );
                          }
                        },
                        child: Icon(
                          Icons.star_border_rounded,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
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
      color: AppColors.deepBlack,
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

  // ---------------------------------------------------------------------------
  // CONFIRMATION CARD (FluxTV-style "Before you continue" gate)
  // ---------------------------------------------------------------------------

  Widget _buildConfirmationCard() {
    return Container(
      color: AppColors.deepBlack,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.deepRose,
                  AppTheme.deepRose.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepRose.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: AppColors.petalWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.deepRose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: AppColors.deepRose.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              _selectedProvider.name,
              style: GoogleFonts.outfit(
                color: AppColors.roseQuartz,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _startPlayback,
            child: Container(
              width: 200,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.deepRose, const Color(0xFF8E1444)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepRose.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Start Watching',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This loads a third-party video source.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 12,
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
