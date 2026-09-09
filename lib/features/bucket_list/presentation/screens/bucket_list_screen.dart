import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import '../widgets/add_bucket_item_sheet.dart';
import '../widgets/bucket_item_card.dart';
import '../widgets/bucket_kanban_board.dart';
import '../widgets/bucket_ui.dart';

/// Our Bucket List — "Starlit Journey".
///
/// A night-sky hero shows how far Khent + Clair have wandered, its stat
/// segments double as the status filter, and one calm row holds the rest
/// of the filters. One stream feeds hero + content so both always agree.
class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

enum _ViewMode { list, board }

/// Max content width — phones go full-bleed, tablets stay centered + calm.
const double _kMaxContentWidth = 720;

class _BucketListScreenState extends State<BucketListScreen> {
  BucketStatus? _filter; // null = all
  _ViewMode _viewMode = _ViewMode.list;
  String? _assigneeFilter; // null=all, 'unassigned', or username
  BucketPriority? _priorityFilter;
  bool _overdueOnly = false;

  /// Client-side filters (avoids extra composite indexes).
  List<BucketItem> _filteredItems(List<BucketItem> all) {
    // Copy first: the list view sorts the result in place — sorting the
    // stream snapshot itself would mutate shared data (and throw if the
    // source is ever unmodifiable).
    var items = List<BucketItem>.of(all);
    if (_filter != null) {
      items = items.where((i) => i.status == _filter).toList();
    }
    if (_assigneeFilter != null) {
      if (_assigneeFilter == 'unassigned') {
        items = items.where((i) => i.assignedTo == null).toList();
      } else {
        items = items.where((i) => i.assignedTo == _assigneeFilter).toList();
      }
    }
    if (_priorityFilter != null) {
      items = items.where((i) => i.priority == _priorityFilter).toList();
    }
    if (_overdueOnly) {
      items = items.where((i) => i.isOverdue).toList();
    }
    return items;
  }

  bool get _hasSecondaryFilters =>
      _assigneeFilter != null || _priorityFilter != null || _overdueOnly;

  bool get _hasAnyFilter => _filter != null || _hasSecondaryFilters;

  void _clearAllFilters() => setState(() {
    _filter = null;
    _assigneeFilter = null;
    _priorityFilter = null;
    _overdueOnly = false;
  });

  @override
  Widget build(BuildContext context) {
    final service = BucketListService();
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser ?? '';

    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      body: Column(
        children: [
          EverglowFeatureHeader(
            title: 'Our Bucket List',
            subtitle: 'dreams we chase together',
            icon: Icons.auto_awesome_rounded,
            hue: AppColors.blushGold,
            actions: [
              _ViewToggle(
                viewMode: _viewMode,
                onTap: () => setState(
                  () => _viewMode = _viewMode == _ViewMode.list
                      ? _ViewMode.board
                      : _ViewMode.list,
                ),
              ),
            ],
          ),
          Expanded(
            child: EverglowStreamView<List<BucketItem>>(
              stream: service.watchAll(),
              streamLabel: 'bucket-list',
              errorMessage: 'Could not load bucket list',
              onRetry: () => setState(() {}),
              loadingView: const _LoadingDreams(),
              // Empty states are handled inside the builder so the journey
              // hero stays visible even with zero (or zero matching) dreams.
              isEmpty: (_) => false,
              builder: (context, all) {
                final items = _filteredItems(all);
                // List mode: priority first, then soonest due, then newest.
                items.sort((a, b) {
                  final pr = b.priority.rank.compareTo(a.priority.rank);
                  if (pr != 0) return pr;
                  if (a.dueDate != null && b.dueDate != null) {
                    return a.dueDate!.compareTo(b.dueDate!);
                  }
                  if (a.dueDate != null) return -1;
                  if (b.dueDate != null) return 1;
                  return b.createdAt.compareTo(a.createdAt);
                });

                return Column(
                  children: [
                    _Constrained(
                      child: _JourneyHero(
                        all: all,
                        selected: _filter,
                        overdueOnly: _overdueOnly,
                        onSelect: (s) =>
                            setState(() => _filter = _filter == s ? null : s),
                        onOverdueTap: () =>
                            setState(() => _overdueOnly = !_overdueOnly),
                      ),
                    ),
                    _Constrained(
                      child: _FilterRow(
                        assigneeFilter: _assigneeFilter,
                        priorityFilter: _priorityFilter,
                        overdueOnly: _overdueOnly,
                        onAssignee: (v) => setState(() => _assigneeFilter = v),
                        onPriority: (v) => setState(() => _priorityFilter = v),
                        onOverdue: () =>
                            setState(() => _overdueOnly = !_overdueOnly),
                        onClearSecondary: () => setState(() {
                          _assigneeFilter = null;
                          _priorityFilter = null;
                          _overdueOnly = false;
                        }),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(child: _buildContent(all, items, currentUser)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _NewDreamFab(
        onTap: () => _showAddSheet(context, auth),
      ),
    );
  }

  Widget _buildContent(
    List<BucketItem> all,
    List<BucketItem> items,
    String currentUser,
  ) {
    if (all.isEmpty) {
      return EverglowEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'No dreams yet',
        subtitle: 'Plant your first star together',
        ctaLabel: 'Plant a dream',
        onCta: () => _showAddSheet(context, context.read<AuthService>()),
      );
    }
    if (items.isEmpty) {
      return EverglowEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching dreams',
        subtitle: 'Try a different filter',
        ctaLabel: _hasAnyFilter ? 'Clear filters' : null,
        onCta: _hasAnyFilter ? _clearAllFilters : null,
      );
    }
    if (_viewMode == _ViewMode.board) {
      return BucketKanbanBoard(
        items: items,
        currentUsername: currentUser,
        onAdd: () => _showAddSheet(context, context.read<AuthService>()),
      );
    }
    return _Constrained(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length,
        itemBuilder: (context, index) => BucketItemCard(
          item: items[index],
          currentUsername: currentUser,
          entranceDelay: Duration(milliseconds: (index.clamp(0, 8)) * 45),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          AddBucketItemSheet(createdBy: auth.currentUser ?? 'unknown'),
    );
  }
}

/// Centers [child] and caps its width on tablets / desktop.
class _Constrained extends StatelessWidget {
  final Widget child;
  const _Constrained({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
        child: child,
      ),
    );
  }
}

/// List ⇄ Board toggle pill in the header.
class _ViewToggle extends StatelessWidget {
  final _ViewMode viewMode;
  final VoidCallback onTap;

  const _ViewToggle({required this.viewMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isList = viewMode == _ViewMode.list;
    return Semantics(
      button: true,
      label: isList ? 'Show board view' : 'Show list view',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.moonlight.withValues(alpha: 0.08),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isList ? Icons.view_kanban_rounded : Icons.view_list_rounded,
                size: 14,
                color: AppColors.blushGold,
              ),
              const SizedBox(width: 6),
              Text(
                isList ? 'Board' : 'List',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.blushGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Journey hero ──────────────────────────────────────────────

/// Night-sky panel: headline, golden dream-trail, and tappable stat
/// segments that double as the status filter.
class _JourneyHero extends StatelessWidget {
  final List<BucketItem> all;
  final BucketStatus? selected;
  final bool overdueOnly;
  final ValueChanged<BucketStatus?> onSelect;
  final VoidCallback onOverdueTap;

  const _JourneyHero({
    required this.all,
    required this.selected,
    required this.overdueOnly,
    required this.onSelect,
    required this.onOverdueTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = all.length;
    final completed = all.where((i) => i.status == BucketStatus.completed);
    final wishes = all.where((i) => i.status == BucketStatus.wish);
    final planned = all.where((i) => i.status == BucketStatus.planned);
    final overdue = all.where((i) => i.isOverdue).length;
    final progress = total > 0 ? completed.length / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusX2,
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.scrimStrong.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.blushGold.withValues(alpha: 0.07),
              blurRadius: 28,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.radiusX2,
          child: Stack(
            children: [
              // Night gradient + warm horizon glow.
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.silk,
                      AppColors.velvet,
                      AppColors.inkDeep,
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.85, -0.7),
                      radius: 1.1,
                      colors: [
                        AppColors.auroraGold.withValues(alpha: 0.16),
                        AppColors.auroraGold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: CustomPaint(painter: BucketStarsPainter()),
              ),
              // Top candle-line.
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(
                  height: 1.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨  OUR JOURNEY SO FAR',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: AppColors.blushGold.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _headline(total, completed.length, progress),
                      style: AppTypography.cormorantBold.copyWith(
                        fontSize: 24,
                        height: 1.05,
                        color: AppColors.petalWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            total == 0
                                ? 'Your story is waiting for its first dream'
                                : '${completed.length} of $total dreams fulfilled · ${(progress * 100).round()}%',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.62,
                              ),
                            ),
                          ),
                        ),
                        if (overdue > 0)
                          _OverdueNudge(
                            count: overdue,
                            active: overdueOnly,
                            onTap: onOverdueTap,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _TrailBar(progress: progress),
                    const SizedBox(height: 14),
                    _StatusSegments(
                      total: total,
                      wishes: wishes.length,
                      planned: planned.length,
                      completed: completed.length,
                      selected: selected,
                      onSelect: onSelect,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _headline(int total, int done, double progress) {
    if (total == 0) return 'Every love story needs a first dream';
    if (progress >= 1) return 'Every dream came true — dream more!';
    if (progress >= 0.66) return 'Look how far we\u2019ve wandered';
    if (progress >= 0.33) return 'Our story is unfolding';
    if (done > 0) return 'Dreams are coming true';
    return 'So many stars left to chase';
  }
}

/// Golden progress trail with a star riding its tip.
class _TrailBar extends StatelessWidget {
  final double progress;
  const _TrailBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final p = progress.clamp(0.0, 1.0);
        final maxW = constraints.maxWidth;
        final fillW = maxW * p;
        return SizedBox(
          height: 22,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.10),
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
              if (p > 0)
                AnimatedContainer(
                  duration: AppMotion.orZero(AppMotion.medium),
                  curve: AppMotion.easeOutStrong,
                  height: 8,
                  width: fillW,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.deepRose, AppColors.auroraGold],
                    ),
                    borderRadius: AppRadius.radiusFull,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.auroraGold.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: (fillW - 11).clamp(0.0, maxW - 22),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.inkDeep,
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.7),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: AppColors.blushGold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "N need attention" pill — appears only when dreams are overdue.
class _OverdueNudge extends StatelessWidget {
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _OverdueNudge({
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Show overdue dreams',
      toggled: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? AppColors.error.withValues(alpha: 0.22)
                : AppColors.error.withValues(alpha: 0.10),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: AppColors.error.withValues(alpha: active ? 0.8 : 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_rounded,
                size: 11,
                color: AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                '$count need${count == 1 ? 's' : ''} love',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four tappable stat segments: All / Wishes / Planned / Done.
class _StatusSegments extends StatelessWidget {
  final int total;
  final int wishes;
  final int planned;
  final int completed;
  final BucketStatus? selected;
  final ValueChanged<BucketStatus?> onSelect;

  const _StatusSegments({
    required this.total,
    required this.wishes,
    required this.planned,
    required this.completed,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.45),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          _segment(
            context,
            emoji: '✨',
            label: 'All',
            count: total,
            hue: AppColors.roseQuartz,
            status: null,
          ),
          _segment(
            context,
            emoji: BucketStatus.wish.emoji,
            label: 'Wishes',
            count: wishes,
            hue: bucketStatusHue(BucketStatus.wish),
            status: BucketStatus.wish,
          ),
          _segment(
            context,
            emoji: BucketStatus.planned.emoji,
            label: 'Planned',
            count: planned,
            hue: bucketStatusHue(BucketStatus.planned),
            status: BucketStatus.planned,
          ),
          _segment(
            context,
            emoji: BucketStatus.completed.emoji,
            label: 'Done',
            count: completed,
            hue: bucketStatusHue(BucketStatus.completed),
            status: BucketStatus.completed,
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String emoji,
    required String label,
    required int count,
    required Color hue,
    required BucketStatus? status,
  }) {
    final isSelected = selected == status;
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Filter by $label',
        toggled: isSelected,
        child: GestureDetector(
          // Tapping the active segment clears back to All.
          onTap: () => onSelect(isSelected ? null : status),
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? hue.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: isSelected
                    ? hue.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.4,
                    color: isSelected
                        ? hue
                        : AppColors.petalWhite.withValues(alpha: 0.55),
                  ),
                ),
                Text(
                  '$count',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: isSelected
                        ? hue
                        : AppColors.petalWhite.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────

/// One calm scrollable row: who → priority → overdue.
class _FilterRow extends StatelessWidget {
  final String? assigneeFilter;
  final BucketPriority? priorityFilter;
  final bool overdueOnly;
  final ValueChanged<String?> onAssignee;
  final ValueChanged<BucketPriority?> onPriority;
  final VoidCallback onOverdue;
  final VoidCallback onClearSecondary;

  const _FilterRow({
    required this.assigneeFilter,
    required this.priorityFilter,
    required this.overdueOnly,
    required this.onAssignee,
    required this.onPriority,
    required this.onOverdue,
    required this.onClearSecondary,
  });

  bool get _hasSecondary =>
      assigneeFilter != null || priorityFilter != null || overdueOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (_hasSecondary) ...[
              _ClearPill(onTap: onClearSecondary),
              const SizedBox(width: 8),
            ],
            _FilterPill(
              label: 'Everyone',
              icon: Icons.groups_rounded,
              hue: AppColors.roseQuartz,
              selected: assigneeFilter == null,
              onTap: () => onAssignee(null),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'Khent',
              icon: Icons.person_rounded,
              hue: AppColors.auroraTeal,
              selected: assigneeFilter == bucketAssigneeKhent,
              onTap: () => onAssignee(bucketAssigneeKhent),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'Clair',
              icon: Icons.favorite_rounded,
              hue: AppColors.auroraRose,
              selected: assigneeFilter == bucketAssigneeClair,
              onTap: () => onAssignee(bucketAssigneeClair),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'Unassigned',
              icon: Icons.person_outline_rounded,
              hue: AppColors.mutedPurple,
              selected: assigneeFilter == 'unassigned',
              onTap: () => onAssignee('unassigned'),
            ),
            _rowDivider(),
            _FilterPill(
              label: 'Any pace',
              icon: Icons.speed_rounded,
              hue: AppColors.roseQuartz,
              selected: priorityFilter == null,
              onTap: () => onPriority(null),
            ),
            const SizedBox(width: 8),
            ...BucketPriority.values.map(
              (p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterPill(
                  label: bucketPriorityShortLabel(p),
                  dot: bucketPriorityHue(p),
                  hue: bucketPriorityHue(p),
                  selected: priorityFilter == p,
                  onTap: () => onPriority(p),
                ),
              ),
            ),
            _rowDivider(),
            _FilterPill(
              label: 'Overdue',
              icon: Icons.warning_rounded,
              hue: AppColors.error,
              selected: overdueOnly,
              onTap: onOverdue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.blushGold.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? dot;
  final Color hue;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.hue,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      toggled: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? hue.withValues(alpha: 0.16)
                : AppColors.moonlight.withValues(alpha: 0.05),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: selected
                  ? hue.withValues(alpha: 0.6)
                  : AppColors.moonlight.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
                ),
                const SizedBox(width: 6),
              ],
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 12,
                  color: selected
                      ? hue
                      : AppColors.petalWhite.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: selected
                      ? hue
                      : AppColors.petalWhite.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearPill extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Clear filters',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.blushGold.withValues(alpha: 0.12),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.close_rounded,
                size: 12,
                color: AppColors.blushGold,
              ),
              const SizedBox(width: 4),
              Text(
                'Clear',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.blushGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FAB + loading ─────────────────────────────────────────────

/// Extended gradient "New dream" button.
class _NewDreamFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NewDreamFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Plant a new dream',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepRose, AppColors.rosePressed],
            ),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.glowRose,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.petalWhite,
              ),
              const SizedBox(width: 6),
              Text(
                'New dream',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 14,
                  color: AppColors.petalWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading shimmer shaped like the hero + cards.
class _LoadingDreams extends StatelessWidget {
  const _LoadingDreams();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: const [
        EverglowSkeleton(width: double.infinity, height: 250, radius: 24),
        SizedBox(height: 12),
        EverglowSkeleton(width: double.infinity, height: 92, radius: 20),
        SizedBox(height: 10),
        EverglowSkeleton(width: double.infinity, height: 92, radius: 20),
        SizedBox(height: 10),
        EverglowSkeleton(width: double.infinity, height: 92, radius: 20),
      ],
    );
  }
}
