import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/animex_models.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/anilist_service.dart';

import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_grid.dart';
import 'animex_skeleton.dart';
import 'animex_tokens.dart';

/// Search page with debounced input, quick filter chips and a results grid.
class AnimeXSearchPage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXSearchPage({super.key, required this.controller});

  @override
  State<AnimeXSearchPage> createState() => _AnimeXSearchPageState();
}

class _AnimeXSearchPageState extends State<AnimeXSearchPage> {
  final AniListService _aniList = AniListService();
  final TextEditingController _input = TextEditingController();
  Timer? _debounce;

  String _query = '';
  String _mode = 'all'; // all | trending | airing | movies | new
  List<MediaItem> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _query = value.trim();
      _run();
    });
  }

  void _selectMode(String mode) {
    _mode = mode;
    _query = '';
    _input.clear();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      AnimexMediaPage page;
      if (_query.isNotEmpty) {
        page = await _aniList.fetchAnimexPage(
          search: _query,
          perPage: 30,
        );
      } else {
        page = switch (_mode) {
          'trending' =>
            await _aniList.fetchAnimexPage(sort: 'TRENDING_DESC', perPage: 30),
          'airing' => await _aniList.fetchAnimexPage(
              sort: 'SCORE_DESC',
              status: 'RELEASING',
              perPage: 30,
            ),
          'movies' => await _aniList.fetchAnimexPage(
              format: 'MOVIE',
              sort: 'POPULARITY_DESC',
              perPage: 30,
            ),
          'new' => await _aniList.fetchAnimexPage(
              sort: 'START_DATE_DESC',
              perPage: 30,
            ),
          _ => await _aniList.fetchAnimexPage(sort: 'TRENDING_DESC', perPage: 30),
        };
      }
      if (!mounted) return;
      setState(() {
        _results = page.items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AnimeXSearch] search failed: $e');
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
      children: [
        Text(
          'Discover Anime',
          style: bebasStyle(size: 32, color: AnimeXTokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          'Search thousands of anime titles',
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        const SizedBox(height: 20),
        _buildSearchBar(),
        const SizedBox(height: 14),
        _buildQuickChips(),
        const SizedBox(height: 24),
        if (_loading)
          const AnimeXSkeletonGrid(count: 12)
        else if (_searched && _results.isEmpty)
          _buildEmpty()
        else if (_results.isNotEmpty)
          AnimeXGrid(
            items: _results,
            onTap: (item) => widget.controller.openWatch(item),
          )
        else
          _buildIdle(),
        const SizedBox(height: 24),
        AnimeXFooter(controller: widget.controller),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        border: Border.all(color: AnimeXTokens.borderStrong),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, size: 19, color: AnimeXTokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _input,
              onChanged: _onChanged,
              style: dmSansStyle(size: 14, color: AnimeXTokens.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search anime...',
                hintStyle: dmSansStyle(
                  size: 14,
                  color: AnimeXTokens.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _input.clear();
                _query = '';
                _run();
              },
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: AnimeXTokens.textSecondary,
                ),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    const chips = <(String, String)>[
      ('all', 'All'),
      ('trending', 'Trending'),
      ('airing', 'Top Airing'),
      ('movies', 'Movies'),
      ('new', 'New'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (mode, label) in chips)
          GestureDetector(
            onTap: () => _selectMode(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _mode == mode && _query.isEmpty
                    ? AnimeXTokens.accent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _mode == mode && _query.isEmpty
                      ? AnimeXTokens.accent.withValues(alpha: 0.4)
                      : AnimeXTokens.border,
                ),
              ),
              child: Text(
                label,
                style: dmSansStyle(
                  size: 12.5,
                  color: _mode == mode && _query.isEmpty
                      ? AnimeXTokens.accent
                      : AnimeXTokens.textSecondary,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIdle() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Text(
          'Start typing to search for anime.',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 13,
            color: AnimeXTokens.textMuted,
          ),
        ),
      ),
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
}
