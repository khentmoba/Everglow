import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_search_field.dart';
import '../../data/models/journal_entry.dart';
import '../../data/services/journal_service.dart';
import '../widgets/add_journal_entry_dialog.dart';
import '../widgets/journal_entry_card.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  JournalCategory? _categoryFilter;
  String? _authorFilter; // username or null
  bool _pinnedOnly = false;
  bool _lockedOnly = false;

  /// Client filters + pinned-first sort, shared by the list and its
  /// empty check so both always agree on what "visible" means.
  List<JournalEntry> _visibleEntries(List<JournalEntry> all) {
    var entries = all;
    if (_categoryFilter != null) {
      entries = entries.where((e) => e.category == _categoryFilter).toList();
    }
    if (_authorFilter != null) {
      entries = entries
          .where((e) => e.author.toLowerCase() == _authorFilter)
          .toList();
    }
    if (_pinnedOnly) {
      entries = entries.where((e) => e.isPinned).toList();
    }
    if (_lockedOnly) {
      entries = entries.where((e) => e.isLocked).toList();
    }

    // Pinned first, then newest
    entries.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return entries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final service = JournalService();

        return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      body: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Our Journal',
                  subtitle: 'words woven together',
                  icon: Icons.menu_book_rounded,
                  hue: AppColors.softLavender,
                  actions: [
                    EverglowIconButton(
                      icon: Icons.edit_note_rounded,
                      onPressed: () => _showAddDialog(auth),
                      semanticLabel: 'New journal entry',
                      tooltip: 'New entry',
                      iconColor: AppColors.blushGold,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EverglowSearchField(
                    controller: _searchController,
                    hint: 'Search memories, tags, dreams...',
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(height: 12),
                // Stats banner
                _buildStatsBanner(service),
                const SizedBox(height: 12),
                // Category chips
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCategoryChip(null, 'All'),
                      ...JournalCategory.values.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildCategoryChip(
                            c,
                            '${c.emoji} ${c.displayName}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip(
                        'All authors',
                        _authorFilter == null,
                        () => setState(() => _authorFilter = null),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Khent',
                        _authorFilter == 'khentsgdz',
                        () => setState(() => _authorFilter = 'khentsgdz'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Clair',
                        _authorFilter == 'clairjassen',
                        () => setState(() => _authorFilter = 'clairjassen'),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 16, color: AppColors.moonlight.withValues(alpha: 0.10)),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                        '📌 Pinned',
                        _pinnedOnly,
                        () => setState(() => _pinnedOnly = !_pinnedOnly),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        '🔒 Locked',
                        _lockedOnly,
                        () => setState(() => _lockedOnly = !_lockedOnly),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // On This Day banner
                _buildOnThisDay(service),
                // Entries list
                Expanded(
                  child: EverglowStreamView<List<JournalEntry>>(
                    stream: _searchQuery.isNotEmpty
                        ? service.search(_searchQuery)
                        : service.watchAll(),
                    streamLabel: 'journal-entries',
                    errorMessage: 'Could not load journal',
                    errorIcon: Icons.menu_book_outlined,
                    onRetry: () => setState(() {}),
                    loadingView: const Padding(
                      padding: EdgeInsets.all(20),
                      child: EverglowSkeleton(
                        width: double.infinity,
                        height: 120,
                        radius: 16,
                      ),
                    ),
                    isEmpty: (all) => _visibleEntries(all).isEmpty,
                    emptyView: Builder(
                      builder: (context) {
                        final isFiltered =
                            _categoryFilter != null ||
                            _authorFilter != null ||
                            _pinnedOnly ||
                            _lockedOnly ||
                            _searchQuery.isNotEmpty;
                        return EverglowEmptyState(
                          icon: Icons.edit_note_rounded,
                          title: isFiltered
                              ? 'No matching entries'
                              : 'Your journal is empty',
                          subtitle: isFiltered
                              ? 'Try adjusting filters or search'
                              : 'Write your first memory together ✨',
                          ctaLabel: isFiltered ? null : 'New Entry',
                          onCta: isFiltered ? null : () => _showAddDialog(auth),
                        );
                      },
                    ),
                    builder: (context, all) {
                      final entries = _visibleEntries(all);
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) => JournalEntryCard(
                          entry: entries[idx],
                          onTap: () =>
                              _showEntryDetail(context, entries[idx], auth),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(auth),
        backgroundColor: AppColors.deepRose,
        foregroundColor: AppColors.petalWhite,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildCategoryChip(JournalCategory? cat, String label) {
    final isSel = _categoryFilter == cat;
    return GestureDetector(
      onTap: () => setState(() => _categoryFilter = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? AppColors.deepRose.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? AppColors.blushGold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel
                ? AppColors.blushGold
                : AppTheme.petalWhite.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.softLavender.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.softLavender : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected
                ? AppColors.softLavender
                : AppTheme.petalWhite.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBanner(JournalService service) {
    return StreamBuilder<List<JournalEntry>>(
      stream: service.watchAll(),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final total = entries.length;
        final words = entries.fold<int>(0, (sum, e) => sum + e.wordCount);
        final pinned = entries.where((e) => e.isPinned).length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.moonlight.withValues(
                alpha: AppTheme.glassOpacity,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                _buildStatItem(
                  total.toString(),
                  'entries',
                  Icons.menu_book_outlined,
                ),
                _buildStatDivider(),
                _buildStatItem(
                  words.toString(),
                  'words',
                  Icons.text_fields_rounded,
                ),
                _buildStatDivider(),
                _buildStatItem(
                  pinned.toString(),
                  'pinned',
                  Icons.push_pin_outlined,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deepRose.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: AppColors.blushGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DailyTxT • Memos',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          color: AppColors.blushGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.blushGold.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 14,
                color: AppTheme.petalWhite,
              ),
            ),
            Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 10,
                color: AppTheme.petalWhite.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatDivider() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppColors.border,
  );

  Widget _buildOnThisDay(JournalService service) {
    return FutureBuilder<List<JournalEntry>>(
      future: service.getOnThisDay(),
      builder: (context, snap) {
        final data = snap.data ?? [];
        if (data.isEmpty) return const SizedBox.shrink();
        final entry = data.first;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GestureDetector(
            onTap: () =>
                _showEntryDetail(context, entry, context.read<AuthService>()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blushGold.withValues(alpha: 0.14),
                    AppColors.deepRose.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: AppColors.blushGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'On this day: "${entry.title}" — ${entry.preview.substring(0, entry.preview.length > 40 ? 40 : entry.preview.length)}',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppTheme.petalWhite.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          ),
        );
      },
    );
  }

  void _showAddDialog(AuthService auth) {
    showDialog(
      context: context,
      builder: (_) =>
          AddJournalEntryDialog(author: auth.currentUser ?? 'unknown'),
    );
  }

  void _showEntryDetail(
    BuildContext context,
    JournalEntry entry,
    AuthService auth,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.velvet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.2),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.petalWhite.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    entry.category.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.title,
                      style: AppTypography.cormorantBold.copyWith(fontSize: 24),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => AddJournalEntryDialog(
                          author: auth.currentUser ?? entry.author,
                          existing: entry,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.blushGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${entry.createdAt.toLocal().toString().substring(0, 16)} • by ${entry.author}${entry.mood != null ? ' • ${entry.mood!.emoji} ${entry.mood!.name}' : ''}',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: entry.tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softLavender.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#$t',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 11,
                              color: AppColors.softLavender,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              if (entry.isLocked)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.inkDeep.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warmAmber.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 28,
                        color: AppColors.warmAmber,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Locked entry',
                        style: AppTypography.outfitBold.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.content,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 14,
                          height: 1.6,
                          color: AppTheme.petalWhite.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SelectableText(
                  entry.content.isEmpty ? 'No content.' : entry.content,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await JournalService().togglePin(
                          entry.id,
                          !entry.isPinned,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon(
                        entry.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: 16,
                      ),
                      label: Text(entry.isPinned ? 'Unpin' : 'Pin'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blushGold,
                        side: BorderSide(
                          color: AppColors.blushGold.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await JournalService().toggleLock(
                          entry.id,
                          !entry.isLocked,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon(
                        entry.isLocked
                            ? Icons.lock_open_rounded
                            : Icons.lock_rounded,
                        size: 16,
                      ),
                      label: Text(entry.isLocked ? 'Unlock' : 'Lock'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warmAmber,
                        side: BorderSide(
                          color: AppColors.warmAmber.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: AppTheme.velvet,
                        title: Text(
                          'Delete entry?',
                          style: AppTypography.outfitBold.copyWith(
                            color: AppTheme.petalWhite,
                          ),
                        ),
                        content: Text(
                          'This cannot be undone.',
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppTheme.petalWhite.withValues(alpha: 0.7),
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
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await JournalService().delete(entry.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
