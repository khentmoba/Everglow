import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:google_fonts/google_fonts.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/filter_chip.dart';
import 'package:everglow/core/theme/app_breakpoints.dart';

// ─── Cinema Color Tokens ─────────────────────────────────────────────
const _cCard = Color(0xFF1C1228);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

// ─────────────────────────────────────────────────────────────────────
// 2. SEARCH TAB
// ─────────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad = isDesktop ? 48.0 : 20.0;

    return Column(
      children: [
        // Hero search header — like cineby's "Discover Your Next Favorite"
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            isDesktop ? 32 : (MediaQuery.of(context).padding.top + 14),
            horizontalPad,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShelfIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    semanticLabel: 'Back to Home',
                    tooltip: 'Back to Home',
                    onTap: () => widget.onSwitchTab(0),
                  ),
                ),
              Text(
                'Discover Your Next Favorite',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isDesktop ? 32 : 26,
                  fontWeight: FontWeight.w800,
                  color: _cWhite,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search through thousands of movies, TV shows, and anime',
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 14 : 12,
                  color: _cMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: _cCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _cDeepRose.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: _cDeepRose.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.outfit(color: _cWhite, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Movies, TV shows...',
                    hintStyle: GoogleFonts.outfit(color: _cMuted, fontSize: 15),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        Icons.search_rounded,
                        color: _cDeepRose,
                        size: 22,
                      ),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: _cMuted,
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
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search filter chips (visible when results are loaded)
        if (_searchResults.isNotEmpty && !_isSearching)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPad, 8, horizontalPad, 0,
            ),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _searchFilterChips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final chip = _searchFilterChips[i];
                  return FilterChip(
                    icon: chip.icon,
                    label: chip.label,
                    color: chip.color,
                    selected: chip.selected,
                    onTap: chip.onTap,
                  );
                },
              ),
            ),
          ),

        // Results
        Expanded(
          child: _isSearching
              ? Center(
                  child: CircularProgressIndicator(
                    color: _cDeepRose,
                    strokeWidth: 2.5,
                  ),
                )
              : _filteredSearchResults.isEmpty
              ? (_searchController.text.isEmpty
                    ? _buildSearchLanding()
                    : _buildSearchEmptyState())
              : GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop
                        ? 6
                        : (AppBreakpoint.isTablet(context) ? 4 : 2),
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _filteredSearchResults.length,
                  itemBuilder: (context, index) {
                    final item = _filteredSearchResults[index];
                    return ShelfPosterCard(
                      imageUrl: item.posterPath,
                      title: item.title,
                      subtitle: item.year.isNotEmpty ? item.year : null,
                      badge: item.mediaType == 'movie' ? 'MOVIE' : 'TV',
                      badgeIcon: item.mediaType == 'movie'
                          ? Icons.movie_outlined
                          : Icons.tv_outlined,
                      onTap: () => widget.onMediaTap(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchEmptyState() {
    return ShelfEmptyState(
      icon: _searchController.text.isEmpty
          ? Icons.travel_explore_rounded
          : Icons.search_off_rounded,
      title: _searchController.text.isEmpty
          ? 'Type to discover magic'
          : 'No results found',
      subtitle: _searchController.text.isEmpty
          ? 'Search any movie or TV show to add it to your queue or mark it as watched.'
          : 'Try a different keyword — the catalogue is huge.',
      accent: _cDeepRose,
    );
  }

  /// Search landing page — shows trending today when no query is entered,
  /// matching cineby's search page UX.
  Widget _buildSearchLanding() {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad = isDesktop ? 48.0 : 20.0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 24, horizontalPad, 16),
            child: ShelfSectionHeader(
              eyebrow: 'Trending Today',
              title: 'Popular Now',
              icon: Icons.local_fire_department_rounded,
              accent: _cDeepRose,
              count: widget.trendingGlobal.length,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop
                  ? 6
                  : (AppBreakpoint.isTablet(context) ? 4 : 2),
              childAspectRatio: 0.65,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = widget.trendingGlobal[index];
              return ShelfPosterCard(
                imageUrl: item.posterPath,
                title: item.title,
                subtitle: item.year.isNotEmpty ? item.year : null,
                badge: item.mediaType == 'movie' ? 'MOVIE' : 'TV',
                badgeIcon: item.mediaType == 'movie'
                    ? Icons.movie_outlined
                    : Icons.tv_outlined,
                onTap: () => widget.onMediaTap(item),
              );
            }, childCount: widget.trendingGlobal.length),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  // ─── Search Logic ─────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
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
    // Exclude anime from cinema search — the dedicated Anime screen
    // already covers Japanese animation content.
    final filtered = results.where((m) => !m.isAnime).toList();
    if (mounted) {
      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    }
  }

  /// Client-side search filter chips — built dynamically from current state.
  List<_SearchFilterChip> get _searchFilterChips {
    final chips = <_SearchFilterChip>[];

    // Media type filters
    chips.add(_SearchFilterChip(
      icon: Icons.movie_outlined,
      label: 'Movies only',
      color: _cDeepRose,
      selected: _filterMoviesOnly,
      onTap: () {
        setState(() {
          _filterMoviesOnly = !_filterMoviesOnly;
          if (_filterMoviesOnly) _filterTVOnly = false;
        });
      },
    ));
    chips.add(_SearchFilterChip(
      icon: Icons.tv_outlined,
      label: 'TV only',
      color: _cGold,
      selected: _filterTVOnly,
      onTap: () {
        setState(() {
          _filterTVOnly = !_filterTVOnly;
          if (_filterTVOnly) _filterMoviesOnly = false;
        });
      },
    ));

    // Rating filters
    for (final rating in [9.0, 8.0]) {
      final key = rating.toStringAsFixed(1);
      final isSelected = _filterMinVote == rating;
      chips.add(_SearchFilterChip(
        icon: Icons.star_rounded,
        label: '$key+',
        color: _cAmber,
        selected: isSelected,
        onTap: () {
          setState(() {
            _filterMinVote = isSelected ? null : rating;
          });
        },
      ));
    }

    // Year filters
    for (final year in ['2025', '2024', '2023']) {
      final isSelected = _filterYears.contains(year);
      chips.add(_SearchFilterChip(
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
      ));
    }

    // Clear all filters
    chips.add(_SearchFilterChip(
      icon: Icons.clear_rounded,
      label: 'Clear filters',
      color: const Color(0xFFE53935),
      selected: false,
      onTap: () {
        setState(_clearSearchFilters);
      },
    ));

    return chips;
  }

  /// Applies client-side filters to [_searchResults].
  List<MediaItem> get _filteredSearchResults {
    var items = _searchResults;
    if (_filterMoviesOnly) {
      items = items.where((i) => i.mediaType == 'movie').toList();
    }
    if (_filterTVOnly) {
      items = items.where((i) => i.mediaType == 'tv').toList();
    }
    if (_filterMinVote != null) {
      // TMDB search results don't include vote_average in multi-search
      // results by default, so we filter on what we can.
    }
    if (_filterYears.isNotEmpty) {
      items = items.where((i) => _filterYears.contains(i.year)).toList();
    }
    return items;
  }

  void _clearSearchFilters() {
    setState(() {
      _filterMoviesOnly = false;
      _filterTVOnly = false;
      _filterMinVote = null;
      _filterYears.clear();
    });
  }
}

/// Helper model for search filter chips used in the Search tab (Phase 3e).
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
