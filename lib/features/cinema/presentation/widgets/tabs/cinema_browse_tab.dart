import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../data/cinema_browse_config.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import '../netflix/netflix_colors.dart';
import '../netflix/netflix_nav_bar.dart';
import '../netflix/netflix_poster_card.dart';
import '../../../../../core/theme/app_typography.dart';

/// Netflix-style browse: quiet category chips feeding a poster grid.
class CinemaBrowseTab extends StatefulWidget {
  final void Function(MediaItem) onMediaTap;
  final void Function(MediaItem)? onPlayItem;
  final void Function(MediaItem, bool add)? onToggleListItem;
  final void Function(MediaItem, double? rating)? onRateItem;
  final bool Function(MediaItem)? isInList;
  final TMDBService? service;

  /// Browse option to auto-select on first build (used by top nav links).
  final String? initialOptionId;

  const CinemaBrowseTab({
    super.key,
    required this.onMediaTap,
    this.onPlayItem,
    this.onToggleListItem,
    this.onRateItem,
    this.isInList,
    this.service,
    this.initialOptionId,
  });

  @override
  State<CinemaBrowseTab> createState() => _CinemaBrowseTabState();
}

class _CinemaBrowseTabState extends State<CinemaBrowseTab> {
  TMDBService get _tmdbService => widget.service ?? TMDBService();

  String? _selectedBrowseOptionId;
  List<MediaItem> _browseResults = [];
  bool _isLoadingBrowse = false;
  int _browseCurrentPage = 0;
  bool _browseHasMore = true;
  bool _browseFailed = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOptionId;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final option = cinemaBrowseOptions.where((o) => o.id == initial);
        if (option.isNotEmpty && mounted) {
          _selectBrowseOption(option.first);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppBreakpoint.isDesktop(context) ? 48 : 16,
            cinemaTopContentInset(context),
            AppBreakpoint.isDesktop(context) ? 48 : 16,
            4,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Browse',
              style: AppTypography.outfitHeading.copyWith(
                fontSize: AppBreakpoint.isDesktop(context) ? 22 : 20,
                color: NetflixColors.textPrimary,
              ),
            ),
          ),
        ),
        ...BrowseCategoryGroup.values.map(
          (group) => SliverToBoxAdapter(child: _buildBrowseGroup(group)),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (_selectedBrowseOptionId != null) ..._buildBrowseResultSlivers(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildBrowseGroup(BrowseCategoryGroup group) {
    final options = cinemaBrowseOptions.where((o) => o.group == group).toList();
    if (options.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 48 : 16,
              0,
              isDesktop ? 48 : 16,
              10,
            ),
            child: Text(
              browseGroupMeta(group).title,
              style: AppTypography.outfitHeading.copyWith(
                fontSize: isDesktop ? 16 : 15,
                color: NetflixColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final option = options[i];
                final selected = _selectedBrowseOptionId == option.id;
                return _BrowsePill(
                  label: option.label,
                  selected: selected,
                  onTap: () => _selectBrowseOption(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBrowseResultSlivers() {
    if (_isLoadingBrowse && _browseResults.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: NetflixColors.accent,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (_browseFailed && _browseResults.isEmpty) {
      return [SliverToBoxAdapter(child: _buildBrowseError())];
    }

    if (_browseResults.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Center(
              child: Text(
                'No titles found for this filter.',
                style: AppTypography.outfitWhite.copyWith(
                  color: NetflixColors.textMuted,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    final isDesktop = AppBreakpoint.isDesktop(context);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            18,
            isDesktop ? 48 : 16,
            12,
          ),
          child: Text(
            '${_browseResults.length} titles',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: NetflixColors.textMuted,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop
                ? 6
                : (AppBreakpoint.isTablet(context) ? 5 : 3),
            childAspectRatio: 0.67,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _browseResults.length,
          itemBuilder: (context, index) {
            final item = _browseResults[index];
            return NetflixPosterCard(
              item: item,
              compact: true,
              selfPreview: true,
              onTap: () => widget.onMediaTap(item),
              onPlay: widget.onPlayItem,
              onToggleList: widget.onToggleListItem,
              onRate: widget.onRateItem,
              isInList: widget.isInList,
            );
          },
        ),
      ),
      if (_browseFailed)
        SliverToBoxAdapter(child: _buildBrowseError())
      else if (_browseHasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: NetflixColors.textPrimary,
                  backgroundColor: NetflixColors.surface,
                ),
                onPressed: _isLoadingBrowse ? null : _loadMoreBrowse,
                child: Text(_isLoadingBrowse ? 'Loading…' : 'Load More'),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildBrowseError() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(
          'Couldn’t load titles. Please try again.',
          style: AppTypography.outfitWhite.copyWith(
            color: NetflixColors.textSecondary,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: NetflixColors.textPrimary,
          ),
          onPressed: _loadMoreBrowse,
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  void _selectBrowseOption(BrowseCategoryOption option) {
    HapticFeedback.lightImpact();
    _requestVersion++;
    setState(() {
      _selectedBrowseOptionId = option.id;
      _browseResults = [];
      _browseCurrentPage = 0;
      _browseHasMore = true;
      _isLoadingBrowse = false;
      _browseFailed = false;
    });
    _loadMoreBrowse();
  }

  Future<void> _loadMoreBrowse() async {
    if (_isLoadingBrowse || !_browseHasMore) return;
    final option = cinemaBrowseOptions.firstWhere(
      (o) => o.id == _selectedBrowseOptionId,
    );
    final version = _requestVersion;
    final page = _browseCurrentPage + 1;
    setState(() {
      _isLoadingBrowse = true;
      _browseFailed = false;
    });
    try {
      final results = await _tmdbService.discoverMedia(
        mediaType: option.mediaType,
        sortBy: option.sortBy,
        withGenres: option.genreId == null ? null : [option.genreId!],
        yearGte: option.yearGte,
        yearLte: option.yearLte,
        voteAverageGte: option.voteAverageGte,
        voteCountGte: option.voteCountGte,
        withOriginalLanguage: option.withOriginalLanguage,
        page: page,
        failOnError: true,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        final seen = _browseResults
            .map((m) => '${m.mediaType}:${m.tmdbId}')
            .toSet();
        _browseResults.addAll(
          results.where((m) => seen.add('${m.mediaType}:${m.tmdbId}')),
        );
        _browseCurrentPage = page;
        _browseHasMore = results.length >= 20 && page < 500;
        _isLoadingBrowse = false;
      });
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _browseFailed = true;
        _isLoadingBrowse = false;
      });
    }
  }
}

class _BrowsePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BrowsePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          foregroundColor: selected
              ? NetflixColors.background
              : NetflixColors.textSecondary,
          backgroundColor: selected
              ? NetflixColors.textPrimary
              : NetflixColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: NetflixColors.hairline),
          ),
          textStyle: AppTypography.outfitHeading.copyWith(fontSize: 12.5),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
