import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/services/ani_zip_service.dart';
import '../../data/services/player_memory_service.dart';
import '../../data/services/playback_progress_writer.dart';
import '../../data/services/cinema_preferences.dart';
import '../widgets/cinema_viewing_preferences.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/video_source_service.dart';
import '../../data/services/cinema_video_sources.dart';
import '../../data/services/video_source_url_builder.dart';
import '../../data/models/video_source_config.dart';
import '../../data/models/media_item.dart';
import '../../data/models/next_episode.dart';
import '../../data/services/next_episode_service.dart';
import '../../../anime/presentation/widgets/animex/animex_videasy_progress.dart';
import '../../../../core/system/web_standalone.dart';
import '../widgets/episode_navigator.dart';
import '../widgets/up_next_overlay.dart';
import '../widgets/netflix/netflix_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_typography.dart';
part 'video_player_widgets.dart';
part 'video_player_state_base.dart';

class VideoPlayerScreen extends StatefulWidget {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final int? season;
  final int? episode;
  final int? startSeconds;
  final String title;

  /// When true, the player uses the MAL-id-based embed (vidsrc.to's
  /// `/embed/anime/mal/...` endpoint) instead of the TMDB-based Videasy
  /// URL. The `tmdbId` field is repurposed as the MAL id for these
  /// items — see [malId] for an explicit, recommended alternative.
  final bool isAnime;

  /// MAL id for anime items. Falls back to [tmdbId] for backwards
  /// compatibility with callers that haven't been updated.
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

class _VideoPlayerScreenState extends _VideoPlayerScreenStateBase {
  @override
  Widget build(BuildContext context) {
    _maybeAutoFullscreen(context);
    if (_isFullscreen) {
      // Theater: the platform-view iframe is fixed to the viewport via
      // DOM (see _toggleFullScreen), so Flutter only needs a black
      // backdrop plus a fallback exit pill. The pill sits behind the
      // fixed iframe when the DOM fix lands (harmless) and stays
      // tappable when it doesn't (no-trap fallback).
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Center(child: _buildPlayerArea()),
            Positioned(
              top: 12,
              left: 12,
              child: _PlayerPillButton(
                icon: Icons.fullscreen_exit_rounded,
                label: 'Exit theater',
                onTap: _toggleFullScreen,
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      // Home Screen status-bar inset arrives via MediaQuery (see
      // WebStandaloneInsets at the app root), so this SafeArea clears
      // it with no per-screen work.
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            // Scrollable body: video + metadata + server selector
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Player iframe area: 16:9, but capped so a strip of
                    // page content stays visible below it. In browser
                    // fullscreen the full-width player is taller than the
                    // viewport, and because embeds swallow wheel events the
                    // page can't be scrolled down to the server selector.
                    _buildPlayerArea(),
                    // Episode Navigator for TV content
                    if (widget.mediaType == 'tv' && !widget.isAnime)
                      EpisodeNavigator(
                        // Rebuild on auto-advance so the playing episode
                        // highlight follows the Up Next flow.
                        key: ValueKey(
                          'ep-nav-$_currentSeason-$_currentEpisode',
                        ),
                        tmdbId: widget.tmdbId,
                        initialSeason: _currentSeason,
                        initialEpisode: _currentEpisode,
                        positionSeconds: _playbackPositionSeconds,
                        durationSeconds: _playbackDurationSeconds,
                        allEpisodesWatched: widget.allEpisodesWatched,
                        currentEpisodeCompleted: _currentEpisodeCompleted,
                        onSeasonChanged: _onSeasonChanged,
                        onEpisodeChanged: _onEpisodeChanged,
                      ),
                    const CinemaViewingPreferences(compact: true),
                    RepaintBoundary(child: _buildMetadataSection()),
                    RepaintBoundary(child: _buildServerSelectorSection()),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 16:9 player frame shared by normal and theater layouts. In theater
  /// the frame fills the viewport; otherwise it caps so page content
  /// stays visible below (embeds swallow wheel events).
  Widget _buildPlayerArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = MediaQuery.sizeOf(context).height;
        final maxPlayerHeight = _isFullscreen
            ? viewportHeight
            : (viewportHeight - 296).clamp(240.0, double.infinity).toDouble();
        if (_iframeFailed) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxPlayerHeight),
            child: _buildErrorCard(context),
          );
        }
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
                    RepaintBoundary(
                      // Built-in factory: episode/server switches reuse
                      // this one frame instead of registering new ones.
                      child: HtmlElementView.fromTagName(
                        tagName: 'div',
                        onElementCreated: (element) {
                          final host = element as web.HTMLDivElement;
                          _playerHost = host;
                          host.style
                            ..width = '100%'
                            ..height = '100%';
                          host.appendChild(_iframe);
                        },
                      ),
                    ),
                    if (_isLoading)
                      _CinematicLoader(
                        providerName: _selectedProvider.shortName,
                      ),
                    // Show the countdown only when autoplay is
                    // about to advance, not a persistent Next pill.
                    if (!_isLoading &&
                        !_iframeFailed &&
                        _upNextVisible &&
                        widget.mediaType == 'tv' &&
                        _nextEpisode != null)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: UpNextOverlay(
                          next: _safeNextEpisode,
                          secondsLeft: _upNextLeft,
                          totalSeconds: _VideoPlayerScreenStateBase
                              ._upNextCountdownSeconds,
                          onPlayNow: _playNextEpisode,
                          onCancel: _cancelUpNext,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Top control & details bar. Uses glass pills that respond to hover
  /// (desktop) and press (touch) without changing any existing behavior.
  /// The title is the show name only: any trailing episode suffix that
  /// rode in on the route (`Show: Episode 3`, `Show Episode 3`, …) is
  /// stripped so the S/E badge below is the single episode label.
  Widget _buildTopBar() {
    final compact = MediaQuery.sizeOf(context).width < 560;
    final title = _playerDisplayTitle(widget.title);
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: _playerSurface,
        border: Border(bottom: BorderSide(color: _playerHairline, width: 1)),
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
          _PlayerPillButton(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Back',
            compact: compact,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: compact ? 8 : 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cormorantSemiBoldWhite.copyWith(
                fontSize: compact ? 15 : 18,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Theater mode',
            child: _PlayerIconButton(
              icon: Icons.fullscreen_rounded,
              compact: compact,
              onTap: () {
                // Manual toggle wins over auto-fullscreen.
                _autoFullscreen = false;
                _toggleFullScreen();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // METADATA SECTION
  // ---------------------------------------------------------------------------

  Widget _buildMetadataSection() {
    final genres = _details?['genres'] as List?;
    final genreNames = genres
        ?.map((g) => g is Map ? (g['name']?.toString() ?? '') : g.toString())
        .where((n) => n.isNotEmpty)
        .toList();
    final overview = (_details?['overview'] ?? '') as String;
    final ratingNum = _details?['vote_average'] as num?;
    final rating = ratingNum?.toDouble().toStringAsFixed(1);
    final runtime = _details?['runtime'] as int?;
    final epRun = _details?['episode_run_time'] as List?;
    final effRuntime =
        runtime ??
        (epRun != null && epRun.isNotEmpty ? epRun.first as int? : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaBadge(
                widget.mediaType == 'movie'
                    ? Icons.movie_rounded
                    : Icons.tv_rounded,
                widget.mediaType == 'movie' ? 'Movie' : 'TV Show',
                tint: _playerSecondary,
              ),
              if (widget.mediaType == 'tv')
                _metaBadge(
                  Icons.layers_rounded,
                  'S$_currentSeason E$_currentEpisode',
                  tint: _playerSecondary,
                ),
              if (rating != null)
                _metaBadge(
                  Icons.star_rounded,
                  '$rating/10',
                  tint: AppColors.blushGold,
                ),
              if (effRuntime != null && effRuntime > 0)
                _metaBadge(
                  Icons.schedule_rounded,
                  '${effRuntime}m',
                  tint: _playerSecondary,
                ),
            ],
          ),
          if (genreNames != null && genreNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: genreNames
                  .take(5)
                  .map(
                    (g) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _playerSurfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        g,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _playerSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              overview,
              style: AppTypography.outfitWhite.copyWith(
                color: _playerSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
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
    final chipColor = tint ?? _playerSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? _playerAccent.withValues(alpha: 0.14)
            : _playerSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: accent
              ? _playerAccent.withValues(alpha: 0.6)
              : _playerHairline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent ? _playerText : chipColor, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              color: accent ? _playerText : _playerSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SERVER SELECTOR
  // ---------------------------------------------------------------------------

  Widget _buildServerSelectorSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: GestureDetector(
        onTap: () => _showProviderSheet(),
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
                const _PulsingDot(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server: ${_selectedProvider.name}',
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedProvider.desc,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _playerSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PlayerIconButton(
                  icon: Icons.swap_horiz_rounded,
                  onTap: _showProviderSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MORE LIKE THIS
  // ---------------------------------------------------------------------------

  void _showProviderSheet() {
    _iframe.style.setProperty('pointer-events', 'none');
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _playerAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Switch Source',
                style: AppTypography.outfitWhite.copyWith(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a streaming provider',
                style: AppTypography.outfitMuted.copyWith(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: _selectableProviders.map((p) {
                    final isSelected = p.id == _selectedProvider.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _playerAccent.withValues(alpha: 0.12)
                                : _playerSurfaceElevated,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: isSelected
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
                                  color: isSelected
                                      ? _playerAccent.withValues(alpha: 0.16)
                                      : _playerHairline.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.live_tv_rounded,
                                  color: isSelected
                                      ? _playerAccent
                                      : _playerSecondary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: AppTypography.outfitWhite.copyWith(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.desc,
                                      style: AppTypography.outfitMuted.copyWith(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.radio_button_checked,
                                  color: _playerAccent,
                                  size: 18,
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    _sourceService.saveDefaultSourceId(p.id);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${p.name} set as default',
                                          ),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: _playerAccent,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Tooltip(
                                    message: 'Set as default source',
                                    child: Icon(
                                      Icons.star_border_rounded,
                                      color: Colors.white38,
                                      size: 20,
                                    ),
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
    ).then((provider) {
      _iframe.style.setProperty('pointer-events', 'auto');
      if (provider != null) _selectProvider(provider);
    });
  }

  /// Inline error card shown when the iframe 404s, errors out, or fails
  /// to load within [_loadTimeout]. Offers a horizontal list of the
  /// other providers (one tap switches the iframe) plus an "Open in
  /// browser" link as a final escape hatch.
  Widget _buildErrorCard(BuildContext context) {
    final active = _activeProvider;
    final others = _selectableProviders
        .where((p) => p.id != active.id)
        .toList();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _playerAccent.withValues(alpha: 0.12),
              border: Border.all(
                color: _playerAccent.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: _playerAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
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
                color: _playerSecondary,
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
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _playerAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: _playerAccent.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
                              color: _playerAccent,
                              size: 17,
                            ),
                            const SizedBox(width: 7),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: _playerAccent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Open in browser',
                    style: AppTypography.outfitBold.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 0.3,
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
}

// ---------------------------------------------------------------------------
// Player chrome widgets (video_player_screen only)
// ---------------------------------------------------------------------------

/// Glass pill button used by the player top bar. Gives desktop hover and
/// touch press feedback while keeping the same tap behavior as before.
