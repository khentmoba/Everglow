import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_chip.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import '../widgets/bucket_item_card.dart';
import '../widgets/add_bucket_item_dialog.dart';
import '../widgets/bucket_kanban_board.dart';
import '../../../../core/theme/app_typography.dart';

class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

enum _ViewMode { list, board }

class _BucketListScreenState extends State<BucketListScreen> {
  BucketStatus? _filter; // null = all
  _ViewMode _viewMode = _ViewMode.list;
  String? _assigneeFilter; // null=all, 'unassigned', or username
  BucketPriority? _priorityFilter;
  bool _overdueOnly = false;

  /// Client-side filters (avoids extra composite indexes). Sorting stays
  /// with the list view — the board orders its own columns.
  List<BucketItem> _filteredItems(List<BucketItem> all) {
    var items = all;
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

  @override
  Widget build(BuildContext context) {
    final service = BucketListService();
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser ?? '';

        return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      body: Column(
              children: [
                // Header
                EverglowFeatureHeader(
                  title: 'Our Bucket List',
                  subtitle: 'dreams we chase together',
                  icon: Icons.card_travel_rounded,
                  hue: AppColors.auroraTeal,
                  actions: [
                    GestureDetector(
                      onTap: () => setState(
                        () => _viewMode = _viewMode == _ViewMode.list
                            ? _ViewMode.board
                            : _ViewMode.list,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.moonlight.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.14)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _viewMode == _ViewMode.list ? Icons.view_kanban_rounded : Icons.view_list_rounded,
                              size: 14,
                              color: AppColors.blushGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _viewMode == _ViewMode.list ? 'Board' : 'List',
                              style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.blushGold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress bar
                _buildProgressHeader(service),
                const SizedBox(height: 12),

                // Status filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(null, 'All'),
                        const SizedBox(width: 8),
                        _buildFilterChip(BucketStatus.wish, 'Wishes'),
                        const SizedBox(width: 8),
                        _buildFilterChip(BucketStatus.planned, 'Planned'),
                        const SizedBox(width: 8),
                        _buildFilterChip(BucketStatus.completed, 'Done'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Assignee + priority + overdue row (Donetick/Vikunja)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAssigneeChip(null, 'All'),
                        const SizedBox(width: 8),
                        _buildAssigneeChip('khentsgdz', 'Khent'),
                        const SizedBox(width: 8),
                        _buildAssigneeChip('clairjassen', 'Clair'),
                        const SizedBox(width: 8),
                        _buildAssigneeChip('unassigned', 'Unassigned'),
                        const SizedBox(width: 12),
                        Container(
                          width: 1,
                          height: 18,
                          color: AppTheme.blushGold.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 12),
                        _buildPriorityFilterChip(null, 'Any prio'),
                        const SizedBox(width: 8),
                        ...BucketPriority.values.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildPriorityFilterChip(
                              p,
                              '${p.emoji} ${p.displayName}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _overdueOnly = !_overdueOnly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _overdueOnly
                                  ? AppColors.error.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _overdueOnly
                                    ? AppColors.error
                                    : AppTheme.blushGold.withValues(
                                        alpha: 0.15,
                                      ),
                              ),
                            ),
                            child: Text(
                              '⚠️ Overdue',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                fontWeight: _overdueOnly
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _overdueOnly
                                    ? AppColors.error
                                    : AppTheme.petalWhite.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // List / Board
                Expanded(
                  child: EverglowStreamView<List<BucketItem>>(
                    stream: service.watchAll(),
                    streamLabel: 'bucket-list',
                    errorMessage: 'Could not load bucket list',
                    onRetry: () => setState(() {}),
                    loadingView: const EverglowSkeleton(
                      width: double.infinity,
                      height: 80,
                      radius: 16,
                    ),
                    isEmpty: (all) => _filteredItems(all).isEmpty,
                    emptyView: Builder(
                      builder: (context) {
                        final isFiltered =
                            _filter != null ||
                            _assigneeFilter != null ||
                            _priorityFilter != null ||
                            _overdueOnly;
                        return EverglowEmptyState(
                          icon: Icons.auto_awesome,
                          title: isFiltered
                              ? 'No matching dreams'
                              : 'Your bucket list is empty',
                          subtitle: isFiltered
                              ? 'Try adjusting filters'
                              : 'Add your first dream together!',
                          ctaLabel: isFiltered ? null : 'Add Dream',
                          onCta: isFiltered
                              ? null
                              : () => _showAddDialog(context, auth),
                        );
                      },
                    ),
                    builder: (context, all) {
                      final items = _filteredItems(all);
                      if (_viewMode == _ViewMode.board) {
                        return BucketKanbanBoard(
                          items: items,
                          currentUsername: currentUser,
                        );
                      }

                      // List mode: sort by priority desc then dueDate asc then createdAt desc
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

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return BucketItemCard(
                            item: items[index],
                            currentUsername: currentUser,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, auth),
        backgroundColor: AppTheme.deepRose,
        foregroundColor: AppTheme.petalWhite,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildProgressHeader(BucketListService service) {
    return StreamBuilder<List<BucketItem>>(
      stream: service.watchAll(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final completed = all
            .where((i) => i.status == BucketStatus.completed)
            .length;
        final total = all.length;
        final progress = total > 0 ? completed / total : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.moonlight.withValues(
                alpha: AppTheme.glassOpacity,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.blushGold.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: AppTheme.petalWhite.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.blushGold,
                        ),
                      ),
                      Text(
                        '$completed',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blushGold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completed of $total dreams fulfilled ✨',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 14,
                          color: AppTheme.petalWhite,
                        ),
                      ),
                      if (total > 0)
                        Text(
                          '${(progress * 100).round()}% complete',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppTheme.petalWhite.withValues(alpha: 0.6),
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

  Widget _buildFilterChip(BucketStatus? status, String label) {
    final isSelected = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Semantics(
        button: true,
        label: 'Filter by $label',
        toggled: isSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.deepRose.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.blushGold
                  : AppTheme.blushGold.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppTheme.blushGold
                  : AppTheme.petalWhite.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeChip(String? value, String label) {
    final isSelected = _assigneeFilter == value;
    return EverglowChip(label: label, selected: isSelected, onTap: () => setState(() => _assigneeFilter = value));
  }

  Widget _buildPriorityFilterChip(BucketPriority? prio, String label) {
    final isSelected = _priorityFilter == prio;
    return EverglowChip(label: label, selected: isSelected, onTap: () => setState(() => _priorityFilter = prio));
  }

  void _showAddDialog(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (context) =>
          AddBucketItemDialog(createdBy: auth.currentUser ?? 'unknown'),
    );
  }
}
