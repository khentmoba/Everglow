import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import '../katana/katana_genres_sidebar.dart';
import '../katana/katana_header.dart';
import '../katana/katana_nav.dart';
import '../katana/katana_pagination.dart';
import '../katana/katana_theme.dart';

/// Full search results page. Shows the compact search cards from
/// Manga Katana (cover, title, latest chapter, authors) with
/// pagination, and supports searching by manga name or author.
class KatanaSearchResultsScreen extends StatefulWidget {
  final String query;
  final String searchBy;

  const KatanaSearchResultsScreen({
    super.key,
    required this.query,
    this.searchBy = 'm_name',
  });

  @override
  State<KatanaSearchResultsScreen> createState() =>
      _KatanaSearchResultsScreenState();
}

class _KatanaSearchResultsScreenState extends State<KatanaSearchResultsScreen> {
  final KatanaService _service = KatanaService();
  late String _searchBy;
  int _page = 1;
  List<KatanaManga> _items = const [];
  List<KatanaGenre> _genres = const [];
  bool _loading = true;
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    _searchBy = widget.searchBy;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _service.fetchCatalog(
        mode: 'search',
        page: _page,
        query: widget.query,
        searchBy: _searchBy,
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
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changePage(int page) {
    if (page < 1) return;
    setState(() => _page = page);
    _load();
  }

  void _switchSearchBy(String value) {
    setState(() {
      _searchBy = value;
      _page = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 960;

    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          const KatanaHeader(active: KatanaNav.home),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildMain()),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 330,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(0, 14, 0, 40),
                              children: [KatanaGenresSidebar(genres: _genres)],
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search results for "${widget.query}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KatanaType.heading,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _searchBy == 'm_name' ? 'by Manga Name' : 'by Author',
                      style: KatanaType.small,
                    ),
                  ],
                ),
              ),
              _searchBySelect(),
            ],
          ),
        ),
        Expanded(child: _buildResults()),
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

  Widget _searchBySelect() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: KatanaColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KatanaColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _searchBy,
          isDense: true,
          style: KatanaType.body.copyWith(fontSize: 12.5),
          dropdownColor: KatanaColors.surface,
          items: const [
            DropdownMenuItem(value: 'm_name', child: Text('Manga Name')),
            DropdownMenuItem(value: 'author', child: Text('Author')),
          ],
          onChanged: (v) {
            if (v != null) _switchSearchBy(v);
          },
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KatanaColors.accent),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 46,
              color: KatanaColors.textLight,
            ),
            const SizedBox(height: 12),
            Text('No results found.', style: KatanaType.body),
          ],
        ),
      );
    }
    final columns = MediaQuery.sizeOf(context).width >= 1400
        ? 3
        : MediaQuery.sizeOf(context).width >= 700
        ? 2
        : 1;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: columns > 1 ? 3.4 : 5.4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) => _SearchResultCard(manga: _items[index]),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final KatanaManga manga;
  const _SearchResultCard({required this.manga});

  @override
  Widget build(BuildContext context) {
    return KatanaCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => pushDetail(context, manga.slug),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 46,
                  height: 62,
                  child: manga.coverUrl.isEmpty
                      ? Container(color: KatanaColors.border)
                      : KatanaNetworkImage(
                          manga.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: KatanaColors.border),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: KatanaColors.text,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (manga.latestChapter != null)
                      Text(
                        'Latest chapter: ${manga.latestChapter!.displayTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KatanaType.accent.copyWith(fontSize: 11.5),
                      ),
                    if (manga.authors.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Author(s): ${manga.authors.join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KatanaType.small.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: KatanaColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
