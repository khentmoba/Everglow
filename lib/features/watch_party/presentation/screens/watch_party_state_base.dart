part of 'watch_party_screen_web.dart';

abstract class _WatchPartyScreenStateBase extends State<WatchPartyScreen>
    with TickerProviderStateMixin {
  late final WatchPartyService _service;
  late final AuthService _auth;
  late WatchPartyRoom _room;
  late String _myUid;
  late String _partnerName;

  StreamSubscription<WatchPartyRoom?>? _roomSub;

  DateTime? _anchorEpoch;
  double _anchorTime = 0.0;

  bool _hasAppliedInitialSnapshot = false;

  bool _isResyncing = false;
  Timer? _resyncHideTimer;

  bool _showEndDialog = false;
  void Function(bool)? _endDialogCallback;

  bool _hostExplicitlyPaused = false;

  bool _autoplay = true;

  DateTime? _lastRemoteUpdate;

  bool _cinesrcReady = false;

  DateTime _ignorePlayerEventsUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool _userSeekPending = false;
  Timer? _playCheckTimer;

  bool _isLoading = true;
  bool _iframeFailed = false;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;
  JSFunction? _onErrorListener;
  Timer? _loadTimer;

  Timer? _contentCheckTimer;

  final ScrollController _pageScrollController = ScrollController();

  double? _lastWindowedMaxPlayerHeight;
  bool _isNativeFullscreenActive = false;
  Timer? _nativeFullscreenSettleTimer;
  JSFunction? _onNativeFullscreenChange;

  JSFunction? _messageListener;

  int? _resolvedTmdbId;

  late VideoSourceConfig _selectedProvider;
  final Set<String> _failedProviderIds = {};

  final VideoSourceService _sourceService = VideoSourceService();

  VoidCallback? _serviceListener;

  final HlsServerPlayerController _hlsController = HlsServerPlayerController();
  late String _hlsViewType;
  bool _hlsFailed = false;
  bool _hlsReady = false;
  String? _hlsError;

  double _hlsVolume = 1.0;

  final PlayerMemoryService _playerMemory = PlayerMemoryService();

  late final WatchPartyClock _clock;

  final WatchPartyStreamResolver _streamResolver = WatchPartyStreamResolver();
  String? _everglowStreamUrl;
  List<WatchPartySubtitle> _availableSubtitles = const [];
  bool _resolvingStream = false;
  String? _streamResolveError;

  bool _captionsOn = true;

  bool _seededLegacyAnchor = false;

  void _regenerateHlsViewType() {
    _hlsViewType =
        'everglow-watchparty-hls-${_room.id}-${DateTime.now().microsecondsSinceEpoch}';
  }

  String get _hlsVolumeKey => PlayerMemoryService.watchPartyKey(_room.id);

  Future<void> _restoreHlsVolume() async {
    final memory = await _playerMemory.load(_hlsVolumeKey);
    if (!mounted) return;
    final volume = (memory.volume ?? PlayerMemoryService.defaultVolume).clamp(
      0.0,
      1.0,
    );
    setState(() => _hlsVolume = volume);
    _hlsController.setVolume(volume);
  }

  void _persistHlsVolume(double volume) {
    _playerMemory.save(_hlsVolumeKey, volume: volume.clamp(0.0, 1.0));
  }

  bool get _isEverglowServer => _room.serverType == 'everglow';

  bool get _isHlsServer =>
      _isEverglowServer ||
      (_room.serverType == 'hls' && (_room.streamUrl ?? '').isNotEmpty);

  bool get _isEmbedServer =>
      _room.serverType == 'embed' && (_room.streamUrl ?? '').isNotEmpty;

  bool get _usesIframe => !_isHlsServer;

  bool get _isHlsMounted => _isHlsServer && _hlsStreamUrl.isNotEmpty;

  String? get _effectiveSubtitleUrl {
    if (!_captionsOn) return null;
    final chosen = _room.subtitleUrl;
    if (chosen != null && chosen.isNotEmpty) return chosen;
    if (_availableSubtitles.isNotEmpty) return _availableSubtitles.first.url;
    return null;
  }

  String get _hlsStreamUrl {
    if (_isEverglowServer) return _everglowStreamUrl ?? '';
    final raw = _room.streamUrl ?? '';
    if (_room.proxyEnabled) return WatchPartyServerService.proxyUrlFor(raw);
    return raw;
  }

  final VoiceChatService _voiceChat = VoiceChatService();

  Timer? _heartbeatTimer;

  Timer? _clockTicker;
  double _displayedTime = 0.0;

  bool _seeking = false;

  static const double _resyncThresholdSeconds = 4.0;

  static const Duration _loadTimeout = Duration(seconds: 15);

  static const Duration _contentCheckTimeout = Duration(seconds: 8);

  static const Duration _heartbeatInterval = Duration(seconds: 5);

  List<VideoSourceConfig> get _providers => _sourceService.providers;
}

abstract class _WatchPartyScreenStateCore extends _WatchPartyScreenStateBase {
  @override
  void initState() {
    super.initState();
    _service = WatchPartyService();
    _clock = WatchPartyClock();
    _auth = context.read<AuthService>();
    _room = widget.initialRoom;
    _myUid = _auth.uid ?? '';
    _partnerName = _auth.partnerName;
    _captionsOn = _room.captionsOn;
    debugPrint(
      'WatchPartyScreen init: tmdbId=${_room.tmdbId}, mediaType=${_room.mediaType}, isAnime=${_room.isAnime}, season=${_room.season}, episode=${_room.episode}',
    );

    if (widget.isHost) {
      _hostExplicitlyPaused = _room.state == 'paused';
    } else {
      _hostExplicitlyPaused = _room.state == 'paused';
    }
    _autoplay = !_hostExplicitlyPaused;

    _selectedProvider = _sourceService.defaultSource;
    _regenerateHlsViewType();
    _restoreHlsVolume();

    _serviceListener = () {
      if (!mounted) return;
      if (!_usesIframe) return;
      final newList = _sourceService.providers;
      if (newList.isNotEmpty && _iframeFailed) {
        debugPrint(
          '[WatchPartyScreen] Providers updated from Firestore — retrying',
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
        _loadTimer = Timer(_WatchPartyScreenStateBase._loadTimeout, () {
          if (!mounted) return;
          if (_isLoading) _onIframeLoadError();
        });
        _applySandbox(_selectedProvider);
        _cinesrcReady = false;
        _iframe.src = _buildPlayerUrl(_selectedProvider, startSeconds: 0);
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _startContentCheck();
      _anchorEpoch = DateTime.now();
      _anchorTime = _localStartHint();
    }).toJS;
    _onErrorListener = ((web.Event _) {
      _onIframeLoadError();
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);
    _iframe.addEventListener('error', _onErrorListener);

    _messageListener = _buildMessageListener();
    web.window.addEventListener('message', _messageListener);
    _onNativeFullscreenChange = ((web.Event _) {
      final active = web.document.fullscreenElement != null;
      _nativeFullscreenSettleTimer?.cancel();
      if (active) {
        _isNativeFullscreenActive = true;
      } else {
        _isNativeFullscreenActive = true;
        _nativeFullscreenSettleTimer = Timer(
          const Duration(milliseconds: 260),
          () {
            _isNativeFullscreenActive = false;
            if (mounted) setState(() {});
          },
        );
      }
    }).toJS;
    web.document.addEventListener(
      'fullscreenchange',
      _onNativeFullscreenChange,
    );

    if (_usesIframe) {
      _loadTimer = Timer(_WatchPartyScreenStateBase._loadTimeout, () {
        if (!mounted) return;
        if (_isLoading) _onIframeLoadError();
      });
    }

    if (_isHlsServer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isEverglowServer) {
          unawaited(_resolveEverglowStream(startSeconds: _localStartHint()));
        } else {
          _reloadHlsAt(_localStartHint());
        }
      });
    } else if (_isEmbedServer) {
      _cinesrcReady = false;
      _iframe.src = _room.streamUrl!;
    } else {
      if (_room.isAnime) {
        _bootstrapAnime();
      } else {
        _cinesrcReady = false;
        _iframe.src = _buildPlayerUrl(
          _selectedProvider,
          startSeconds: _localStartHint(),
        );
      }
    }

    _roomSub = _service.getRoomStream(_room.id).listen(_onRoomUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_room.active && _room.updatedBy != _myUid) {
        unawaited(_voiceChat.endCall());
        Navigator.of(context).pop();
      }
    });

    _startClockTicker();
    _startHeartbeat();

    _initVoiceChat();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initVoiceChat() async {
    final partnerUid = _auth.partnerUid;
    if (partnerUid == null) return;
    if (!_room.active) return;
    VoiceChatService.clearIncomingWatcher();
    await _voiceChat.init(
      roomId: _room.id,
      myUid: _myUid,
      remoteUid: partnerUid,
      isCaller: widget.isHost,
      callerName: widget.isHost ? _auth.currentUser : _room.hostName,
      mediaTitle: _room.title,
      mediaPosterPath: _room.posterPath,
      mediaType: _room.mediaType,
      tmdbId: _room.tmdbId != 0 ? _room.tmdbId : null,
      malId: _room.malId,
      isAnime: _room.isAnime,
      season: _room.season,
      episode: _room.episode,
    );
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _playCheckTimer?.cancel();
    _clockTicker?.cancel();
    _resyncHideTimer?.cancel();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _nativeFullscreenSettleTimer?.cancel();
    if (_onNativeFullscreenChange != null) {
      web.document.removeEventListener(
        'fullscreenchange',
        _onNativeFullscreenChange,
      );
    }
    _roomSub?.cancel();
    _streamResolver.dispose();
    _voiceChat.dispose();
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
    _iframe.src = 'about:blank';
    _iframe.remove();
    _pageScrollController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  double _estimatedLocalTime() {
    if (_isHlsServer && _hlsController.isAttached && _hlsReady) {
      return _hlsController.currentTime;
    }
    if (_anchorEpoch == null) {
      return _room.livePositionAt(_clock.serverNow);
    }
    if (_hostExplicitlyPaused) return _anchorTime;
    final elapsed =
        DateTime.now().difference(_anchorEpoch!).inMilliseconds / 1000.0;
    return _anchorTime + elapsed;
  }

  double _positionForWrite() => _estimatedLocalTime();

  double _localStartHint() => _room.livePositionAt(_clock.serverNow);

  void _startClockTicker() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _seeking) return;
      setState(() {
        _displayedTime = _estimatedLocalTime();
      });
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      _WatchPartyScreenStateBase._heartbeatInterval,
      (_) async {
        if (!mounted) return;
        final publishing = _isHlsServer
            ? (_hlsController.isAttached &&
                _hlsReady &&
                _hlsController.isPlaying)
            : !_hostExplicitlyPaused;
        await _service.heartbeat(
          roomId: _room.id,
          beatBy: _myUid,
          currentTime: publishing ? _estimatedLocalTime() : null,
        );
      },
    );
  }

  Future<void> _bootstrapAnime() async {
    final malId = _room.malId ?? _room.tmdbId;
    var tmdbId = await AniZipService().fetchTmdbId(malId);
    if (tmdbId == null && malId > 0) {
      try {
        final mappings = await AniZipService().fetchMappingsByAnilist(malId);
        final raw = mappings?['mappings']?['themoviedb_id'];
        if (raw is num) tmdbId = raw.toInt();
        if (raw is String) tmdbId = int.tryParse(raw);
      } catch (e, st) {
        Logger.e(
          'WatchParty: AniZip Anilist fallback failed',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (!mounted) return;
    if (tmdbId == null) {
      setState(() => _iframeFailed = true);
      _loadTimer?.cancel();
      return;
    }
    _resolvedTmdbId = tmdbId;
    _cinesrcReady = false;
    _iframe.src = _buildPlayerUrl(
      _selectedProvider,
      startSeconds: _localStartHint(),
    );
  }

  bool _mediaIdentityChanged(WatchPartyRoom a, WatchPartyRoom b) {
    return a.tmdbId != b.tmdbId ||
        a.malId != b.malId ||
        a.mediaType != b.mediaType ||
        a.isAnime != b.isAnime ||
        a.season != b.season ||
        a.episode != b.episode ||
        a.serverType != b.serverType ||
        a.serverName != b.serverName ||
        a.streamUrl != b.streamUrl ||
        a.proxyEnabled != b.proxyEnabled;
  }

  void _onRoomUpdate(WatchPartyRoom? incoming) {
    if (!mounted) return;
    if (incoming == null) {
      _showEndedAndPop();
      return;
    }
    if (!incoming.active) {
      _showEndedAndPop();
      return;
    }

    final looksPending =
        incoming.updatedAt.difference(DateTime.now()).abs() <
        const Duration(seconds: 1);
    if (!looksPending &&
        _lastRemoteUpdate != null &&
        incoming.updatedAt.isBefore(_lastRemoteUpdate!)) {
      debugPrint(
        'WatchPartyScreen _onRoomUpdate: discarding out-of-order update (updatedAt=${incoming.updatedAt} < last=$_lastRemoteUpdate)',
      );
      return;
    }
    _lastRemoteUpdate = incoming.updatedAt;
    _clock.observe(incoming.updatedAt);

    final mediaChanged = _mediaIdentityChanged(incoming, _room);
    final captionsChanged =
        incoming.subtitleUrl != _room.subtitleUrl ||
        incoming.captionsOn != _room.captionsOn;
    final stateChanged = (incoming.state == 'paused') != _hostExplicitlyPaused;
    final isLocalWrite =
        incoming.updatedBy == _myUid &&
        (incoming.beatBy == null || incoming.beatBy == _myUid);
    debugPrint(
      'WatchPartyScreen _onRoomUpdate: isLocal=$isLocalWrite, state=${incoming.state}, time=${incoming.currentTime}, updatedBy=${incoming.updatedBy}',
    );
    if (isLocalWrite && !mediaChanged && !stateChanged && !captionsChanged) {
      _room = incoming;
      return;
    }
    final wasHlsMounted = _isHlsMounted;
    _room = incoming;
    _hostExplicitlyPaused = incoming.state == 'paused';
    _captionsOn = incoming.captionsOn;

    if (!_seededLegacyAnchor &&
        incoming.positionAt == null &&
        incoming.state == 'playing') {
      _seededLegacyAnchor = true;
      unawaited(
        _service.updatePlayback(
          roomId: incoming.id,
          state: 'playing',
          currentTime: incoming.livePositionAt(_clock.serverNow),
          updatedBy: _myUid,
        ),
      );
    }

    if (mediaChanged) {
      _autoplay = true;
      _anchorEpoch = DateTime.now();
      _anchorTime = 0.0;
      if (_isEverglowServer) {
        _hlsReady = false;
        _isResyncing = true;
        _everglowStreamUrl = null;
        _availableSubtitles = const [];
        unawaited(_resolveEverglowStream(startSeconds: 0));
      } else if (_isHlsServer) {
        _reloadHlsAt(0);
      } else if (_isEmbedServer) {
        _cinesrcReady = false;
        _iframe.src = _room.streamUrl!;
      } else if (_room.isAnime) {
        _bootstrapAnime();
      } else {
        _cinesrcReady = false;
        _iframe.src = _buildPlayerUrl(_selectedProvider, startSeconds: 0);
      }
      if (!(wasHlsMounted && _isHlsMounted)) {
        _regenerateHlsViewType();
      }
      setState(() {});
      return;
    }

    if (captionsChanged) {
      _hlsController.setCaptions(_captionsOn);
      setState(() {});
    }

    if (stateChanged) {
      _autoplay = !_hostExplicitlyPaused;
      final live = incoming.livePositionAt(_clock.serverNow);
      if (_isHlsServer) {
        _applyHlsState(incoming);
        setState(() {});
      } else if (_isControlledEmbed) {
        _syncPlayerTo(live, paused: _hostExplicitlyPaused);
        setState(() {});
      } else {
        _rebuildAt(live);
      }
      return;
    }

    if (!_hasAppliedInitialSnapshot) {
      _hasAppliedInitialSnapshot = true;
      _room = incoming;
      _hostExplicitlyPaused = incoming.state == 'paused';
      _anchorEpoch = DateTime.now();
      _anchorTime = incoming.livePositionAt(_clock.serverNow);
      setState(() {});
      return;
    }

    final live = incoming.livePositionAt(_clock.serverNow);
    final drift = (live - _estimatedLocalTime()).abs();
    if (drift > _WatchPartyScreenStateBase._resyncThresholdSeconds) {
      if (_isHlsServer && _hlsController.isAttached) {
        _hlsController.seek(live);
      } else if (_isControlledEmbed) {
        _quietPlayerEvents();
        _sendCinesrc('seek', [live]);
      } else {
        _rebuildAt(live);
      }
      _anchorEpoch = DateTime.now();
      _anchorTime = live;
      setState(() {});
    } else {
      _anchorEpoch = DateTime.now();
      _anchorTime = live;
      setState(() {});
    }
  }

  void _rebuildAt(double startSeconds) {
    if (!mounted) return;
    if (_isHlsServer) {
      _reloadHlsAt(startSeconds);
      return;
    }
    setState(() {
      _isResyncing = true;
    });
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _failedProviderIds.clear();
    _isLoading = true;
    _iframeFailed = false;
    _anchorEpoch = DateTime.now();
    _anchorTime = startSeconds;
    _cinesrcReady = false;
    _iframe.src = _buildPlayerUrl(
      _selectedProvider,
      startSeconds: startSeconds,
    );
    _resyncHideTimer?.cancel();
    _resyncHideTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _isResyncing = false);
    });
  }

  void _onIframeLoadError() {
    if (!mounted) return;
    if (_isEmbedServer) {
      setState(() => _iframeFailed = true);
      return;
    }
    if (!_isLoading) return;
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    debugPrint('[WatchPartyScreen] Provider "${_selectedProvider.id}" failed');
    _failedProviderIds.add(_selectedProvider.id);
    final next = _providers.cast<VideoSourceConfig?>().firstWhere(
      (p) => !_failedProviderIds.contains(p!.id),
      orElse: () => null,
    );
    if (next != null) {
      setState(() {
        _selectedProvider = next;
        _isLoading = true;
        _iframeFailed = false;
      });
      _loadTimer = Timer(_WatchPartyScreenStateBase._loadTimeout, () {
        if (!mounted) return;
        if (_isLoading) _onIframeLoadError();
      });
      _applySandbox(next);
      _cinesrcReady = false;
      _iframe.src = _buildPlayerUrl(next, startSeconds: _localStartHint());
    } else {
      setState(() => _iframeFailed = true);
    }
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

  void _startContentCheck() {
    if (_selectedProvider.id != 'vidlink') return;
    _contentCheckTimer?.cancel();
    _contentCheckTimer = Timer(
      _WatchPartyScreenStateBase._contentCheckTimeout,
      () {
        if (!mounted) return;
        _onIframeLoadError();
      },
    );
  }

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

  JSFunction _buildMessageListener() {
    return ((web.Event e) {
      try {
        final msg = e as web.MessageEvent;
        final origin = msg.origin;
        final data = msg.data;
        if (data == null) return;
        if (!identical(msg.source, _iframe.contentWindow)) return;
        final iframeOrigin = Uri.parse(_iframe.src).origin;
        final activeOrigin = _originForProvider(_selectedProvider.id);
        if (origin != iframeOrigin && origin != activeOrigin) return;

        final raw = data.dartify();
        final scrollDelta = parseEverglowEmbedScrollDelta(raw);
        if (scrollDelta != null) {
          _applyEmbedScroll(scrollDelta);
          return;
        }
        if (_selectedProvider.id == 'everglow-embed' && raw is Map) {
          if (raw['type'] == 'everglow-embed-failed') {
            _onIframeLoadError();
            return;
          }
          final playerEvent = parseCinesrcEvent(raw);
          if (playerEvent != null) {
            _contentCheckTimer?.cancel();
            _onCinesrcEvent(playerEvent);
            return;
          }
        }
        if (raw is! Map) return;
        final type = raw['type'];
        if (type == 'MEDIA_DATA' || type == 'PLAYER_EVENT') {
          _contentCheckTimer?.cancel();
        }
      } catch (e) {
        debugPrint(
          '[WatchPartyScreen] Cross-origin postMessage parse error: $e',
        );
      }
    }).toJS;
  }

  void _applyEmbedScroll(double dy) {
    if (!mounted || web.document.fullscreenElement != null) return;
    if (!_pageScrollController.hasClients) return;
    final position = _pageScrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final next = (position.pixels + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      position.jumpTo(next);
    }
  }

  String _buildPlayerUrl(
    VideoSourceConfig provider, {
    required double startSeconds,
  }) {
    final movieBase = provider.movieUrl;
    final tvBase = provider.tvUrl;
    final id = _room.isAnime
        ? (_resolvedTmdbId ?? _room.malId ?? _room.tmdbId)
        : _room.tmdbId;
    debugPrint(
      'WatchPartyScreen _buildPlayerUrl: provider=${provider.id}, id=$id, mediaType=${_room.mediaType}, season=${_room.season}, episode=${_room.episode}',
    );

    String base;
    if (provider.id == 'everglow-embed') {
      if (_room.mediaType == 'tv') {
        final s = _room.season ?? 1;
        final e = _room.episode ?? 1;
        return '$tvBase?tmdbId=$id&type=tv&s=$s&e=$e';
      }
      return '$movieBase?tmdbId=$id&type=movie';
    }
    if (_room.mediaType == 'tv') {
      final s = _room.season ?? 1;
      final e = _room.episode ?? 1;
      if (tvBase.contains('multiembed.mov')) {
        base = '$tvBase$id&tmdb=1&s=$s&e=$e';
      } else if (provider.id == 'vsembed') {
        base = '$tvBase$id?season=$s&episode=$e';
      } else {
        final separator = tvBase.endsWith('/') ? '' : '/';
        base = '$tvBase$separator$id/$s/$e';
      }
    } else {
      if (movieBase.contains('multiembed.mov')) {
        base = '$movieBase$id&tmdb=1';
      } else {
        final separator =
            movieBase.endsWith('/') ||
                movieBase.contains('?') ||
                movieBase.contains('=')
            ? ''
            : '/';
        base = '$movieBase$separator$id';
      }
    }

    if (provider.id == 'vidlink' ||
        provider.id == 'videasy' ||
        provider.id == 'vidfast') {
      final isTv = _room.mediaType == 'tv';
      final auto = _autoplay ? 'true' : 'false';
      final flags = isTv
          ? 'autoplay=$auto&nextButton=true&episodeSelector=true'
          : 'autoplay=$auto';
      final sep = base.contains('?') ? '&' : '?';
      base = '$base$sep$flags';
      if (_autoplay) {
        base = '$base&muted=1';
      }
      return base;
    }
    return base;
  }

  String _externalOpenUrl() {
    if (_isHlsServer) {
      return _hlsController.playbackUrl ?? _room.streamUrl ?? '';
    }
    if (_isEmbedServer) return _room.streamUrl ?? '';
    return _buildPlayerUrl(_selectedProvider, startSeconds: _localStartHint());
  }

  bool get _isControlledEmbed =>
      _cinesrcReady && _usesIframe && !_isEmbedServer;

  void _quietPlayerEvents() {
    _ignorePlayerEventsUntil = DateTime.now().add(
      const Duration(milliseconds: 1500),
    );
  }

  bool get _playerEventsQuiet =>
      DateTime.now().isBefore(_ignorePlayerEventsUntil);

  void _sendCinesrc(String command, [List<Object?> args = const []]) {
    final target = _iframe.contentWindow;
    if (target == null) return;
    try {
      target.postMessage(
        cinesrcCommand(command, args).jsify(),
        Uri.parse(_iframe.src).origin.toJS,
      );
    } catch (e) {
      debugPrint('[WatchPartyScreen] cinesrc command $command failed: $e');
    }
  }

  void _syncPlayerTo(
    double time, {
    required bool paused,
    bool forceSeek = false,
  }) {
    _quietPlayerEvents();
    final drift = (time - _estimatedLocalTime()).abs();
    final seek = forceSeek ? time > 1.0 : drift > (paused ? 0.5 : 1.5);
    if (seek) {
      _anchorTime = time;
      _sendCinesrc('seek', [time]);
    }
    _anchorEpoch = DateTime.now();
    if (paused) {
      _playCheckTimer?.cancel();
      _sendCinesrc('pause');
    } else {
      _playWhenAllowed();
    }
  }

  void _playWhenAllowed() {
    _sendCinesrc('play');
    _playCheckTimer?.cancel();
    _playCheckTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || _hostExplicitlyPaused) return;
      _sendCinesrc('getPaused');
    });
  }

  void _onCinesrcEvent(CinesrcEvent event) {
    final time = event.currentTime;
    switch (event.name) {
      case 'ready':
        _cinesrcReady = true;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isResyncing = false;
          });
        }
        _syncPlayerTo(
          _room.livePositionAt(_clock.serverNow),
          paused: _hostExplicitlyPaused,
          forceSeek: true,
        );
      case 'timeupdate':
        if (time != null) {
          _anchorTime = time;
          _anchorEpoch = DateTime.now();
        }
      case 'response':
        if (event.command == 'getPaused' &&
            event.result == true &&
            !_hostExplicitlyPaused) {
          _quietPlayerEvents();
          _sendCinesrc('setMuted', [true]);
          _sendCinesrc('play');
        }
      case 'play':
        if (!_playerEventsQuiet && _hostExplicitlyPaused) {
          _broadcastLocal(paused: false);
        }
      case 'pause':
        if (!_playerEventsQuiet && !_hostExplicitlyPaused) {
          _broadcastLocal(paused: true);
        }
      case 'seeking':
        if (!_playerEventsQuiet &&
            time != null &&
            isUserSeek(
              expectedSeconds: _estimatedLocalTime(),
              reportedSeconds: time,
            )) {
          _userSeekPending = true;
        }
      case 'seeked':
        if (_userSeekPending && time != null) {
          _userSeekPending = false;
          _broadcastLocal(paused: _hostExplicitlyPaused, time: time);
        }
    }
  }

  void _broadcastLocal({required bool paused, double? time}) {
    final t = time ?? _estimatedLocalTime();
    setState(() {
      _hostExplicitlyPaused = paused;
      _autoplay = !paused;
    });
    _anchorTime = t;
    _anchorEpoch = DateTime.now();
    unawaited(
      _service.updatePlayback(
        roomId: _room.id,
        state: paused ? 'paused' : 'playing',
        currentTime: t,
        updatedBy: _myUid,
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    final nextState = _hostExplicitlyPaused ? 'playing' : 'paused';
    final willPause = nextState == 'paused';
    debugPrint(
      'WatchPartyScreen _togglePlayPause: hostExplicitlyPaused=$_hostExplicitlyPaused → nextState=$nextState',
    );
    setState(() {
      _hostExplicitlyPaused = willPause;
      _autoplay = !willPause;
    });
    if (willPause) {
      _anchorTime = _estimatedLocalTime();
      _anchorEpoch = DateTime.now();
    } else {
      _anchorEpoch = DateTime.now();
    }
    if (_isHlsServer) {
      if (willPause) {
        _hlsController.pause();
      } else {
        _hlsController.setMuted(false);
        _hlsController.play();
      }
      await _service.updatePlayback(
        roomId: _room.id,
        state: nextState,
        currentTime: _positionForWrite(),
        updatedBy: _myUid,
      );
      return;
    }
    if (_isControlledEmbed) {
      _quietPlayerEvents();
      if (willPause) {
        _playCheckTimer?.cancel();
        _sendCinesrc('pause');
      } else {
        _sendCinesrc('setMuted', [false]);
        _playWhenAllowed();
      }
      await _service.updatePlayback(
        roomId: _room.id,
        state: nextState,
        currentTime: _estimatedLocalTime(),
        updatedBy: _myUid,
      );
      return;
    }
    if (_isEmbedServer) {
      _iframe.setAttribute('src', _room.streamUrl!);
      await _service.updatePlayback(
        roomId: _room.id,
        state: nextState,
        currentTime: _estimatedLocalTime(),
        updatedBy: _myUid,
      );
      return;
    }
    final url = _buildPlayerUrl(
      _selectedProvider,
      startSeconds: _estimatedLocalTime(),
    );
    debugPrint(
      'WatchPartyScreen _togglePlayPause: reloading iframe autoplay=$_autoplay',
    );
    _iframe.setAttribute('src', url);
    await _service.updatePlayback(
      roomId: _room.id,
      state: nextState,
      currentTime: _estimatedLocalTime(),
      updatedBy: _myUid,
    );
  }

  void _reloadHlsAt(double startSeconds) {
    if (!mounted) return;
    if (_isEverglowServer && (_everglowStreamUrl ?? '').isEmpty) {
      unawaited(_resolveEverglowStream(startSeconds: startSeconds));
      return;
    }
    setState(() {
      _isResyncing = true;
      _hlsReady = false;
      _hlsFailed = false;
      _hlsError = null;
    });
    _anchorEpoch = DateTime.now();
    _anchorTime = startSeconds;
    _hlsController.load(
      url: _hlsStreamUrl,
      startSeconds: startSeconds,
      autoplay: !_hostExplicitlyPaused,
    );
    _resyncHideTimer?.cancel();
    _resyncHideTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _isResyncing = false);
    });
  }

  Future<void> _resolveEverglowStream({double? startSeconds}) async {
    if (!mounted || !_room.hasMedia) return;
    final tmdbId = _room.tmdbId;
    final malId = _room.malId;
    final season = _room.season;
    final episode = _room.episode;
    final serverType = _room.serverType;
    setState(() {
      _resolvingStream = true;
      _streamResolveError = null;
      _hlsFailed = false;
      _hlsError = null;
    });
    try {
      final stream = await _streamResolver.resolve(_room);
      if (!mounted) return;
      if (_room.tmdbId != tmdbId ||
          _room.malId != malId ||
          _room.season != season ||
          _room.episode != episode ||
          _room.serverType != serverType) {
        setState(() => _resolvingStream = false);
        return;
      }
      setState(() {
        _everglowStreamUrl = stream.src;
        _availableSubtitles = stream.subtitles;
        _resolvingStream = false;
        _hlsReady = false;
        _hlsFailed = false;
        _hlsError = null;
      });
      _reloadHlsAt(startSeconds ?? _localStartHint());
    } catch (e, st) {
      Logger.e(
        'WatchParty: Everglow stream resolve failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      final message = e is StateError && e.message.isNotEmpty
          ? e.message
          : 'Could not reach the Everglow server.';
      setState(() {
        _resolvingStream = false;
        _hlsFailed = true;
        _streamResolveError = message;
        _hlsError = message;
      });
    }
  }

  void _applyHlsState(WatchPartyRoom incoming) {
    _isResyncing = false;
    if (incoming.state == 'playing') {
      _hlsController.playWithSoundFallback();
    } else {
      _hlsController.pause();
    }
    _anchorEpoch = DateTime.now();
    _anchorTime = incoming.livePositionAt(_clock.serverNow);
  }

  void _showEndedAndPop() {
    if (!mounted) return;
    unawaited(_voiceChat.endCall());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_partnerName ended the party.',
          style: AppTypography.outfitWhite.copyWith(color: _cWhite),
        ),
        backgroundColor: _cDeepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.of(context).pop();
  }
}
