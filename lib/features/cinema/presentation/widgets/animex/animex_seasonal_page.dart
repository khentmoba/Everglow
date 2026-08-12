import 'package:flutter/material.dart';

import 'package:everglow/features/cinema/data/models/animex_models.dart';
import 'package:everglow/features/cinema/data/services/anilist_service.dart';

import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_grid.dart';
import 'animex_skeleton.dart';
import 'animex_tokens.dart';

const _seasons = <(String, String)>[
  ('WINTER', 'Winter'),
  ('SPRING', 'Spring'),
  ('SUMMER', 'Summer'),
  ('FALL', 'Fall'),
];

/// Seasonal page: pick a season + year and browse the anime grid.
class AnimeXSeasonalPage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXSeasonalPage({super.key, required this.controller});

  @override
  State<AnimeXSeasonalPage> createState() => _AnimeXSeasonalPageState();
}

class _AnimeXSeasonalPageState extends State<AnimeXSeasonalPage> {
  final AniListService _aniList = AniListService();

  late String _season;
  late int _year;
  int _page = 1;
  AnimexMediaPage? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _season = _currentSeasonName();
    _year = DateTime.now().year;
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
        season: _season,
        seasonYear: _year,
        sort: 'POPULARITY_DESC',
        page: target,
        perPage: 24,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AnimeXSeasonal] fetch failed: $e');
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

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      DateTime.now().year - 2005 + 1,
      (i) => DateTime.now().year - i,
    );
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
      children: [
        Text(
          'Seasonal',
          style: bebasStyle(size: 32, color: AnimeXTokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          'Anime by season and year',
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (value, label) in _seasons)
              GestureDetector(
                onTap: () {
                  _season = value;
                  _data = null;
                  _fetch(page: 1);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _season == value
                        ? AnimeXTokens.accent
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _season == value
                          ? AnimeXTokens.accent
                          : AnimeXTokens.border,
                    ),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: dmSansStyle(
                      size: 12,
                      color: _season == value
                          ? Colors.white
                          : AnimeXTokens.textSecondary,
                      weight: FontWeight.w700,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                border: Border.all(color: AnimeXTokens.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _year,
                  dropdownColor: AnimeXTokens.surfaceRaised,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AnimeXTokens.textSecondary,
                  ),
                  style: dmSansStyle(
                    size: 13,
                    color: AnimeXTokens.textPrimary,
                    weight: FontWeight.w600,
                  ),
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    _year = v;
                    _data = null;
                    _fetch(page: 1);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_loading && _data == null)
          const AnimeXSkeletonGrid(count: 12)
        else if (_data != null && _data!.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Text(
                'Nothing to show',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 14,
                  color: AnimeXTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          AnimeXGrid(
            items: _data?.items ?? const [],
            onTap: (item) => widget.controller.openWatch(item),
            loading: _loading,
          ),
        const SizedBox(height: 20),
        if (_data != null && (_data!.hasNextPage || _page > 1))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SeasonPagerButton(
                label: 'Prev',
                enabled: _page > 1,
                onTap: () => _fetch(page: _page - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'Page $_page',
                  style: dmSansStyle(
                    size: 12.5,
                    color: AnimeXTokens.textSecondary,
                  ),
                ),
              ),
              _SeasonPagerButton(
                label: 'Next',
                enabled: _data?.hasNextPage ?? false,
                onTap: () => _fetch(page: _page + 1),
              ),
            ],
          ),
        const SizedBox(height: 24),
        AnimeXFooter(controller: widget.controller),
      ],
    );
  }
}

class _SeasonPagerButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SeasonPagerButton({
    required this.label,
    required this.enabled,
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
        child: Text(
          label,
          style: dmSansStyle(
            size: 12.5,
            color: enabled
                ? AnimeXTokens.textPrimary
                : AnimeXTokens.textMuted,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _currentSeasonName() {
  final month = DateTime.now().month;
  if (month >= 3 && month <= 5) return 'SPRING';
  if (month >= 6 && month <= 8) return 'SUMMER';
  if (month >= 9 && month <= 11) return 'FALL';
  return 'WINTER';
}
