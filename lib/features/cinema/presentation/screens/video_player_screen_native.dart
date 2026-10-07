import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/media_item.dart';
import '../../data/models/next_episode.dart';
import '../../data/models/video_source_config.dart';
import '../../data/services/cinema_video_sources.dart';
import '../../data/services/next_episode_service.dart';
import '../../data/services/playback_progress_writer.dart';
import '../../data/services/player_memory_service.dart';
import '../../data/services/cinema_preferences.dart';
import '../widgets/cinema_viewing_preferences.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/video_source_service.dart';
import '../../data/services/video_source_url_builder.dart';
import '../widgets/embed_webview.dart';
import '../widgets/netflix/netflix_colors.dart';

/// Show name only: strips any trailing episode suffix the route may have
/// carried (`Show: Episode 3`, `Show Episode 3`) so the stepper below is
/// the single episode label.
String _nativeDisplayTitle(String raw) {
  var title = raw.trim();
  if (title.isEmpty) return title;
  final suffixes = [
    RegExp(r'\s*[:|–—-]\s*S\d+\s*E\d+.*$', caseSensitive: false),
    RegExp(r'\s*[:|–—-]\s*E\d+.*$', caseSensitive: false),
    RegExp(r'\s*[:|–—-]\s*Episode\s*\d+.*$', caseSensitive: false),
    RegExp(r'\s+S\d+\s*E\d+\s*$', caseSensitive: false),
    RegExp(r'\s+E\d+\s*$', caseSensitive: false),
    RegExp(r'\s+Episode\s*\d+\s*$', caseSensitive: false),
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final pattern in suffixes) {
      final next = title.replaceAll(pattern, '').trim();
      if (next.isNotEmpty && next != title) {
        title = next;
        changed = true;
      }
    }
  }
  return title.isEmpty ? raw.trim() : title;
}

/// Native player for the third-party embed sources.
///
/// Web embeds are iframe-only, so on Android the same provider URL runs
/// inside an in-app WebView. The provider list and URL shape match the web
/// player exactly; only the delivery mechanism differs.
///
/// WebViews without real progress keep manual Next; no timer guesses an ending.
/// Phones auto-fullscreen in landscape.
class VideoPlayerScreen extends StatefulWidget {
  final int tmdbId;
  final String mediaType;
  final int? season;
  final int? episode;
  final int? startSeconds;
  final String title;
  final bool isAnime;
  final int? malId;
  final String posterPath;
  final bool allEpisodesWatched;
  final bool currentEpisodeCompleted;

  const VideoPlayerScreen({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.season,
    this.episode,
    this.startSeconds,
    required this.title,
    this.isAnime = false,
    this.malId,
    this.posterPath = '',
    this.allEpisodesWatched = false,
    this.currentEpisodeCompleted = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
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

  final VideoSourceService _sourceService = VideoSourceService();
  final NextEpisodeService _nextService = NextEpisodeService();
  final PlayerMemoryService _memoryService = PlayerMemoryService();
  late List<VideoSourceConfig> _providers;
  late VideoSourceConfig _currentProvider;
  String? _savedProviderId;
  bool _userSelectedSource = false;

  late int _currentSeason;
  late int _currentEpisode;

  /// Season/episode the WebView was loaded with. Manual navigation keeps
  /// these equal to the current ones, but when the embed advances on its
  /// own only the current pair moves — the WebView keeps playing the new
  /// episode without a rebuild while the UI follows it.
  late int _playerSeason;
  late int _playerEpisode;

  NextEpisode? _nextEpisode;
  bool _hasSavedWatchProgress = false;
  final PlaybackProgressWriter _progressWriter = PlaybackProgressWriter();
  int _playbackPositionSeconds = 0;
  int _playbackDurationSeconds = 0;
  int? _startSeconds;
  final Set<String> _failedProviderIds = {};

  int get _externalId =>
      widget.isAnime ? (widget.malId ?? widget.tmdbId) : widget.tmdbId;

  /// Per-title memory key, shared with the web player so the picked
  /// server follows Clair across phone and browser on this device.
  String get _memoryKey => PlayerMemoryService.cinemaKey(
    id: _externalId,
    mediaType: widget.mediaType,
    isAnime: widget.isAnime,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSeason = widget.season ?? 1;
    _currentEpisode = widget.episode ?? 1;
    _playerSeason = _currentSeason;
    _playerEpisode = _currentEpisode;
    _startSeconds = widget.startSeconds;
    _playbackPositionSeconds = _startSeconds ?? 0;
    unawaited(
      CinemaPreferences.instance.setUser(
        context.read<AuthService>().currentUser,
      ),
    );
    _sourceService.addListener(_onSourcesChanged);
    _providers = _resolveProviders();
    _currentProvider = _resolveCurrent(_providers);
    _restoreDefaultSource();
    _resolveNextEpisode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveWatchProgress());
  }

  void _saveWatchProgress() {
    if (_hasSavedWatchProgress) return;
    _hasSavedWatchProgress = true;

    String userName = '';
    try {
      userName = context.read<AuthService>().currentUser ?? '';
    } catch (e) {
      debugPrint('[VideoPlayerScreenNative] Failed to read AuthService: $e');
    }
    if (userName.isEmpty) return;

    final status = _watchingStatusFor(userName);
    unawaited(
      _progressWriter.writeNow(
        () => TMDBService().updateProgress(
          MediaItem(
            id: '',
            tmdbId: widget.tmdbId,
            title: _nativeDisplayTitle(widget.title),
            mediaType: widget.mediaType,
            posterPath: widget.posterPath,
            status: status,
            isAnime: widget.isAnime,
            userName: userName,
            addedAt: DateTime.now(),
            source: widget.isAnime ? 'jikan' : 'tmdb',
          ),
          userName,
          season: widget.mediaType == 'tv' ? _currentSeason : null,
          episode: widget.mediaType == 'tv' ? _currentEpisode : null,
          timestamp:
              _currentSeason == _playerSeason &&
                  _currentEpisode == _playerEpisode
              ? _playbackPositionSeconds
              : 0,
          durationSeconds: _playbackDurationSeconds > 0
              ? _playbackDurationSeconds
              : null,
          status: status,
        ),
      ),
    );
  }

  void _scheduleProgressHeartbeat() {
    String userName = '';
    try {
      userName = context.read<AuthService>().currentUser ?? '';
    } catch (_) {
      return;
    }
    if (userName.isEmpty) return;

    final season = widget.mediaType == 'tv' ? _currentSeason : null;
    final episode = widget.mediaType == 'tv' ? _currentEpisode : null;
    final position = _playbackPositionSeconds;
    final duration = _playbackDurationSeconds;
    final provider = _currentProvider.id;
    final key = _memoryKey;
    _progressWriter.schedule(() async {
      await TMDBService().heartbeatProgress(
        widget.tmdbId,
        userName,
        season: season,
        episode: episode,
        timestamp: position,
        durationSeconds: duration > 0 ? duration : null,
      );
      if (!mounted ||
          season != (widget.mediaType == 'tv' ? _currentSeason : null) ||
          episode != (widget.mediaType == 'tv' ? _currentEpisode : null) ||
          provider != _currentProvider.id ||
          key != _memoryKey) {
        return;
      }
      await _memoryService.save(
        key,
        providerId: provider,
        season: season,
        episode: episode,
        positionSeconds: position > 0 ? position : null,
        clearPosition: position <= 0,
      );
    });
  }

  void _onPlayerProgress(int position, int duration) {
    if (!mounted ||
        position < 0 ||
        duration <= 0 ||
        position > duration ||
        (position == _playbackPositionSeconds &&
            duration == _playbackDurationSeconds)) {
      return;
    }
    setState(() {
      _playbackPositionSeconds = position;
      _playbackDurationSeconds = duration;
    });
    if (!_hasSavedWatchProgress) _saveWatchProgress();
    _scheduleProgressHeartbeat();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _scheduleProgressHeartbeat();
    _persistEpisodeMemory();
    unawaited(_progressWriter.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleProgressHeartbeat();
    _persistEpisodeMemory();
    unawaited(_progressWriter.flush());
    _sourceService.removeListener(_onSourcesChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  List<VideoSourceConfig> _resolveProviders() {
    return CinemaVideoSources.selectable(
      _sourceService.providers,
      isAnime: widget.isAnime,
    );
  }

  VideoSourceConfig _resolveCurrent(List<VideoSourceConfig> providers) {
    if (providers.isEmpty) {
      return const VideoSourceConfig(
        id: 'none',
        name: 'No source',
        shortName: 'None',
        movieUrl: '',
        tvUrl: '',
      );
    }
    final saved = _savedProviderId;
    for (final provider in providers) {
      if (provider.id == saved) return provider;
    }
    for (final provider in providers) {
      if (provider.isRecommended) return provider;
    }
    return providers.first;
  }

  void _onSourcesChanged() {
    if (!mounted) return;
    setState(() {
      final providers = _resolveProviders();
      _providers = providers;
      _currentProvider = _resolveCurrent(providers);
    });
  }

  Future<void> _restoreDefaultSource() async {
    if (_userSelectedSource) return;
    // This title's last-used server wins; the global default is fallback.
    final memory = await _memoryService.load(_memoryKey);
    if (!mounted || _userSelectedSource) return;
    final id = memory.providerId ?? await _sourceService.loadDefaultSourceId();
    if (!mounted || id == null) return;
    setState(() {
      _savedProviderId = id;
      final providers = _resolveProviders();
      _providers = providers;
      _currentProvider = _resolveCurrent(providers);
    });
  }

  Future<void> _selectProvider(VideoSourceConfig provider) async {
    _failedProviderIds.clear();
    _userSelectedSource = true;
    _savedProviderId = provider.id;
    // The resume offset belongs to the loaded episode. When the selection
    // drifted ahead via auto-play, the new server loads the new episode
    // from its start instead of seeking into the old offset.
    if (_playerSeason != _currentSeason || _playerEpisode != _currentEpisode) {
      _startSeconds = null;
    }
    setState(() {
      _currentProvider = provider;
      // A new server must load the episode actually being watched, which
      // may have drifted ahead of the loaded WebView via auto-play.
      _playerSeason = _currentSeason;
      _playerEpisode = _currentEpisode;
    });
    await _memoryService.save(_memoryKey, providerId: provider.id);
    await _sourceService.saveDefaultSourceId(provider.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${provider.name} selected'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _playerAccent,
      ),
    );
  }

  /// Remembers the current server + episode for this title so the
  /// next visit reopens where Clair left off. Fire-and-forget.
  void _persistEpisodeMemory() {
    final sameEpisode =
        _currentSeason == _playerSeason && _currentEpisode == _playerEpisode;
    _memoryService.save(
      _memoryKey,
      providerId: _currentProvider.id,
      season: _currentSeason,
      episode: _currentEpisode,
      positionSeconds: sameEpisode && _playbackPositionSeconds > 0
          ? _playbackPositionSeconds
          : null,
      clearPosition: !sameEpisode || _playbackPositionSeconds <= 0,
    );
  }

  Future<void> _resolveNextEpisode() async {
    if (widget.mediaType != 'tv' || widget.isAnime) return;
    final season = _currentSeason;
    final episode = _currentEpisode;
    final next = await _nextService.resolve(
      tmdbId: widget.tmdbId,
      season: season,
      episode: episode,
    );
    if (!mounted) return;
    if (season != _currentSeason || episode != _currentEpisode) return;
    setState(() => _nextEpisode = next);
  }

  void _playNextEpisode() {
    final next = _nextEpisode;
    if (next == null) return;
    setState(() {
      _currentSeason = next.season;
      _currentEpisode = next.episode;
      _playerSeason = next.season;
      _playerEpisode = next.episode;
      _nextEpisode = null;
      _startSeconds = null;
      _playbackPositionSeconds = 0;
      _playbackDurationSeconds = 0;
      _hasSavedWatchProgress = false;
    });
    _resolveNextEpisode();
    _saveWatchProgress();
    _persistEpisodeMemory();
  }

  void _playPreviousEpisode() {
    if (_currentEpisode <= 1) return;
    setState(() {
      _currentEpisode--;
      _playerSeason = _currentSeason;
      _playerEpisode = _currentEpisode;
      _nextEpisode = null;
      _startSeconds = null;
      _playbackPositionSeconds = 0;
      _playbackDurationSeconds = 0;
      _hasSavedWatchProgress = false;
    });
    _resolveNextEpisode();
    _saveWatchProgress();
    _persistEpisodeMemory();
  }

  String _buildUrl() {
    // Built from the LOADED episode, not the selection: after a
    // player-driven advance the selection moves on while the WebView keeps
    // playing, and the URL must stay byte-identical so Flutter reuses it.
    return buildVideoSourceUrl(
      _currentProvider,
      mediaType: widget.mediaType,
      id: _externalId.toString(),
      season: _playerSeason,
      episode: _playerEpisode,
      startSeconds: _startSeconds,
    );
  }

  /// Follows the embed when it changes episodes on its own (CineSrc
  /// auto-play or its built-in episode picker), without rebuilding the
  /// WebView — no reload, no lost position. Only the Everglow server
  /// reports these on native (our wrapper bridges them); the direct
  /// CineSrc embed posts to itself inside the WebView, out of reach.
  void _onPlayerEpisodeChanged(int season, int episode) {
    if (!mounted || widget.mediaType != 'tv' || widget.isAnime) return;
    if (season <= 0 || episode <= 0) return;
    if (_currentProvider.id != 'everglow-embed') return;
    if (season == _currentSeason && episode == _currentEpisode) return;
    setState(() {
      _currentSeason = season;
      _currentEpisode = episode;
      _nextEpisode = null;
      _playbackPositionSeconds = 0;
      _playbackDurationSeconds = 0;
      _startSeconds = null;
      _hasSavedWatchProgress = false;
    });
    _resolveNextEpisode();
    _saveWatchProgress();
    _persistEpisodeMemory();
  }

  void _onPlayerMessage(String raw) {
    if (_currentProvider.id == 'everglow-embed' &&
        !widget.isAnime &&
        EmbedWebView.isOwnedPlayerUrl(_buildUrl())) {
      final progress = EmbedWebView.parsePlayerProgress(raw);
      if (progress != null) _onPlayerProgress(progress.$1, progress.$2);
    }
    final ep = EmbedWebView.parsePlayerEpisode(raw);
    if (ep != null) _onPlayerEpisodeChanged(ep.$1, ep.$2);
  }

  void _onSourceError() {
    if (!mounted) return;
    _failedProviderIds.add(_currentProvider.id);
    final remaining = _providers.where(
      (p) => !_failedProviderIds.contains(p.id),
    );
    if (remaining.isEmpty) return; // The WebView already offers Retry.
    if (_playerSeason != _currentSeason || _playerEpisode != _currentEpisode) {
      _startSeconds = null;
    }
    setState(() {
      _currentProvider = remaining.first;
      _playerSeason = _currentSeason;
      _playerEpisode = _currentEpisode;
    });
  }

  Future<void> _openInBrowser() async {
    final url = _buildUrl();
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    final canLaunch = await canLaunchUrl(uri);
    var ok = false;
    if (canLaunch) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        ok = true;
      } catch (_) {
        ok = false;
      }
    }
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not open the browser. Try another source.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _playerAccent,
        ),
      );
    }
  }

  void _showSourceSheet() {
    showModalBottomSheet<VideoSourceConfig>(
      context: context,
      backgroundColor: _playerSurface,
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
                  color: _playerHairline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Switch Source',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Playback runs in-app. Switch sources if a server fails.',
                style: TextStyle(color: _playerSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: _providers.map((provider) {
                    final selected = provider.id == _currentProvider.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, provider),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _playerAccent.withValues(alpha: 0.12)
                                  : _playerSurfaceElevated,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: selected
                                    ? _playerAccent.withValues(alpha: 0.65)
                                    : _playerHairline,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _playerAccent.withValues(alpha: 0.16)
                                        : _playerHairline.withValues(
                                            alpha: 0.35,
                                          ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    selected
                                        ? Icons.check_rounded
                                        : Icons.live_tv_rounded,
                                    color: selected
                                        ? _playerAccent
                                        : _playerSecondary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        provider.desc,
                                        style: TextStyle(
                                          color: _playerSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
    ).then((provider) async {
      if (provider != null) {
        await _selectProvider(provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPhone = size.shortestSide < 600;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // Phones auto-fullscreen in landscape: player fills the screen,
    // chrome hides, system UI goes immersive. Portrait restores all.
    if (isPhone && isLandscape) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      });
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildFullscreenPlayer(),
              Positioned(
                top: 8,
                left: 8,
                child: _LandscapeBackButton(
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _nativeDisplayTitle(widget.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _playerSurface,
        foregroundColor: _playerText,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildPlayerCard(),
          if (widget.mediaType == 'tv' && !widget.isAnime) ...[
            const SizedBox(height: AppSpacing.md),
            _buildEpisodeStepper(),
          ],
          const SizedBox(height: AppSpacing.lg),
          const CinemaViewingPreferences(compact: true),
          _buildSourceCard(),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open in browser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _playerAccent,
                side: BorderSide(color: _playerAccent.withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'If the player stays blank, pick another source below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _playerSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeStepper() {
    final canPrev = _currentEpisode > 1;
    final next = _nextEpisode;
    return Row(
      children: [
        Expanded(
          child: _StepperButton(
            label: 'Prev Episode',
            icon: Icons.skip_previous_rounded,
            enabled: canPrev,
            accent: _playerAccent,
            onTap: canPrev ? _playPreviousEpisode : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StepperButton(
            label: next == null ? 'Next Episode' : 'Next: ${next.label}',
            icon: Icons.skip_next_rounded,
            enabled: next != null,
            accent: _playerAccent,
            onTap: next == null ? null : _playNextEpisode,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: _playerHairline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EmbedWebView(
                key: ValueKey(
                  '${_currentProvider.id}-$_externalId-$_playerSeason-$_playerEpisode',
                ),
                url: _buildUrl(),
                onPlayerMessage: _onPlayerMessage,
                onError: _onSourceError,
                onLoaded: () {
                  debugPrint(
                    '[VideoPlayerScreen] Loaded ${_currentProvider.id} for '
                    '$_externalId',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenPlayer() {
    return EmbedWebView(
      key: ValueKey(
        'fs-${_currentProvider.id}-$_externalId-$_playerSeason-$_playerEpisode',
      ),
      url: _buildUrl(),
      onPlayerMessage: _onPlayerMessage,
      onError: _onSourceError,
    );
  }

  Widget _buildSourceCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _showSourceSheet,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.x2),
            color: _playerSurfaceElevated,
            border: Border.all(color: _playerHairline),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: _playerSurface,
              borderRadius: BorderRadius.circular(AppRadius.x2),
            ),
            child: Row(
              children: [
                Icon(Icons.live_tv_rounded, color: _playerSecondary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server: ${_currentProvider.name}',
                        style: TextStyle(
                          color: _playerText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentProvider.desc,
                        style: TextStyle(color: _playerSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.swap_horiz_rounded, color: _playerSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final Color accent;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.14)
                : NetflixColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.6)
                  : NetflixColors.hairline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? accent : AppColors.textDisabled,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? Colors.white : AppColors.textDisabled,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapeBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LandscapeBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: NetflixColors.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: NetflixColors.hairline),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white70,
            size: 18,
          ),
        ),
      ),
    );
  }
}
