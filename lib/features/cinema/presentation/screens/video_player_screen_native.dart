import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/video_source_config.dart';
import '../../data/services/cinema_video_sources.dart';
import '../../data/services/video_source_service.dart';
import '../../data/services/video_source_url_builder.dart';
import '../widgets/embed_webview.dart';

/// Native player for the third-party embed sources.
///
/// Web embeds are iframe-only, so on Android the same provider URL runs
/// inside an in-app WebView. The provider list and URL shape match the web
/// player exactly; only the delivery mechanism differs.
class VideoPlayerScreen extends StatefulWidget {
  final int tmdbId;
  final String mediaType;
  final int? season;
  final int? episode;
  final String title;
  final bool isAnime;
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
  final VideoSourceService _sourceService = VideoSourceService();
  late List<VideoSourceConfig> _providers;
  late VideoSourceConfig _currentProvider;
  String? _savedProviderId;
  bool _userSelectedSource = false;

  int get _externalId =>
      widget.isAnime ? (widget.malId ?? widget.tmdbId) : widget.tmdbId;

  int get _season => widget.season ?? 1;
  int get _episode => widget.episode ?? 1;

  @override
  void initState() {
    super.initState();
    _sourceService.addListener(_onSourcesChanged);
    _providers = _resolveProviders();
    _currentProvider = _resolveCurrent(_providers);
    _restoreDefaultSource();
  }

  @override
  void dispose() {
    _sourceService.removeListener(_onSourcesChanged);
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
      return VideoSourceConfig(
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

  String _buildUrl() {
    return buildVideoSourceUrl(
      _currentProvider,
      mediaType: widget.mediaType,
      id: _externalId.toString(),
      season: _season,
      episode: _episode,
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
              Text(
                'Switch Source',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Playback runs in-app. Switch sources if a server fails.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
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
                                      ? AppColors.deepRose
                                          .withValues(alpha: 0.2)
                                      : AppColors.moonlight
                                          .withValues(alpha: 0.08),
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

  Widget _buildPlayerCard() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.deepRose.withValues(alpha: 0.4),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md - 1),
          child: EmbedWebView(
            key: ValueKey(
              '${_currentProvider.id}-$_externalId-$_season-$_episode',
            ),
            url: _buildUrl(),
            onLoaded: () {
              debugPrint(
                '[VideoPlayerScreen] Loaded ${_currentProvider.id} for '
                '$_externalId',
              );
            },
          ),
        ),
      ),
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
              const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.roseQuartz,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
