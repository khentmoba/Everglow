import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../data/models/wiki_page.dart';
import '../../data/services/wiki_service.dart';

class WikiScreen extends StatefulWidget {
  const WikiScreen({super.key});

  @override
  State<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends State<WikiScreen> {
  @override
  Widget build(BuildContext context) {
    final service = WikiService();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: EverglowBackground(baseColor: AppColors.inkDeep, glows: const [RadialGlow(color: AppColors.softLavender, alignment: Alignment(-0.6, -0.8), size: 0.85, opacity: 0.12)], showPetals: true)),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(title: 'Our Universe', subtitle: 'lore book • AFFiNE × BookStack', icon: Icons.menu_book_rounded, hue: AppColors.softLavender, actions: [IconButton(onPressed: () => _showAddShelf(), icon: Icon(Icons.create_new_folder_rounded, color: AppColors.blushGold))]),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.15))), child: Row(children: [Icon(Icons.auto_stories_rounded, size: 16, color: AppColors.softLavender), const SizedBox(width: 8), Text('Shelves → Books → Pages', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite)), const Spacer(), Text('BookStack', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.softLavender))])),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<WikiShelf>>(
                    stream: service.watchShelves(),
                    builder: (context, snap) {
                      final shelves = snap.data ?? [];
                      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2));
                      if (shelves.isEmpty) return EverglowEmptyState(icon: Icons.library_books_rounded, title: 'No shelves yet', subtitle: 'Create your first shelf — e.g., Our Story, Travel Lore, Inside Jokes', ctaLabel: 'New Shelf', onCta: _showAddShelf);
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: shelves.length,
                        itemBuilder: (context, idx) {
                          final shelf = shelves[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: AppTheme.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.15))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.softLavender.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(shelf.icon, style: const TextStyle(fontSize: 20)))),
                                  title: Text(shelf.title, style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppTheme.petalWhite)),
                                  subtitle: Text(shelf.description.isEmpty ? 'No description' : shelf.description, style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: IconButton(onPressed: () => _showAddBook(shelf.id), icon: Icon(Icons.add_rounded, size: 18, color: AppColors.softLavender)),
                                ),
                                StreamBuilder<List<WikiBook>>(
                                  stream: service.watchBooks(shelf.id),
                                  builder: (context, snap) {
                                    final books = snap.data ?? [];
                                    if (books.isEmpty) return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text('No books — tap + to add', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.5), fontStyle: FontStyle.italic)));
                                    return Column(
                                      children: books.map((book) => ListTile(
                                            onTap: () => context.push('/wiki/book/${book.id}'),
                                            leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(int.tryParse(book.coverColor.replaceAll('#', '0xFF')) ?? 0xFF8E44AD).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.book_rounded, size: 16, color: Color(int.tryParse(book.coverColor.replaceAll('#', '0xFF')) ?? 0xFF8E44AD))),
                                            title: Text(book.title, style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite)),
                                            subtitle: Text(book.description.isEmpty ? 'No description' : book.description, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            trailing: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.blushGold),
                                          )).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddShelf, backgroundColor: AppColors.softLavender, foregroundColor: Colors.white, child: const Icon(Icons.add_rounded)),
    );
  }

  void _showAddShelf() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String icon = '📚';
    final icons = ['📚', '💕', '🗺️', '✨', '🎵', '🎬', '✈️', '🏠'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          backgroundColor: AppTheme.velvet,
          title: Text('New Shelf', style: AppTypography.cormorantBold.copyWith(color: AppTheme.petalWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(spacing: 8, children: icons.map((e) => GestureDetector(onTap: () => setDlg(() => icon = e), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: icon == e ? AppColors.softLavender.withValues(alpha: 0.25) : AppColors.twilight, shape: BoxShape.circle, border: Border.all(color: icon == e ? AppColors.softLavender : AppColors.border)), child: Text(e, style: const TextStyle(fontSize: 18))))).toList()),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite), decoration: InputDecoration(hintText: 'Shelf title — e.g., Our Story', hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.4)), filled: true, fillColor: AppColors.twilight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13), decoration: InputDecoration(hintText: 'Description', hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.4)), filled: true, fillColor: AppColors.twilight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final auth = context.read<AuthService>();
                await WikiService().addShelf(WikiShelf(id: '', title: title, description: descCtrl.text.trim(), icon: icon, createdBy: auth.currentUser ?? 'unknown', createdAt: DateTime.now()));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  void _showAddBook(String shelfId) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String color = '#8E44AD';
    final colors = ['#8E44AD', '#C2185B', '#1976D2', '#2E7D32', '#F0A500', '#7EE8D2'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          backgroundColor: AppTheme.velvet,
          title: Text('New Book', style: AppTypography.cormorantBold.copyWith(color: AppTheme.petalWhite)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite), decoration: InputDecoration(hintText: 'Book title — e.g., First Year Together', hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.4)), filled: true, fillColor: AppColors.twilight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 13), decoration: InputDecoration(hintText: 'Description', hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.4)), filled: true, fillColor: AppColors.twilight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: colors.map((c) => GestureDetector(onTap: () => setDlg(() => color = c), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(int.parse(c.replaceAll('#', '0xFF'))), shape: BoxShape.circle, border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 2))))).toList()),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final auth = context.read<AuthService>();
                await WikiService().addBook(WikiBook(id: '', shelfId: shelfId, title: title, description: descCtrl.text.trim(), coverColor: color, createdBy: auth.currentUser ?? 'unknown', createdAt: DateTime.now()));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepRose),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }
}
