import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/comick_service.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/features/manga/data/services/mangakakalot_service.dart';
import 'package:everglow/features/manga/data/services/scanlation_service.dart';
import 'package:everglow/features/manga/presentation/screens/manga_reader_screen.dart';
import 'package:everglow/services/auth_service.dart';

/// Bottom-sheet details for a manga / manhwa / manhua. Mirrors
/// `EpisodeDrawer` from the cinema feature — same gradient cover,
/// same description block, same library-status row, but the
/// "episodes" rail is a chapter list and tapping a chapter opens
/// the manga reader instead of the video player.
class MangaDetailsDrawer extends StatefulWidget {
  final MangaItem item;
  const MangaDetailsDrawer({Key? key, required this.item}) : super(key: key);

  @override
  State<MangaDetailsDrawer> createState() => _MangaDetailsDrawerState();
}

class _MangaDetailsDrawerState extends State<MangaDetailsDrawer> {
  final ComickService _comickService = ComickService();
  final MangaDexService _mangaDexService = MangaDexService();
  final MangaKakalotService _kakalotService = MangaKakalotService();
  final ScanlationService _scanlationService = ScanlationService();
  final ScrollController _chapterScrollController = ScrollController();

  /// Populated when chapters come from scanlation sites; passed to
  /// the reader so it can resolve page images from the same sites.
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

    List<MangaChapter>? list;

    // 1) Comick API — richest chapter metadata (scanlation groups, dates)
    if (_item.comickId > 0) {
      try {
        list = await _comickService.getChapterFeed(_item.comickId);
        if (list.isNotEmpty) {
          if (!mounted) return;
          setState(() { _chapters = list!; _isLoadingChapters = false; });
          return;
        }
      } catch (_) { /* fall through */ }
    }

    // 2) MangaDex API — the mangaKakalotId field actually stores the
    //    MangaDex UUID (set from Comick's md_id).
    final mangaDexId = _item.mangaKakalotId;
    if (mangaDexId.isNotEmpty) {
      try {
        list = await _mangaDexService.getChapterFeed(mangaDexId);
        if (list.isNotEmpty) {
          if (!mounted) return;
          setState(() { _chapters = list!; _isLoadingChapters = false; });
          return;
        }
      } catch (_) { /* fall through */ }
    }

    // 3) MangaKakalot scraping — for legacy titles
    try {
      String slug = _item.mangaKakalotId.isNotEmpty
          ? _item.mangaKakalotId
          : _item.mangaId;
      if (slug.isEmpty || slug.length < 5) {
        final resolved = await _kakalotService.searchByTitle(_item.title);
        if (resolved.isNotEmpty) slug = resolved;
      }
      list = await _kakalotService.getChapterFeed(slug);
    } catch (_) { /* fall through */ }

    // 4) Scanlation sites — search ArcaneScans, AsuraScans, ReaperScans, etc.
    if (list == null || list.isEmpty) {
      try {
        final slugs = await _scanlationService.searchAll(_item.title);
        if (slugs.isNotEmpty) {
          final scanChapters =
              await _scanlationService.getChapterFeedFromAll(slugs);
          if (scanChapters.isNotEmpty) {
            _scanlationSlugs = slugs;
            if (!mounted) return;
            setState(() {
              _chapters = scanChapters;
              _isLoadingChapters = false;
            });
            return;
          }
        }
      } catch (_) { /* fall through */ }
    }

    if (!mounted) return;
    if (list != null && list.isNotEmpty) {
      setState(() {
        _chapters = list!;
        _isLoadingChapters = false;
      });
    } else {
      setState(() {
        _chapterError = 'No English chapters available.';
        _isLoadingChapters = false;
      });
    }
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
          style: GoogleFonts.outfit(color: AppTheme.petalWhite),
        ),
        backgroundColor: AppTheme.deepRose,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            color: AppTheme.twilight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHero(context),
                  _buildLibraryRow(),
                  const Divider(
                      height: 1,
                      color: Color(0x33F4C2C2)),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                      color: AppTheme.roseQuartz
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
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
              _item.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppTheme.velvet),
            )
          else
            Container(color: AppTheme.velvet),
          // Bottom gradient with text
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.fromLTRB(20, 40, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.twilight.withValues(alpha: 0.85),
                    AppTheme.twilight,
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
                          color: _typeColor
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _typeColor
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _item.contentType.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: AppTheme.roseQuartz,
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
                            color: AppTheme.blushGold
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _item.status.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: AppTheme.blushGold,
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
                      color: AppTheme.roseQuartz,
                    ),
                  ),
                  if (_item.author.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'by ${_item.author}',
                        style: GoogleFonts.outfit(
                          color: AppTheme.roseQuartz
                              .withValues(alpha: 0.7),
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
                      color: AppTheme.petalWhite, size: 18),
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
        return const Color(0xFFE91E63);
      case 'zh':
        return const Color(0xFF00BCD4);
      default:
        return AppTheme.deepRose;
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
              color: AppTheme.roseQuartz.withValues(alpha: 0.6),
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
              ]
                  .map((entry) {
                final selected = _item.libraryStatus == entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.label,
                        style: GoogleFonts.outfit(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) => _updateLibraryStatus(entry.value),
                    selectedColor: AppTheme.deepRose,
                    backgroundColor: AppTheme.velvet,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppTheme.petalWhite
                          : AppTheme.roseQuartz.withValues(alpha: 0.7),
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
    if (_item.description.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Synopsis',
          style: GoogleFonts.outfit(
            color: AppTheme.roseQuartz.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.moonlight
                .withValues(alpha: AppTheme.glassOpacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.moonlight.withValues(alpha: 0.15),
            ),
          ),
          child: Html(
            data: _item.description,
            style: {
              'body': Style(
                color: AppTheme.petalWhite.withValues(alpha: 0.85),
                fontSize: FontSize(14),
                fontFamily: GoogleFonts.outfit().fontFamily,
                lineHeight: const LineHeight(1.6),
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'p': Style(margin: Margins.only(bottom: 8)),
              'a': Style(color: AppTheme.roseQuartz),
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
                  color: AppTheme.moonlight
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.roseQuartz
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.outfit(
                    color: AppTheme.roseQuartz
                        .withValues(alpha: 0.8),
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
                color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            if (_chapters.isNotEmpty)
              Text(
                '${_chapters.length} total',
                style: GoogleFonts.outfit(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingChapters)
          const Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.deepRose),
            ),
          )
        else if (_chapterError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _chapterError!,
                style: GoogleFonts.outfit(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                ),
              ),
            ),
          )
        else if (_chapters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No English chapters available.',
                style: GoogleFonts.outfit(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                ),
              ),
            ),
          )
        else
          ..._chapters.map((c) => _ChapterTile(
                chapter: c,
                isLastRead: _item.lastReadChapterId == c.id,
                onTap: () => _openReader(c),
              )),
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
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isLastRead
                  ? AppTheme.deepRose.withValues(alpha: 0.15)
                  : AppTheme.moonlight
                      .withValues(alpha: AppTheme.glassOpacity),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLastRead
                    ? AppTheme.deepRose.withValues(alpha: 0.4)
                    : AppTheme.moonlight.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.deepRose.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isLastRead
                        ? const Icon(Icons.bookmark,
                            color: AppTheme.deepRose, size: 18)
                        : const Icon(Icons.menu_book_rounded,
                            color: AppTheme.roseQuartz, size: 18),
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
                          color: AppTheme.petalWhite,
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
                          color: AppTheme.roseQuartz
                              .withValues(alpha: 0.6),
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
                  color: AppTheme.roseQuartz,
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
