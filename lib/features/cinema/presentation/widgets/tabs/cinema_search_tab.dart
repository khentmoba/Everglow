import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import '../netflix/netflix_colors.dart';
import '../netflix/netflix_nav_bar.dart';
import '../netflix/netflix_poster_card.dart';
import '../../../../../core/theme/app_typography.dart';

/// Netflix-style search: a quiet input, instant results, popular searches.
class CinemaSearchTab extends StatefulWidget {
  final List<MediaItem> trendingGlobal;
  final void Function(MediaItem) onMediaTap;
  final void Function(MediaItem)? onPlayItem;
  final void Function(MediaItem, bool add)? onToggleListItem;
  final void Function(MediaItem, double? rating)? onRateItem;
  final bool Function(MediaItem)? isInList;
  final TMDBService? service;
  final void Function(int) onSwitchTab;

  const CinemaSearchTab({
    super.key,
    required this.trendingGlobal,
    required this.onMediaTap,
    this.onPlayItem,
    this.onToggleListItem,
    this.onRateItem,
    this.isInList,
    this.service,
    required this.onSwitchTab,
  });

  @override
  State<CinemaSearchTab> createState() => _CinemaSearchTabState();
}

class _CinemaSearchTabState extends State<CinemaSearchTab> {
  TMDBService get _tmdbService => widget.service ?? TMDBService();
  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  int _requestVersion = 0;
  int _searchPage = 0;
  bool _searchHasMore = false;
  bool _searchFailed = false;
  bool _isLoadingMore = false;

  // Search filter state
  bool _filterMoviesOnly = false;
  bool _filterTVOnly = false;
  final Set<String> _filterYears = {};

  @override
  void dispose() {
    _requestVersion++;
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _onSearchChanged(query);
    _searchDebounce?.cancel();
    if (query.trim().isNotEmpty) _performSearch(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad = isDesktop ? 48.0 : 16.0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            cinemaTopContentInset(context),
            horizontalPad,
            4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search',
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: isDesktop ? 22 : 20,
                  color: NetflixColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: NetflixColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NetflixColors.hairline),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: AppTypography.outfitWhite.copyWith(
                    color: NetflixColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search movie and TV titles',
                    hintStyle: AppTypography.outfitWhite.copyWith(
                      color: NetflixColors.textMuted,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: NetflixColors.textSecondary,
                      size: 21,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: NetflixColors.textMuted,
                              size: 18,
                            ),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_searchResults.isNotEmpty && !_isSearching)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 4),
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _searchFilterChips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final chip = _searchFilterChips[i];
                  return _SearchPill(
                    label: chip.label,
                    selected: chip.selected,
                    onTap: chip.onTap,
                  );
                },
              ),
            ),
          ),

        Expanded(
          child: _isSearching
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: NetflixColors.accent,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : _searchController.text.trim().isEmpty
              ? _buildSearchLanding()
              : _buildSearchResults(horizontalPad),
        ),
      ],
    );
  }

  Widget _buildSearchResults(double horizontalPad) {
    final items = _filteredSearchResults;
    return CustomScrollView(
      slivers: [
        if (items.isEmpty && !_searchFailed)
          SliverToBoxAdapter(
            child: SizedBox(height: 200, child: _buildSearchEmptyState()),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 0),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppBreakpoint.isDesktop(context)
                  ? 6
                  : (AppBreakpoint.isTablet(context) ? 5 : 3),
              childAspectRatio: 0.67,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
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
        if (_searchFailed || _searchHasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_searchFailed)
                    Text(
                      'Couldn’t search titles. Please try again.',
                      style: AppTypography.outfitWhite.copyWith(
                        color: NetflixColors.textSecondary,
                      ),
                    ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: NetflixColors.textPrimary,
                      backgroundColor: NetflixColors.surface,
                    ),
                    onPressed: _isLoadingMore
                        ? null
                        : () => _performSearch(
                            _searchController.text.trim(),
                            page: _searchPage + 1,
                          ),
                    child: Text(
                      _isLoadingMore
                          ? 'Loading…'
                          : (_searchFailed ? 'Retry' : 'Load More'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: NetflixColors.textMuted,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              _searchResults.isEmpty
                  ? 'No results found'
                  : 'No titles match these filters',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textPrimary,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchResults.isEmpty
                  ? 'Try a different title.'
                  : 'Clear the filters or load more titles.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: NetflixColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchLanding() {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad = isDesktop ? 48.0 : 16.0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (widget.trendingGlobal.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                20,
                horizontalPad,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Popular Searches',
                    style: AppTypography.outfitHeading.copyWith(
                      color: NetflixColors.textPrimary,
                      fontSize: isDesktop ? 18 : 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.trendingGlobal.take(12).map((item) {
                      return _SearchPill(
                        label: item.title,
                        selected: false,
                        onTap: () => _runSearch(item.title),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 14),
            child: Text(
              'Popular Now',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textPrimary,
                fontSize: isDesktop ? 18 : 16,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop
                  ? 6
                  : (AppBreakpoint.isTablet(context) ? 5 : 3),
              childAspectRatio: 0.67,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = widget.trendingGlobal[index];
              return NetflixPosterCard(
                item: item,
                compact: true,
                selfPreview: true,
                onTap: () => widget.onMediaTap(item),
              );
            }, childCount: widget.trendingGlobal.length),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final version = ++_requestVersion;
    setState(() {
      _searchResults = [];
      _searchPage = 0;
      _searchHasMore = false;
      _searchFailed = false;
      _isLoadingMore = false;
      _isSearching = query.trim().isNotEmpty;
      _clearSearchFilters();
    });
    if (query.trim().isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && version == _requestVersion) _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query, {int page = 1}) async {
    final version = _requestVersion;
    setState(() {
      _isSearching = page == 1;
      _isLoadingMore = page > 1;
      _searchFailed = false;
    });
    try {
      final results = await _tmdbService.searchMedia(
        query,
        page: page,
        failOnError: true,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        final seen = _searchResults
            .map((m) => '${m.mediaType}:${m.tmdbId}')
            .toSet();
        _searchResults.addAll(
          results.where(
            (m) => !m.isAnime && seen.add('${m.mediaType}:${m.tmdbId}'),
          ),
        );
        _searchPage = page;
        // The list API has no total-pages metadata. A final empty page
        // ends pagination even when anime filtering shortened this page.
        _searchHasMore = results.isNotEmpty && page < 500;
        _isSearching = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _searchFailed = true;
        _isSearching = false;
        _isLoadingMore = false;
      });
    }
  }

  List<_SearchFilterChip> get _searchFilterChips {
    final chips = <_SearchFilterChip>[];

    chips.add(
      _SearchFilterChip(
        label: 'Movies only',
        selected: _filterMoviesOnly,
        onTap: () {
          setState(() {
            _filterMoviesOnly = !_filterMoviesOnly;
            if (_filterMoviesOnly) _filterTVOnly = false;
          });
        },
      ),
    );
    chips.add(
      _SearchFilterChip(
        label: 'TV only',
        selected: _filterTVOnly,
        onTap: () {
          setState(() {
            _filterTVOnly = !_filterTVOnly;
            if (_filterTVOnly) _filterMoviesOnly = false;
          });
        },
      ),
    );

    for (var offset = 0; offset < 3; offset++) {
      final year = '${DateTime.now().year - offset}';
      final isSelected = _filterYears.contains(year);
      chips.add(
        _SearchFilterChip(
          label: year,
          selected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _filterYears.remove(year);
              } else {
                _filterYears.add(year);
              }
            });
          },
        ),
      );
    }

    chips.add(
      _SearchFilterChip(
        label: 'Clear',
        selected: false,
        onTap: () {
          setState(_clearSearchFilters);
        },
      ),
    );

    return chips;
  }

  List<MediaItem> get _filteredSearchResults {
    var items = _searchResults;
    if (_filterMoviesOnly) {
      items = items.where((i) => i.mediaType == 'movie').toList();
    }
    if (_filterTVOnly) {
      items = items.where((i) => i.mediaType == 'tv').toList();
    }
    if (_filterYears.isNotEmpty) {
      items = items.where((i) => _filterYears.contains(i.year)).toList();
    }
    return items;
  }

  void _clearSearchFilters() {
    _filterMoviesOnly = false;
    _filterTVOnly = false;
    _filterYears.clear();
  }
}

class _SearchPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SearchPill({
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: NetflixColors.textPrimary,
          backgroundColor: selected
              ? NetflixColors.accent
              : NetflixColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: selected ? NetflixColors.accent : NetflixColors.hairline,
            ),
          ),
          textStyle: AppTypography.outfitHeading.copyWith(fontSize: 12.5),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SearchFilterChip {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SearchFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
}
