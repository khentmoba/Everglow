import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/scroll_memory.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_search_field.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/models/journal_entry.dart';
import '../../data/services/journal_service.dart';
import '../widgets/add_journal_entry_dialog.dart';
import '../widgets/journal_detail_sheet.dart';
import '../widgets/journal_entry_card.dart';
import '../widgets/journal_ui.dart';

class JournalScreen extends StatefulWidget {
  final List<JournalEntry>? demoEntries;
  const JournalScreen({super.key, this.demoEntries});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _searchController = TextEditingController();
  final _entriesScroll = RememberedScrollController('journal:entries');
  String _searchQuery = '';
  Future<List<JournalEntry>>? _searchFuture;
  JournalCategory? _categoryFilter;
  String? _authorFilter;
  bool _pinnedOnly = false;
  bool _lockedOnly = false;

  List<JournalEntry> _visibleEntries(List<JournalEntry> all) {
    var entries = List<JournalEntry>.of(all);
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

    entries.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return entries;
  }

  bool get _isFiltered =>
      _categoryFilter != null ||
      _authorFilter != null ||
      _pinnedOnly ||
      _lockedOnly;

  @override
  void dispose() {
    _searchController.dispose();
    _entriesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final service = JournalService();
    final searching = _searchQuery.trim().isNotEmpty;

    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      centerMaxWidth: 740,
      glows: const [
        RadialGlow(
          color: AppColors.deepRose,
          alignment: Alignment(-0.8, -0.9),
          size: 0.7,
          opacity: 0.16,
        ),
        RadialGlow(
          color: AppColors.plum,
          alignment: Alignment(0.8, -0.6),
          size: 0.6,
          opacity: 0.12,
        ),
        RadialGlow(
          color: AppColors.auroraGold,
          alignment: Alignment(0.9, 0.9),
          size: 0.65,
          opacity: 0.08,
        ),
      ],
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
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: EverglowSearchField(
              controller: _searchController,
              hint: 'Search memories, tags, dreams...',
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _searchFuture = v.trim().isEmpty ? null : service.search(v);
                });
              },
            ),
          ),
          Expanded(
            child: EverglowStreamView<List<JournalEntry>>(
              stream: widget.demoEntries != null ? Stream.value(widget.demoEntries!) : service.watchAll(),
              streamLabel: 'journal-entries',
              errorMessage: 'Could not load journal',
              errorIcon: Icons.menu_book_outlined,
              onRetry: () => setState(() {}),
              loadingView: const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  children: [
                    EverglowSkeleton(
                      width: double.infinity,
                      height: 148,
                      radius: 20,
                    ),
                    SizedBox(height: 12),
                    EverglowSkeleton(
                      width: double.infinity,
                      height: 120,
                      radius: 16,
                    ),
                  ],
                ),
              ),
              builder: (context, all) {
                if (all.isEmpty) {
                  if (searching) return _noMatchView();
                  return EverglowEmptyState(
                    icon: Icons.edit_note_rounded,
                    title: 'Your journal is empty',
                    subtitle: 'Write your first memory together ✨',
                    ctaLabel: 'New Entry',
                    onCta: () => _showAddDialog(auth),
                  );
                }
                final entries = _visibleEntries(all);
                return Column(
                  children: [
                    _StoryCard(entries: all),
                    const SizedBox(height: 12),
                    _ChapterRail(
                      entries: all,
                      selected: _categoryFilter,
                      onSelect: (c) => setState(() => _categoryFilter = c),
                    ),
                    const SizedBox(height: 8),
                    _AuthorRow(
                      authorFilter: _authorFilter,
                      pinnedOnly: _pinnedOnly,
                      lockedOnly: _lockedOnly,
                      onAuthor: (a) => setState(() => _authorFilter = a),
                      onPinned: () =>
                          setState(() => _pinnedOnly = !_pinnedOnly),
                      onLocked: () =>
                          setState(() => _lockedOnly = !_lockedOnly),
                    ),
                    const SizedBox(height: 8),
                    if (!searching) _MemoryCapsule(service: service),
                    Expanded(
                      child: searching
                          ? _buildSearchResults()
                          : entries.isEmpty
                              ? _noMatchView()
                              : _PaginatedJournalList(
                                  firstPage: entries,
                                  isFiltered: _isFiltered,
                                  onTap: (entry) =>
                                      _showEntryDetail(entry, auth),
                                ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          gradient: const LinearGradient(
            colors: [AppColors.deepRose, AppColors.auroraRose],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.auroraGold.withValues(alpha: 0.16),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddDialog(auth),
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.petalWhite,
          icon: const Icon(Icons.edit_note_rounded, size: 21),
          label: Text(
            'Write',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _noMatchView() {
    return const EverglowEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matching entries',
      subtitle: 'Try adjusting filters or search',
    );
  }

  Widget _buildSearchResults() {
    final future = _searchFuture;
    if (future == null) return const SizedBox.shrink();
    final service = JournalService();
    return FutureBuilder<List<JournalEntry>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: EverglowSkeleton(
              width: double.infinity,
              height: 120,
              radius: 16,
            ),
          );
        }
        if (snap.hasError) {
          return EverglowEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Search failed',
            subtitle: 'Try again',
            ctaLabel: 'Retry',
            onCta: () => setState(() {
              _searchFuture = service.search(_searchQuery);
            }),
          );
        }
        final entries = _visibleEntries(snap.data ?? const <JournalEntry>[]);
        if (entries.isEmpty) return _noMatchView();
        final auth = context.read<AuthService>();
        return ListView.separated(
          controller: _entriesScroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, idx) => JournalEntryCard(
            entry: entries[idx],
            onTap: () => _showEntryDetail(entries[idx], auth),
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

  void _showEntryDetail(JournalEntry entry, AuthService auth) {
    showJournalDetailSheet(
      context: context,
      entry: entry,
      onEdit: () {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => AddJournalEntryDialog(
            author: auth.currentUser ?? entry.author,
            existing: entry,
          ),
        );
      },
    );
  }
}

/// "Our story so far" — entries, words, days writing, plus the last two
/// weeks as activity dots. Every number comes from the live list.
class _StoryCard extends StatelessWidget {
  final List<JournalEntry> entries;
  const _StoryCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final words = entries.fold<int>(0, (total, e) => total + e.wordCount);
    final wrote = entries.map((e) => journalDayKey(e.createdAt)).toSet();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.plum.withValues(alpha: 0.55),
              AppColors.velvet.withValues(alpha: 0.70),
              AppColors.inkDeep.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.40),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'our story so far',
                        style: AppTypography.handwrittenTitle().copyWith(
                          fontSize: 25,
                          color: AppColors.blushGold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'every word is a piece of us',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11.5,
                          color: AppColors.petalWhite.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Stat(
                  value: '${entries.length}',
                  label: 'entries',
                  icon: Icons.menu_book_rounded,
                ),
                const SizedBox(width: 6),
                _Stat(
                  value: journalNumberFormat(words),
                  label: 'words',
                  icon: Icons.draw_rounded,
                ),
                const SizedBox(width: 6),
                _Stat(
                  value: '${wrote.length}',
                  label: 'days',
                  icon: Icons.calendar_today_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: AppColors.blushGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'last 2 weeks',
                        style: AppTypography.outfitMedium.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          color: AppColors.petalWhite.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(14, (i) {
                      final day = DateTime.now().subtract(
                        Duration(days: 13 - i),
                      );
                      final key = journalDayKey(day);
                      final filled = wrote.contains(key);
                      final isToday = i == 13;
                      return Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                        child: Container(
                          width: isToday ? 11 : 8.5,
                          height: isToday ? 11 : 8.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? (isToday
                                    ? AppColors.auroraGold
                                    : AppColors.blushGold)
                                : AppColors.moonlight.withValues(alpha: 0.14),
                            border: isToday
                                ? Border.all(
                                    color: AppColors.petalWhite,
                                    width: 1.2,
                                  )
                                : null,
                            boxShadow: filled
                                ? [
                                    BoxShadow(
                                      color: (isToday
                                              ? AppColors.auroraGold
                                              : AppColors.blushGold)
                                          .withValues(
                                            alpha: isToday ? 0.6 : 0.4,
                                          ),
                                      blurRadius: isToday ? 8 : 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 11,
                color: AppColors.blushGold.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 14,
                  height: 1.1,
                  color: AppColors.blushGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 9.5,
              letterSpacing: 0.3,
              color: AppColors.petalWhite.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chapter rail — "All" plus one pill per category with live counts.
class _ChapterRail extends StatelessWidget {
  final List<JournalEntry> entries;
  final JournalCategory? selected;
  final ValueChanged<JournalCategory?> onSelect;

  const _ChapterRail({
    required this.entries,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _ChapterPill(
            emoji: '✨',
            name: 'All',
            count: entries.length,
            color: AppColors.blushGold,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...JournalCategory.values.map((c) {
            final count = entries.where((e) => e.category == c).length;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _ChapterPill(
                emoji: c.emoji,
                name: c.displayName,
                count: count,
                color: journalCategoryColor(c),
                selected: selected == c,
                onTap: () => onSelect(c),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChapterPill extends StatelessWidget {
  final String emoji;
  final String name;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ChapterPill({
    required this.emoji,
    required this.name,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.30),
                    color.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: selected ? null : AppColors.panelGlass,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.70)
                : AppColors.moonlight.withValues(alpha: 0.11),
            width: selected ? 1.3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              name,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 11.5,
                color: selected
                    ? AppColors.petalWhite
                    : AppColors.petalWhite.withValues(alpha: 0.75),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.30)
                      : AppColors.moonlight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 10,
                    color: selected ? AppColors.petalWhite : color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Author + pin/lock filters — slim second row under the chapters.
class _AuthorRow extends StatelessWidget {
  final String? authorFilter;
  final bool pinnedOnly;
  final bool lockedOnly;
  final ValueChanged<String?> onAuthor;
  final VoidCallback onPinned;
  final VoidCallback onLocked;

  const _AuthorRow({
    required this.authorFilter,
    required this.pinnedOnly,
    required this.lockedOnly,
    required this.onAuthor,
    required this.onPinned,
    required this.onLocked,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'All authors',
            selected: authorFilter == null,
            accentColor: AppColors.softLavender,
            onTap: () => onAuthor(null),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Khent',
            avatarDotAuthor: 'khentsgdz',
            selected: authorFilter == 'khentsgdz',
            accentColor: AppColors.auroraTeal,
            onTap: () => onAuthor('khentsgdz'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Clair',
            avatarDotAuthor: 'clairjassen',
            selected: authorFilter == 'clairjassen',
            accentColor: AppColors.auroraRose,
            onTap: () => onAuthor('clairjassen'),
          ),
          const SizedBox(width: 10),
          Center(
            child: Container(
              width: 1,
              height: 16,
              color: AppColors.moonlight.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: '📌 Pinned',
            selected: pinnedOnly,
            accentColor: AppColors.blushGold,
            onTap: onPinned,
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: '🔒 Locked',
            selected: lockedOnly,
            accentColor: AppColors.warmAmber,
            onTap: onLocked,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final String? avatarDotAuthor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor = AppColors.softLavender,
    this.avatarDotAuthor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.18)
              : AppColors.panelGlass,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.70)
                : AppColors.moonlight.withValues(alpha: 0.10),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarDotAuthor != null) ...[
              AuthorDot(author: avatarDotAuthor!, size: 14),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 11,
                color: selected
                    ? accentColor
                    : AppColors.petalWhite.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "On this day" memory capsule — a golden peek at a past year.
class _MemoryCapsule extends StatelessWidget {
  final JournalService service;
  const _MemoryCapsule({required this.service});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JournalEntry>>(
      future: service.getOnThisDay(),
      builder: (context, snap) {
        final data = snap.data ?? [];
        if (data.isEmpty) return const SizedBox.shrink();
        final entry = data.first;
        final auth = context.read<AuthService>();
        final preview = entry.isLocked
            ? 'A sealed page from the past...'
            : (entry.preview.length > 60
                ? '${entry.preview.substring(0, 60)}…'
                : entry.preview);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: GestureDetector(
            onTap: () => showJournalDetailSheet(
              context: context,
              entry: entry,
              onEdit: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AddJournalEntryDialog(
                    author: auth.currentUser ?? entry.author,
                    existing: entry,
                  ),
                );
              },
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blushGold.withValues(alpha: 0.16),
                    AppColors.deepRose.withValues(alpha: 0.14),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.blushGold.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 17,
                      color: AppColors.blushGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'On this day in ${entry.createdAt.year}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: AppColors.blushGold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '"${entry.title.isEmpty ? 'Untitled' : entry.title}" — $preview',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite.withValues(alpha: 0.85),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
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
}

/// Journal list with month chapter dividers and cursor pagination past
/// the live first page.
class _PaginatedJournalList extends StatefulWidget {
  const _PaginatedJournalList({
    required this.firstPage,
    required this.isFiltered,
    required this.onTap,
  });

  final List<JournalEntry> firstPage;
  final bool isFiltered;
  final void Function(JournalEntry entry) onTap;

  @override
  State<_PaginatedJournalList> createState() => _PaginatedJournalListState();
}

class _PaginatedJournalListState extends State<_PaginatedJournalList> {
  final List<JournalEntry> _older = [];
  final _scroll = RememberedScrollController('journal:entries:paged');

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DocumentSnapshot? _cursor;
  bool _loadingMore = false;
  bool _exhausted = false;
  Object? _error;

  static const int _firstPageSize = 100;

  bool get _canPage =>
      !widget.isFiltered &&
      widget.firstPage.length >= _firstPageSize &&
      !_exhausted;

  Future<void> _loadMore() async {
    if (_loadingMore || !_canPage) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final isFirst = _cursor == null && _older.isEmpty;
      final page = isFirst && widget.firstPage.isNotEmpty
          ? await JournalService().fetchOlderThan(
              widget.firstPage.last.createdAt,
              limit: 20,
            )
          : await JournalService().fetchPage(cursor: _cursor, limit: 20);
      if (!mounted) return;
      final seen = {
        ...widget.firstPage.map((e) => e.id),
        ..._older.map((e) => e.id),
      };
      setState(() {
        _older.addAll(page.items.where((e) => !seen.contains(e.id)));
        _cursor = page.nextCursor;
        _exhausted = !page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = e;
      });
    }
  }

  Widget? _headerFor(int idx, List<JournalEntry> entries) {
    final entry = entries[idx];
    if (idx == 0) {
      return entry.isPinned
          ? const _PinnedHeader()
          : _MonthHeader(date: entry.createdAt);
    }
    final prev = entries[idx - 1];
    if (prev.isPinned && entry.isPinned) return null;
    if (prev.isPinned != entry.isPinned) {
      return _MonthHeader(date: entry.createdAt);
    }
    if (prev.createdAt.month != entry.createdAt.month ||
        prev.createdAt.year != entry.createdAt.year) {
      return _MonthHeader(date: entry.createdAt);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = [...widget.firstPage, ..._older];
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: entries.length + (_canPage ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, idx) {
        if (idx >= entries.length) {
          if (_error != null) {
            return EverglowEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Could not load older entries',
              subtitle: 'Try again',
              ctaLabel: 'Retry',
              onCta: _loadMore,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Load older entries'),
                    ),
            ),
          );
        }
        final entry = entries[idx];
        final header = _headerFor(idx, entries);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[header, const SizedBox(height: 10)],
            JournalEntryCard(entry: entry, onTap: () => widget.onTap(entry)),
          ],
        );
      },
    );
  }
}

class _PinnedHeader extends StatelessWidget {
  const _PinnedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blushGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.push_pin_rounded,
                  size: 12,
                  color: AppColors.blushGold,
                ),
                const SizedBox(width: 5),
                Text(
                  'Pinned with love',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.blushGold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blushGold.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime date;
  const _MonthHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.blushGold.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 11,
                  color: AppColors.blushGold.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 7),
                Text(
                  journalMonthLabel(date),
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 18,
                    letterSpacing: 0.8,
                    color: AppColors.blushGold,
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  Icons.auto_awesome,
                  size: 11,
                  color: AppColors.blushGold.withValues(alpha: 0.65),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blushGold.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
