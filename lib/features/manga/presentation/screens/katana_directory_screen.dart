import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';
import 'package:everglow/features/manga/presentation/katana/katana_filter_panel.dart';
import 'package:everglow/features/manga/presentation/katana/katana_genres_sidebar.dart';
import 'package:everglow/features/manga/presentation/katana/katana_header.dart';
import 'package:everglow/features/manga/presentation/katana/katana_item_card.dart';
import 'package:everglow/features/manga/presentation/katana/katana_nav.dart';
import 'package:everglow/features/manga/presentation/katana/katana_pagination.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';

/// Manga Directory and its sibling list pages (Latest update, New
/// Manga, genre and author pages). Mirrors Manga Katana: expanded
/// item list on the left, Filter + Genres widgets on the right.
class KatanaDirectoryScreen extends StatefulWidget {
  final String mode; // directory | latest | new | genre | author
  final String slug;
  final String title;

  const KatanaDirectoryScreen({
    super.key,
    this.mode = 'directory',
    this.slug = '',
    this.title = '',
  });

  @override
  State<KatanaDirectoryScreen> createState() => _KatanaDirectoryScreenState();
}

class _KatanaDirectoryScreenState extends State<KatanaDirectoryScreen> {
  final KatanaService _service = KatanaService();

  int _page = 1;
  Set<String> _include = {};
  Set<String> _exclude = {};
  String _genreMode = 'and';
  String _chapters = '1';
  String _orderBy = 'latest';

  List<KatanaManga> _items = const [];
  List<KatanaGenre> _genres = const [];
  bool _loading = true;
  bool _hasNext = false;
  String? _error;

  KatanaNav get _activeNav {
    switch (widget.mode) {
      case 'latest':
        return KatanaNav.latest;
      case 'new':
        return KatanaNav.newManga;
      case 'genre':
        return KatanaNav.genres;
      default:
        return KatanaNav.directory;
    }
  }

  bool get _showFilter =>
      widget.mode == 'directory' || widget.mode == 'genre' || widget.mode == 'author';

  String get _title {
    if (widget.title.isNotEmpty) return widget.title;
    switch (widget.mode) {
      case 'latest':
        return 'Latest Update';
      case 'new':
        return 'New Manga';
      case 'genre':
        return widget.slug;
      case 'author':
        return widget.slug;
      default:
        return 'Manga Directory';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchCatalog(
        mode: widget.mode,
        key: widget.slug,
        page: _page,
        include: _include.toList(),
        exclude: _exclude.toList(),
        genreMode: _genreMode,
        chapters: _chapters,
        orderBy: _orderBy,
      );
      final genres = _genres.isEmpty ? await _service.fetchGenres() : _genres;
      if (mounted) {
        setState(() {
          _items = result.items;
          _hasNext = result.hasNext;
          _genres = genres;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this page. Tap retry.';
        });
      }
    }
  }

  void _applyFilter(KatanaFilterState state) {
    setState(() {
      _include = state.include;
      _exclude = state.exclude;
      _genreMode = state.genreMode;
      _chapters = state.chapters;
      _orderBy = state.orderBy;
      _page = 1;
    });
    _load();
  }

  void _changePage(int page) {
    if (page < 1) return;
    setState(() => _page = page);
    _load();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KatanaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: KatanaFilterPanel(
            include: _include,
            exclude: _exclude,
            genreMode: _genreMode,
            chapters: _chapters,
            orderBy: _orderBy,
            onApply: (state) {
              Navigator.pop(context);
              _applyFilter(state);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 960;

    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          KatanaHeader(active: _activeNav),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildMain(),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 330,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(0, 14, 0, 40),
                              children: [
                                if (_showFilter) ...[
                                  KatanaCard(
                                    padding: const EdgeInsets.all(14),
                                    child: KatanaFilterPanel(
                                      include: _include,
                                      exclude: _exclude,
                                      genreMode: _genreMode,
                                      chapters: _chapters,
                                      orderBy: _orderBy,
                                      onApply: _applyFilter,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                KatanaGenresSidebar(genres: _genres),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _buildMain(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Column(
      children: [
        _buildBreadcrumb(),
        Expanded(child: _buildList()),
        Padding(
          padding: const EdgeInsets.all(16),
          child: KatanaPagination(
            page: _page,
            hasPrev: _page > 1,
            hasNext: _hasNext,
            onPageChanged: _changePage,
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    final mobile = MediaQuery.sizeOf(context).width < 960;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => pushHome(context),
            child: const Icon(Icons.home_rounded,
                size: 15, color: KatanaColors.textMuted),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              size: 15, color: KatanaColors.textLight),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitBold.copyWith(
                color: KatanaColors.textMuted,
                fontSize: 12.5,
              ),
            ),
          ),
          if (mobile && _showFilter) ...[
            const Spacer(),
            KatanaButton(
              label: 'Filter',
              icon: Icons.filter_list_rounded,
              onTap: _openFilterSheet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KatanaColors.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 46, color: KatanaColors.textLight),
            const SizedBox(height: 12),
            Text(_error!, style: KatanaType.body),
            const SizedBox(height: 12),
            KatanaButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: _load),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 46, color: KatanaColors.textLight),
            const SizedBox(height: 12),
            Text('No manga match these filters.', style: KatanaType.body),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: KatanaItemCard(manga: _items[index]),
        );
      },
    );
  }
}
