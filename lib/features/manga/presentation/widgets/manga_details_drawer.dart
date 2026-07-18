import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/comick_service.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/features/manga/data/services/mangakakalot_service.dart';
import 'package:everglow/features/manga/data/services/mangakatana_service.dart';
import 'package:everglow/features/manga/data/services/bato_service.dart';
import 'package:everglow/features/manga/data/services/scanlation_service.dart';
import 'package:everglow/features/manga/presentation/screens/manga_reader_screen.dart';
import 'package:everglow/services/auth_service.dart';

/// Bottom-sheet details for a manga / manhwa / manhua.
/// Features: virtualized chapter list, consistent design tokens.
class MangaDetailsDrawer extends StatefulWidget {
  final MangaItem item;
  const MangaDetailsDrawer({super.key, required this.item});

  @override
  State<MangaDetailsDrawer> createState() => _MangaDetailsDrawerState();
}

class _MangaDetailsDrawerState extends State<MangaDetailsDrawer> {
  final ComickService _comickService = ComickService();
  final MangaDexService _mangaDexService = MangaDexService();
  final MangaKakalotService _kakalotService = MangaKakalotService();
  final MangakatanaService _mangakatanaService = MangakatanaService();
  final ScanlationService _scanlationService = ScanlationService();
  final BatoService _batoService = BatoService();
  final ScrollController _chapterScrollController = ScrollController();

  Map<String, String>? _scanlationSlugs;

  late MangaItem _item;
  List<MangaChapter> _chapters = const [];
  bool _isLoadingChapters = true;
  String? _chapterError;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadChapters();
  }

  @override
  void dispose() {
    _chapterScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoadingChapters = true;
      _chapterError = null;
    });

    final futures = <Future<List<MangaChapter>>>[];
    final timeout = const Duration(seconds: 20);

    final titlesToTry = <String>[_item.title];
    for (final alt in _item.altTitles) {
      if (alt.isNotEmpty && !titlesToTry.contains(alt)) {
        titlesToTry.add(alt);
      }
    }

    // 1) Comick API — by hid if we have it
    if (_item.comickSlug.isNotEmpty) {
      futures.add(_comickService
          .getChapterFeed(_item.comickSlug)
          .timeout(timeout, onTimeout: () => <MangaChapter>[]));
    } else if (_item.comickId > 0 && _item.mangaId.isNotEmpty) {
      futures.add(_comickService
          .getChapterFeed(_item.mangaId)
          .timeout(timeout, onTimeout: () => <MangaChapter>[]));
    }

    // 2) Comick API — search by title to find hid
    if (_item.comickSlug.isEmpty && _item.comickId == 0) {
      for (final title in titlesToTry) {
        futures.add(_comickService
            .search(query: title, limit: 1)
            .timeout(timeout, onTimeout: () => <MangaItem>[])
            .then((results) async {
          if (results.isEmpty) return <MangaChapter>[];
          final hid = results.first.comickSlug.isNotEmpty
              ? results.first.comickSlug
              : results.first.mangaId;
          if (hid.isEmpty) return <MangaChapter>[];
          return _comickService.getChapterFeed(hid);
        }).timeout(timeout, onTimeout: () => <MangaChapter>[]));
      }
    }

    // 3) MangaDex API
    final mangaDexId = _item.mangaKakalotId;
    if (mangaDexId.isNotEmpty) {
      futures.add(_mangaDexService
          .getChapterFeed(mangaDexId)
          .timeout(timeout, onTimeout: () => <MangaChapter>[]));
    }
    if (_item.mangaId.isNotEmpty &&
        _item.mangaId != mangaDexId &&
        _item.comickId == 0) {
      futures.add(_mangaDexService
          .getChapterFeed(_item.mangaId)
          .timeout(timeout, onTimeout: () => <MangaChapter>[]));
    }

    // 4) MangaKakalot
    for (final title in titlesToTry) {
      futures.add(_kakalotService
          .searchByTitle(title)
          .timeout(timeout, onTimeout: () => '')
          .then((slug) async {
        if (slug.isEmpty) return <MangaChapter>[];
        return _kakalotService.getChapterFeed(slug);
      }).timeout(timeout, onTimeout: () => <MangaChapter>[]));
    }

    // 5) MangaKatana
    for (final title in titlesToTry) {
      futures.add(_mangakatanaService
          .searchByTitle(title)
          .timeout(timeout, onTimeout: () => '')
          .then((slug) async {
        if (slug.isEmpty) return <MangaChapter>[];
        return _mangakatanaService.getChapterFeed(slug);
      }).timeout(timeout, onTimeout: () => <MangaChapter>[]));
    }

    // 6) Scanlation sites
    futures.add(_scanlationService
        .searchAll(_item.title)
        .timeout(timeout, onTimeout: () => <String, String>{})
        .then((slugs) async {
      if (slugs.isEmpty) return <MangaChapter>[];
      return _scanlationService.getChapterFeedFromAll(slugs);
    }).timeout(timeout, onTimeout: () => <MangaChapter>[]));

    // 7) Bato.to
    for (final title in titlesToTry) {
      futures.add(_batoService
          .searchByTitle(title)
          .timeout(timeout, onTimeout: () => '')
          .then((slug) async {
        if (slug.isEmpty) return <MangaChapter>[];
        return _batoService.getChapterFeed(slug);
      }).timeout(timeout, onTimeout: () => <MangaChapter>[]));
    }

    // Pick source with most chapters
    final list = await _pickBestFromAll(futures);

    if (!mounted) return;
    if (list.isNotEmpty) {
      setState(() {
        _chapters = list;
        _isLoadingChapters = false;
      });
    } else {
      setState(() {
        _chapterError = 'No English chapters available.';
        _isLoadingChapters = false;
      });
    }
  }

  Future<List<MangaChapter>> _pickBestFromAll(
    List<Future<List<MangaChapter>>> futures,
  ) async {
    if (futures.isEmpty) return const [];
    final results = await Future.wait(
      futures.map((f) => f.then(
        (list) => list,
        onError: (_) => <MangaChapter>[],
      )),
    );
    List<MangaChapter> best = const [];
    for (final list in results) {
      if (list.length > best.length) best = list;
    }
    return best;
  }

  void _openReader(MangaChapter chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          manga: _item,
          chapter: chapter,
          allChapters: _chapters,
          scanlationSlugs: _scanlationSlugs,
        ),
      ),
    );
  }

  Future<void> _updateLibraryStatus(String status) async {
    final user = context.read<AuthService>().currentUser ?? '';
    if (user.isEmpty) return;
    await _kakalotService.saveToLibrary(_item, status, user);
    setState(() {
      _item = _item.copyWith(libraryStatus: status);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'none'
              ? 'Removed from your library'
              : 'Set to ${_item.libraryDisplay}',
          style: GoogleFonts.outfit(color: AppColors.petalWhite),
        ),
        backgroundColor: AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.twilight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHero(context),
                  _buildLibraryRow(),
                  Divider(height: 1, color: AppColors.divider),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        _buildDescription(),
                        const SizedBox(height: 24),
                        _buildChapterList(),
                      ],
                    ),
                  ),
                ],
              ),
              // Drag handle
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.roseQuartz.withValues(alpha: 0.3),
                      borderRadius: AppRadius.radiusFull,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_item.coverUrl.isNotEmpty)
            Image.network(
              _mangaDexService.proxiedImageUrl(_item.coverUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.velvet),
            )
          else
            Container(color: AppColors.velvet),
          // Bottom gradient with text
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.twilight.withValues(alpha: 0.85),
                    AppColors.twilight,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.25),
                          borderRadius: AppRadius.radiusXs,
                          border: Border.all(
                            color: _typeColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _item.contentType.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: AppColors.roseQuartz,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (_item.status.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.blushGold.withValues(alpha: 0.2),
                            borderRadius: AppRadius.radiusXs,
                          ),
                          child: Text(
                            _item.status.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: AppColors.blushGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _item.title,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.roseQuartz,
                    ),
                  ),
                  if (_item.author.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'by ${_item.author}',
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: AppColors.petalWhite, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _typeColor {
    switch (_item.originalLanguage) {
      case 'ko':
        return AppColors.animeMagenta;
      case 'zh':
        return AppColors.animeCyan;
      default:
        return AppColors.deepRose;
    }
  }

  Widget _buildLibraryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Library',
            style: GoogleFonts.outfit(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _LibChip(value: 'reading', label: 'Reading'),
                _LibChip(value: 'plan-to-read', label: 'Plan'),
                _LibChip(value: 'completed', label: 'Completed'),
                _LibChip(value: 'on-hold', label: 'Hold'),
                _LibChip(value: 'dropped', label: 'Dropped'),
              ].map((entry) {
                final selected = _item.libraryStatus == entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.label,
                        style: GoogleFonts.outfit(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) => _updateLibraryStatus(entry.value),
                    selectedColor: AppColors.deepRose,
                    backgroundColor: AppColors.velvet,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.petalWhite
                          : AppColors.textMuted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    if (_item.description.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Synopsis',
          style: GoogleFonts.outfit(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.border),
          ),
          child: Html(
            data: _item.description,
            style: {
              'body': Style(
                color: AppColors.textMedium,
                fontSize: FontSize(14),
                fontFamily: GoogleFonts.outfit().fontFamily,
                lineHeight: const LineHeight(1.6),
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'p': Style(margin: Margins.only(bottom: 8)),
              'a': Style(color: AppColors.roseQuartz),
            },
          ),
        ),
        if (_item.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _item.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.10),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(
                    color: AppColors.roseQuartz.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.outfit(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildChapterList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chapters',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            if (_chapters.isNotEmpty)
              Text(
                '${_chapters.length} total',
                style: GoogleFonts.outfit(
                  color: AppColors.textDisabled,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingChapters)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.deepRose),
            ),
          )
        else if (_chapterError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _chapterError!,
                style: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
            ),
          )
        else if (_chapters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No English chapters available.',
                style: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
            ),
          )
        else
          // Virtualized: only builds visible chapter tiles
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final c = _chapters[index];
              return _ChapterTile(
                chapter: c,
                isLastRead: _item.lastReadChapterId == c.id,
                onTap: () => _openReader(c),
              );
            },
          ),
      ],
    );
  }
}

class _LibChip {
  final String value;
  final String label;
  const _LibChip({required this.value, required this.label});
}

class _ChapterTile extends StatelessWidget {
  final MangaChapter chapter;
  final bool isLastRead;
  final VoidCallback onTap;
  const _ChapterTile({
    required this.chapter,
    required this.isLastRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.radiusSm,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isLastRead
                  ? AppColors.deepRose.withValues(alpha: 0.15)
                  : AppColors.surfaceGlass,
              borderRadius: AppRadius.radiusSm,
              border: Border.all(
                color: isLastRead
                    ? AppColors.deepRose.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.deepRose.withValues(alpha: 0.2),
                    borderRadius: AppRadius.radiusXs,
                  ),
                  child: Center(
                    child: isLastRead
                        ? const Icon(Icons.bookmark,
                            color: AppColors.deepRose, size: 18)
                        : const Icon(Icons.menu_book_rounded,
                            color: AppColors.roseQuartz, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chapter.displayTitle,
                        style: GoogleFonts.outfit(
                          color: AppColors.textHigh,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${chapter.scanlationGroup.isNotEmpty ? "${chapter.scanlationGroup} • " : ""}${chapter.pages} pages',
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.roseQuartz,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
