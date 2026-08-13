part of 'watch_party_screen.dart';

mixin _WatchPartyScreenStateData on State<WatchPartyScreen> {
  late final WatchPartyService _service;
  late final AuthService _auth;
  late WatchPartyRoom _room;
  late String _myUid;
  late String _partnerName;

  StreamSubscription<WatchPartyRoom?>? _roomSub;

  // ─── Local playback clock ─────────────────────────────────────────
  // The iframe doesn't expose its timeline, so we run a local wall-clock
  // estimate. Anchored every time the iframe fires `load` (we assume it
  // starts at the hint we set in the URL) and re-anchored whenever a
  // remote update arrives from the partner.

  /// DateTime at which the iframe is "officially" at position
  /// [_anchorTime]. Add `now - _anchorEpoch` to estimate the live
  /// position while playing.
  DateTime? _anchorEpoch;
  double _anchorTime = 0.0;

  /// One-shot guard so we don't re-process the initial snapshot we
  /// already have on screen.  False from the start because the iframe
  /// was already positioned via `widget.initialRoom` in `initState`;
  /// the first Firestore snapshot coming in should only nudge the
  /// anchor, never trigger a redundant iframe rebuild (which would
  /// reload stale cached data over the fresh `initialRoom`).
  bool _hasAppliedInitialSnapshot = false;

  /// True while we're rebuilding the iframe to land at a new offset.
  /// The partner sees a "Syncing..." pill during this window.
  bool _isResyncing = false;
  Timer? _resyncHideTimer;

  // ─── In‑stack dialog (avoids iframe event capture on web) ─────
  bool _showEndDialog = false;
  void Function(bool)? _endDialogCallback;

  /// True if the host has explicitly paused (separate from "the host
  /// hasn't pressed play yet"). Triggers the "Paused by Clair" pill
  /// on the partner's screen.
  bool _hostExplicitlyPaused = false;

  /// Whether the iframe URL should include autoplay=true.  Toggled
  /// on every play/pause so the DOM-level reload actually stops/starts
  /// the cross-origin embed.
  bool _autoplay = true;

  /// Timestamp of the last remote Firestore snapshot we applied.
  /// Used to discard stale heartbeats that were sent before a newer
  /// play/pause event but arrived later due to network reordering.
  DateTime? _lastRemoteUpdate;

  // ─── iframe plumbing (mirrors VideoPlayerScreen) ──────────────────
  bool _isLoading = true;
  bool _iframeFailed = false;
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;
  JSFunction? _onErrorListener;
  Timer? _loadTimer;

  /// Checks if VidLink actually serves content (postMessage-based).
  /// Ensures we don't hang on "content not available" pages.
  Timer? _contentCheckTimer;
  JSFunction? _onWheelListener;

  /// Drives the page scroll view so wheel events from the embed iframe
  /// (which Flutter never sees) can be forwarded to it.
  final ScrollController _pageScrollController = ScrollController();

  /// Listens for VidLink's MEDIA_DATA / PLAYER_EVENT postMessage to
  /// confirm content is playable.
  JSFunction? _messageListener;

  /// Resolved TMDB id for anime items. Populated by [_bootstrapAnime]
  /// on init; null when the lookup failed or the item isn't anime.
  int? _resolvedTmdbId;

  late VideoSourceConfig _selectedProvider;
  final Set<String> _failedProviderIds = {};

  /// Shared embed-provider service. Sources are loaded from Firestore
  /// with a hardcoded fallback.
  final VideoSourceService _sourceService = VideoSourceService();

  /// Listener callback for when the service's provider list updates
  /// asynchronously from Firestore.
  VoidCallback? _serviceListener;

  // ── Self-hosted playback server (AniChan-style server layer) ───────
  // Rooms can carry a normalized server entry ('hls' or 'embed'). HLS
  // servers play in a real <video> element via hls.js so the couple
  // gets precise play/pause/seek sync; embed servers use the iframe.
  final HlsServerPlayerController _hlsController = HlsServerPlayerController();
  late final String _hlsViewType;
  bool _hlsFailed = false;
  bool _hlsReady = false;
  String? _hlsError;

  bool get _isHlsServer =>
      _room.serverType == 'hls' && (_room.streamUrl ?? '').isNotEmpty;

  bool get _isEmbedServer =>
      _room.serverType == 'embed' && (_room.streamUrl ?? '').isNotEmpty;

  /// Whether the legacy embed-provider iframe path is in use.
  bool get _usesIframe => !_isHlsServer;

  /// Final stream URL, proxied when the server requires it.
  String get _hlsStreamUrl {
    final raw = _room.streamUrl ?? '';
    if (_room.proxyEnabled) return WatchPartyServerService.proxyUrlFor(raw);
    return raw;
  }

  // ─── Voice chat ───────────────────────────────────────────────────
  final VoiceChatService _voiceChat = VoiceChatService();

  // Heartbeat keeps the partner's local clock fresh — every 5s we
  // publish our estimated position so they can drift-correct.
  Timer? _heartbeatTimer;

  // Tiny ticker that re-renders the visible mm:ss clock once per
  // second while playing. We don't write to Firestore every tick,
  // just to the local widget tree.
  Timer? _clockTicker;
  double _displayedTime = 0.0;

  // ─── Sync tunables ────────────────────────────────────────────────

  /// When the partner's reported time diverges from our local estimate
  /// by more than this, we auto-rebuild the iframe at the partner's
  /// position. Tuned to 4s — smaller than the heartbeat interval (5s)
  /// so we never auto-resync on a single jittery update, and large
  /// enough that we don't fight the iframe's own startup time.
  static const double _resyncThresholdSeconds = 4.0;

  /// How long we wait for the iframe to fire `load` before declaring
  /// the embed dead and trying the next provider.
  static const Duration _loadTimeout = Duration(seconds: 15);

  /// How long to wait for VidLink to send a `MEDIA_DATA` postMessage
  /// event after the iframe loads. If the event never arrives the
  /// provider likely showed "content not available", so we fall back.
  static const Duration _contentCheckTimeout = Duration(seconds: 8);

  /// Heartbeat interval. 5s keeps the partner's local clock within
  /// ~5s of the host without thrashing Firestore.
  static const Duration _heartbeatInterval = Duration(seconds: 5);

  /// Free embed providers. Shared via [VideoSourceService] which loads
  /// from Firestore with a hardcoded fallback. The watch-party player
  /// doesn't expose a provider switcher — we just cycle through the
  /// list internally on iframe error.
  List<VideoSourceConfig> get _providers => _sourceService.providers;

  @override
  void initState() {
    super.initState();
    _service = WatchPartyService();
    _auth = context.read<AuthService>();
    _room = widget.initialRoom;
    _myUid = _auth.uid ?? '';
    _partnerName = _auth.partnerName;
    debugPrint(
      'WatchPartyScreen init: tmdbId=${_room.tmdbId}, mediaType=${_room.mediaType}, isAnime=${_room.isAnime}, season=${_room.season}, episode=${_room.episode}',
    );

    // The host decides when play/pause/seek happens, the partner
    // listens + auto-resyncs. We do honour explicit "Resync" taps
    // on the partner side though.
    if (widget.isHost) {
      _hostExplicitlyPaused = _room.state == 'paused';
    } else {
      _hostExplicitlyPaused = _room.state == 'paused';
    }
    _autoplay = !_hostExplicitlyPaused;

    _selectedProvider = _providers.first;
    _hlsViewType =
        'everglow-watchparty-hls-${_room.id}-${DateTime.now().microsecondsSinceEpoch}';

    // Listen for provider list updates from Firestore. If the iframe
    // has already failed with the hardcoded defaults, retry with the
    // freshly loaded sources.
    _serviceListener = () {
      if (!mounted) return;
      if (!_usesIframe) return;
      final newList = _sourceService.providers;
      if (newList.isNotEmpty && _iframeFailed) {
        debugPrint(
          '[WatchPartyScreen] Providers updated from Firestore — retrying',
        );
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
        _iframe.src = _buildPlayerUrl(_selectedProvider, startSeconds: 0);
      }
    };
    _sourceService.addListener(_serviceListener!);

    _viewType =
        'everglow-watchparty-${_room.tmdbId}-${_room.mediaType}-${_room.season ?? 0}-${_room.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

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
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Start the content-available check for VidLink so we fall back
      // quickly when it shows "content not available".
      _startContentCheck();
      // Re-anchor the local clock: the iframe is "officially" at the
      // hint we put in the URL right now. The clock then runs off
      // wall time until the next anchor (next heartbeat or seek).
      _anchorEpoch = DateTime.now();
      _anchorTime = _localStartHint();
    }).toJS;
    _onErrorListener = ((web.Event _) {
      _onIframeLoadError();
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);
    _iframe.addEventListener('error', _onErrorListener);

    // Forward wheel events over the iframe to the page scroll view. The
    // embed swallows them, so without this the page can't be scrolled
    // on desktop while the cursor is over the player.
    _onWheelListener = ((web.Event e) {
      if (!_pageScrollController.hasClients) return;
      final wheel = e as web.WheelEvent;
      if (wheel.ctrlKey) return;
      wheel.preventDefault();
      var delta = wheel.deltaY;
      switch (wheel.deltaMode) {
        case 1:
          delta *= 20;
          break;
        case 2:
          delta *= 600;
          break;
      }
      if (delta == 0) return;
      final position = _pageScrollController.position;
      final target = (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) position.jumpTo(target);
    }).toJS;
    _iframe.addEventListener('wheel', _onWheelListener, true.toJS);

    // Listen for postMessage events from embed providers (VidLink)
    // to confirm content is actually playable.
    _messageListener = _buildMessageListener();
    web.window.addEventListener('message', _messageListener);

    if (_usesIframe) {
      _loadTimer = Timer(_loadTimeout, () {
        if (!mounted) return;
        if (_isLoading) _onIframeLoadError();
      });
    }

    // For anime we don't have a TMDB id on the room — the slot holds
    // the MAL id. Resolve MAL→TMDB via ani.zip, then set the iframe's
    // src once. If the lookup fails we land in the error card.
    if (_isHlsServer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _reloadHlsAt(_localStartHint());
      });
    } else if (_isEmbedServer) {
      _iframe.src = _room.streamUrl!;
    } else {
      if (_room.isAnime) {
        _bootstrapAnime();
      } else {
        _iframe.src = _buildPlayerUrl(
          _selectedProvider,
          startSeconds: _localStartHint(),
        );
      }
    }

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );

    // Subscribe to the room. Updates are debounced by Firestore's
    // snapshot pipeline (1-3s in practice) which is fine for our
    // 5s heartbeat cadence.
    _roomSub = _service.getRoomStream(_room.id).listen(_onRoomUpdate);

    // If the room has ended before either of us joined (host left
    // earlier), bounce out immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_room.active && _room.updatedBy != _myUid) {
        unawaited(_voiceChat.endCall());
        Navigator.of(context).pop();
      }
    });

    _startClockTicker();
    if (widget.isHost) {
      _startHeartbeat();
    }

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
    // We're on the watch party screen now, so suppress the
    // app-wide "incoming call" banner — otherwise it would float
    // on top of the active call UI.
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
    _clockTicker?.cancel();
    _resyncHideTimer?.cancel();
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _roomSub?.cancel();
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
    if (_onWheelListener != null) {
      _iframe.removeEventListener('wheel', _onWheelListener);
    }
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
    }
    _iframe.src = 'about:blank';
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

  // ─── Local clock helpers ──────────────────────────────────────────

  /// Wall-clock estimate of the current playback position. We add
  /// elapsed wall time to the last anchored hint. While paused we
  /// just return the anchor (the iframe keeps playing, but we lie
  /// about it in the UI so the user can see "paused" badges).
  double _estimatedLocalTime() {
    if (_isHlsServer && _hlsController.isAttached) {
      return _hlsController.currentTime;
    }
    if (_anchorEpoch == null) return _anchorTime;
    if (_hostExplicitlyPaused) return _anchorTime;
    final elapsed =
        DateTime.now().difference(_anchorEpoch!).inMilliseconds / 1000.0;
    return _anchorTime + elapsed;
  }

  /// The hint we wrote into the player URL the last time we built
  /// the iframe. Defaults to the room's `currentTime` so a joiner
  /// lands on the same scene the host is watching.
  double _localStartHint() => _room.currentTime;

  void _startClockTicker() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _displayedTime = _estimatedLocalTime();
      });
    });
  }

  // ─── Heartbeat (host) ─────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!mounted) return;
      final t = _estimatedLocalTime();
      final s = _hostExplicitlyPaused ? 'paused' : 'playing';
      debugPrint(
        'WatchPartyScreen heartbeat: state=$s time=$t anchorTime=$_anchorTime anchorEpoch=$_anchorEpoch hostPaused=$_hostExplicitlyPaused',
      );
      await _service.heartbeat(
        roomId: _room.id,
        state: s,
        currentTime: t,
        updatedBy: _myUid,
      );
    });
  }

  /// Anime bootstrap: look up the TMDB id for the MAL id via ani.zip,
  /// then point the iframe at the player URL. The embed providers
  /// expect TMDB ids, not MAL ids, so this resolution is required for
  /// anime items to play.
  Future<void> _bootstrapAnime() async {
    final malId = _room.malId ?? _room.tmdbId;
    final tmdbId = await AniZipService().fetchTmdbId(malId);
    if (!mounted) return;
    if (tmdbId == null) {
      setState(() => _iframeFailed = true);
      _loadTimer?.cancel();
      return;
    }
    _resolvedTmdbId = tmdbId;
    _iframe.src = _buildPlayerUrl(
      _selectedProvider,
      startSeconds: _localStartHint(),
    );
  }

  // ─── Snapshot pipeline ────────────────────────────────────────────

  bool _mediaIdentityChanged(WatchPartyRoom a, WatchPartyRoom b) {
    return a.tmdbId != b.tmdbId ||
        a.mediaType != b.mediaType ||
        a.season != b.season ||
        a.episode != b.episode ||
        a.serverType != b.serverType ||
        a.serverName != b.serverName ||
        a.streamUrl != b.streamUrl ||
        a.subtitleUrl != b.subtitleUrl ||
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

    final isLocalWrite = incoming.updatedBy == _myUid;
    debugPrint(
      'WatchPartyScreen _onRoomUpdate: isLocal=$isLocalWrite, state=${incoming.state}, time=${incoming.currentTime}, updatedBy=${incoming.updatedBy}, updatedAt=${incoming.updatedAt}',
    );
    if (isLocalWrite) {
      _room = incoming;
      return;
    }

    // Discard remote snapshots that are older than the last one we
    // applied.  Without this gate a heartbeat (sent at T with
    // state='playing') can beat a pause (sent at T+0.5 with
    // state='paused') to the partner's screen, flipping the overlay
    // from "Khent paused" back to "Synced" and kicking the clock.
    if (_lastRemoteUpdate != null &&
        !incoming.updatedAt.isAfter(_lastRemoteUpdate!)) {
      debugPrint(
        'WatchPartyScreen _onRoomUpdate: discarding stale update (updatedAt=${incoming.updatedAt} ≤ last=$_lastRemoteUpdate)',
      );
      return;
    }
    _lastRemoteUpdate = incoming.updatedAt;

    final mediaChanged = _mediaIdentityChanged(incoming, _room);
    final stateChanged = incoming.state != _room.state;
    _room = incoming;
    _hostExplicitlyPaused = incoming.state == 'paused';

    if (mediaChanged) {
      _autoplay = true;
      _anchorEpoch = DateTime.now();
      _anchorTime = 0.0;
      if (_isHlsServer) {
        _reloadHlsAt(0);
      } else if (_isEmbedServer) {
        _iframe.src = _room.streamUrl!;
      } else {
        _iframe.src = _buildPlayerUrl(_selectedProvider, startSeconds: 0);
      }
      setState(() {});
      return;
    }

    // When the host toggles play/pause, the remote side must also
    // reload its iframe so the autoplay flag takes effect.  Without
    // this the partner's iframe keeps its old src and stays paused
    // (or keeps playing) regardless of what the overlay says.
    if (stateChanged) {
      _autoplay = !_hostExplicitlyPaused;
      if (_isHlsServer) {
        _applyHlsState(incoming);
        setState(() {});
      } else {
        _rebuildAt(incoming.currentTime);
      }
      return;
    }

    if (!_hasAppliedInitialSnapshot) {
      _hasAppliedInitialSnapshot = true;
      // The iframe was already positioned at widget.initialRoom's
      // media in initState.  Don't check mediaChanged here — the
      // first snapshot may be stale cache data from an earlier
      // session (e.g. a different movie).  Just nudge the anchor
      // and adopt incoming metadata silently.  The next snapshot
      // (from the server) will go through the normal flow.
      _room = incoming;
      _hostExplicitlyPaused = incoming.state == 'paused';
      _anchorEpoch = DateTime.now();
      _anchorTime = incoming.currentTime;
      setState(() {});
      return;
    }

    final drift = (incoming.currentTime - _estimatedLocalTime()).abs();
    if (drift > _resyncThresholdSeconds) {
      if (_isHlsServer && _hlsController.isAttached) {
        _hlsController.seek(incoming.currentTime);
      } else {
        _rebuildAt(incoming.currentTime);
      }
      _anchorEpoch = DateTime.now();
      _anchorTime = incoming.currentTime;
      setState(() {});
    } else {
      _anchorEpoch = DateTime.now();
      _anchorTime = incoming.currentTime;
      // Host changed play/pause (or a small drift) — we need to rebuild the
      // overlay so "Khent paused" flips to "Synced" and the time updates.
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
    // Cancel any pending load timer from a previous provider attempt
    // so it doesn't fire and incorrectly mark the current provider as
    // failed while we're rebuilding the iframe at a new offset.
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    // Reset the failed set so every provider gets a fresh attempt on
    // rebuild — the previous failures may have been caused by the
    // stale timer race rather than actual provider errors.
    _failedProviderIds.clear();
    _isLoading = true;
    _iframeFailed = false;
    _anchorEpoch = DateTime.now();
    _anchorTime = startSeconds;
    _iframe.src = _buildPlayerUrl(
      _selectedProvider,
      startSeconds: startSeconds,
    );
    // Auto-hide the "Syncing..." pill after 2s — by then the iframe
    // is usually up and the local clock is re-anchored.
    _resyncHideTimer?.cancel();
    _resyncHideTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _isResyncing = false);
    });
  }

  // ─── Provider failover (mirrors VideoPlayerScreen) ─────────────────

  void _onIframeLoadError() {
    if (!mounted) return;
    if (_isEmbedServer) {
      setState(() => _iframeFailed = true);
      return;
    }
    // Ignore stale errors from a previous load that was aborted by a
    // rebuild or provider switch — the current load may still succeed.
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
      _loadTimer = Timer(_loadTimeout, () {
        if (!mounted) return;
        if (_isLoading) _onIframeLoadError();
      });
      _iframe.src = _buildPlayerUrl(next, startSeconds: _localStartHint());
    } else {
      setState(() => _iframeFailed = true);
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
        final activeOrigin = _originForProvider(_selectedProvider.id);
        if (origin != activeOrigin) return;
        final map = data.dartify();
        if (map is! Map) return;
        final type = map['type'];
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

  // ─── URL building ─────────────────────────────────────────────────
  // Mirrors the regular player. The only addition is a trailing
  // `&start=N` for providers that support it (Videasy accepts
  // `?startTime=N`). For the rest the hint is silently ignored —
  // they always start at 0 — which is the documented limitation of
  // the sync.

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
    if (_room.mediaType == 'tv') {
      final s = _room.season ?? 1;
      final e = _room.episode ?? 1;
      if (tvBase.contains('vidsrc.to')) {
        base = '$tvBase$id?season=$s&episode=$e';
      } else if (tvBase.contains('multiembed.mov')) {
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

    // VidLink / Videasy: autoplay flag mirrors play/pause so the
    // DOM-level reload actually stops or starts the video.
    // When autoplay is on, we also emit muted=1 so the browser
    // allows autoplay even without a user gesture on the partner's side.
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
    // VidFast doesn't support seek parameters — we always return the
    // clean URL so the default first provider never fails due to an
    // unsupported `?start=N`. Only Videasy honours startTime.
    return base;
  }

  /// The URL the user can open in a new tab. Uses the same URL the
  /// iframe would use for the current provider — if every embed has
  /// failed, this gives the user a manual escape hatch.
  String _externalOpenUrl() {
    if (_isHlsServer) return _hlsStreamUrl;
    if (_isEmbedServer) return _room.streamUrl ?? '';
    return _buildPlayerUrl(_selectedProvider, startSeconds: _localStartHint());
  }

  // ─── User actions ─────────────────────────────────────────────────

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
        // Local taps are a user gesture, so unmute for real audio.
        _hlsController.setMuted(false);
        _hlsController.play();
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
    // Reload the iframe via DOM so the user-gesture window stays open
    // and the browser allows autoplay on the new document.
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

  /// Reload the HLS player at [startSeconds] (used when switching
  /// servers or media, or on a manual resync).
  void _reloadHlsAt(double startSeconds) {
    if (!mounted) return;
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

  /// Apply a remote state change to the HLS player without reloading
  /// the stream: play/pause directly on the real <video> element.
  void _applyHlsState(WatchPartyRoom incoming) {
    _isResyncing = false;
    if (incoming.state == 'playing') {
      // Remote play may lack a user gesture; keep it muted so the
      // browser allows autoplay.
      _hlsController.setMuted(true);
      _hlsController.play();
    } else {
      _hlsController.pause();
    }
    _anchorEpoch = DateTime.now();
    _anchorTime = incoming.currentTime;
  }

  Future<void> _showServerPicker() async {
    final serverService = WatchPartyServerService();
    final current = _room.streamUrl == null
        ? null
        : WatchPartyServer.fromRoom(
            serverType: _room.serverType ?? 'embed',
            serverName: _room.serverName ?? 'Server',
            serverHost: _room.serverHost ?? 'custom',
            streamUrl: _room.streamUrl ?? '',
            subtitleUrl: _room.subtitleUrl,
            proxyEnabled: _room.proxyEnabled,
          );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ServerPickerSheet(
        servers: serverService.servers,
        selected: current,
        onSelect: _applyServer,
      ),
    );
  }

  Future<void> _applyServer(WatchPartyServer? server) async {
    final roomId = _room.id;
    final uid = _myUid;
    if (server == null) {
      await _service.clearServer(roomId: roomId, updatedBy: uid);
      if (!mounted) return;
      setState(() {
        _room = _room
            .copyWith(state: 'paused', currentTime: 0.0)
            .copyWithServer();
        _hostExplicitlyPaused = true;
        _hlsReady = false;
        _hlsFailed = false;
        _hlsError = null;
      });
      return;
    }
    await _service.updateServer(
      roomId: roomId,
      serverType: server.type,
      serverName: server.name,
      serverHost: server.host,
      streamUrl: server.streamUrl,
      subtitleUrl: server.subtitleUrl,
      proxyEnabled: server.proxyEnabled,
      updatedBy: uid,
    );
    if (!mounted) return;
    setState(() {
      _room = _room
          .copyWith(state: 'paused', currentTime: 0.0)
          .copyWithServer(
            serverType: server.type,
            serverName: server.name,
            serverHost: server.host,
            streamUrl: server.streamUrl,
            subtitleUrl: server.subtitleUrl,
            proxyEnabled: server.proxyEnabled,
          );
      _hostExplicitlyPaused = true;
      _hlsReady = false;
      _hlsFailed = false;
      _hlsError = null;
    });
    if (server.isHls) {
      _reloadHlsAt(0);
    } else if (_usesIframe) {
      _iframe.src = server.streamUrl;
    }
  }

  Future<void> _endParty() async {
    if (_showEndDialog) return;
    final completer = Completer<bool>();
    setState(() {
      _showEndDialog = true;
      _endDialogCallback = completer.complete;
    });
    final result = await completer.future;
    if (result != true) return;
    await _service.endRoom(_room.id);
    await _voiceChat.endCall();
    if (mounted) Navigator.of(context).pop();
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

  // ─── Build ────────────────────────────────────────────────────────


  void _selectProvider(VideoSourceConfig provider) {
    if (provider.id == _selectedProvider.id) return;
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _failedProviderIds.clear();
    setState(() {
      _selectedProvider = provider;
      _isLoading = true;
      _iframeFailed = false;
    });
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _iframe.src = _buildPlayerUrl(provider, startSeconds: _localStartHint());
  }

  String _formatT(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

}
