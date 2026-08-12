import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:everglow/core/theme/app_typography.dart';

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

  // Metadata state
  Map<String, dynamic>? _details;

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

  /// Whether the player is in custom fullscreen (theater) mode.
  bool _isFullscreen = false;

  /// Drives the page scroll view so wheel events from the embed iframe
  /// (which Flutter never sees) can be forwarded to it.
  final ScrollController _scrollController = ScrollController();

  /// Native wheel listener on the embed iframe. The iframe swallows
  /// wheel events, so without this the page can't be scrolled in
  /// browser fullscreen, where the player covers the whole viewport.
  JSFunction? _onWheelListener;

  /// DOM exit chip shown in theater mode. It lives outside Flutter's
  /// canvas (which sits underneath the fixed-position iframe), so it
  /// stays reachable while theater mode is on.
  web.HTMLDivElement? _fullscreenExitButton;
  JSFunction? _onFullscreenExitListener;

  /// Shared embed-provider service. Sources are loaded from Firestore
  /// with a hardcoded fallback.
  final VideoSourceService _sourceService = VideoSourceService();

  /// Listener callback for when the service's provider list updates
  /// asynchronously from Firestore.
  VoidCallback? _serviceListener;

  VideoSourceConfig get _activeProvider => _selectedProvider;

  /// Providers offered for the active item. For anime playback the VidEasy
  /// embed is kept as server one even if a Firestore config reorders the
  /// list; movies and TV keep the configured order untouched.
  List<VideoSourceConfig> get _selectableProviders {
    final list = _sourceService.providers;
    if (!widget.isAnime) return list;
    final videasy = list.where((p) => p.id == 'videasy').toList();
    final rest = list.where((p) => p.id != 'videasy').toList();
    return [...videasy, ...rest];
  }

  @override
  void initState() {
    super.initState();
    // Load the user's saved default source, or fall back to the
    // first recommended source from the service.
    final srcList = _selectableProviders;
    _selectedProvider = srcList.isNotEmpty ? srcList.first : _sourceService.defaultSource;
    _loadSavedDefaultSource();
    _currentUserName = context.read<AuthService>().currentUser ?? '';

    // Listen for provider list updates from Firestore. If the iframe
    // has already failed with the hardcoded defaults, retry with the
    // freshly loaded sources.
    _serviceListener = () {
      if (!mounted) return;
      final newList = _selectableProviders;
      if (newList.isNotEmpty && _iframeFailed) {
        debugPrint('[VideoPlayerScreen] Providers updated from Firestore — retrying');
        _failedProviderIds.clear();
        _selectedProvider = newList.first;
        setState(() {
          _iframeFailed = false;
          _isLoading = true;
        });
        _loadTimer?.cancel();
        _loadTimer = Timer(_loadTimeout, () {
          if (!mounted) return;
          if (_isLoading) _onIframeLoadError();
        });
        _iframe.src = _buildPlayerUrl(_selectedProvider);
      }
    };
    _sourceService.addListener(_serviceListener!);

    _viewType =
        'everglow-cinema-player-${widget.tmdbId}-${widget.mediaType}-${widget.season ?? 0}-${widget.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..allow =
          'autoplay *; fullscreen *; encrypted-media *; picture-in-picture *; accelerometer *; gyroscope *; clipboard-write *'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..setAttribute('referrerpolicy', 'no-referrer')
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
      _saveWatchProgress();
    }).toJS;
    _onErrorListener = ((web.Event _) {
      _onIframeLoadError();
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);
    _iframe.addEventListener('error', _onErrorListener);

    // Wheel events over the native iframe never reach Flutter's
    // scrollable, so forward them to the page scroll view directly.
    // This keeps the page scrollable even in browser fullscreen, where
    // the player fills nearly the entire viewport.
    _onWheelListener = ((web.Event e) {
      if (_isFullscreen || !_scrollController.hasClients) return;
      final wheel = e as web.WheelEvent;
      if (wheel.ctrlKey) return; // Leave pinch-zoom gestures alone.
      wheel.preventDefault();
      var delta = wheel.deltaY;
      switch (wheel.deltaMode) {
        case 1: // DOM_DELTA_LINE
          delta *= 20;
          break;
        case 2: // DOM_DELTA_PAGE
          delta *= 600;
          break;
      }
      if (delta == 0) return;
      final position = _scrollController.position;
      final target = (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) position.jumpTo(target);
    }).toJS;
    _iframe.addEventListener('wheel', _onWheelListener, true.toJS);

    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });

    _messageListener = _buildMessageListener();
    web.window.addEventListener('message', _messageListener);

_currentSeason = widget.season ?? 1;
    _currentEpisode = widget.episode ?? 1;

    // For anime we don't have a TMDB id on the MediaItem — the slot
    // holds the MAL id. Resolve MAL→TMDB via ani.zip, then set the
    // iframe's src once. If the lookup fails (no cross-reference
    // exists) we land in the error card and offer external links.
    if (widget.isAnime) {
      _bootstrapAnime();
    } else {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

  /// Called when the iframe fires `error` or the [_loadTimeout] fires
  /// while still loading. Marks the current provider as failed and
  /// automatically tries the next untried provider in [_providers].
  void _onIframeLoadError() {
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    if (!mounted) return;
    debugPrint('[VideoPlayerScreen] Provider "${_selectedProvider.id}" failed (url: ${_buildPlayerUrl(_selectedProvider)})');
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
      } catch (e) {
        debugPrint('[VideoPlayerScreen] Failed to read AuthService for username: $e');
      }
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
      } catch (e) {
        debugPrint('[VideoPlayerScreen] Cross-origin postMessage parse error: $e');
      } // ignore cross-origin / parse errors
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
    // Anime always starts on the VidEasy embed (server one), regardless of
    // any saved default that may point at a dead source.
    if (widget.isAnime) return;
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
      debugPrint('[VideoPlayerScreen] Trying next provider: "${next.id}" (${_failedProviderIds.length} failed so far)');
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
      debugPrint('[VideoPlayerScreen] All ${_selectableProviders.length} providers failed — showing error card');
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

  /// Toggles custom fullscreen (theater) mode. Instead of using the
  /// browser Fullscreen API (which doesn't play well with Flutter web's
  /// rendering layer and causes the player controls to be cut off), we
  /// expand the iframe via CSS `position: fixed` to fill the viewport
  /// and show a DOM exit chip on top so the user is never trapped.
  void _toggleFullScreen() {
    final entering = !_isFullscreen;
    setState(() => _isFullscreen = entering);
    if (entering) {
      _iframe.style
        ..position = 'fixed'
        ..top = '0'
        ..left = '0'
        ..width = '100vw'
        ..height = '100vh'
        ..zIndex = '9999';
      _showFullscreenExitButton();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _iframe.style
        ..position = ''
        ..top = ''
        ..left = ''
        ..width = '100%'
        ..height = '100%'
        ..zIndex = '';
      _hideFullscreenExitButton();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Adds the DOM exit chip for theater mode. Flutter widgets can't
  /// paint above the platform-view iframe, so this chip is a plain DOM
  /// element appended to the page with a higher z-index.
  void _showFullscreenExitButton() {
    if (_fullscreenExitButton != null) return;
    final button = web.HTMLDivElement()..textContent = 'Exit theater';
    button.style
      ..position = 'fixed'
      ..top = '16px'
      ..right = '16px'
      ..zIndex = '10000'
      ..padding = '10px 14px'
      ..background = 'rgba(28, 18, 40, 0.92)'
      ..border = '1px solid rgba(255, 255, 255, 0.28)'
      ..borderRadius = '999px'
      ..boxShadow = '0 6px 22px rgba(0, 0, 0, 0.5)'
      ..cursor = 'pointer'
      ..color = '#FFFFFF'
      ..fontSize = '13px'
      ..fontWeight = '700'
      ..fontFamily = 'system-ui, sans-serif'
      ..userSelect = 'none';
    _onFullscreenExitListener = ((web.Event _) => _toggleFullScreen()).toJS;
    button.addEventListener('click', _onFullscreenExitListener);
    web.document.body?.appendChild(button);
    _fullscreenExitButton = button;
  }

  void _hideFullscreenExitButton() {
    final button = _fullscreenExitButton;
    _fullscreenExitButton = null;
    if (button == null) return;
    if (_onFullscreenExitListener != null) {
      button.removeEventListener('click', _onFullscreenExitListener);
      _onFullscreenExitListener = null;
    }
    button.remove();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    if (_serviceListener != null) {
      _sourceService.removeListener(_serviceListener!);
    }
    if (_onLoadListener != null) {
      _iframe.removeEventListener('load', _onLoadListener);
    }
    if (_onErrorListener != null) {
      _iframe.removeEventListener('error', _onErrorListener);
    }
    if (_onWheelListener != null) {
      _iframe.removeEventListener('wheel', _onWheelListener);
    }
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
    }
    if (_isFullscreen) {
      _iframe.style
        ..position = ''
        ..top = ''
        ..left = ''
        ..width = '100%'
        ..height = '100%'
        ..zIndex = '';
    }
    _hideFullscreenExitButton();
    _iframe.src = 'about:blank';
    _scrollController.dispose();

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
        return '$tvBase$id?season=$seasonNum&episode=$epNum';
      } else if (tvBase.contains('multiembed.mov')) {
        return '$tvBase$id&tmdb=1&s=$seasonNum&e=$epNum';
      } else if (provider.id == 'vsembed') {
        return '$tvBase$id?season=$seasonNum&episode=$epNum';
      } else if (tvBase.contains('embed') && !tvBase.endsWith('/')) {
        return '$tvBase$id?season=$seasonNum&episode=$epNum';
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
            _buildTopBar(),
            // Scrollable body: video + metadata + server selector
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Player iframe area: 16:9, but capped so a strip of
                    // page content stays visible below it. In browser
                    // fullscreen the full-width player is taller than the
                    // viewport, and because embeds swallow wheel events the
                    // page can't be scrolled down to the server selector.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxPlayerHeight =
                            (MediaQuery.sizeOf(context).height - 296)
                                .clamp(240.0, double.infinity)
                                .toDouble();
                        if (_iframeFailed) {
                          return ConstrainedBox(
                            constraints:
                                BoxConstraints(maxHeight: maxPlayerHeight),
                            child: _buildErrorCard(context),
                          );
                        }
                        return ConstrainedBox(
                          constraints:
                              BoxConstraints(maxHeight: maxPlayerHeight),
                          child: RepaintBoundary(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const ColoredBox(color: Colors.black),
                                    RepaintBoundary(
                                      child: HtmlElementView(
                                        viewType: _viewType,
                                      ),
                                    ),
                                    if (_isLoading)
                                      _CinematicLoader(
                                        providerName:
                                            _selectedProvider.shortName,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Episode Navigator for TV content
                    if (widget.mediaType == 'tv' && !widget.isAnime)
                      EpisodeNavigator(
                        tmdbId: widget.tmdbId,
                        initialSeason: _currentSeason,
                        initialEpisode: _currentEpisode,
                        onSeasonChanged: _onSeasonChanged,
                        onEpisodeChanged: _onEpisodeChanged,
                      ),
                    RepaintBoundary(child: _buildMetadataSection()),
                    RepaintBoundary(child: _buildServerSelectorSection()),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top control & details bar. Uses glass pills that respond to hover
  /// (desktop) and press (touch) without changing any existing behavior.
  Widget _buildTopBar() {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        border: Border(
          bottom: BorderSide(
            color: AppColors.moonlight.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _PlayerPillButton(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Back',
            compact: compact,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: compact ? 8 : 14),
          if (!compact) ...[
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cormorantSemiBoldWhite.copyWith(
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (!_isLoading && !_iframeFailed) ...[
            _PlayerPillButton(
              icon: Icons.swap_horiz_rounded,
              label: 'Try Another Source',
              accent: true,
              compact: compact,
              onTap: _onIframeLoadError,
            ),
            SizedBox(width: compact ? 6 : 8),
          ],
          Tooltip(
            message: 'Theater mode',
            child: _PlayerIconButton(
              icon: Icons.fullscreen_rounded,
              compact: compact,
              onTap: _toggleFullScreen,
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          _buildProviderBadge(compact: compact),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // METADATA SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMetadataSection() {
    final genres = _details?['genres'] as List?;
    final genreNames = genres?.map((g) => g is Map ? (g['name']?.toString() ?? '') : g.toString()).where((n) => n.isNotEmpty).toList();
    final overview = (_details?['overview'] ?? '') as String;
    final ratingNum = _details?['vote_average'] as num?;
    final rating = ratingNum?.toDouble().toStringAsFixed(1);
    final runtime = _details?['runtime'] as int?;
    final epRun = _details?['episode_run_time'] as List?;
    final effRuntime = runtime ?? (epRun != null && epRun.isNotEmpty ? epRun.first as int? : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _metaBadge(
              Icons.source_rounded,
              _selectedProvider.shortName,
              accent: true,
            ),
            _metaBadge(
              widget.mediaType == 'movie'
                  ? Icons.movie_rounded
                  : Icons.tv_rounded,
              widget.mediaType == 'movie' ? 'Movie' : 'TV Show',
              tint: AppColors.softLavender,
            ),
            if (widget.mediaType == 'tv')
              _metaBadge(
                Icons.layers_rounded,
                'S$_currentSeason E$_currentEpisode',
                tint: AppColors.moonlight,
              ),
            if (rating != null)
              _metaBadge(
                Icons.star_rounded,
                '$rating/10',
                tint: AppColors.blushGold,
              ),
            if (effRuntime != null && effRuntime > 0)
              _metaBadge(
                Icons.schedule_rounded,
                '${effRuntime}m',
                tint: AppColors.softLavender,
              ),
          ]),
          if (genreNames != null && genreNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: genreNames.take(5).map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surfaceGlass, borderRadius: BorderRadius.circular(AppRadius.xs)),
              child: Text(g, style: AppTypography.outfitWhite.copyWith(color: AppColors.textMuted, fontSize: 11)),
            )).toList()),
          ],
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              overview,
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.textMedium,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaBadge(
    IconData icon,
    String label, {
    bool accent = false,
    Color? tint,
  }) {
    final chipColor = tint ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? AppColors.deepRose.withValues(alpha: 0.15) : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: accent
              ? AppColors.deepRose.withValues(alpha: 0.5)
              : AppColors.border,
          width: 1,
        ),
        boxShadow: accent
            ? [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.18),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          icon,
          color: accent ? AppColors.roseQuartz : chipColor,
          size: 13,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.outfitHeading.copyWith(
            color: accent ? AppColors.roseQuartz : AppColors.textMedium,
            fontSize: 11,
          ),
        ),
      ]),
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
          // 1px gradient frame around the card.
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.x2),
            gradient: const LinearGradient(
              colors: [AppColors.deepRose, AppColors.softLavender],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.inkDeep.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.x2 - 1),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server: ${_selectedProvider.name}',
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedProvider.desc,
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PlayerIconButton(
                  icon: Icons.swap_horiz_rounded,
                  onTap: _showProviderSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MORE LIKE THIS
  // ---------------------------------------------------------------------------

  /// The chip in the header that shows the current embed source. A
  /// [PopupMenuButton] that lets the user switch providers manually.
  Widget _buildProviderBadge({bool compact = false}) {
    final active = _activeProvider;
    final isSelectable = _selectableProviders.length > 1;

    final badge = _ProviderBadge(
      active: active,
      isSelectable: isSelectable,
      compact: compact,
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
      backgroundColor: AppColors.inkDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.x2)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.roseGoldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Switch Source',
                style: AppTypography.outfitWhite.copyWith(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a streaming provider',
                style: AppTypography.outfitMuted.copyWith(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: _selectableProviders.map((p) {
                    final isSelected = p.id == _selectedProvider.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.deepRose.withValues(alpha: 0.12)
                                : AppColors.surfaceGlass,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.deepRose.withValues(alpha: 0.65)
                                  : AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.deepRose
                                          .withValues(alpha: 0.2)
                                      : AppColors.moonlight
                                          .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.live_tv_rounded,
                                  color: isSelected
                                      ? AppColors.roseQuartz
                                      : AppColors.textMuted,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: AppTypography.outfitWhite.copyWith(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.desc,
                                      style: AppTypography.outfitMuted.copyWith(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.radio_button_checked,
                                  color: AppTheme.deepRose,
                                  size: 18,
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    _sourceService.saveDefaultSourceId(p.id);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${p.name} set as default',
                                          ),
                                          duration: const Duration(seconds: 2),
                                          behavior:
                                              SnackBarBehavior.floating,
                                          backgroundColor: AppTheme.deepRose,
                                        ),
                                      );
                                    }
                                  },
                                  child: Tooltip(
                                    message: 'Set as default source',
                                    child: Icon(
                                      Icons.star_border_rounded,
                                      color: Colors.white38,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deepRose.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.deepRose.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.deepRose,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This title isn\'t available on ${active.shortName}.',
            textAlign: TextAlign.center,
            style: AppTypography.outfitHeading.copyWith(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'The embed returned a 404 or didn\'t respond. Try a different source below.',
            textAlign: TextAlign.center,
            style: AppTypography.outfitMuted.copyWith(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 24),
          if (others.isNotEmpty) ...[
            Text(
              'Try another source',
              style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
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
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.deepRose.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                                color: AppTheme.deepRose
                                    .withValues(alpha: 0.5),
                                width: 1),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.deepRose.withValues(alpha: 0.18),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppTheme.roseQuartz,
                                size: 17,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                p.name,
                                style: AppTypography.outfitHeading.copyWith(
                                    color: Colors.white, fontSize: 12),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                gradient: AppTheme.roseGoldGradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Open in browser',
                    style: AppTypography.outfitBold.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 0.3,
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

// ---------------------------------------------------------------------------
// Player chrome widgets (video_player_screen only)
// ---------------------------------------------------------------------------

/// Glass pill button used by the player top bar. Gives desktop hover and
/// touch press feedback while keeping the same tap behavior as before.
class _PlayerPillButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool compact;

  const _PlayerPillButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
    this.compact = false,
  });

  @override
  State<_PlayerPillButton> createState() => _PlayerPillButtonState();
}

class _PlayerPillButtonState extends State<_PlayerPillButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: accent
                  ? AppColors.deepRose.withValues(
                      alpha: _hovered ? 0.30 : 0.18)
                  : AppColors.moonlight.withValues(
                      alpha: _hovered ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: accent
                    ? AppColors.deepRose.withValues(
                        alpha: _hovered ? 0.85 : 0.55)
                    : AppColors.moonlight.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: (accent
                                ? AppColors.deepRose
                                : AppColors.softLavender)
                            .withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: accent
                      ? AppColors.roseQuartz
                      : Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: AppTypography.outfitHeading.copyWith(
                    color: accent
                        ? AppColors.roseQuartz
                        : Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact square glass icon button for the player chrome.
class _PlayerIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  const _PlayerIconButton({
    required this.icon,
    this.onTap,
    this.compact = false,
  });

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: widget.compact ? 30 : 32,
            height: widget.compact ? 30 : 32,
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(
                alpha: _hovered ? 0.18 : 0.10,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: AppColors.softLavender.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: _hovered
                  ? AppColors.roseQuartz
                  : Colors.white70,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rose gradient pill showing the active embed source in the top bar.
class _ProviderBadge extends StatelessWidget {
  final VideoSourceConfig active;
  final bool isSelectable;
  final bool compact;

  const _ProviderBadge({
    required this.active,
    required this.isSelectable,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepRose.withValues(alpha: 0.92),
            AppColors.auroraRose.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.petalWhite.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRose.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            active.shortName,
            style: AppTypography.outfitBold.copyWith(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          if (isSelectable) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              color: Colors.white,
              size: 15,
            ),
          ],
        ],
      ),
    );
  }
}

/// Live status dot with a soft pulse for the server selector card.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (AppTheme.shouldReduceMotion) {
      _controller.value = 0.35;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + _pulse.value * 1.6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.deepRose.withValues(
                      alpha: (1 - _pulse.value) * 0.35,
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.deepRose,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cinematic buffering state shown over the video area while the embed
/// loads. Purely visual; pointer events pass through it.
class _CinematicLoader extends StatefulWidget {
  final String providerName;

  const _CinematicLoader({
    required this.providerName,
  });

  @override
  State<_CinematicLoader> createState() => _CinematicLoaderState();
}

class _CinematicLoaderState extends State<_CinematicLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (AppTheme.shouldReduceMotion) {
      _controller.value = 0.5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: AppColors.inkDeep.withValues(alpha: 0.96),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.8 + _controller.value * 0.5,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.deepRose.withValues(
                                  alpha: (1 - _controller.value) * 0.45,
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.velvet, AppColors.deepRose],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepRose.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.movie_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Preparing your stream',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'via ${widget.providerName}',
                    style: AppTypography.outfitMuted.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Container(
                      width: 140,
                      height: 3,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: Align(
                        alignment: Alignment(
                          _controller.value * 2 - 1,
                          0,
                        ),
                        child: Container(
                          width: 52,
                          height: 3,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.deepRose,
                                AppColors.auroraRose,
                                AppColors.blushGold,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
