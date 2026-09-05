import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../data/models/wiki_page.dart';
import '../../data/services/wiki_service.dart';

class BookScreen extends StatelessWidget {
  final String bookId;
  const BookScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final service = WikiService();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.softLavender,
                  alignment: Alignment(-0.6, -0.8),
                  size: 0.8,
                  opacity: 0.12,
                ),
              ],
              showPetals: false,
            ),
          ),
          SafeArea(
            child: EverglowStreamView<List<WikiBook>>(
              stream: service.watchAllBooks(),
              streamLabel: 'wiki-book',
              errorMessage: 'Could not load book',
              loadingView: const Padding(
                padding: EdgeInsets.all(16),
                child: EverglowSkeleton(
                  width: double.infinity,
                  height: 140,
                  radius: 16,
                ),
              ),
              isEmpty: (books) =>
                  books.where((b) => b.id == bookId).isEmpty,
              emptyView: Center(
                child: Text(
                  'Book not found',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
              builder: (context, books) {
                final book = books.firstWhere((b) => b.id == bookId);
                return Column(
                  children: [
                    EverglowFeatureHeader(
                      title: book.title,
                      subtitle: book.description.isEmpty
                          ? 'pages • AFFiNE style'
                          : book.description,
                      icon: Icons.book_rounded,
                      hue: Color(
                        int.tryParse(book.coverColor.replaceAll('#', '0xFF')) ??
                            0xFF8E44AD,
                      ),
                      onBack: () => context.pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddPage(context, bookId),
                              icon: const Icon(
                                Icons.note_add_rounded,
                                size: 16,
                              ),
                              label: Text(
                                'New Page',
                                style: AppTypography.outfitBold.copyWith(
                                  fontSize: 12,
                                  color: AppColors.petalWhite,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.deepRose,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _confirmDeleteBook(context, bookId),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            label: Text(
                              'Delete Book',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 11,
                                color: AppColors.error,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<List<WikiPage>>(
                        stream: service.watchPages(bookId),
                        builder: (context, snap) {
                          final pages = snap.data ?? [];
                          if (pages.isEmpty) {
                            return EverglowEmptyState(
                              icon: Icons.article_outlined,
                              title: 'No pages yet',
                              subtitle:
                                  'Add your first page — markdown supported',
                              ctaLabel: 'New Page',
                              onCta: () => _showAddPage(context, bookId),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: pages.length,
                            itemBuilder: (context, idx) {
                              final page = pages[idx];
                              return GestureDetector(
                                onTap: () =>
                                    context.push('/wiki/page/${page.id}'),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.moonlight.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: page.isPinned
                                          ? AppColors.blushGold.withValues(
                                              alpha: 0.3,
                                            )
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.softLavender
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.article_rounded,
                                          size: 18,
                                          color: AppColors.softLavender,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    page.title,
                                                    style: AppTypography
                                                        .outfitBold
                                                        .copyWith(
                                                          fontSize: 13,
                                                          color: AppTheme
                                                              .petalWhite,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (page.isPinned)
                                                  const Icon(
                                                    Icons.push_pin_rounded,
                                                    size: 12,
                                                    color: AppColors.blushGold,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              page.markdown.isEmpty
                                                  ? 'No content'
                                                  : page.markdown.substring(
                                                      0,
                                                      page.markdown.length > 60
                                                          ? 60
                                                          : page
                                                                .markdown
                                                                .length,
                                                    ),
                                              style: AppTypography.outfitWhite
                                                  .copyWith(
                                                    fontSize: 11,
                                                    color: AppColors.petalWhite
                                                        .withValues(alpha: 0.6),
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${page.wordCount} words • by ${page.author}',
                                              style: AppTypography.outfitWhite
                                                  .copyWith(
                                                    fontSize: 10,
                                                    color: AppColors.petalWhite
                                                        .withValues(alpha: 0.5),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: AppColors.blushGold,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPage(BuildContext context, String bookId) {
    final titleCtrl = TextEditingController();
    final mdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: Text(
          'New Page',
          style: AppTypography.cormorantBold.copyWith(
            color: AppColors.petalWhite,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                ),
                decoration: InputDecoration(
                  hintText: 'Page title',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mdCtrl,
                maxLines: 6,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Markdown content...',
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final auth = ctx.read<AuthService>();
              final md = mdCtrl.text.trim();
              await WikiService().addPage(
                WikiPage(
                  id: '',
                  bookId: bookId,
                  title: title,
                  markdown: md,
                  author: auth.currentUser ?? 'unknown',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  wordCount: md
                      .split(RegExp(r'\s+'))
                      .where((w) => w.isNotEmpty)
                      .length,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepRose,
            ),
            child: const Text('Create', style: TextStyle(color: AppColors.petalWhite)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBook(BuildContext context, String bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: Text(
          'Delete book?',
          style: AppTypography.outfitBold.copyWith(color: AppColors.petalWhite),
        ),
        content: Text(
          'All pages in this book will be deleted.',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await WikiService().deleteBook(bookId);
      if (context.mounted) context.pop();
    }
  }
}
