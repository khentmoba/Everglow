part of 'video_player_screen_web.dart';

abstract class _VideoPlayerScreenStateBase extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  Color get _playerAccent =>
      widget.isAnime ? AppColors.deepRose : NetflixColors.accent;
  Color get _playerSecondary =>
      widget.isAnime ? AppColors.softLavender : NetflixColors.textSecondary;
  Color get _playerText =>
      widget.isAnime ? AppColors.roseQuartz : NetflixColors.textPrimary;
  Color get _playerSurface =>
      widget.isAnime ? AppColors.inkDeep : NetflixColors.surface;
  Color get _playerSurfaceElevated =>
      widget.isAnime ? AppColors.surfaceGlass : NetflixColors.surfaceElevated;
  Color get _playerHairline =>
      widget.isAnime ? AppColors.border : NetflixColors.hairline;

  bool _isLoading = true;

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

  NextEpisode? _nextEpisode;
  bool _upNextVisible = false;
  int _upNextLeft = 10;
  Timer? _upNextTimer;
  bool _upNextDismissed = false;
  bool _autoFullscreen = false;
  bool _landscapeFullscreenDismissed = false;
  final NextEpisodeService _nextService = NextEpisodeService();
  static const int _upNextCountdownSeconds = 10;

  bool _hasSavedWatchProgress = false;
  bool _currentEpisodeCompleted = false;

  late int _currentSeason;
  late int _currentEpisode;

  String _currentUserName = '';

  Map<String, dynamic>? _details;

  static const Duration _loadTimeout = Duration(seconds: 15);

  static const Duration _contentCheckTimeout = Duration(seconds: 8);

  late VideoSourceConfig _selectedProvider;

  int? _resolvedStartSeconds;

  Future<void> _restoreFuture = Future.value();

  final PlayerMemoryService _memoryService = PlayerMemoryService();

  final Set<String> _failedProviderIds = {};

  bool _isFullscreen = false;
  double? _lastWindowedMaxPlayerHeight;
  double _preFullscreenScrollOffset = 0;
  bool _nativeFullscreenSettling = false;
  Timer? _nativeFullscreenSettleTimer;
  JSFunction? _onNativeFullscreenChange;

  bool get _isNativeFullscreenActive =>
      _nativeFullscreenSettling || web.document.fullscreenElement != null;

  final ScrollController _scrollController = ScrollController();
  double _playerAreaHeight = 0;

  static const Set<String> _playerKeys = {
    ' ', 'k', 'K', 'j', 'J', 'l', 'L',
    'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown',
    'm', 'M', 'f', 'F', 'c', 'C', 'n', 'N',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  };
  JSFunction? _keyForwarder;

  web.HTMLButtonElement? _fullscreenExitButton;
  web.HTMLDivElement? _playerHost;
  web.HTMLVideoElement? _videoElement;
  String? _currentMountedBlobUrl;
  bool _isOfflinePlayback = false;
  JSFunction? _videoLoadedListener;
  JSFunction? _videoTimeUpdateListener;
  JSFunction? _videoEndedListener;
  JSFunction? _videoErrorListener;
  JSFunction? _videoWheelListener;
  web.HTMLElement? _theaterPlatformView;
  String? _platformViewStyles;
  JSFunction? _onFullscreenExitListener;

  String get _currentDownloadId {
    if (widget.isAnime) {
      final animeId = widget.malId ?? widget.tmdbId;
      return OfflineMediaService.animeEpisodeId(animeId, _currentEpisode);
    }
    if (widget.mediaType == 'tv') {
      return OfflineMediaService.cinemaEpisodeId(
        widget.tmdbId,
        _currentSeason,
        _currentEpisode,
      );
    }
    return OfflineMediaService.cinemaMovieId(widget.tmdbId);
  }

  OfflineMediaItem? get _currentOfflineItem =>
      OfflineMediaService.instance.getItem(_currentDownloadId);

  bool get _isCurrentOfflineDownloaded =>
      _currentOfflineItem != null && _currentOfflineItem!.isCompleted;

  void _mountPlayerHost(web.HTMLDivElement host) {
    _playerHost = host;
    if (_isCurrentOfflineDownloaded) {
      _mountOfflineVideo(host, _currentOfflineItem!);
    } else {
      _mountOnlineIframe(host);
    }
  }

  void _mountOfflineVideo(web.HTMLDivElement host, OfflineMediaItem item) {
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _isOfflinePlayback = true;

    if (_videoElement == null) {
      _videoElement = web.HTMLVideoElement()
        ..controls = true
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000'
        ..setAttribute('playsinline', 'true')
        ..setAttribute('webkit-playsinline', 'true');

      _videoLoadedListener = ((web.Event _) {
        if (mounted) setState(() => _isLoading = false);
        _saveWatchProgress();
      }).toJS;
      _videoTimeUpdateListener = ((web.Event _) {
        if (!mounted || _videoElement == null) return;
        final pos = _videoElement!.currentTime.round();
        final dur = _videoElement!.duration.isFinite
            ? _videoElement!.duration.round()
            : 0;
        _playbackPositionSeconds = pos;
        if (dur > 0) _playbackDurationSeconds = dur;
        OfflineMediaService.instance.updatePlaybackPosition(item.id, pos);
        _saveWatchProgress();
      }).toJS;
      _videoEndedListener = ((web.Event _) {
        if (!mounted) return;
        if (widget.mediaType == 'tv' && _nextEpisode != null) {
          _playNextEpisode();
        }
      }).toJS;
      _videoErrorListener = ((web.Event _) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _iframeFailed = true;
          });
        }
      }).toJS;

      _videoElement!.addEventListener('loadeddata', _videoLoadedListener);
      _videoElement!.addEventListener('timeupdate', _videoTimeUpdateListener);
      _videoElement!.addEventListener('ended', _videoEndedListener);
      _videoElement!.addEventListener('error', _videoErrorListener);
      _videoWheelListener = ((web.Event event) {
        final wheel = event as web.WheelEvent;
        final delta = parseEverglowEmbedScrollDelta({
          'type': 'everglow-embed-scroll',
          'deltaY': wheel.deltaY,
          'deltaMode': wheel.deltaMode,
        });
        if (delta != null) _applyEmbedScroll(delta);
      }).toJS;
      _videoElement!.addEventListener('wheel', _videoWheelListener);
    }

    OfflineMediaService.instance.getPlayableUrl(item).then((url) {
      if (!mounted) return;
      if (url != null && url.isNotEmpty && _videoElement != null) {
        if (_currentMountedBlobUrl != null && _currentMountedBlobUrl != url) {
          unawaited(OfflineMediaStorage.instance.revokeBlobUrl(_currentMountedBlobUrl!));
        }
        _currentMountedBlobUrl = url;
        _videoElement!.src = url;
        final startSec = _resolvedStartSeconds ?? item.lastPositionSeconds ?? 0;
        if (startSec > 0) {
          _videoElement!.currentTime = startSec.toDouble();
        }
        _videoElement!.play();
      } else {
        _mountOnlineIframe(host);
      }
    });

    mountPlayerNode(host, _videoElement!);
  }

  bool _tryPlayOfflineEpisode(int season, int episode) {
    final animeId = widget.malId ?? widget.tmdbId;
    final nextDownloadId = widget.isAnime
        ? OfflineMediaService.animeEpisodeId(animeId, episode)
        : OfflineMediaService.cinemaEpisodeId(widget.tmdbId, season, episode);
    final nextOfflineItem = OfflineMediaService.instance.getItem(nextDownloadId);
    if (nextOfflineItem != null &&
        nextOfflineItem.isCompleted &&
        _playerHost != null) {
      _currentSeason = season;
      _currentEpisode = episode;
      _mountOfflineVideo(_playerHost!, nextOfflineItem);
      _resolveNextEpisode();
      _persistPlayerMemory(resetPosition: true);
      return true;
    } else if (_isOfflinePlayback && _playerHost != null) {
      _mountOnlineIframe(_playerHost!);
    }
    return false;
  }

  void _mountOnlineIframe(web.HTMLDivElement host) {
    _isOfflinePlayback = false;
    _videoElement?.pause();
    mountPlayerNode(host, _iframe);
  }

  final VideoSourceService _sourceService = VideoSourceService();

  VoidCallback? _serviceListener;

  VideoSourceConfig get _activeProvider => _selectedProvider;

  List<VideoSourceConfig> get _selectableProviders =>
      CinemaVideoSources.selectable(
        _sourceService.providers,
        isAnime: widget.isAnime,
      );

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
    final srcList = _selectableProviders;
    _selectedProvider = srcList.isNotEmpty
        ? srcList.first
        : _sourceService.defaultSource;
    _resolvedStartSeconds = widget.startSeconds;
    _currentUserName = context.read<AuthService>().currentUser ?? '';
    unawaited(_preferences.setUser(_currentUserName));
    _restoreFuture = _restorePlayerMemory();

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
    _onNativeFullscreenChange = ((web.Event _) {
      _nativeFullscreenSettleTimer?.cancel();
      if (web.document.fullscreenElement != null) {
        _nativeFullscreenSettling = false;
      } else {
        _nativeFullscreenSettling = true;
        _nativeFullscreenSettleTimer = Timer(
          const Duration(milliseconds: 260),
          () {
            _nativeFullscreenSettling = false;
            if (mounted) setState(() {});
          },
        );
      }
    }).toJS;
    web.document.addEventListener(
      'fullscreenchange',
      _onNativeFullscreenChange,
    );
    _installKeyForwarder();

    _currentSeason = widget.season ?? 1;
    _currentEpisode = widget.episode ?? 1;
    _currentEpisodeCompleted = widget.currentEpisodeCompleted;
    _playbackPositionSeconds = widget.startSeconds ?? 0;
    _resolveNextEpisode();

    if (widget.isAnime) {
      _bootstrapAnime();
    } else {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

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

  void _onEpisodeChanged(int episode) {
    if (episode == _currentEpisode) return;
    ++_restoreRevision;
    unawaited(_progressWriter.flush());
    _resetUpNextForNewEpisode();
    _playbackPositionSeconds = 0;
    _playbackDurationSeconds = 0;
    setState(() {
      _currentEpisode = episode;
      _currentEpisodeCompleted = false;
      _isLoading = true;
      _iframeFailed = false;
    });
    _failedProviderIds.clear();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();

    if (_tryPlayOfflineEpisode(_currentSeason, episode)) {
      return;
    }

    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _applySandbox(_selectedProvider);
    _iframe.src = _buildPlayerUrl(_selectedProvider);
    _resolveNextEpisode();
    _persistPlayerMemory(resetPosition: true);
  }

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
      _currentEpisodeCompleted = false;
      _isLoading = true;
      _iframeFailed = false;
    });
    _failedProviderIds.clear();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();

    if (_tryPlayOfflineEpisode(season, 1)) {
      return;
    }

    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _applySandbox(_selectedProvider);
    _iframe.src = _buildPlayerUrl(_selectedProvider);
    _resolveNextEpisode();
    _persistPlayerMemory(resetPosition: true);
  }

  void _saveWatchProgress() {
    if (_hasSavedWatchProgress) return;
    _hasSavedWatchProgress = true;
    _restoreFuture.whenComplete(_writeWatchProgress);
  }

  void _writeWatchProgress() {
    if (!mounted) return;

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
            title: _playerDisplayTitle(widget.title),
            mediaType: widget.mediaType,
            posterPath: widget.posterPath,
            status: status,
            isAnime: widget.isAnime,
            userName: userName,
            addedAt: DateTime.now(),
            source: widget.isAnime ? 'jikan' : 'tmdb',
          ),
          userName,
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

  void _startContentCheck() {
    if (_selectedProvider.id != 'vidlink') return;
    _contentCheckTimer?.cancel();
    _contentCheckTimer = Timer(_contentCheckTimeout, () {
      if (!mounted) return;
      _onIframeLoadError();
    });
  }

  JSFunction _buildMessageListener() {
    return ((web.Event e) {
      try {
        final msg = e as web.MessageEvent;
        final origin = msg.origin;
        final data = msg.data;
        if (data == null || !identical(msg.source, _iframe.contentWindow)) {
          return;
        }
        if (origin != Uri.parse(_iframe.src).origin) return;
        final wrapperMessage = data.dartify();
        final scrollDelta = parseEverglowEmbedScrollDelta(wrapperMessage);
        if (scrollDelta != null) {
          _applyEmbedScroll(scrollDelta);
          return;
        }
        if ((_selectedProvider.id == 'everglow-embed' ||
                _selectedProvider.id == 'everglow-shell') &&
            (wrapperMessage == 'animex-content-error' ||
                (wrapperMessage is Map &&
                    wrapperMessage['type'] == 'everglow-embed-failed'))) {
          _onIframeLoadError();
          return;
        }
        final hlsProgress = CinemaVideoSources.parseEverglowHlsProgress(
          _selectedProvider.id,
          origin,
          wrapperMessage,
          expectedEpisode: widget.mediaType == 'tv' ? _currentEpisode : null,
        );
        if (hlsProgress != null) {
          _contentCheckTimer?.cancel();
          _onPlaybackTick(hlsProgress.$1, hlsProgress.$2);
          return;
        }

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

        try {
          final obj = data.dartify();
          if (obj is Map && obj['type'] == 'cinesrc:timeupdate') {
            final position = obj['currentTime'];
            final duration = obj['duration'];
            if (CinemaVideoSources.trustsCinesrcProgressEvent(
                  _selectedProvider.id,
                  origin,
                ) &&
                position is num &&
                duration is num &&
                position.isFinite &&
                duration.isFinite &&
                position >= 0 &&
                duration > 0 &&
                position <= duration) {
              final positionSeconds = position.round();
              final durationSeconds = duration.round();
              if (durationSeconds > 0 && positionSeconds <= durationSeconds) {
                _contentCheckTimer?.cancel();
                _onPlaybackTick(positionSeconds, durationSeconds);
              }
            }
            return;
          }
        } catch (_) {
          // Ignore malformed CineSrc progress events.
        }

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
      }
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
      _currentEpisodeCompleted = false;
    });
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
        source: widget.isAnime ? 'jikan' : 'tmdb',
        mediaType: widget.mediaType,
        season: season,
        episode: episode,
        timestamp: position,
        durationSeconds: duration,
      );
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
    if (season != _currentSeason || episode != _currentEpisode) return;
    setState(() => _nextEpisode = next);
    _checkUpNext();
  }

  void _checkUpNext() {
    if (widget.mediaType != 'tv' || _nextEpisode == null) return;
    final completed = shouldAutoplayNext(
      enabled: _preferences.autoplayNext,
      positionSeconds: _playbackPositionSeconds,
      durationSeconds: _playbackDurationSeconds,
    );
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

  void _playNextEpisode() {
    final next = _nextEpisode;
    if (next == null) return;
    ++_restoreRevision;
    _upNextTimer?.cancel();
    unawaited(_progressWriter.flush());
    _hasSavedWatchProgress = false;
    _resolvedStartSeconds = null;
    setState(() {
      _currentSeason = next.season;
      _currentEpisode = next.episode;
      _currentEpisodeCompleted = false;
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

    if (_tryPlayOfflineEpisode(next.season, next.episode)) {
      return;
    }

    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _applySandbox(_selectedProvider);
    _iframe.src = _buildPlayerUrl(_selectedProvider);
    _resolveNextEpisode();
  }

  void _resetUpNextForNewEpisode() {
    _upNextTimer?.cancel();
    _hasSavedWatchProgress = false;
    _upNextVisible = false;
    _upNextDismissed = false;
    _nextEpisode = null;
    _resolvedStartSeconds = null;
  }

  void _maybeAutoFullscreen(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobilePlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobilePlatform) return;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (!isLandscape) _landscapeFullscreenDismissed = false;
    final isPhone = size.shortestSide < 600;
    if (!isPhone) return;
    if (isLandscape &&
        !_isFullscreen &&
        !_iframeFailed &&
        !_landscapeFullscreenDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _isFullscreen ||
            _iframeFailed ||
            _landscapeFullscreenDismissed ||
            MediaQuery.orientationOf(context) != Orientation.landscape ||
            MediaQuery.sizeOf(context).shortestSide >= 600) {
          return;
        }
        _autoFullscreen = true;
        _toggleFullScreen();
      });
    } else if (!isLandscape && _isFullscreen && _autoFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_isFullscreen ||
            !_autoFullscreen ||
            MediaQuery.orientationOf(context) != Orientation.portrait) {
          return;
        }
        _autoFullscreen = false;
        _toggleFullScreen();
      });
    }
  }

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

  String get _memoryKey => PlayerMemoryService.cinemaKey(
    id: _externalId,
    mediaType: widget.mediaType,
    isAnime: widget.isAnime,
  );

  Future<void> _restorePlayerMemory() async {
    final revision = _restoreRevision;
    final memory = await _memoryService.load(_memoryKey);
    if (!mounted || revision != _restoreRevision) return;
    var needsReload = false;

    final routeNamedSpot =
        widget.season != null ||
        widget.episode != null ||
        widget.startSeconds != null;
    final saved = routeNamedSpot || _currentUserName.isEmpty
        ? null
        : await TMDBService().getSavedProgress(
            widget.tmdbId,
            _currentUserName,
            source: widget.isAnime ? 'jikan' : 'tmdb',
            mediaType: widget.mediaType,
          );
    if (!mounted || revision != _restoreRevision) return;
    final live = saved == null || saved.isWatched ? null : saved;
    final cloudSeason = live?.currentSeason;
    final cloudEpisode = live?.currentEpisode;
    final cloudSeconds = live?.resumeSeconds;

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
    if (_iframe.src.isNotEmpty && _iframe.src != 'about:blank') {
      _iframe.src = _buildPlayerUrl(_selectedProvider);
    }
  }

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

  void _selectProvider(VideoSourceConfig provider, {bool retry = false}) {
    if (provider.id == _selectedProvider.id && !retry) return;
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

  void _applyEmbedScroll(double dy) {
    if (!mounted || _isFullscreen || web.document.fullscreenElement != null) {
      return;
    }
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final next = (position.pixels + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      position.jumpTo(next);
    }
  }

  void _toggleFullScreen() {
    final entering = !_isFullscreen;
    if (entering) {
      _preFullscreenScrollOffset = _scrollController.hasClients
          ? _scrollController.offset
          : 0;
      if (_scrollController.hasClients && _scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
      setState(() => _isFullscreen = true);
      _expandPlatformViewForTheater();
      _animateTheaterTransition();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isFullscreen) {
          _applyTheaterPlatformViewStyle();
        }
      });
      _showFullscreenExitButton();
      _setBodyOverflowHidden(true);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _restorePlatformViewStyle();
      setState(() => _isFullscreen = false);
      _animateTheaterTransition();
      final savedOffset = _preFullscreenScrollOffset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isFullscreen || !_scrollController.hasClients) return;
        if (savedOffset > 0) {
          final clamped = savedOffset.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(clamped);
        }
      });
      _hideFullscreenExitButton();
      _setBodyOverflowHidden(false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _animateTheaterTransition() {
    final host = _playerHost;
    if (host == null) return;
    host.style
      ..transition =
          'opacity 0.22s cubic-bezier(0.22, 1, 0.36, 1), transform 0.22s cubic-bezier(0.22, 1, 0.36, 1)'
      ..opacity = '0.88'
      ..transform = 'scale(0.985)';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      host.style
        ..opacity = '1'
        ..transform = 'scale(1)';
    });
  }

  web.HTMLElement? _findTheaterView() {
    try {
      final hostParent = _playerHost?.parentElement;
      if (hostParent != null) return hostParent as web.HTMLElement;
    } catch (_) {
      // Fall through to the iframe-anchored lookup.
    }
    try {
      final grandParent = _iframe.parentElement?.parentElement;
      if (grandParent != null) return grandParent as web.HTMLElement;
    } catch (_) {
      // Detached iframe; theater still works Flutter-side.
    }
    return null;
  }

  void _expandPlatformViewForTheater() {
    final platformView = _findTheaterView();
    if (platformView == null) return;
    _theaterPlatformView = platformView;
    _platformViewStyles ??= platformView.style.cssText;
    _applyTheaterPlatformViewStyle();
  }

  void _applyTheaterPlatformViewStyle() {
    final platformView = _theaterPlatformView ?? _findTheaterView();
    if (platformView == null) return;
    _theaterPlatformView = platformView;
    platformView.style
      ..position = 'fixed'
      ..display = 'block'
      ..top = '0'
      ..left = '0'
      ..width = '100vw'
      ..height = '100dvh'
      ..zIndex = '9999'
      ..transform = 'none'
      ..overflow = 'hidden';
  }

  String? _bodyOverflowPrev;

  void _setBodyOverflowHidden(bool hidden) {
    try {
      final body = web.document.body;
      if (body == null) return;
      if (hidden) {
        _bodyOverflowPrev ??= body.style.overflow;
        body.style.overflow = 'hidden';
      } else {
        final prev = _bodyOverflowPrev;
        _bodyOverflowPrev = null;
        body.style.overflow = prev ?? '';
      }
    } catch (_) {
      // DOM access is best-effort; theater still works Flutter-side.
    }
  }

  void _restorePlatformViewStyle() {
    final platformView = _theaterPlatformView;
    final styles = _platformViewStyles;
    _theaterPlatformView = null;
    _platformViewStyles = null;
    if (platformView != null && styles != null) {
      try {
        platformView.style.cssText = styles;
      } catch (_) {
        // Ignore restore failures on a detached view.
      }
    }
  }

  static const Map<String, String> _mediaKeyAliases = {
    'MediaPlayPause': ' ',
    'MediaFastForward': 'l',
    'MediaRewind': 'j',
    'MediaTrackNext': 'n',
  };

  void _installKeyForwarder() {
    _keyForwarder = ((web.KeyboardEvent event) {
      if (event.ctrlKey || event.metaKey || event.altKey) return;
      final rawKey = event.key;
      if (_isFullscreen &&
          (rawKey == 'Escape' ||
              rawKey == 'GoBack' ||
              rawKey == 'BrowserBack')) {
        _toggleFullScreen();
        event.preventDefault();
        return;
      }
      if (_selectedProvider.id != 'everglow-embed') return;
      if (_scrollController.hasClients &&
          _playerAreaHeight > 0 &&
          _scrollController.offset > _playerAreaHeight) {
        return;
      }
      try {
        final target = event.target;
        if (target != null) {
          final tag = (target as web.Element).tagName;
          if (tag == 'INPUT' || tag == 'TEXTAREA' || tag == 'SELECT') return;
        }
      } catch (_) {
        // Not an element; treat it as the page and carry on.
      }
      final key = _mediaKeyAliases[rawKey] ?? rawKey;
      if (key.isEmpty || !_playerKeys.contains(key)) return;
      try {
        _iframe.contentWindow?.postMessage(
          <String, String>{'type': 'everglow-key', 'key': key}.jsify(),
          CinemaVideoSources.proxyCinemaOrigin.toJS,
        );
        event.preventDefault();
      } catch (_) {
        // A detached frame simply drops the key.
      }
    }).toJS;
    web.document.addEventListener('keydown', _keyForwarder);
  }

  void _showFullscreenExitButton() {
    if (_fullscreenExitButton != null) return;
    final button = web.HTMLButtonElement()
      ..type = 'button'
      ..textContent = 'Exit theater'
      ..setAttribute('aria-label', 'Exit theater');
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
    _onFullscreenExitListener = ((web.Event _) {
      if (MediaQuery.sizeOf(context).shortestSide < 600 &&
          MediaQuery.orientationOf(context) == Orientation.landscape) {
        _landscapeFullscreenDismissed = true;
      }
      _autoFullscreen = false;
      _toggleFullScreen();
    }).toJS;
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
    _nativeFullscreenSettleTimer?.cancel();
    _nativeFullscreenSettling = false;
    if (_onNativeFullscreenChange != null) {
      web.document.removeEventListener(
        'fullscreenchange',
        _onNativeFullscreenChange,
      );
    }
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
    if (_keyForwarder != null) {
      web.document.removeEventListener('keydown', _keyForwarder);
      _keyForwarder = null;
    }
    if (_isFullscreen) {
      _restorePlatformViewStyle();
    }
    _setBodyOverflowHidden(false);
    _hideFullscreenExitButton();
    if (_currentMountedBlobUrl != null) {
      unawaited(OfflineMediaStorage.instance.revokeBlobUrl(_currentMountedBlobUrl!));
      _currentMountedBlobUrl = null;
    }
    unawaited(OfflineMediaService.instance.flushPlaybackPosition());
    if (_videoElement != null) {
      _videoElement!.pause();
      if (_videoLoadedListener != null) {
        _videoElement!.removeEventListener('loadeddata', _videoLoadedListener);
      }
      if (_videoTimeUpdateListener != null) {
        _videoElement!.removeEventListener('timeupdate', _videoTimeUpdateListener);
      }
      if (_videoEndedListener != null) {
        _videoElement!.removeEventListener('ended', _videoEndedListener);
      }
      if (_videoErrorListener != null) {
        _videoElement!.removeEventListener('error', _videoErrorListener);
      }
      if (_videoWheelListener != null) {
        _videoElement!.removeEventListener('wheel', _videoWheelListener);
      }
      _videoElement = null;
    }
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

  int get _externalId =>
      widget.isAnime ? (widget.malId ?? widget.tmdbId) : widget.tmdbId;

  int? _externalTmdbId;

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
      title: _playerDisplayTitle(widget.title),
    );
  }

  String _externalOpenUrl() {
    return _buildPlayerUrl(_activeProvider);
  }
}

@visibleForTesting
void mountPlayerNode(web.HTMLDivElement host, web.Node node) {
  host.replaceChildren(node);
}
