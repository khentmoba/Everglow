import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/features/cinema/data/cinema_browse_config.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_colors.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Netflix-style browse: quiet category chips feeding a poster grid.
class CinemaBrowseTab extends StatefulWidget {
  final void Function(MediaItem) onMediaTap;

  /// Browse option to auto-select on first build (used by top nav links).
  final String? initialOptionId;

  const CinemaBrowseTab({
    super.key,
    required this.onMediaTap,
    this.initialOptionId,
  });

  @override
  State<CinemaBrowseTab> createState() => _CinemaBrowseTabState();
}

class _CinemaBrowseTabState extends State<CinemaBrowseTab> {
  final TMDBService _tmdbService = TMDBService();

  String? _selectedBrowseOptionId;
  List<MediaItem> _browseResults = [];
  bool _isLoadingBrowse = false;
  int _browseCurrentPage = 1;
  bool _browseHasMore = true;

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
            24,
            AppBreakpoint.isDesktop(context) ? 48 : 16,
            4,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Browse',
              style: AppTypography.outfitHeading.copyWith(fontSize: AppBreakpoint.isDesktop(context) ? 22 : 20, color: NetflixColors.textPrimary),
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
              style: AppTypography.outfitHeading.copyWith(fontSize: isDesktop ? 16 : 15, color: NetflixColors.textSecondary),
            ),
          ),
          SizedBox(
            height: 36,
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
    if (_isLoadingBrowse) {
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

    if (_browseResults.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Center(
              child: Text(
                'No titles found for this filter.',
                style: AppTypography.outfitWhite.copyWith(color: NetflixColors.textMuted, fontSize: 13.5),
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
            '\ titles',
            style: AppTypography.outfitWhite.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: NetflixColors.textMuted),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop
                ? 6
                : (AppBreakpoint.isTablet(context) ? 4 : 3),
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
            );
          },
        ),
      ),
      if (_browseHasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Center(
              child: GestureDetector(
                onTap: _loadMoreBrowse,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: NetflixColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NetflixColors.hairline),
                  ),
                  child: Text(
                    'Load More',
                    style: AppTypography.outfitHeading.copyWith(color: NetflixColors.textPrimary, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  void _selectBrowseOption(BrowseCategoryOption option) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedBrowseOptionId = option.id;
      _browseResults = [];
      _browseCurrentPage = 1;
      _browseHasMore = true;
    });
    _fetchBrowseResults(option);
  }

  Future<void> _fetchBrowseResults(BrowseCategoryOption option) async {
    setState(() => _isLoadingBrowse = true);
    final results = await _fetchBrowsePage(option);
    if (!mounted) return;
    setState(() {
      _browseResults = results;
      _browseHasMore = results.length >= 20;
      _isLoadingBrowse = false;
    });
  }

  Future<void> _loadMoreBrowse() async {
    if (_isLoadingBrowse || !_browseHasMore) return;
    _browseCurrentPage++;

    final option = cinemaBrowseOptions.firstWhere(
      (o) => o.id == _selectedBrowseOptionId,
      orElse: () => cinemaBrowseOptions.first,
    );

    setState(() => _isLoadingBrowse = true);
    final results = await _fetchBrowsePage(option);
    if (!mounted) return;
    setState(() {
      _browseResults.addAll(results);
      _browseHasMore = results.length >= 20;
      _isLoadingBrowse = false;
    });
  }

  Future<List<MediaItem>> _fetchBrowsePage(BrowseCategoryOption option) async {
    if (option.genreId != null) {
      return _tmdbService.discoverByGenre(
        genreId: option.genreId!,
        mediaType: option.mediaType,
        sortBy: option.sortBy,
      );
    }
    return _tmdbService.discoverMedia(
      mediaType: option.mediaType,
      sortBy: option.sortBy,
      yearGte: option.yearGte,
      yearLte: option.yearLte,
      voteAverageGte: option.voteAverageGte,
      voteCountGte: option.voteCountGte,
      withOriginalLanguage: option.withOriginalLanguage,
      page: _browseCurrentPage,
    );
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? Colors.white : NetflixColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.white : NetflixColors.hairline,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.outfitHeading.copyWith(color: selected ? Colors.black : NetflixColors.textSecondary, fontSize: 12.5),
        ),
      ),
    );
  }
}
