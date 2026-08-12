import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';
import 'package:everglow/features/manga/presentation/katana/katana_header.dart';
import 'package:everglow/features/manga/presentation/katana/katana_nav.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';
import 'package:everglow/services/auth_service.dart';

/// The user's bookmarked manga, with continue-reading progress and
/// quick removal, mirroring the site's bookmark list.
class KatanaBookmarksScreen extends StatefulWidget {
  const KatanaBookmarksScreen({super.key});

  @override
  State<KatanaBookmarksScreen> createState() => _KatanaBookmarksScreenState();
}

class _KatanaBookmarksScreenState extends State<KatanaBookmarksScreen> {
  final KatanaService _service = KatanaService();
  List<KatanaBookmark> _bookmarks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final user = context.read<AuthService>().currentUser ?? '';
    _service.bookmarkStream(user).listen((items) {
      if (mounted) {
        setState(() {
          _bookmarks = items;
          _loading = false;
        });
      }
    });
  }

  Future<void> _openBookmark(KatanaBookmark bookmark, {required bool continueReading}) async {
    final detail = await _service.fetchMangaDetail(bookmark.slug);
    if (!mounted) return;
    final chapters = detail?.chapters ?? const <KatanaChapter>[];
    final sorted = sortChaptersAscending(chapters);
    if (sorted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No readable chapters yet.'),
          backgroundColor: KatanaColors.headerDark,
        ),
      );
      return;
    }
    KatanaChapter target = sorted.first;
    if (continueReading && bookmark.lastReadChapterId.isNotEmpty) {
      target = sorted.firstWhere(
        (c) => c.id == bookmark.lastReadChapterId,
        orElse: () => sorted.first,
      );
    }
    pushReader(
      context,
      slug: bookmark.slug,
      chapterId: target.path,
      chapters: chapters,
      mangaTitle: bookmark.title,
      coverUrl: bookmark.coverUrl,
    );
  }

  Future<void> _removeBookmark(KatanaBookmark bookmark) async {
    final user = context.read<AuthService>().currentUser ?? '';
    await _service.setBookmark(
      KatanaManga(
        slug: bookmark.slug,
        id: bookmark.slug,
        title: bookmark.title,
        coverUrl: bookmark.coverUrl,
      ),
      user,
      bookmarked: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthService>().currentUser ?? '';
    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          const KatanaHeader(active: KatanaNav.home),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: KatanaColors.accent),
                      )
                    : user.isEmpty
                        ? _buildEmpty(
                            icon: Icons.person_off_outlined,
                            title: 'Sign in to see bookmarks',
                            subtitle: 'Your bookmarked manga will show up here.',
                          )
                        : _bookmarks.isEmpty
                            ? _buildEmpty(
                                icon: Icons.bookmark_border_rounded,
                                title: 'No bookmarks yet',
                                subtitle:
                                    'Tap "Bookmark" on any manga to keep it here and continue where you left off.',
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 60),
                                itemCount: _bookmarks.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _BookmarkCard(
                                    bookmark: _bookmarks[index],
                                    onContinue: () => _openBookmark(
                                        _bookmarks[index],
                                        continueReading: true),
                                    onOpen: () => _openBookmark(
                                        _bookmarks[index],
                                        continueReading: false),
                                    onRemove: () =>
                                        _removeBookmark(_bookmarks[index]),
                                  ),
                                ),
                              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: KatanaColors.textLight),
            const SizedBox(height: 14),
            Text(title, style: KatanaType.heading),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: KatanaType.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final KatanaBookmark bookmark;
  final VoidCallback onContinue;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _BookmarkCard({
    required this.bookmark,
    required this.onContinue,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return KatanaCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 78,
              height: 110,
              child: bookmark.coverUrl.isEmpty
                  ? Container(
                      color: KatanaColors.border,
                      child: const Icon(Icons.menu_book_rounded,
                          color: KatanaColors.textLight),
                    )
                  : KatanaNetworkImage(
                      bookmark.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: KatanaColors.border,
                        child: const Icon(Icons.broken_image_rounded,
                            color: KatanaColors.textLight),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.text,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _pill(
                      bookmark.status == 'completed' ? 'Completed' : 'Ongoing',
                      color: bookmark.status == 'completed'
                          ? KatanaColors.green
                          : KatanaColors.accent,
                    ),
                    if (bookmark.latestChapterTitle.isNotEmpty)
                      _pill('Latest: ${bookmark.latestChapterTitle}',
                          color: KatanaColors.textMuted),
                  ],
                ),
                if (bookmark.hasProgress) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Continue reading ${bookmark.lastReadChapterTitle.isEmpty ? bookmark.lastReadChapterId : bookmark.lastReadChapterTitle} · page ${bookmark.lastReadPage}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KatanaType.accent.copyWith(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    KatanaButton(
                      label: bookmark.hasProgress
                          ? 'Continue reading'
                          : 'Read first chapter',
                      icon: Icons.play_arrow_rounded,
                      onTap: bookmark.hasProgress ? onContinue : onOpen,
                    ),
                    KatanaButton(
                      label: 'Remove',
                      icon: Icons.bookmark_remove_rounded,
                      filled: false,
                      onTap: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTypography.outfitBold.copyWith(
          color: color,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
