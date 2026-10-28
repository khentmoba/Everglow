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
  'Ecchi',
  'Fantasy',
  'Horror',
  'Isekai',
  'Mahou Shoujo',
  'Mecha',
  'Music',
  'Mystery',
  'Psychological',
  'Reincarnation',
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
  final AniListService? service;

  const AnimeXBrowsePage({
    super.key,
    required this.controller,
    this.service,
  });

  @override
  State<AnimeXBrowsePage> createState() => _AnimeXBrowsePageState();
}

class _AnimeXBrowsePageState extends State<AnimeXBrowsePage> {
  late final AniListService _aniList = widget.service ?? AniListService();

  late String _sort;
  late Set<String> _genres;
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
    _genres = Set<String>.from(c.browseGenres);
    if (_genres.isEmpty && c.browseGenre != null) {
      _genres.add(c.browseGenre!);
    }
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
        genres: _genres.isNotEmpty ? _genres.toList() : null,
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
        if (_genres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final g in _genres)
                _ActiveGenreChip(
                  label: g,
                  onRemove: () {
                    setState(() {
                      _genres.remove(g);
                    });
                    widget.controller.browseGenres = _genres.toList();
                    _resetAndFetch();
                  },
                ),
              InkWell(
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
                onTap: () {
                  setState(() {
                    _genres.clear();
                  });
                  widget.controller.browseGenres = [];
                  _resetAndFetch();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Clear all',
                    style: dmSansStyle(
                      size: 12,
                      color: AnimeXTokens.accentWarm,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
        _GenreMultiSelect(
          selected: _genres,
          options: _genreOptions,
          onChanged: (updated) {
            setState(() {
              _genres = updated;
            });
            widget.controller.browseGenres = updated.toList();
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
              weight: FontWeight.w600,
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
                weight: FontWeight.w600,
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

class _GenreMultiSelect extends StatelessWidget {
  final Set<String> selected;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;

  const _GenreMultiSelect({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  void _openDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _GenrePickerSheet(
        initial: selected,
        options: options,
        onApply: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = selected.length;
    final String label;
    if (count == 0) {
      label = 'All Genres';
    } else if (count == 1) {
      label = selected.first;
    } else {
      label = 'Genres ($count)';
    }

    final hasSelection = count > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
      onTap: () => _openDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: hasSelection
              ? AnimeXTokens.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
          border: Border.all(
            color: hasSelection
                ? AnimeXTokens.accent.withValues(alpha: 0.6)
                : AnimeXTokens.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: dmSansStyle(
                size: 13,
                color: hasSelection
                    ? AnimeXTokens.accentWarm
                    : AnimeXTokens.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: hasSelection
                  ? AnimeXTokens.accentWarm
                  : AnimeXTokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenrePickerSheet extends StatefulWidget {
  final Set<String> initial;
  final List<String> options;
  final ValueChanged<Set<String>> onApply;

  const _GenrePickerSheet({
    required this.initial,
    required this.options,
    required this.onApply,
  });

  @override
  State<_GenrePickerSheet> createState() => _GenrePickerSheetState();
}

class _GenrePickerSheetState extends State<_GenrePickerSheet> {
  late Set<String> _current;

  @override
  void initState() {
    super.initState();
    _current = Set<String>.from(widget.initial);
  }

  void _toggle(String genre) {
    setState(() {
      if (_current.contains(genre)) {
        _current.remove(genre);
      } else {
        _current.add(genre);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AnimeXTokens.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl),
        side: const BorderSide(color: AnimeXTokens.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Genres & Themes',
                          style: bebasStyle(
                            size: 22,
                            color: AnimeXTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick one or multiple to combine filters',
                          style: dmSansStyle(
                            size: 12.5,
                            color: AnimeXTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_current.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _current.clear()),
                      child: Text(
                        'Reset',
                        style: dmSansStyle(
                          size: 12.5,
                          color: AnimeXTokens.accentWarm,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final genre in widget.options) ...[
                        _GenreChip(
                          label: genre,
                          selected: _current.contains(genre),
                          onTap: () => _toggle(genre),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: dmSansStyle(
                        size: 13,
                        color: AnimeXTokens.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AnimeXTokens.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AnimeXTokens.radiusMd,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      widget.onApply(_current);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      _current.isEmpty
                          ? 'Show All'
                          : 'Apply (${_current.length})',
                      style: dmSansStyle(
                        size: 13,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AnimeXTokens.radiusFull),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AnimeXTokens.accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusFull),
          border: Border.all(
            color: selected ? AnimeXTokens.accent : AnimeXTokens.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 14,
                color: AnimeXTokens.accentWarm,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: dmSansStyle(
                size: 12,
                color: selected
                    ? AnimeXTokens.textPrimary
                    : AnimeXTokens.textSecondary,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveGenreChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveGenreChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AnimeXTokens.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusFull),
        border: Border.all(
          color: AnimeXTokens.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: dmSansStyle(
              size: 11.5,
              color: AnimeXTokens.accentWarm,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusFull),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: AnimeXTokens.accentWarm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
