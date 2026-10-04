import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/tmdb_images.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../anime/data/services/anilist_service.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb/tmdb_discovery_service.dart';
import '../../../cinema/data/services/tmdb/tmdb_search_service.dart';
import '../../data/models/media_ref.dart';

enum _PickerCategory { cinema, anime }

/// Bottom sheet that lets Khent or Clair search and choose any movie,
/// TV show, or anime to watch together in real time.
class WatchPartyMediaPickerSheet extends StatefulWidget {
  final String currentTitle;
  final ValueChanged<MediaRef> onSelect;

  const WatchPartyMediaPickerSheet({
    super.key,
    required this.currentTitle,
    required this.onSelect,
  });

  @override
  State<WatchPartyMediaPickerSheet> createState() =>
      _WatchPartyMediaPickerSheetState();
}

class _WatchPartyMediaPickerSheetState
    extends State<WatchPartyMediaPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TMDBSearchService _tmdbSearch = TMDBSearchService();
  final TMDBDiscoveryService _tmdbDiscovery = TMDBDiscoveryService();
  final AniListService _aniListService = AniListService();

  _PickerCategory _category = _PickerCategory.cinema;
  Timer? _debounce;
  bool _loading = false;
  String? _errorMessage;

  List<MediaItem> _results = [];
  List<MediaItem> _trendingCinema = [];
  List<MediaItem> _trendingAnime = [];

  @override
  void initState() {
    super.initState();
    _loadInitialTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTrending() async {
    setState(() => _loading = true);
    try {
      final cinema = await _tmdbDiscovery.fetchTrending(
        region: 'all',
        timeWindow: 'day',
      );
      if (mounted) {
        setState(() {
          _trendingCinema = cinema;
          if (_category == _PickerCategory.cinema &&
              _searchController.text.trim().isEmpty) {
            _results = cinema;
            _loading = false;
          }
        });
      }
    } catch (e, st) {
      Logger.e(
        'WatchPartyMediaPicker: initial cinema trending load failed',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _loading = false);
    }

    try {
      final animePage = await _aniListService.fetchAnimexPage(
        sort: 'TRENDING_DESC',
        perPage: 20,
      );
      if (mounted) {
        setState(() {
          _trendingAnime = animePage.items;
          if (_category == _PickerCategory.anime &&
              _searchController.text.trim().isEmpty) {
            _results = animePage.items;
            _loading = false;
          }
        });
      }
    } catch (e, st) {
      Logger.e(
        'WatchPartyMediaPicker: initial anime trending load failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _onCategoryChanged(_PickerCategory newCategory) {
    if (_category == newCategory) return;
    HapticFeedback.selectionClick();
    setState(() {
      _category = newCategory;
    });
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query);
    } else {
      setState(() {
        _results = newCategory == _PickerCategory.cinema
            ? _trendingCinema
            : _trendingAnime;
        _loading = false;
        _errorMessage = null;
      });
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = null;
        _results = _category == _PickerCategory.cinema
            ? _trendingCinema
            : _trendingAnime;
      });
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      List<MediaItem> items;
      if (_category == _PickerCategory.cinema) {
        items = await _tmdbSearch.searchMedia(query);
      } else {
        items = await _aniListService.searchAnime(query);
      }

      if (mounted) {
        setState(() {
          _results = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Could not load search results. Please try again.';
        });
      }
    }
  }

  void _pickMovie(MediaItem item) {
    HapticFeedback.mediumImpact();
    widget.onSelect(
      MediaRef(
        tmdbId: item.tmdbId,
        mediaType: 'movie',
        isAnime: false,
        title: item.title,
        posterPath: item.posterPath,
      ),
    );
    Navigator.of(context).pop();
  }

  void _pickTvOrAnime(MediaItem item, {required bool isAnime}) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EpisodeSelectorSheet(
        item: item,
        isAnime: isAnime,
        onConfirm: (season, episode) {
          Navigator.of(ctx).pop();
          widget.onSelect(
            MediaRef(
              tmdbId: item.tmdbId,
              malId: isAnime
                  ? (item.tmdbId > 0 ? item.tmdbId : item.anilistId)
                  : null,
              mediaType: (isAnime && item.format.toLowerCase() == 'movie')
                  ? 'movie'
                  : 'tv',
              isAnime: isAnime,
              season: isAnime ? 1 : season,
              episode: episode,
              title: item.title,
              posterPath: item.posterPath,
            ),
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom;
    final maxSheetHeight = (mediaQuery.size.height * 0.88).clamp(420.0, 780.0);

    return Container(
      height: maxSheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.inkDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: Color(0x33DCB5E6),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.petalWhite.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(),
          _buildCategoryTabs(),
          _buildSearchBar(),
          const SizedBox(height: 8),
          Expanded(child: _buildResultsList()),
          SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Title to Watch Together',
                  style: AppTypography.outfitHeading.copyWith(
                    color: AppColors.petalWhite,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.currentTitle.isNotEmpty
                      ? 'Currently watching: ${widget.currentTitle}'
                      : 'Pick any movie, TV show, or anime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitMuted.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.petalWhite),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              category: _PickerCategory.cinema,
              icon: Icons.movie_rounded,
              label: 'Movies & TV',
            ),
          ),
          Expanded(
            child: _tabButton(
              category: _PickerCategory.anime,
              icon: Icons.auto_awesome_rounded,
              label: 'Anime',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required _PickerCategory category,
    required IconData icon,
    required String label,
  }) {
    final active = _category == category;
    return GestureDetector(
      onTap: () => _onCategoryChanged(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.deepRose.withValues(alpha: 0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : AppColors.mutedPurple,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                color: active ? Colors.white : AppColors.mutedPurple,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hint = _category == _PickerCategory.cinema
        ? 'Search movies or TV shows...'
        : 'Search anime (English or Romaji)...';

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.16),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: AppTypography.outfitWhite.copyWith(fontSize: 14),
        cursorColor: AppColors.deepRose,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.outfitMuted.copyWith(
            color: AppColors.mutedPurple,
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.mutedPurple,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: AppColors.mutedPurple,
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.deepRose),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.deepRose,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.outfitMuted.copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: AppColors.mutedPurple,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              'No titles found',
              style: AppTypography.outfitHeading.copyWith(
                color: AppColors.petalWhite,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another search term or check spelling',
              style: AppTypography.outfitMuted.copyWith(
                color: AppColors.mutedPurple,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final isSearching = _searchController.text.trim().isNotEmpty;
    final headerLabel = isSearching
        ? 'Search Results (${_results.length})'
        : (_category == _PickerCategory.cinema
            ? '🔥 Trending Movies & TV'
            : '🌸 Trending Anime');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(
              headerLabel,
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.7),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        final item = _results[index - 1];
        return _buildMediaTile(item);
      },
    );
  }

  Widget _buildMediaTile(MediaItem item) {
    final isAnime = _category == _PickerCategory.anime || item.isAnime;
    final isMovie = item.mediaType == 'movie' ||
        (isAnime && item.format.toLowerCase() == 'movie');

    final posterUrl = item.posterPath.isNotEmpty
        ? (item.posterPath.startsWith('http')
            ? item.posterPath
            : TmdbImages.posterFor(item.posterPath))
        : '';

    final badgeLabel = isAnime
        ? (isMovie ? 'Anime Movie' : 'Anime Series')
        : (isMovie ? 'Movie' : 'TV Show');

    final extraInfo = isAnime
        ? (item.episodeCount != null && item.episodeCount! > 0
            ? '${item.episodeCount} eps'
            : (item.year.isNotEmpty ? item.year : 'Anime'))
        : (item.year.isNotEmpty ? item.year : 'Cinema');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isMovie) {
            _pickMovie(item);
          } else {
            _pickTvOrAnime(item, isAnime: isAnime);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 72,
                  child: posterUrl.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.shimmerBase,
                          child: const Icon(
                            Icons.movie_rounded,
                            color: AppColors.mutedPurple,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitHeading.copyWith(
                        color: AppColors.petalWhite,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isAnime
                                ? AppColors.animeGold.withValues(alpha: 0.15)
                                : AppColors.deepRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeLabel,
                            style: AppTypography.outfitMuted.copyWith(
                              color: isAnime
                                  ? AppColors.animeGold
                                  : AppColors.deepRose,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          extraInfo,
                          style: AppTypography.outfitMuted.copyWith(
                            color: AppColors.mutedPurple,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.deepRose.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.petalWhite,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMovie ? 'Watch' : 'Episodes',
                      style: AppTypography.outfitHeading.copyWith(
                        color: AppColors.petalWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
  }
}

/// Quick season/episode selector sheet for TV shows and anime.
class _EpisodeSelectorSheet extends StatefulWidget {
  final MediaItem item;
  final bool isAnime;
  final void Function(int season, int episode) onConfirm;

  const _EpisodeSelectorSheet({
    required this.item,
    required this.isAnime,
    required this.onConfirm,
  });

  @override
  State<_EpisodeSelectorSheet> createState() => _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends State<_EpisodeSelectorSheet> {
  int _season = 1;
  int _episode = 1;

  @override
  Widget build(BuildContext context) {
    final maxEpisodes = widget.isAnime
        ? (widget.item.episodeCount ?? 26).clamp(1, 1000)
        : 24;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.inkDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: Color(0x33DCB5E6),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Episode',
                      style: AppTypography.outfitHeading.copyWith(
                        color: AppColors.petalWhite,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitMuted.copyWith(
                        color: AppColors.mutedPurple,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.petalWhite,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!widget.isAnime) ...[
            Text(
              'Season',
              style: AppTypography.outfitHeading.copyWith(
                color: AppColors.petalWhite,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _numberPickerRow(
              value: _season,
              min: 1,
              max: 20,
              onChanged: (v) => setState(() => _season = v),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Episode',
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.petalWhite,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _numberPickerRow(
            value: _episode,
            min: 1,
            max: maxEpisodes,
            onChanged: (v) => setState(() => _episode = v),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => widget.onConfirm(_season, _episode),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.auroraRose, AppColors.deepRose],
                ),
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isAnime
                          ? 'Start Episode $_episode'
                          : 'Start S$_season E$_episode',
                      style: AppTypography.outfitHeading.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberPickerRow({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: value > min
                ? AppColors.petalWhite
                : AppColors.petalWhite.withValues(alpha: 0.2),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value',
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.petalWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: value < max
                ? AppColors.petalWhite
                : AppColors.petalWhite.withValues(alpha: 0.2),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
