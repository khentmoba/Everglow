part of 'video_player_screen_web.dart';

abstract class _VideoPlayerScreenStateBase extends State<VideoPlayerScreen> {
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

  /// Providers offered for the active item. Cinema content promotes the
  /// ad-free FluxTV server first and keeps every existing source; anime
  /// playback keeps its existing Videasy-first list without FluxTV servers.
  List<VideoSourceConfig> get _selectableProviders =>
      CinemaVideoSources.selectable(
        _sourceService.providers,
        isAnime: widget.isAnime,
      );

  /// Looks up a provider in the list actually offered to this player,
  /// including cinema-only FluxTV servers that are not in the shared
  /// [VideoSourceService] registry.
  VideoSourceConfig? _providerById(String id) {
    for (final provider in _selectableProviders) {
      if (provider.id == id) return provider;
    }
    return null;
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
      // Movies don't have episode progress - write null so existing
      // movie docs get their stale season/episode fields cleared.
      season: widget.mediaType == 'tv' ? _currentSeason : null,
      episode: widget.mediaType == 'tv' ? _currentEpisode : null,
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
    final cfg = _providerById(providerId);
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
      final match = _providerById(savedId);
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
    final id = widget.isAnime ? (_activeTmdbId ?? _externalId) : _externalId;
    return buildVideoSourceUrl(
      provider,
      mediaType: widget.mediaType,
      id: id.toString(),
      season: _currentSeason,
      episode: _currentEpisode,
    );
  }

  /// The URL the user can open in a new tab. Uses the same URL the
  /// iframe would use for the current provider — if every embed has
  /// failed, this gives the user a manual escape hatch.
  String _externalOpenUrl() {
    return _buildPlayerUrl(_activeProvider);
  }

}
