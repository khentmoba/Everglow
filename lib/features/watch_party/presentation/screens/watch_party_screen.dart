import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/services/voice_chat_service.dart';
import '../../data/services/watch_party_service.dart';
import '../widgets/voice_chat_overlay.dart';

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
  /// already have on screen.
  bool _hasAppliedInitialSnapshot = false;

  /// True while we're rebuilding the iframe to land at a new offset.
  /// The partner sees a "Syncing..." pill during this window.
  bool _isResyncing = false;
  Timer? _resyncHideTimer;

  /// True if the host has explicitly paused (separate from "the host
  /// hasn't pressed play yet"). Triggers the "Paused by Clair" pill
  /// on the partner's screen.
  bool _hostExplicitlyPaused = false;

  // ─── iframe plumbing (mirrors VideoPlayerScreen) ──────────────────
  bool _isLoading = true;
  bool _iframeFailed = false;
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;
  JSFunction? _onErrorListener;
  Timer? _loadTimer;
  late VideoProvider _selectedProvider;
  final Set<String> _failedProviderIds = {};

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

  /// Heartbeat interval. 5s keeps the partner's local clock within
  /// ~5s of the host without thrashing Firestore.
  static const Duration _heartbeatInterval = Duration(seconds: 5);

  /// Free embed providers. Same order as the regular VideoPlayerScreen
  /// so we fall back consistently. We duplicate the table here to
  /// keep this screen self-contained — the regular player and the
  /// watch-party player have slightly different needs (offset hint in
  /// the URL, no provider switcher UI) and trying to share logic
  /// across two iframes is messier than re-declaring the URLs.
  static const List<VideoProvider> _providers = [
    VideoProvider(
      id: 'vidfast',
      name: 'VidFast',
      shortName: 'VidFast',
      movieUrl: 'https://vidfast.pro/movie/',
      tvUrl: 'https://vidfast.pro/tv/',
    ),
    VideoProvider(
      id: 'vidlink',
      name: 'VidLink',
      shortName: 'VidLink',
      movieUrl: 'https://vidlink.pro/movie/',
      tvUrl: 'https://vidlink.pro/tv/',
    ),
    VideoProvider(
      id: 'multiembed',
      name: 'MultiEmbed',
      shortName: 'MultiEmbed',
      movieUrl: 'https://multiembed.mov/?video_id=',
      tvUrl: 'https://multiembed.mov/?video_id=',
    ),
    VideoProvider(
      id: '2embed.cc',
      name: '2Embed',
      shortName: '2Embed',
      movieUrl: 'https://www.2embed.cc/embed/',
      tvUrl: 'https://www.2embed.cc/embedtv/',
    ),
    VideoProvider(
      id: 'videasy',
      name: 'Videasy',
      shortName: 'Videasy',
      movieUrl: 'https://player.videasy.net/movie/',
      tvUrl: 'https://player.videasy.net/tv/',
    ),
    VideoProvider(
      id: 'vsembed',
      name: 'VsEmbed',
      shortName: 'VsEmbed',
      movieUrl: 'https://vsembed.ru/embed/movie/',
      tvUrl: 'https://vsembed.ru/embed/',
    ),
    VideoProvider(
      id: 'vidrock',
      name: 'VidRock',
      shortName: 'VidRock',
      movieUrl: 'https://vidrock.ru/movie/',
      tvUrl: 'https://vidrock.ru/tv/',
    ),
    VideoProvider(
      id: '111movies',
      name: '111Movies',
      shortName: '111Movies',
      movieUrl: 'https://111movies.com/movie/',
      tvUrl: 'https://111movies.com/tv/',
    ),
    VideoProvider(
      id: 'vidsrc',
      name: 'VidSrc',
      shortName: 'VidSrc',
      movieUrl: 'https://vidsrc.to/embed/movie/',
      tvUrl: 'https://vidsrc.to/embed/tv/',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _service = WatchPartyService();
    _auth = context.read<AuthService>();
    _room = widget.initialRoom;
    _myUid = _auth.uid ?? '';
    _partnerName = _auth.partnerName;

    // The host decides when play/pause/seek happens, the partner
    // listens + auto-resyncs. We do honour explicit "Resync" taps
    // on the partner side though.
    if (widget.isHost) {
      _hostExplicitlyPaused = _room.state == 'paused';
    } else {
      _hostExplicitlyPaused = _room.state == 'paused';
    }

    _selectedProvider = _providers.first;

    _viewType =
        'everglow-watchparty-${_room.tmdbId}-${_room.mediaType}-${_room.season ?? 0}-${_room.episode ?? 0}-${DateTime.now().microsecondsSinceEpoch}';

    _iframe = web.HTMLIFrameElement()
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; clipboard-write'
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

    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });

    _iframe.src = _buildPlayerUrl(_selectedProvider, startSeconds: _localStartHint());

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int viewId) => _iframe);

    // Subscribe to the room. Updates are debounced by Firestore's
    // snapshot pipeline (1-3s in practice) which is fine for our
    // 5s heartbeat cadence.
    _roomSub = _service.getRoomStream(_room.id).listen(_onRoomUpdate);

    // If the room has ended before either of us joined (host left
    // earlier), bounce out immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_room.active && _room.updatedBy != _myUid) {
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
    await _voiceChat.init(
      roomId: _room.id,
      myUid: _myUid,
      remoteUid: partnerUid,
      isCaller: widget.isHost,
    );
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _clockTicker?.cancel();
    _resyncHideTimer?.cancel();
    _loadTimer?.cancel();
    _roomSub?.cancel();
    _voiceChat.dispose();
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

  // ─── Local clock helpers ──────────────────────────────────────────

  /// Wall-clock estimate of the current playback position. We add
  /// elapsed wall time to the last anchored hint. While paused we
  /// just return the anchor (the iframe keeps playing, but we lie
  /// about it in the UI so the user can see "paused" badges).
  double _estimatedLocalTime() {
    if (_anchorEpoch == null) return _anchorTime;
    if (_hostExplicitlyPaused) return _anchorTime;
    final elapsed = DateTime.now().difference(_anchorEpoch!).inMilliseconds / 1000.0;
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
      await _service.heartbeat(
        roomId: _room.id,
        state: _hostExplicitlyPaused ? 'paused' : 'playing',
        currentTime: t,
        updatedBy: _myUid,
      );
    });
  }

  // ─── Snapshot pipeline ────────────────────────────────────────────

  void _onRoomUpdate(WatchPartyRoom? incoming) {
    if (!mounted) return;
    if (incoming == null) {
      // Doc deleted under us — treat as party ended.
      _showEndedAndPop();
      return;
    }
    if (!incoming.active) {
      _showEndedAndPop();
      return;
    }

    // Ignore our own writes — they echo back to us through the
    // snapshot pipeline and would cause an infinite iframe reload
    // loop on every heartbeat.
    final isLocalWrite = incoming.updatedBy == _myUid;
    if (isLocalWrite) {
      _room = incoming;
      return;
    }

    _room = incoming;
    _hostExplicitlyPaused = incoming.state == 'paused';

    if (!_hasAppliedInitialSnapshot) {
      _hasAppliedInitialSnapshot = true;
      // First remote snapshot after we mounted: jump the iframe
      // to the host's current position. After that we only
      // re-resync on drift.
      _rebuildAt(incoming.currentTime, immediate: true);
      return;
    }

    final drift = (incoming.currentTime - _estimatedLocalTime()).abs();
    if (drift > _resyncThresholdSeconds) {
      _rebuildAt(incoming.currentTime);
    } else {
      // Small drift — just re-anchor our clock without reloading
      // the iframe. The partner catches up smoothly.
      _anchorEpoch = DateTime.now();
      _anchorTime = incoming.currentTime;
    }
  }

  void _rebuildAt(double startSeconds, {bool immediate = false}) {
    if (!mounted) return;
    setState(() {
      _isResyncing = true;
    });
    // Tear down and re-mount the iframe at the new offset. This is
    // a hard seek (third-party providers don't expose a JS seek
    // API we can call from outside), but for our 4s drift threshold
    // it's invisible to the user.
    _isLoading = true;
    _iframeFailed = false;
    _anchorEpoch = DateTime.now();
    _anchorTime = startSeconds;
    _iframe.src = _buildPlayerUrl(_selectedProvider, startSeconds: startSeconds);
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
    _loadTimer?.cancel();
    if (!mounted) return;
    _failedProviderIds.add(_selectedProvider.id);
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
      _iframe.src = _buildPlayerUrl(next, startSeconds: _localStartHint());
    } else {
      setState(() => _iframeFailed = true);
    }
  }

  // ─── URL building ─────────────────────────────────────────────────
  // Mirrors the regular player. The only addition is a trailing
  // `&start=N` for providers that support it (Videasy accepts
  // `?startTime=N`). For the rest the hint is silently ignored —
  // they always start at 0 — which is the documented limitation of
  // the sync.

  String _buildPlayerUrl(VideoProvider provider, {required double startSeconds}) {
    final movieBase = provider.movieUrl;
    final tvBase = provider.tvUrl;
    final id = _room.isAnime ? (_room.malId ?? _room.tmdbId) : _room.tmdbId;
    final start = startSeconds.round();

    String base;
    if (_room.mediaType == 'tv') {
      final s = _room.season ?? 1;
      final e = _room.episode ?? 1;
      if (tvBase.contains('vidsrc.to')) {
        base = '$tvBase$id&season=$s&episode=$e';
      } else if (tvBase.contains('multiembed.mov')) {
        base = '$tvBase$id&tmdb=1&s=$s&e=$e';
      } else if (tvBase.contains('2embed.cc')) {
        base = '$tvBase$id&s=$s&e=$e';
      } else if (provider.id == 'vsembed') {
        base = '$tvBase$id?season=$s&episode=$e';
      } else {
        final sep = tvBase.endsWith('/') ? '' : '/';
        base = '$tvBase$sep$id/$s/$e';
      }
    } else {
      if (movieBase.contains('multiembed.mov')) {
        base = '$movieBase$id&tmdb=1';
      } else {
        final sep = movieBase.endsWith('/') ? '' : '/';
        base = '$movieBase$sep$id';
      }
    }

    // Only Videasy honours startTime in our supported provider set.
    // For everything else we still load — the start hint is just a
    // "would be nice". We never block on it.
    if (provider.id == 'videasy' && start > 0) {
      final sep = base.contains('?') ? '&' : '?';
      return '$base${sep}startTime=$start&autoplay=true';
    }
    if (provider.id == 'vidfast' && start > 0) {
      final sep = base.contains('?') ? '&' : '?';
      return '$base${sep}start=$start';
    }
    return base;
  }

  // ─── User actions ─────────────────────────────────────────────────

  Future<void> _togglePlayPause() async {
    final nextState = _hostExplicitlyPaused ? 'playing' : 'paused';
    setState(() {
      _hostExplicitlyPaused = !_hostExplicitlyPaused;
    });
    // Re-anchor the clock at the moment of pause/play so the local
    // estimate is exact from the toggle point forward.
    if (_hostExplicitlyPaused) {
      _anchorTime = _estimatedLocalTime();
      _anchorEpoch = DateTime.now();
    } else {
      _anchorEpoch = DateTime.now();
    }
    await _service.updatePlayback(
      roomId: _room.id,
      state: nextState,
      currentTime: _estimatedLocalTime(),
      updatedBy: _myUid,
    );
  }

  Future<void> _manualResync() async {
    setState(() => _isResyncing = true);
    _rebuildAt(_room.currentTime, immediate: true);
    await _service.updatePlayback(
      roomId: _room.id,
      state: _hostExplicitlyPaused ? 'paused' : 'playing',
      currentTime: _estimatedLocalTime(),
      updatedBy: _myUid,
    );
  }

  Future<void> _endParty() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'End the night?',
          style: GoogleFonts.cormorantGaramond(
            color: _cWhite,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Your partner will be sent back to the cinema.',
          style: GoogleFonts.outfit(color: _cWhite.withValues(alpha: 0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay',
                style: GoogleFonts.outfit(color: _cRose, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('End',
                style: GoogleFonts.outfit(
                    color: _cDeepRose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.endRoom(_room.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _showEndedAndPop() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_partnerName ended the party.',
          style: GoogleFonts.outfit(color: _cWhite),
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
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  if (!_iframeFailed) HtmlElementView(viewType: _viewType),
                  if (_isLoading && !_iframeFailed)
                    const Center(
                      child: CircularProgressIndicator(color: AppTheme.deepRose),
                    ),
                  if (_iframeFailed) _buildErrorCard(),
                  // The sync overlay is always on top so the partner
                  // can see drift / pause state at a glance.
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _buildSyncOverlay(),
                  ),
                  if (!widget.isHost)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: _buildPartnerControls(),
                    ),
                  VoiceChatOverlay(
                    service: _voiceChat,
                    partnerName: _partnerName,
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(color: Colors.black),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('Back',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _cDeepRose,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'WATCHING TOGETHER',
                      style: GoogleFonts.outfit(
                        color: _cRose,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _endParty,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _cDeepRose.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cDeepRose.withValues(alpha: 0.6)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('End',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncOverlay() {
    final pillColor = _isResyncing
        ? _cAmber
        : _hostExplicitlyPaused
            ? _cMuted
            : _cGreen;
    final label = _isResyncing
        ? 'Syncing to ${_formatT(_room.currentTime)}…'
        : _hostExplicitlyPaused
            ? '$_partnerName paused'
            : 'Synced · ${_formatT(_displayedTime)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: pillColor.withValues(alpha: 0.6), width: 1),
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
                      ? [BoxShadow(color: _cGreen.withValues(alpha: 0.6), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _manualResync,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cDeepRose.withValues(alpha: 0.6), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Resync to ${_formatT(_room.currentTime)}',
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
    );
  }

  Widget _buildBottomBar() {
    if (!widget.isHost) {
      // Partner sees a slim "follow host" bar — they don't get
      // play/pause because their player mirrors the host's anyway.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.black,
        child: Row(
          children: [
            const Icon(Icons.favorite, color: _cDeepRose, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Following $_partnerName · you\'re ${_formatT(_displayedTime)} in',
                style: GoogleFonts.outfit(color: _cWhite.withValues(alpha: 0.7), fontSize: 12),
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
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
                    style: GoogleFonts.outfit(
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
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _cDeepRose, size: 48),
            const SizedBox(height: 12),
            Text(
              'No provider could load this title.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _onIframeLoadError,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _cDeepRose.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cDeepRose.withValues(alpha: 0.6)),
                ),
                child: Text(
                  'Try next source',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

/// Minimal provider descriptor. The watch-party player doesn't expose
/// a provider switcher — we just cycle through the list internally on
/// iframe error.
class VideoProvider {
  final String id;
  final String name;
  final String shortName;
  final String movieUrl;
  final String tvUrl;

  const VideoProvider({
    required this.id,
    required this.name,
    required this.shortName,
    required this.movieUrl,
    required this.tvUrl,
  });
}
