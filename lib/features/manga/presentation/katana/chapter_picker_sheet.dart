import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import 'katana_theme.dart';

class ChapterPickerSheet extends StatefulWidget {
  final List<KatanaChapter> chapters;
  final KatanaChapter currentChapter;
  final ValueChanged<KatanaChapter> onChapterSelected;

  const ChapterPickerSheet({
    super.key,
    required this.chapters,
    required this.currentChapter,
    required this.onChapterSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<KatanaChapter> chapters,
    required KatanaChapter currentChapter,
    required ValueChanged<KatanaChapter> onChapterSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: KatanaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChapterPickerSheet(
        chapters: chapters,
        currentChapter: currentChapter,
        onChapterSelected: onChapterSelected,
      ),
    );
  }

  @override
  State<ChapterPickerSheet> createState() => _ChapterPickerSheetState();
}

class _ChapterPickerSheetState extends State<ChapterPickerSheet> {
  final TextEditingController _filterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _reversed = false; // default: ascending (oldest to newest)
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final list = _filteredChapters;
    final index = list.indexWhere((c) => c.id == widget.currentChapter.id);
    if (index > 0) {
      final target = (index * 52.0) - 100;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<KatanaChapter> get _filteredChapters {
    var list = List<KatanaChapter>.from(widget.chapters);
    if (_reversed) {
      list = list.reversed.toList();
    }
    if (_query.trim().isEmpty) return list;

    final q = _query.trim().toLowerCase();
    return list.where((c) {
      return c.displayTitle.toLowerCase().contains(q) ||
          c.num.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _filteredChapters;
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: KatanaColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 14, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: KatanaColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Chapters',
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.text,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: KatanaColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: KatanaColors.border),
                  ),
                  child: Text(
                    '${widget.chapters.length}',
                    style: KatanaType.small.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _reversed ? 'Oldest first' : 'Newest first',
                  icon: Icon(
                    _reversed ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: KatanaColors.textMuted,
                    size: 19,
                  ),
                  onPressed: () {
                    setState(() => _reversed = !_reversed);
                  },
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: KatanaColors.textLight,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search / filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: KatanaColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KatanaColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.search_rounded,
                    color: KatanaColors.textLight,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _filterController,
                      style: KatanaType.body.copyWith(
                        color: KatanaColors.text,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Jump to chapter, e.g. 50...',
                        hintStyle: TextStyle(
                          color: KatanaColors.textLight,
                          fontSize: 12.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        setState(() => _query = val);
                      },
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: KatanaColors.textLight,
                        size: 16,
                      ),
                      onPressed: () {
                        _filterController.clear();
                        setState(() => _query = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: KatanaColors.border),

          // Chapters list
          Expanded(
            child: chapters.isEmpty
                ? Center(
                    child: Text(
                      'No chapters match "$_query"',
                      style: KatanaType.small,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: chapters.length,
                    itemExtent: 52,
                    itemBuilder: (ctx, index) {
                      final chapter = chapters[index];
                      final isCurrent = chapter.id == widget.currentChapter.id;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (!isCurrent) {
                            widget.onChapterSelected(chapter);
                          }
                        },
                        child: Container(
                          color: isCurrent
                              ? KatanaColors.accent.withValues(alpha: 0.12)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCurrent
                                    ? Icons.play_arrow_rounded
                                    : Icons.menu_book_rounded,
                                size: 18,
                                color: isCurrent
                                    ? KatanaColors.accent
                                    : KatanaColors.textLight,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  chapter.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.outfitBold.copyWith(
                                    color: isCurrent
                                        ? KatanaColors.accent
                                        : KatanaColors.text,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KatanaColors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Reading',
                                    style: AppTypography.outfitBold.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
