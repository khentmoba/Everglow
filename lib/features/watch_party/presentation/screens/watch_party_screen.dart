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
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_spacing.dart';
import 'package:everglow/features/cinema/data/services/ani_zip_service.dart';
import 'package:everglow/features/cinema/data/services/video_source_service.dart';
import 'package:everglow/features/cinema/data/models/video_source_config.dart';
import 'package:everglow/services/auth_service.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/models/watch_party_server.dart';
import '../../data/services/voice_chat_service.dart';
import '../../data/services/watch_party_server_service.dart';
import '../../data/services/watch_party_service.dart';
import '../widgets/hls_server_player.dart';
import '../widgets/server_picker_sheet.dart';
import '../widgets/voice_chat_overlay.dart';
import '../widgets/watch_party_chat_drawer.dart';
import 'package:everglow/core/theme/app_typography.dart';

// ─── Color tokens (mirror cinema_screen.dart / episode_drawer.dart) ──
const _cRose = Color(0xFFF4C2C2);
const _cCard = Color(0xFF1C1228);
const _cDeepRose = Color(0xFFC2185B);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);
const _cGreen = Color(0xFF4ADE80);

/// Real-time synchronized playback screen for the couple.
///
/// Built on top of the same third-party embed providers as the regular
/// [VideoPlayerScreen] (Videasy / VidLink / 2Embed / etc.) but with a
/// coordination layer that mirrors the host's playback state to the
/// partner's iframe. See `lib/features/watch_party/data/services/watch_party_service.dart`
/// for the room lifecycle; this file handles the UI + sync timing.
///
/// Why we don't get pixel-perfect sync:
///   The iframes are cross-origin and don't expose their timeline, so
///   we can't read `currentTime` or call `play()/pause()` on them
///   directly. Instead both clients keep a local clock anchored to
///   the most recent Firestore update, and when the host's time
///   diverges from the partner's by more than [_resyncThreshold] we
///   rebuild the iframe with a fresh `?start=` hint. This isn't a
///   frame-perfect Netflix Party — it's a "we're watching the same
///   scene within a few seconds" best effort, which is good enough
///   for a movie night across town.
class WatchPartyScreen extends StatefulWidget {
  /// The room to join. The host constructs this from the picked media
  /// + their auth info; the partner receives the same `id` from
  /// Firestore when they tap Resume on the dashboard.
  final WatchPartyRoom initialRoom;

  /// True if the current user is the room's host. Drives UI affordances
  /// (host gets the play/pause button; partner gets Resync + the
  /// "follow host" auto-resync loop).
  final bool isHost;

  const WatchPartyScreen({
    super.key,
    required this.initialRoom,
    required this.isHost,
  });

  @override
  State<WatchPartyScreen> createState() => _WatchPartyScreenState();
}

class _WatchPartyScreenState extends State<WatchPartyScreen>
    with TickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildCinemaTopBar(),
            Expanded(
              child: SingleChildScrollView(
                controller: _pageScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCinemaPlayerStage(),
                    _buildCinemaMetadata(),
                    _buildCinemaServerSelector(),
                    const SizedBox(height: AppSpacing.x3),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  /// Cinema-style 16:9 stage. Keeps the HLS player / iframe in the same
  /// platform view, with loading, error, sync, voice, and chat overlays.
  Widget _buildCinemaPlayerStage() {
    final maxPlayerHeight =
        (MediaQuery.sizeOf(context).height - 320).clamp(240.0, double.infinity);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxPlayerHeight),
      child: RepaintBoundary(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (_isHlsServer)
                  HlsServerPlayer(
                    streamUrl: _hlsStreamUrl,
                    subtitleUrl: _room.subtitleUrl,
                    startSeconds: _localStartHint(),
                    autoplay: !_hostExplicitlyPaused,
                    viewType: _hlsViewType,
                    controller: _hlsController,
                    onReady: () {
                      if (!mounted) return;
                      setState(() {
                        _hlsReady = true;
                        _hlsFailed = false;
                        _hlsError = null;
                      });
                    },
                    onTimeUpdate: (time) {
                      _anchorTime = time;
                      _anchorEpoch = DateTime.now();
                    },
                    onError: (message) {
                      if (!mounted) return;
                      debugPrint(
                        '[WatchPartyScreen] HLS server error: $message',
                      );
                      setState(() {
                        _hlsFailed = true;
                        _hlsError = message;
                      });
                    },
                  )
                else if (!_iframeFailed)
                  HtmlElementView(viewType: _viewType),
                if (_isHlsServer && !_hlsReady && !_hlsFailed)
                  _WatchPartyCinematicLoader(serverName: _activeServerLabel),
                if (_isLoading && !_iframeFailed && !_isHlsServer)
                  _WatchPartyCinematicLoader(serverName: _activeServerLabel),
                if (_hlsFailed) _buildHlsErrorCard(),
                if (_iframeFailed) _buildErrorCard(),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _buildSyncOverlay(),
                ),
                VoiceChatOverlay(
                  service: _voiceChat,
                  partnerName: _partnerName,
                ),
                WatchPartyChatDrawer(roomId: _room.id),
                if (_showEndDialog) _buildEndDialog(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _activeServerLabel {
    if (_room.streamUrl != null) {
      return _room.serverName ?? (_room.serverType == 'hls' ? 'HLS' : 'Embed');
    }
    return _selectedProvider.shortName;
  }

  Widget _buildCinemaTopBar() {
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
          _CinemaPillButton(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Back',
            compact: compact,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: compact ? 8 : 14),
          if (!compact) ...[
            Expanded(
              child: Text(
                _room.title,
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
          _CinemaPillButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Try Another Source',
            accent: true,
            compact: compact,
            onTap: _showServerPicker,
          ),
          SizedBox(width: compact ? 6 : 8),
          _buildServerChip(compact: compact),
          SizedBox(width: compact ? 6 : 8),
          _CinemaPillButton(
            icon: Icons.close_rounded,
            label: 'End',
            compact: compact,
            accent: true,
            onTap: _endParty,
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaMetadata() {
    final isTv = _room.mediaType == 'tv';
    final activeServer = _activeServerLabel;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _metaBadge(
                Icons.source_rounded,
                activeServer,
                accent: true,
              ),
              _metaBadge(
                isTv ? Icons.tv_rounded : Icons.movie_rounded,
                isTv ? 'TV Show' : 'Movie',
                tint: AppColors.softLavender,
              ),
              if (isTv)
                _metaBadge(
                  Icons.layers_rounded,
                  'S${_room.season ?? 1} E${_room.episode ?? 1}',
                  tint: AppColors.moonlight,
                ),
              _metaBadge(
                _hostExplicitlyPaused
                    ? Icons.pause_rounded
                    : Icons.sensors_rounded,
                _hostExplicitlyPaused ? 'Paused by host' : 'Synced live',
                tint: _hostExplicitlyPaused ? _cAmber : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Watching together with $_partnerName',
            style: AppTypography.outfitWhite.copyWith(
              color: AppColors.textMedium,
              fontSize: 13,
              height: 1.5,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.deepRose.withValues(alpha: 0.15)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: accent
              ? AppColors.deepRose.withValues(alpha: 0.5)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
    );
  }

  Widget _buildCinemaServerSelector() {
    final isHls = _room.serverType == 'hls';
    final serverName = _room.streamUrl == null
        ? _selectedProvider.name
        : (_room.serverName ?? 'Server');
    final desc = _room.streamUrl == null
        ? _selectedProvider.desc
        : isHls
            ? 'Self-hosted HLS stream · real play/pause/seek sync'
            : 'Embedded server · best-effort sync';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: GestureDetector(
        onTap: _showServerPicker,
        child: Container(
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
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isHls ? AppColors.success : AppColors.blushGold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isHls
                                ? AppColors.success
                                : AppColors.blushGold)
                            .withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server: $serverName',
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.petalWhite,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncOverlay() {
    final pillColor = _isResyncing
        ? _cAmber
        : _hostExplicitlyPaused
        ? _cMuted
        : _cGreen;
    final pausedByMe =
        _hostExplicitlyPaused && _room.updatedBy == _myUid;
    final label = _isResyncing
        ? 'Syncing to ${_formatT(_room.currentTime)}…'
        : _hostExplicitlyPaused
        ? (pausedByMe ? 'You paused' : '$_partnerName paused')
        : 'Synced · ${_formatT(_displayedTime)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pillColor.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: pillColor,
                  shape: BoxShape.circle,
                  boxShadow: pillColor == _cGreen
                      ? [
                          BoxShadow(
                            color: _cGreen.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.outfitHeading.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (!widget.isHost) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.black,
        child: Row(
          children: [
            _buildServerChip(compact: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You\'re ${_formatT(_displayedTime)} in',
                style: AppTypography.outfitWhite.copyWith(
                  color: _cWhite.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: _hostExplicitlyPaused ? 'Play video' : 'Pause video',
              button: true,
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _cDeepRose.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _cDeepRose.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hostExplicitlyPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hostExplicitlyPaused ? 'RESUME' : 'PAUSE',
                        style: AppTypography.outfitWhite.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: Colors.black),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildServerChip(compact: true),
          const SizedBox(width: 10),
          Semantics(
            label: _hostExplicitlyPaused ? 'Play video' : 'Pause video',
            button: true,
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_cDeepRose, Color(0xFF8E1444)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _cDeepRose.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hostExplicitlyPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hostExplicitlyPaused ? 'RESUME' : 'PAUSE',
                      style: AppTypography.outfitWhite.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerChip({bool compact = false}) {
    final active = _room.streamUrl != null;
    final color = active
        ? (_room.serverType == 'hls' ? _cGreen : _cAmber)
        : _cMuted;
    final label = active ? (_room.serverName ?? 'Server') : 'Auto';
    return Semantics(
      label: 'Choose playback server',
      button: true,
      child: GestureDetector(
        onTap: _showServerPicker,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.dns_rounded : Icons.dns_outlined,
                color: color,
                size: 12,
              ),
              if (!compact) ...[
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      color: Colors.white,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHlsErrorCard() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_rounded, color: _cDeepRose, size: 48),
            const SizedBox(height: 12),
            Text(
              'This server could not start playback.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            if (_hlsError != null) ...[
              const SizedBox(height: 6),
              Text(
                _hlsError!,
                textAlign: TextAlign.center,
                style: AppTypography.outfitMuted.copyWith(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _errorAction(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  color: _cDeepRose,
                  onTap: () => _reloadHlsAt(_localStartHint()),
                ),
                _errorAction(
                  label: 'Switch server',
                  icon: Icons.dns_rounded,
                  color: _cAmber,
                  onTap: _showServerPicker,
                ),
                _errorAction(
                  label: 'Open in browser',
                  icon: Icons.open_in_new_rounded,
                  color: _cGreen,
                  onTap: () async {
                    final uri = Uri.parse(_externalOpenUrl());
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                color: Colors.white,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndDialog() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {},
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'End the night?',
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 22,
                    color: _cWhite,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your partner will be sent back to the cinema.',
                  textAlign: TextAlign.center,
                  style: AppTypography.outfitWhite.copyWith(
                    color: _cWhite.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _endDialogCallback?.call(false);
                        setState(() => _showEndDialog = false);
                      },
                      child: Text(
                        'Stay',
                        style: AppTypography.outfitBold.copyWith(color: _cRose),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _endDialogCallback?.call(true);
                        setState(() => _showEndDialog = false);
                      },
                      child: Text(
                        'End',
                        style: AppTypography.outfitHeading.copyWith(
                          color: _cDeepRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    final active = _selectedProvider;
    final others = _providers.where((p) => p.id != active.id).toList();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _cDeepRose,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'This title isn\'t available on ${active.shortName}.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The embed returned a 404 or didn\'t respond. Try a different source below.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitMuted.copyWith(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            if (others.isNotEmpty) ...[
              Text(
                'Try another source',
                style: AppTypography.outfitWhite.copyWith(
                  color: _cMuted,
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
                    .map(
                      (p) => GestureDetector(
                        onTap: () => _selectProvider(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _cDeepRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _cDeepRose.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                color: _cDeepRose,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.name,
                                style: AppTypography.outfitHeading.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
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
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open in browser',
                      style: AppTypography.outfitHeading.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

class _CinemaPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final bool accent;
  final VoidCallback onTap;

  const _CinemaPillButton({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.deepRose : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.deepRose.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: accent
                ? AppColors.deepRose.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.outfitHeading.copyWith(
                  color: color,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WatchPartyCinematicLoader extends StatefulWidget {
  final String serverName;

  const _WatchPartyCinematicLoader({required this.serverName});

  @override
  State<_WatchPartyCinematicLoader> createState() =>
      _WatchPartyCinematicLoaderState();
}

class _WatchPartyCinematicLoaderState extends State<_WatchPartyCinematicLoader>
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
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.petalWhite,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Fetching Media',
                    style: AppTypography.cormorantBoldWhite.copyWith(
                      fontSize: 22,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trying streaming servers...',
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.moonlight.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.blushGold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.serverName,
                          style: AppTypography.outfitHeading.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Trying...',
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
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
