import 'package:flutter/material.dart';

import '../../../data/models/animex_models.dart';
import '../../../data/services/anilist_service.dart';

import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_grid.dart';
import 'animex_skeleton.dart';
import 'animex_tokens.dart';

const _genreOptions = <String>[
  'Action',
  'Adventure',
  'Comedy',
  'Drama',
  'Fantasy',
  'Horror',
  'Mystery',
  'Romance',
  'Sci-Fi',
  'Slice of Life',
  'Sports',
  'Supernatural',
  'Thriller',
];

const _sortOptions = <(String, String)>[
  ('TRENDING_DESC', 'Trending'),
  ('POPULARITY_DESC', 'Popularity'),
  ('SCORE_DESC', 'Top Rated'),
  ('START_DATE_DESC', 'Newest'),
  ('FAVOURITES_DESC', 'Favorites'),
];

/// Browse / explore page: sort, format, genre and year filters plus a
/// responsive grid and pagination.
class AnimeXBrowsePage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXBrowsePage({super.key, required this.controller});

  @override
  State<AnimeXBrowsePage> createState() => _AnimeXBrowsePageState();
}

class _AnimeXBrowsePageState extends State<AnimeXBrowsePage> {
  final AniListService _aniList = AniListService();

  late String _sort;
  late String? _genre;
  late int? _year;
  bool _moviesOnly = false;
  int _page = 1;
  AnimexMediaPage? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _sort = c.browseSort ?? 'TRENDING_DESC';
    _genre = c.browseGenre;
    _year = c.browseYear;
    _moviesOnly = false;
    _fetch();
  }

  Future<void> _fetch({int? page}) async {
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _page = target;
    });
    try {
      final data = await _aniList.fetchAnimexPage(
        sort: _sort,
        genre: _genre,
        seasonYear: _year,
        format: _moviesOnly ? 'MOVIE' : null,
        page: target,
        perPage: 24,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AnimeXBrowse] fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _data = const AnimexMediaPage(
          items: [],
          scores: [],
          currentPage: 1,
          hasNextPage: false,
        );
        _loading = false;
      });
    }
  }

  void _resetAndFetch() {
    _data = null;
    _fetch(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
      children: [
        Text(
          'Browse',
          style: bebasStyle(size: 32, color: AnimeXTokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          'Explore anime',
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        const SizedBox(height: 20),
        _buildFilterBar(),
        const SizedBox(height: 24),
        if (_loading && _data == null)
          const AnimeXSkeletonGrid(count: 12)
        else if (_data != null && _data!.items.isEmpty)
          _buildEmpty()
        else
          AnimeXGrid(
            items: _data?.items ?? const [],
            onTap: (item) => widget.controller.openWatch(item),
            loading: _loading,
            skeletonCount: 12,
          ),
        const SizedBox(height: 20),
        if (_data != null && (_data!.hasNextPage || _page > 1)) _buildPager(),
        AnimeXFooter(controller: widget.controller),
      ],
    );
  }

  Widget _buildFilterBar() {
    final years = List.generate(
      DateTime.now().year - 1990 + 1,
      (i) => DateTime.now().year - i,
    );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Select(
          value: _sort,
          label: 'Sort',
          options: _sortOptions.map((o) => (o.$1, o.$2)).toList(),
          onChanged: (v) {
            _sort = v;
            _resetAndFetch();
          },
        ),
        _Select(
          value: _moviesOnly ? 'MOVIE' : 'ALL',
          label: 'Type',
          options: const [('ALL', 'All Anime'), ('MOVIE', 'Anime movies')],
          onChanged: (v) {
            _moviesOnly = v == 'MOVIE';
            _resetAndFetch();
          },
        ),
        _Select(
          value: _genre ?? 'ALL',
          label: 'Genre',
          options: [
            ('ALL', 'All Genres'),
            for (final g in _genreOptions) (g, g),
          ],
          onChanged: (v) {
            _genre = v == 'ALL' ? null : v;
            _resetAndFetch();
          },
        ),
        _Select(
          value: _year?.toString() ?? 'ALL',
          label: 'Year',
          options: [
            ('ALL', 'All Years'),
            for (final y in years) (y.toString(), y.toString()),
          ],
          onChanged: (v) {
            _year = v == 'ALL' ? null : int.tryParse(v);
            _resetAndFetch();
          },
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              color: AnimeXTokens.textMuted,
              size: 40,
            ),
            SizedBox(height: 12),
            Text(
              'Nothing to show',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 14,
                color: AnimeXTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPager() {
    final lastPage = _data?.lastPage ?? 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageButton(
          label: 'Prev',
          icon: Icons.arrow_back_ios_new_rounded,
          enabled: _page > 1,
          iconAtEnd: false,
          onTap: () => _fetch(page: _page - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Page $_page of $lastPage',
            style: dmSansStyle(
              size: 12.5,
              color: AnimeXTokens.textSecondary,
              weight: FontWeight.w500,
            ),
          ),
        ),
        _PageButton(
          label: 'Next',
          icon: Icons.arrow_forward_ios_rounded,
          enabled: _data?.hasNextPage ?? false,
          iconAtEnd: true,
          onTap: () => _fetch(page: _page + 1),
        ),
      ],
    );
  }
}

class _Select extends StatelessWidget {
  final String value;
  final String label;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _Select({
    required this.value,
    required this.label,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLabel = options
        .firstWhere((o) => o.$1 == value, orElse: () => ('', label))
        .$2;
    return PopupMenuButton<String>(
      initialValue: value,
      tooltip: label,
      color: AnimeXTokens.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        side: const BorderSide(color: AnimeXTokens.border),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final o in options)
          PopupMenuItem(
            value: o.$1,
            child: Row(
              children: [
                if (o.$1 == value)
                  const Icon(
                    Icons.check_rounded,
                    color: AnimeXTokens.accent,
                    size: 15,
                  )
                else
                  const SizedBox(width: 15),
                const SizedBox(width: 8),
                Text(
                  o.$2,
                  style: dmSansStyle(size: 13, color: AnimeXTokens.textPrimary),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
          border: Border.all(color: AnimeXTokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLabel,
              style: dmSansStyle(
                size: 13,
                color: AnimeXTokens.textPrimary,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AnimeXTokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool iconAtEnd;
  final VoidCallback onTap;

  const _PageButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.iconAtEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
          border: Border.all(
            color: enabled ? AnimeXTokens.borderStrong : AnimeXTokens.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!iconAtEnd) ...[
              Icon(icon, size: 13, color: AnimeXTokens.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: dmSansStyle(
                size: 12.5,
                color: enabled
                    ? AnimeXTokens.textPrimary
                    : AnimeXTokens.textMuted,
                weight: FontWeight.w600,
              ),
            ),
            if (iconAtEnd) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 13, color: AnimeXTokens.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
