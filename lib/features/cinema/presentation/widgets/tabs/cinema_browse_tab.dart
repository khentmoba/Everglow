import 'dart:async';
import 'package:flutter/material.dart' hide FilterChip;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/data/cinema_browse_config.dart';
import 'package:everglow/shared/widgets/shelf/shelf_section_header.dart';
import 'package:everglow/shared/widgets/shelf/shelf_empty_state.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/shared/widgets/shelf/filter_chip.dart';
import 'package:everglow/core/theme/app_breakpoints.dart';

// ─── Cinema Color Tokens ─────────────────────────────────────────────
const _cDeepRose = Color(0xFFC2185B);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

// ─────────────────────────────────────────────────────────────────────
// 3. BROWSE TAB
// ─────────────────────────────────────────────────────────────────────

class CinemaBrowseTab extends StatefulWidget {
  final void Function(MediaItem) onMediaTap;

  const CinemaBrowseTab({
    super.key,
    required this.onMediaTap,
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_cDeepRose, _cAmber],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Browse',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _cWhite,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Filter by genre, decade, language, or sort order.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: _cMuted,
            ),
          ),
        ),
        ...BrowseCategoryGroup.values.map(_buildBrowseGroup),
        const SizedBox(height: 16),
        if (_selectedBrowseOptionId != null) _buildBrowseResults(),
      ],
    );
  }

  Widget _buildBrowseGroup(BrowseCategoryGroup group) {
    final options =
        cinemaBrowseOptions.where((o) => o.group == group).toList();
    final meta = browseGroupMeta(group);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        meta.tint,
                        meta.tint.withValues(alpha: 0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(meta.icon, color: meta.tint, size: 18),
                const SizedBox(width: 8),
                Text(
                  meta.title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: meta.tint,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  meta.subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _cMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final option = options[i];
                final selected = _selectedBrowseOptionId == option.id;
                return FilterChip(
                  icon: option.icon,
                  label: option.label,
                  color: option.color,
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

  Widget _buildBrowseResults() {
    if (_isLoadingBrowse) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: _cDeepRose),
        ),
      );
    }

    if (_browseResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: ShelfEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results',
          subtitle: 'Try a different filter.',
          accent: _cDeepRose,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: ShelfSectionHeader(
            eyebrow: 'Results',
            title: '${_browseResults.length} titles',
            icon: Icons.movie_filter_rounded,
            accent: _cDeepRose,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppBreakpoint.isDesktop(context)
                  ? 6
                  : (AppBreakpoint.isTablet(context) ? 4 : 2),
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _browseResults.length,
            itemBuilder: (context, index) {
              final item = _browseResults[index];
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
        if (_browseHasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: GestureDetector(
                onTap: _loadMoreBrowse,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _cDeepRose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _cDeepRose.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Load more',
                    style: GoogleFonts.outfit(
                      color: _cDeepRose,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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

  /// Shared fetch logic for browse pagination.
  Future<List<MediaItem>> _fetchBrowsePage(BrowseCategoryOption option) async {
    if (option.genreId != null) {
      return _tmdbService.discoverByGenre(
        genreId: option.genreId!,
        mediaType: option.mediaType,
        sortBy: option.sortBy,
      );
    } else {
      return _tmdbService.discoverMedia(
        mediaType: option.mediaType,
        sortBy: option.sortBy,
        withGenres: option.genreId != null ? [option.genreId!] : null,
        yearGte: option.yearGte,
        yearLte: option.yearLte,
        voteAverageGte: option.voteAverageGte,
        voteCountGte: option.voteCountGte,
        withOriginalLanguage: option.withOriginalLanguage,
        page: _browseCurrentPage,
      );
    }
  }
}
