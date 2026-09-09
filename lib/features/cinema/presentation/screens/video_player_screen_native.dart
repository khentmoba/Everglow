import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/next_episode.dart';
import '../../data/models/video_source_config.dart';
import '../../data/services/cinema_video_sources.dart';
import '../../data/services/next_episode_service.dart';
import '../../data/services/video_source_service.dart';
import '../../data/services/video_source_url_builder.dart';
import '../widgets/embed_webview.dart';
import '../widgets/up_next_overlay.dart';

/// Native player for the third-party embed sources.
///
/// Web embeds are iframe-only, so on Android the same provider URL runs
/// inside an in-app WebView. The provider list and URL shape match the web
/// player exactly; only the delivery mechanism differs.
///
/// TV episodes get the same Up Next flow as the web player: a persistent
/// Next pill plus a "Next episode in 10..." auto countdown near the end
/// (runtime-estimate fallback — WebViews never report real position).
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
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final VideoSourceService _sourceService = VideoSourceService();
  final NextEpisodeService _nextService = NextEpisodeService();
  late List<VideoSourceConfig> _providers;
  late VideoSourceConfig _currentProvider;
  String? _savedProviderId;
  bool _userSelectedSource = false;

  late int _currentSeason;
  late int _currentEpisode;

  NextEpisode? _nextEpisode;
  bool _upNextVisible = false;
  int _upNextLeft = 10;
  Timer? _upNextTimer;
  Timer? _upNextFallbackTimer;
  bool _upNextDismissed = false;
  static const int _upNextCountdownSeconds = 10;
  static const int _upNextLeadSeconds = 90;

  int get _externalId =>
      widget.isAnime ? (widget.malId ?? widget.tmdbId) : widget.tmdbId;

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.season ?? 1;
    _currentEpisode = widget.episode ?? 1;
    _sourceService.addListener(_onSourcesChanged);
    _providers = _resolveProviders();
    _currentProvider = _resolveCurrent(_providers);
    _restoreDefaultSource();
    _resolveNextEpisode();
    _scheduleUpNextFallback();
  }

  @override
  void dispose() {
    _upNextTimer?.cancel();
    _upNextFallbackTimer?.cancel();
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
    final id = await _sourceService.loadDefaultSourceId();
    if (!mounted || id == null) return;
    setState(() {
      _savedProviderId = id;
      final providers = _resolveProviders();
      _providers = providers;
      _currentProvider = _resolveCurrent(providers);
    });
  }

  Future<void> _selectProvider(VideoSourceConfig provider) async {
    _userSelectedSource = true;
    _savedProviderId = provider.id;
    setState(() => _currentProvider = provider);
    await _sourceService.saveDefaultSourceId(provider.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${provider.name} selected'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepRose,
      ),
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

  /// Runtime-estimate fallback: WebViews never report playback position,
  /// so the countdown is scheduled for 90 seconds before the estimated
  /// end (TMDB runtime, defaulting to 42 minutes).
  Future<void> _scheduleUpNextFallback() async {
    _upNextFallbackTimer?.cancel();
    if (widget.mediaType != 'tv' || widget.isAnime) return;
    final minutes = await _nextService.fetchEpisodeRuntime(
      tmdbId: widget.tmdbId,
    );
    if (!mounted) return;
    final totalSeconds = (minutes ?? 42) * 60;
    final delaySeconds = totalSeconds - _upNextLeadSeconds;
    if (delaySeconds <= 10) return;
    _upNextFallbackTimer = Timer(
      Duration(seconds: delaySeconds),
      () {
        if (!mounted) return;
        _showUpNext();
      },
    );
  }

  void _showUpNext() {
    if (_upNextVisible || _upNextDismissed) return;
    if (_nextEpisode == null || !mounted) return;
    setState(() {
      _upNextVisible = true;
      _upNextLeft = _upNextCountdownSeconds;
    });
    _upNextTimer?.cancel();
    _upNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
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
    _upNextTimer?.cancel();
    _upNextFallbackTimer?.cancel();
    setState(() {
      _currentSeason = next.season;
      _currentEpisode = next.episode;
      _upNextVisible = false;
      _upNextDismissed = false;
      _nextEpisode = null;
    });
    _resolveNextEpisode();
    _scheduleUpNextFallback();
  }

  void _playPreviousEpisode() {
    if (_currentEpisode <= 1) return;
    _upNextTimer?.cancel();
    _upNextFallbackTimer?.cancel();
    setState(() {
      _currentEpisode--;
      _upNextVisible = false;
      _upNextDismissed = false;
      _nextEpisode = null;
    });
    _resolveNextEpisode();
    _scheduleUpNextFallback();
  }

  String _buildUrl() {
    return buildVideoSourceUrl(
      _currentProvider,
      mediaType: widget.mediaType,
      id: _externalId.toString(),
      season: _currentSeason,
      episode: _currentEpisode,
    );
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
        const SnackBar(
          content: Text('Could not open the browser. Try another source.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.deepRose,
        ),
      );
    }
  }

  void _showSourceSheet() {
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
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: _providers.map((provider) {
                    final selected = provider.id == _currentProvider.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.deepRose.withValues(alpha: 0.12)
                                : AppColors.surfaceGlass,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: selected
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
                                  color: selected
                                      ? AppColors.deepRose.withValues(
                                          alpha: 0.2,
                                        )
                                      : AppColors.moonlight.withValues(
                                          alpha: 0.08,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  selected
                                      ? Icons.check_rounded
                                      : Icons.live_tv_rounded,
                                  color: selected
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
                                        color: AppColors.textMuted,
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
              if (widget.mediaType == 'tv' &&
                  !widget.isAnime &&
                  _nextEpisode != null)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _upNextVisible
                      ? UpNextOverlay(
                          next: _nextEpisode!,
                          secondsLeft: _upNextLeft,
                          totalSeconds: _upNextCountdownSeconds,
                          onPlayNow: _playNextEpisode,
                          onCancel: _cancelUpNext,
                        )
                      : NextEpisodeButton(
                          next: _nextEpisode!,
                          onTap: _playNextEpisode,
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
        title: Text(widget.title),
        backgroundColor: AppColors.inkDeep,
        foregroundColor: AppColors.petalWhite,
        actions: [
          TextButton.icon(
            onPressed: _showSourceSheet,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(_currentProvider.shortName),
            style: TextButton.styleFrom(foregroundColor: AppColors.roseQuartz),
          ),
          const SizedBox(width: 8),
        ],
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
          _buildSourceCard(),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open in browser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.roseQuartz,
                side: BorderSide(
                  color: AppColors.roseQuartz.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'If the player stays blank, pick another source below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
            onTap: canPrev ? _playPreviousEpisode : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StepperButton(
            label: next == null ? 'Next Episode' : 'Next: ${next.label}',
            icon: Icons.skip_next_rounded,
            enabled: next != null,
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
          border: Border.all(color: AppColors.deepRose.withValues(alpha: 0.4)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EmbedWebView(
                key: ValueKey(
                  '${_currentProvider.id}-$_externalId-$_currentSeason-$_currentEpisode',
                ),
                url: _buildUrl(),
                onLoaded: () {
                  debugPrint(
                    '[VideoPlayerScreen] Loaded ${_currentProvider.id} for '
                    '$_externalId',
                  );
                },
              ),
              if (widget.mediaType == 'tv' &&
                  !widget.isAnime &&
                  _nextEpisode != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _upNextVisible
                      ? UpNextOverlay(
                          next: _nextEpisode!,
                          secondsLeft: _upNextLeft,
                          totalSeconds: _upNextCountdownSeconds,
                          onPlayNow: _playNextEpisode,
                          onCancel: _cancelUpNext,
                        )
                      : NextEpisodeButton(
                          next: _nextEpisode!,
                          onTap: _playNextEpisode,
                        ),
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
        'fs-${_currentProvider.id}-$_externalId-$_currentSeason-$_currentEpisode',
      ),
      url: _buildUrl(),
    );
  }

  Widget _buildSourceCard() {
    return GestureDetector(
      onTap: _showSourceSheet,
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
            color: AppColors.inkDeep.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.x2 - 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.live_tv_rounded,
                color: AppColors.roseQuartz,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server: ${_currentProvider.name}',
                      style: const TextStyle(
                        color: AppColors.petalWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentProvider.desc,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.swap_horiz_rounded, color: AppColors.roseQuartz),
            ],
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
  final VoidCallback? onTap;

  const _StepperButton({
    required this.label,
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.deepRose.withValues(alpha: 0.16)
              : AppColors.moonlight.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: enabled
                ? AppColors.deepRose.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled
                  ? AppColors.roseQuartz
                  : AppColors.textDisabled,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled
                      ? AppColors.petalWhite
                      : AppColors.textDisabled,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.2),
          ),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white70,
          size: 18,
        ),
      ),
    );
  }
}
