import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../data/models/wiki_page.dart';
import '../../data/services/wiki_service.dart';

class PageScreen extends StatefulWidget {
  final String pageId;
  const PageScreen({super.key, required this.pageId});

  @override
  State<PageScreen> createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> {
  bool _editing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _mdCtrl;

  @override
  void dispose() {
    if (_editing) {
      _titleCtrl.dispose();
      _mdCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = WikiService();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: EverglowBackground(baseColor: AppColors.inkDeep, glows: const [RadialGlow(color: AppColors.softLavender, alignment: Alignment(-0.6, -0.8), size: 0.8, opacity: 0.12)], showPetals: true)),
          SafeArea(
            child: StreamBuilder<List<WikiPage>>(
              stream: service.watchAllPages(),
              builder: (context, snap) {
                final pages = snap.data ?? [];
                final page = pages.where((p) => p.id == widget.pageId).isEmpty ? null : pages.firstWhere((p) => p.id == widget.pageId);
                if (page == null) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2));
                  return Center(child: Text('Page not found', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite)));
                }
                if (_editing) {
                  // Editing mode
                  return Column(
                    children: [
                      EverglowFeatureHeader(title: 'Edit Page', subtitle: page.title, icon: Icons.edit_rounded, hue: AppColors.softLavender, onBack: () => setState(() => _editing = false)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextField(controller: _titleCtrl, style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: 'Title', filled: true, fillColor: AppColors.twilight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                              const SizedBox(height: 12),
                              Expanded(child: TextField(controller: _mdCtrl, maxLines: null, expands: true, style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite, fontSize: 14, height: 1.5), decoration: InputDecoration(hintText: 'Markdown...', filled: true, fillColor: AppColors.twilight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                              const SizedBox(height: 12),
                              Row(children: [Expanded(child: OutlinedButton(onPressed: () => setState(() => _editing = false), child: Text('Cancel', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite)))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: () async { final title = _titleCtrl.text.trim(); if (title.isEmpty) return; final md = _mdCtrl.text; await service.updatePage(page.copyWith(title: title, markdown: md, wordCount: md.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length)); if (mounted) setState(() => _editing = false); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepRose), child: Text('Save', style: AppTypography.outfitBold.copyWith(color: Colors.white))))]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    EverglowFeatureHeader(title: page.title, subtitle: '${page.wordCount} words • by ${page.author}', icon: Icons.article_rounded, hue: AppColors.softLavender, onBack: () => Navigator.pop(context), actions: [IconButton(onPressed: () => setState(() { _titleCtrl = TextEditingController(text: page.title); _mdCtrl = TextEditingController(text: page.markdown); _editing = true; }), icon: Icon(Icons.edit_rounded, color: AppColors.blushGold)), IconButton(onPressed: () => _togglePin(page), icon: Icon(page.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: AppColors.blushGold))]),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (page.tags.isNotEmpty) Wrap(spacing: 6, children: page.tags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.softLavender.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text('#$t', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.softLavender)))).toList()),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppTheme.moonlight.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: SelectableText(page.markdown.isEmpty ? 'No content yet — tap edit to write your lore ✨' : page.markdown, style: AppTypography.outfitWhite.copyWith(fontSize: 14, height: 1.6, color: AppTheme.petalWhite)),
                            ),
                            const SizedBox(height: 16),
                            Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _confirmDelete(context, page.id), icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent), label: Text('Delete', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: Colors.redAccent)), style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3))))), const SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: () => setState(() { _titleCtrl = TextEditingController(text: page.title); _mdCtrl = TextEditingController(text: page.markdown); _editing = true; }), icon: const Icon(Icons.edit_rounded, size: 16), label: Text('Edit', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepRose)))]),
                          ],
                        ),
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

  Future<void> _togglePin(WikiPage page) async {
    await WikiService().togglePin(page.id, !page.isPinned);
  }

  Future<void> _confirmDelete(BuildContext context, String pageId) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: AppTheme.velvet, title: Text('Delete page?', style: AppTypography.outfitBold.copyWith(color: AppTheme.petalWhite)), content: Text('This cannot be undone.', style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.7))), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent)))]));
    if (confirm == true) {
      await WikiService().deletePage(pageId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

extension _PageCopy on WikiPage {
  WikiPage copyWith({String? title, String? markdown, int? wordCount}) => WikiPage(id: id, bookId: bookId, title: title ?? this.title, markdown: markdown ?? this.markdown, author: author, createdAt: createdAt, updatedAt: DateTime.now(), tags: tags, wordCount: wordCount ?? this.wordCount, isPinned: isPinned);
}
