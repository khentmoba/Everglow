part of 'video_player_screen_web.dart';

abstract class _VideoPlayerScreenStateBase extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;

  /// Set to true when the iframe fires `error`, returns no response
  /// within [_loadTimeout], or fails three URL-form retries. The error
  /// card takes over from the spinner in that case.
  bool _iframeFailed = false;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;
  JSFunction? _onErrorListener;
  Timer? _loadTimer;
  Timer? _contentCheckTimer;
  JSFunction? _messageListener;
  final PlaybackProgressWriter _progressWriter = PlaybackProgressWriter();
  final CinemaPreferences _preferences = CinemaPreferences.instance;
  int _restoreRevision = 0;
  int _memoryRevision = 0;
  int _playbackPositionSeconds = 0;
  int _playbackDurationSeconds = 0;

  // Opt-in autoplay requires trusted completion. Silent embeds keep manual Next.
  NextEpisode? _nextEpisode;
  bool _upNextVisible = false;
  int _upNextLeft = 10;
  Timer? _upNextTimer;
  bool _upNextDismissed = false;
  bool _autoFullscreen = false;
  final NextEpisodeService _nextService = NextEpisodeService();
  static const int _upNextCountdownSeconds = 10;

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

  /// Seek target for the initial embed URL. Starts as the route's `start`
  /// param; per-title memory fills it in when the route carries none.
  int? _resolvedStartSeconds;

  /// Resume lookup in flight. The first progress write waits for it so a
  /// slow lookup can't be beaten by a write of position 0 that erases the
  /// very spot we are about to resume from.
  Future<void> _restoreFuture = Future.value();

  /// Per-title comfort memory: last-used server, episode, and position.
  final PlayerMemoryService _memoryService = PlayerMemoryService();

  /// Tracks which providers have already been tried and failed during
  /// this session so auto-fallback doesn't re-try a dead source.
  final Set<String> _failedProviderIds = {};

  /// Whether the player is in custom fullscreen (theater) mode.
  bool _isFullscreen = false;

  /// Drives the page scroll view below the player.
  ///
  /// There is deliberately no wheel forwarding from the embed iframe:
  /// wheel events inside a cross-origin iframe never reach this
  /// document, so a listener on the iframe element can never fire.
  final ScrollController _scrollController = ScrollController();

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
    WidgetsBinding.instance.addObserver(this);
    _preferences.addListener(_onPreferencesChanged);
    // Restore this title's last-used server (or the saved global default),
    // falling back to the first recommended source from the service.
    final srcList = _selectableProviders;
    _selectedProvider = srcList.isNotEmpty
        ? srcList.first
        : _sourceService.defaultSource;
    _resolvedStartSeconds = widget.startSeconds;
    _currentUserName = context.read<AuthService>().currentUser ?? '';
    unawaited(_preferences.setUser(_currentUserName));
    _restoreFuture = _restorePlayerMemory();

    // Listen for provider list updates from Firestore. If the iframe
    // has already failed with the hardcoded defaults, retry with the
    // freshly loaded sources.
    _serviceListener = () {
      if (!mounted) return;
      final newList = _selectableProviders;
      if (newList.isNotEmpty && _iframeFailed) {
        debugPrint(
          '[VideoPlayerScreen] Providers updated from Firestore — retrying',
        );
        _failedProviderIds.clear();
        _selectedProvider = newList.firstWhere(
          (p) => !_failedProviderIds.contains(p.id),
          orElse: () => _sourceService.defaultSource,
        );
        setState(() {
          _iframeFailed = false;
          _isLoading = true;
        });
        _loadTimer?.cancel();
        _loadTimer = Timer(_loadTimeout, () {
          if (!mounted) return;
          if (_isLoading) _onIframeLoadError();
        });
        _applySandbox(_selectedProvider);
        _iframe.src = _buildPlayerUrl(_selectedProvider);
      }
    };
    _sourceService.addListener(_serviceListener!);

    _iframe = web.HTMLIFrameElement()
      ..allow =
          'autoplay *; fullscreen *; encrypted-media *; picture-in-picture *; accelerometer *; gyroscope *; clipboard-write *'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no');
    _applySandbox(_selectedProvider);
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

    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });

    _messageListener = _buildMessageListener();
    web.window.addEventListener('message', _messageListener);

    _currentSeason = widget.season ?? 1;
    _currentEpisode = widget.episode ?? 1;
    _playbackPositionSeconds = widget.startSeconds ?? 0;
    _resolveNextEpisode();

    // For anime we don't have a TMDB id on the MediaItem — the slot
    // holds the MAL id. Resolve MAL→TMDB via ani.zip, then set the
    // iframe's src once. If the lookup fails (no cross-reference
    // exists) we land in the error card and offer external links.
    if (widget.isAnime) {
      _bootstrapAnime();
    } else {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }

    // All orientations allowed — phones auto-enter theater mode in
    // landscape (see [_maybeAutoFullscreen]) instead of being locked.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    _resolveNextEpisode();
  }

  /// Called when the iframe fires `error` or the [_loadTimeout] fires
  /// while still loading. Marks the current provider as failed and
  /// automatically tries the next untried provider in [_providers].
  void _onIframeLoadError() {
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    if (!mounted) return;
    debugPrint(
      '[VideoPlayerScreen] Provider "${_selectedProvider.id}" failed (url: ${_buildPlayerUrl(_selectedProvider)})',
    );
    _failedProviderIds.add(_selectedProvider.id);
    _tryNextProvider();
  }

  /// Called when the user picks a different episode from [EpisodeNavigator].
  /// Rebuilds the iframe URL for the new episode and resets loading state.
  void _onEpisodeChanged(int episode) {
    if (episode == _currentEpisode) return;
    ++_restoreRevision;
    unawaited(_progressWriter.flush());
    _resetUpNextForNewEpisode();
    _playbackPositionSeconds = 0;
    _playbackDurationSeconds = 0;
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
    _applySandbox(_selectedProvider);
    _iframe.src = _buildPlayerUrl(_selectedProvider);
    _resolveNextEpisode();
    _persistPlayerMemory(resetPosition: true);
  }

  /// Called when the user picks a different season from [EpisodeNavigator].
  void _onSeasonChanged(int season) {
    if (season == _currentSeason) return;
    ++_restoreRevision;
    unawaited(_progressWriter.flush());
    _resetUpNextForNewEpisode();
    _playbackPositionSeconds = 0;
    _playbackDurationSeconds = 0;
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
    _applySandbox(_selectedProvider);
    _iframe.src = _buildPlayerUrl(_selectedProvider);
    _resolveNextEpisode();
    _persistPlayerMemory(resetPosition: true);
  }

  /// Saves or updates the watch progress in Firestore so the
  /// "Currently Watching" shelves across the app reflect what the
  /// user is watching right now. Runs once per playback session.
  void _saveWatchProgress() {
    if (_hasSavedWatchProgress) return;
    _hasSavedWatchProgress = true;
    _restoreFuture.whenComplete(_writeWatchProgress);
  }

  void _writeWatchProgress() {
    if (!mounted) return;

    // If the cached username is empty (shouldn't happen since we capture
    // it in initState, but be defensive), attempt a direct read.
    String userName = _currentUserName;
    if (userName.isEmpty) {
      try {
        userName = context.read<AuthService>().currentUser ?? '';
      } catch (e) {
        debugPrint(
          '[VideoPlayerScreen] Failed to read AuthService for username: $e',
        );
      }
    }
    if (userName.isEmpty) return;

    final tmdb = TMDBService();
    final status = _watchingStatusFor(userName);

    final season = widget.mediaType == 'tv' ? _currentSeason : null;
    final episode = widget.mediaType == 'tv' ? _currentEpisode : null;
    final timestamp = _playbackPositionSeconds;
    final duration = _playbackDurationSeconds > 0
        ? _playbackDurationSeconds
        : null;
    unawaited(
      _progressWriter.writeNow(
        () => tmdb.updateProgress(
          MediaItem(
            id: '',
            tmdbId: widget.tmdbId,
            title: widget.title,
            mediaType: widget.mediaType,
            posterPath: widget.posterPath,
            status: status,
            isAnime: widget.isAnime,
            userName: userName,
            addedAt: DateTime.now(),
            source: widget.isAnime ? 'jikan' : 'tmdb',
          ),
          userName,
          // Movies don't have episode progress - write null so existing
          // movie docs get their stale season/episode fields cleared.
          season: season,
          episode: episode,
          timestamp: timestamp,
          durationSeconds: duration,
          status: status,
        ),
      ),
    );
    _persistPlayerMemory();
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
        if (data == null || msg.source != _iframe.contentWindow) return;
        // All events must come from the active frame and its exact origin.
        if (origin != Uri.parse(_iframe.src).origin) return;
        final wrapperMessage = data.dartify();
        if (_selectedProvider.id == 'everglow-embed' &&
            wrapperMessage is Map &&
            wrapperMessage['type'] == 'everglow-embed-failed') {
          _onIframeLoadError();
          return;
        }

        // Videasy progress ticks (JSON string). Origin-checked inside
        // the parser — other providers stay silent here.
        try {
          final dataStr = data.toString();
          final videasy = parseVideasyProgress(origin, dataStr);
          if (videasy != null) {
            _contentCheckTimer?.cancel();
            _onPlaybackTick(
              videasy.positionSeconds.round(),
              videasy.durationSeconds.round(),
            );
            return;
          }
        } catch (_) {
          // Fall through to CineSrc / VidLink handling.
        }

        // CineSrc internal episode changes (auto-play or its episode
        // picker) arrive as objects. Trusted per provider: the direct
        // embed must speak from the real upstream origin, while our
        // wrapper's forwards were already origin-checked in embed.html.
        try {
          final obj = data.dartify();
          if (obj is Map && obj['type'] == 'cinesrc:nextepisode') {
            if (CinemaVideoSources.trustsCinesrcEpisodeEvent(
              _selectedProvider.id,
              origin,
            )) {
              final season = (obj['season'] as num?)?.toInt();
              final episode = (obj['episode'] as num?)?.toInt();
              if (season != null && episode != null && mounted) {
                _onPlayerEpisodeChanged(season, episode);
              }
            }
            return;
          }
        } catch (_) {
          // Not an object message — fall through to VidLink handling.
        }

        // Only accept messages from the active provider's origin
        final activeOrigin = _originForProvider(_selectedProvider.id);
        if (origin != activeOrigin) return;

        final map = data.dartify();
        if (map is! Map) return;
        final type = map['type'];
        if (type == 'MEDIA_DATA' || type == 'PLAYER_EVENT') {
          _contentCheckTimer?.cancel();
          final playback = _extractPlayback(map);
          if (playback != null && mounted) {
            _onPlaybackTick(playback.$1, playback.$2);
          }
        }
      } catch (e) {
        debugPrint(
          '[VideoPlayerScreen] Cross-origin postMessage parse error: $e',
        );
      } // ignore cross-origin / parse errors
    }).toJS;
  }

  (int, int)? _extractPlayback(dynamic value) {
    if (value is List) {
      for (final child in value) {
        final found = _extractPlayback(child);
        if (found != null) return found;
      }
      return null;
    }
    if (value is! Map) return null;

    var position = -1;
    var duration = 0;
    value.forEach((key, child) {
      final name = key.toString().replaceAll('_', '').toLowerCase();
      if (child is num && child >= 0) {
        if (name == 'currenttime' || name == 'position' || name == 'time') {
          position = child.round();
        } else if (name == 'duration') {
          duration = child.round();
        }
      }
    });

    if (position >= 0 && duration > 0) return (position, duration);
    for (final child in value.values) {
      final found = _extractPlayback(child);
      if (found != null) return found;
    }
    return null;
  }

  /// Follows the embed when CineSrc changes episodes on its own
  /// (auto-play or its built-in episode picker).
  ///
  /// Without this the navigator kept highlighting the finished episode
  /// while the frame played the next one — and the runtime-estimate
  /// fallback timer would later reload the already-playing episode from
  /// scratch. The new position re-resolves Up Next and reschedules the
  /// timer, while the iframe itself is never touched: no reload, no
  /// lost position. Anime-in-cinema is skipped (its MAL ids don't map
  /// to the reported TMDB season/episode; AnimeX is the anime path).
  void _onPlayerEpisodeChanged(int season, int episode) {
    if (!mounted || widget.mediaType != 'tv' || widget.isAnime) return;
    if (season <= 0 || episode <= 0) return;
    if (season == _currentSeason && episode == _currentEpisode) return;
    ++_restoreRevision;
    unawaited(_progressWriter.flush());
    _resetUpNextForNewEpisode();
    _playbackPositionSeconds = 0;
    _playbackDurationSeconds = 0;
    setState(() {
      _currentSeason = season;
      _currentEpisode = episode;
    });
    // Manual navigation reloads the iframe, whose load event saves
    // progress — with no reload we save explicitly instead.
    _saveWatchProgress();
    _resolveNextEpisode();
    _persistPlayerMemory(resetPosition: true);
  }

  void _startProgressHeartbeat() {
    if (_currentUserName.isEmpty) return;
    final user = _currentUserName;
    final season = widget.mediaType == 'tv' ? _currentSeason : null;
    final episode = widget.mediaType == 'tv' ? _currentEpisode : null;
    final position = _playbackPositionSeconds;
    final duration = _playbackDurationSeconds > 0
        ? _playbackDurationSeconds
        : null;
    final provider = _selectedProvider.id;
    final key = _memoryKey;
    final memoryRevision = _memoryRevision;
    _progressWriter.schedule(() async {
      await TMDBService().heartbeatProgress(
        widget.tmdbId,
        user,
        season: season,
        episode: episode,
        timestamp: position,
        durationSeconds: duration,
      );
      // A slow heartbeat must not overwrite newer local memory saved by
      // an episode/source change or exit after this tick was scheduled.
      if (!mounted || memoryRevision != _memoryRevision) return;
      final currentSeason = widget.mediaType == 'tv' ? _currentSeason : null;
      final currentEpisode = widget.mediaType == 'tv' ? _currentEpisode : null;
      if (season != currentSeason ||
          episode != currentEpisode ||
          provider != _selectedProvider.id ||
          key != _memoryKey) {
        return;
      }
      await _memoryService.save(
        key,
        providerId: provider,
        season: season,
        episode: episode,
        positionSeconds: position,
      );
    });
  }

  /// Real progress replaces estimates; the throttle never restarts on a tick.
  void _onPlaybackTick(int position, int duration) {
    if (!mounted) return;
    if (position != _playbackPositionSeconds ||
        duration != _playbackDurationSeconds) {
      setState(() {
        _playbackPositionSeconds = position;
        _playbackDurationSeconds = duration;
      });
      _startProgressHeartbeat();
    }
    _checkUpNext();
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    if (!_preferences.autoplayNext && _upNextVisible) _cancelUpNext();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _startProgressHeartbeat();
      _persistPlayerMemory();
      unawaited(_progressWriter.flush());
    }
  }

  /// Resolves the episode after the current one for the Up Next card
  /// and the persistent Next pill. TV only — movies have no next.
  Future<void> _resolveNextEpisode() async {
    if (widget.mediaType != 'tv') return;
    final tmdbId = widget.isAnime ? _activeTmdbId : widget.tmdbId;
    if (tmdbId == null) return;
    final season = _currentSeason;
    final episode = _currentEpisode;
    final next = await _nextService.resolve(
      tmdbId: tmdbId,
      season: season,
      episode: episode,
    );
    if (!mounted) return;
    // Stale response (user zapped episodes mid-flight) — drop it.
    if (season != _currentSeason || episode != _currentEpisode) return;
    setState(() => _nextEpisode = next);
    _checkUpNext();
  }

  /// Completion comes from the active player, never from elapsed time.
  void _checkUpNext() {
    if (widget.mediaType != 'tv' || _nextEpisode == null) return;
    final completed = shouldAutoplayNext(
      enabled: _preferences.autoplayNext,
      positionSeconds: _playbackPositionSeconds,
      durationSeconds: _playbackDurationSeconds,
    );
    // Rewinding during the countdown hides it so replay isn't
    // interrupted; reaching the end again re-triggers it.
    if (_upNextVisible) {
      if (!completed) {
        _upNextTimer?.cancel();
        if (mounted) setState(() => _upNextVisible = false);
      }
      return;
    }
    if (_upNextDismissed) return;
    if (completed) _showUpNext();
  }

  NextEpisode get _safeNextEpisode => _preferences.hideSpoilers
      ? NextEpisode(
          season: _nextEpisode!.season,
          episode: _nextEpisode!.episode,
        )
      : _nextEpisode!;

  void _showUpNext() {
    if (_upNextVisible || _upNextDismissed) return;
    if (_nextEpisode == null || !mounted) return;
    setState(() {
      _upNextVisible = true;
      _upNextLeft = _upNextCountdownSeconds;
    });
    _upNextTimer?.cancel();
    _upNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_preferences.autoplayNext) {
        timer.cancel();
        return;
      }
      if (_upNextLeft <= 1) {
        timer.cancel();
        _playNextEpisode();
        return;
      }
      setState(() => _upNextLeft--);
    });
  }

  void _cancelUpNext() {
    _upNextTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _upNextVisible = false;
      _upNextDismissed = true;
    });
  }

  /// Plays the resolved next episode (same-season or season premiere).
  /// Reloads the iframe in place — Clair never leaves the player.
  void _playNextEpisode() {
    final next = _nextEpisode;
    if (next == null) return;
    ++_restoreRevision;
    _upNextTimer?.cancel();
    unawaited(_progressWriter.flush());
    _hasSavedWatchProgress = false;
    // New episode starts from the beginning — same as
    // [_resetUpNextForNewEpisode], which this path inlines.
    _resolvedStartSeconds = null;
    setState(() {
      _currentSeason = next.season;
      _currentEpisode = next.episode;
      _isLoading = true;
      _iframeFailed = false;
      _upNextVisible = false;
      _upNextDismissed = false;
      _nextEpisode = null;
      _playbackPositionSeconds = 0;
      _playbackDurationSeconds = 0;
    });
    _failedProviderIds.clear();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _applySandbox(_selectedProvider);
    _iframe.src = _buildPlayerUrl(_selectedProvider);
    _resolveNextEpisode();
  }

  /// Resets Up Next state when the episode changes by any other path
  /// (navigator, season switch, player auto-advance). The caller
  /// re-resolves + reschedules. The resume offset is dropped too: it
  /// belongs to the previous episode, and keeping it would seek the
  /// new episode into the middle (or past its end).
  void _resetUpNextForNewEpisode() {
    _upNextTimer?.cancel();
    _hasSavedWatchProgress = false;
    _upNextVisible = false;
    _upNextDismissed = false;
    _nextEpisode = null;
    _resolvedStartSeconds = null;
  }

  /// Auto-enters theater mode when a phone rotates to landscape, and
  /// auto-exits when it rotates back to portrait. Tablets/desktops and
  /// manual toggles are never touched.
  void _maybeAutoFullscreen(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPhone = size.shortestSide < 600;
    if (!isPhone) return;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (isLandscape && !_isFullscreen && !_iframeFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isFullscreen) return;
        _autoFullscreen = true;
        _toggleFullScreen();
      });
    } else if (!isLandscape && _isFullscreen && _autoFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isFullscreen || !_autoFullscreen) return;
        _autoFullscreen = false;
        _toggleFullScreen();
      });
    }
  }

  /// Returns the expected postMessage origin for a given provider.
  /// Derives the origin from the provider's movie URL (the host portion).
  String _originForProvider(String providerId) {
    final cfg = _providerById(providerId);
    if (cfg == null) return '';
    try {
      final uri = Uri.parse(cfg.movieUrl);
      return uri.origin;
    } catch (_) {
      return '';
    }
  }

  /// Per-title memory key. Anime items are keyed by MAL id (the id this
  /// player navigates with), everything else by TMDB id.
  String get _memoryKey => PlayerMemoryService.cinemaKey(
    id: _externalId,
    mediaType: widget.mediaType,
    isAnime: widget.isAnime,
  );

  /// Restores this title's last-used server, episode, and position.
  /// Explicit route params (tapped episode, Continue Watching resume)
  /// always win; memory only fills in what the route didn't specify.
  /// Falls back to the saved global default server when the title has
  /// no memory yet (non-anime only — anime keeps its Videasy default).
  Future<void> _restorePlayerMemory() async {
    final revision = _restoreRevision;
    final memory = await _memoryService.load(_memoryKey);
    if (!mounted || revision != _restoreRevision) return;
    var needsReload = false;

    // Episode + position follow the account, not the device: what Clair
    // watched last on the tablet beats what this phone remembers. Only
    // asked when the route didn't already say where to start.
    final routeNamedSpot =
        widget.season != null ||
        widget.episode != null ||
        widget.startSeconds != null;
    final saved = routeNamedSpot || _currentUserName.isEmpty
        ? null
        : await TMDBService().getSavedProgress(widget.tmdbId, _currentUserName);
    if (!mounted || revision != _restoreRevision) return;
    // A finished title starts over instead of jumping to its credits.
    final live = saved == null || saved.isWatched ? null : saved;
    final cloudSeason = live?.currentSeason;
    final cloudEpisode = live?.currentEpisode;
    final cloudSeconds = live?.resumeSeconds;

    // Server: per-title memory first, then the global default.
    final rememberedId = memory.providerId;
    VideoSourceConfig? match = rememberedId == null
        ? null
        : _providerById(rememberedId);
    if (match == null && !widget.isAnime) {
      final savedId = await _sourceService.loadDefaultSourceId();
      if (!mounted || revision != _restoreRevision) return;
      match = savedId == null ? null : _providerById(savedId);
    }
    if (match != null &&
        !_failedProviderIds.contains(match.id) &&
        match.id != _selectedProvider.id) {
      _selectedProvider = match;
      _applySandbox(match);
      needsReload = true;
    }

    // Episode: only when the route didn't name one.
    final hasCloudEpisode =
        widget.mediaType == 'tv' &&
        cloudSeason != null &&
        cloudSeason > 0 &&
        cloudEpisode != null &&
        cloudEpisode > 0;
    if (widget.mediaType == 'tv') {
      final season = hasCloudEpisode ? cloudSeason : memory.season;
      final episode = hasCloudEpisode ? cloudEpisode : memory.episode;
      if (widget.season == null && season != null && season > 0) {
        if (season != _currentSeason) needsReload = true;
        _currentSeason = season;
      }
      if (widget.episode == null && episode != null && episode > 0) {
        if (episode != _currentEpisode) needsReload = true;
        _currentEpisode = episode;
      }
    }

    // Position: only when the route didn't carry one, and only when the
    // saved position belongs to the episode being opened — otherwise a
    // resume point from one episode would seek a different episode.
    final cloudSameEpisode = widget.mediaType != 'tv'
        ? live != null
        : hasCloudEpisode &&
              cloudSeason == _currentSeason &&
              cloudEpisode == _currentEpisode;
    final localSameEpisode =
        memory.season == _currentSeason && memory.episode == _currentEpisode;
    final resumeSeconds = cloudSameEpisode && cloudSeconds != null
        ? cloudSeconds
        : (localSameEpisode ? memory.positionSeconds : null);
    if (widget.startSeconds == null &&
        _resolvedStartSeconds == null &&
        resumeSeconds != null &&
        resumeSeconds > 0) {
      _resolvedStartSeconds = resumeSeconds;
      _playbackPositionSeconds = resumeSeconds;
      needsReload = true;
    }

    if (!needsReload) return;
    setState(() {});
    // If the iframe already has a src (non-anime path sets it
    // synchronously in initState), reload it with the restored choices.
    // Otherwise initState/_bootstrapAnime picks them up when setting src.
    if (_iframe.src.isNotEmpty && _iframe.src != 'about:blank') {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }
  }

  /// Persists the current server/episode/position for this title so the
  /// next visit reopens exactly where Clair left off. Fire-and-forget.
  void _persistPlayerMemory({bool resetPosition = false}) {
    ++_memoryRevision;
    _memoryService.save(
      _memoryKey,
      providerId: _selectedProvider.id,
      season: widget.mediaType == 'tv' ? _currentSeason : null,
      episode: widget.mediaType == 'tv' ? _currentEpisode : null,
      positionSeconds: _playbackPositionSeconds > 0
          ? _playbackPositionSeconds
          : null,
      clearPosition: resetPosition,
    );
  }

  /// Applies the `sandbox` attribute when the provider is marked
  /// `sandboxSafe`. Sandboxing kills popups/top-navigation without a
  /// server round-trip — ideal for CineSrc/Movish/VidBolt.
  void _applySandbox(VideoSourceConfig provider) {
    if (provider.sandboxSafe) {
      _iframe.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-presentation allow-pointer-lock',
      );
    } else {
      _iframe.removeAttribute('sandbox');
    }
  }

  /// Find the next untried provider and switch to it. If every
  /// provider has been tried, show the error card.
  void _tryNextProvider() {
    ++_restoreRevision;
    _resolvedStartSeconds = _playbackPositionSeconds;
    _cancelUpNext();
    final next = _selectableProviders.cast<VideoSourceConfig?>().firstWhere(
      (p) => !_failedProviderIds.contains(p!.id),
      orElse: () => null,
    );
    if (next != null) {
      debugPrint(
        '[VideoPlayerScreen] Trying next provider: "${next.id}" (${_failedProviderIds.length} failed so far)',
      );
      setState(() {
        _selectedProvider = next;
        _isLoading = true;
        _iframeFailed = false;
      });
      _loadTimer = Timer(_loadTimeout, () {
        if (!mounted) return;
        if (_isLoading) _onIframeLoadError();
      });
      _applySandbox(next);
      _iframe.src = _buildPlayerUrl(next);
    } else {
      debugPrint(
        '[VideoPlayerScreen] All ${_selectableProviders.length} providers failed — showing error card',
      );
      setState(() => _iframeFailed = true);
    }
  }

  /// Called when the user picks a different provider from the dropdown
  /// or error card. Clears the failed set so the chosen provider gets
  /// a fresh attempt.
  void _selectProvider(VideoSourceConfig provider) {
    if (provider.id == _selectedProvider.id) return;
    ++_restoreRevision;
    _resolvedStartSeconds = _playbackPositionSeconds;
    _cancelUpNext();
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
    _applySandbox(provider);
    _iframe.src = _buildPlayerUrl(provider);
    _persistPlayerMemory();
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
    // Standalone-web only: keep the chip below the iPhone status bar
    // so it stays tappable. Everywhere else the inset is 0.
    final topInset = WebStandalone.safeAreaTop();
    button.style
      ..position = 'fixed'
      ..top = '${16 + topInset}px'
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
    WidgetsBinding.instance.removeObserver(this);
    _preferences.removeListener(_onPreferencesChanged);
    _upNextTimer?.cancel();
    _startProgressHeartbeat();
    _persistPlayerMemory();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    unawaited(_progressWriter.flush());
    if (_serviceListener != null) {
      _sourceService.removeListener(_serviceListener!);
    }
    if (_onLoadListener != null) {
      _iframe.removeEventListener('load', _onLoadListener);
    }
    if (_onErrorListener != null) {
      _iframe.removeEventListener('error', _onErrorListener);
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
    _iframe.remove();
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
  int get _externalId =>
      widget.isAnime ? (widget.malId ?? widget.tmdbId) : widget.tmdbId;

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
      startSeconds: _resolvedStartSeconds,
    );
  }

  /// The URL the user can open in a new tab. Uses the same URL the
  /// iframe would use for the current provider — if every embed has
  /// failed, this gives the user a manual escape hatch.
  String _externalOpenUrl() {
    return _buildPlayerUrl(_activeProvider);
  }
}
