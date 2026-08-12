import 'dart:async';
import 'package:flutter/material.dart';

import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_colors.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_nav_bar.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Netflix-style search: a quiet input, instant results, popular searches.
class CinemaSearchTab extends StatefulWidget {
  final List<MediaItem> trendingGlobal;
  final void Function(MediaItem) onMediaTap;
  final void Function(int) onSwitchTab;

  const CinemaSearchTab({
    super.key,
    required this.trendingGlobal,
    required this.onMediaTap,
    required this.onSwitchTab,
  });

  @override
  State<CinemaSearchTab> createState() => _CinemaSearchTabState();
}

class _CinemaSearchTabState extends State<CinemaSearchTab> {
  final TMDBService _tmdbService = TMDBService();
  final TextEditingController _searchController = TextEditingController();
  List<MediaItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  // Search filter state
  bool _filterMoviesOnly = false;
  bool _filterTVOnly = false;
  double? _filterMinVote;
  final Set<String> _filterYears = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _runSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _performSearch(query.trim());
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
                style: AppTypography.outfitHeading.copyWith(fontSize: isDesktop ? 22 : 20, color: NetflixColors.textPrimary),
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
                  style: AppTypography.outfitWhite.copyWith(color: NetflixColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Titles, actors, genres',
                    hintStyle: AppTypography.outfitWhite.copyWith(color: NetflixColors.textMuted, fontSize: 15),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: NetflixColors.textSecondary,
                      size: 21,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: NetflixColors.textMuted,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _isSearching = false;
                                _clearSearchFilters();
                              });
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
              height: 32,
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
              : _filteredSearchResults.isEmpty
              ? (_searchController.text.isEmpty
                    ? _buildSearchLanding()
                    : _buildSearchEmptyState())
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    10,
                    horizontalPad,
                    120,
                  ),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop
                        ? 6
                        : (AppBreakpoint.isTablet(context) ? 4 : 3),
                    childAspectRatio: 0.67,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _filteredSearchResults.length,
                  itemBuilder: (context, index) {
                    final item = _filteredSearchResults[index];
                    return NetflixPosterCard(
                      item: item,
                      compact: true,
                      selfPreview: true,
                      onTap: () => widget.onMediaTap(item),
                    );
                  },
                ),
        ),
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
              'No results found',
              style: AppTypography.outfitHeading.copyWith(color: NetflixColors.textPrimary, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different title or keyword.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(color: NetflixColors.textMuted, fontSize: 13),
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
                    style: AppTypography.outfitHeading.copyWith(color: NetflixColors.textPrimary, fontSize: isDesktop ? 18 : 16),
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
              style: AppTypography.outfitHeading.copyWith(color: NetflixColors.textPrimary, fontSize: isDesktop ? 18 : 16),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop
                  ? 6
                  : (AppBreakpoint.isTablet(context) ? 4 : 3),
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
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _clearSearchFilters();
    });
    final results = await _tmdbService.searchMedia(query);
    // Exclude anime from cinema search - the dedicated Anime screen
    // already covers Japanese animation content.
    final filtered = results.where((m) => !m.isAnime).toList();
    if (mounted) {
      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    }
  }

  List<_SearchFilterChip> get _searchFilterChips {
    final chips = <_SearchFilterChip>[];

    chips.add(
      _SearchFilterChip(
        icon: Icons.movie_outlined,
        label: 'Movies only',
        color: NetflixColors.accent,
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
        icon: Icons.tv_outlined,
        label: 'TV only',
        color: NetflixColors.gold,
        selected: _filterTVOnly,
        onTap: () {
          setState(() {
            _filterTVOnly = !_filterTVOnly;
            if (_filterTVOnly) _filterMoviesOnly = false;
          });
        },
      ),
    );

    for (final rating in [9.0, 8.0]) {
      final key = rating.toStringAsFixed(1);
      final isSelected = _filterMinVote == rating;
      chips.add(
        _SearchFilterChip(
          icon: Icons.star_rounded,
          label: '$key+',
          color: NetflixColors.gold,
          selected: isSelected,
          onTap: () {
            setState(() {
              _filterMinVote = isSelected ? null : rating;
            });
          },
        ),
      );
    }

    for (final year in ['2025', '2024', '2023']) {
      final isSelected = _filterYears.contains(year);
      chips.add(
        _SearchFilterChip(
          icon: Icons.calendar_today_rounded,
          label: year,
          color: const Color(0xFF4CAF50),
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
        icon: Icons.clear_rounded,
        label: 'Clear',
        color: const Color(0xFFE53935),
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
    _filterMinVote = null;
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : NetflixColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.white : NetflixColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitHeading.copyWith(color: selected ? Colors.black : NetflixColors.textSecondary, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _SearchFilterChip {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SearchFilterChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
}
