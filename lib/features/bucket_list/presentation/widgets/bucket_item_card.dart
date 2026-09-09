import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';
import '../widgets/bucket_ui.dart';

/// A dream ticket: big tap-to-fulfill ring, category + due + assignee pills.
///
/// Swipe right toggles fulfilled, swipe left deletes (with confirmation).
/// Set [enableSwipe] to false when nested in the horizontally-scrolling
/// board so card gestures never fight column scrolling.
class BucketItemCard extends StatelessWidget {
  final BucketItem item;
  final String currentUsername;
  final bool enableSwipe;
  final Duration entranceDelay;

  const BucketItemCard({
    super.key,
    required this.item,
    required this.currentUsername,
    this.enableSwipe = true,
    this.entranceDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == BucketStatus.completed;

    final card = _DreamEntrance(
      id: item.id,
      delay: entranceDelay,
      child: Semantics(
        label:
            '${item.title}, ${item.category.displayName}, ${bucketStatusLabel(item.status)}',
        button: true,
        child: GestureDetector(
          onTap: () => _showDetail(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.petalWhite.withValues(
                    alpha: isCompleted ? 0.06 : 0.045,
                  ),
                  AppColors.velvet.withValues(alpha: 0.55),
                ],
              ),
              borderRadius: AppRadius.radiusX2,
              border: Border.all(
                color: isCompleted
                    ? AppColors.blushGold.withValues(alpha: 0.45)
                    : AppColors.moonlight.withValues(alpha: 0.10),
              ),
              boxShadow: [
                if (isCompleted)
                  BoxShadow(
                    color: AppColors.blushGold.withValues(alpha: 0.10),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                BoxShadow(
                  color: AppColors.scrimStrong.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority edge (only loud priorities get a stripe).
                Container(
                  width: 4,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.radiusFull,
                    color: isCompleted
                        ? AppColors.blushGold.withValues(alpha: 0.8)
                        : _edgeHue(),
                  ),
                ),
                const SizedBox(width: 10),
                _FulfillRing(
                  completed: isCompleted,
                  title: item.title,
                  onTap: () => _toggleComplete(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 15,
                                height: 1.15,
                                color: isCompleted
                                    ? AppColors.petalWhite.withValues(
                                        alpha: 0.5,
                                      )
                                    : AppColors.petalWhite,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.blushGold.withValues(
                                  alpha: 0.7,
                                ),
                                decorationThickness: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.priority == BucketPriority.urgent &&
                              !isCompleted)
                            const Padding(
                              padding: EdgeInsets.only(right: 6, top: 1),
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                size: 15,
                                color: AppColors.error,
                              ),
                            ),
                          _StatusPill(status: item.status),
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _CategoryPill(category: item.category),
                          if (item.assignedTo != null)
                            _AssigneePill(username: item.assignedTo),
                          if (item.dueDate != null) _DuePill(item: item),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!enableSwipe) {
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: card);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: isCompleted
            ? DismissDirection.endToStart
            : DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.16),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 28,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: const Icon(
            Icons.delete_rounded,
            color: AppColors.error,
            size: 28,
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            return _confirmDelete(context);
          }
          await _toggleComplete();
          return false;
        },
        child: card,
      ),
    );
  }

  /// Loud priorities get a glowing edge; calm ones stay invisible.
  Color _edgeHue() {
    switch (item.priority) {
      case BucketPriority.urgent:
        return AppColors.error.withValues(alpha: 0.85);
      case BucketPriority.high:
        return AppColors.warmAmber.withValues(alpha: 0.8);
      case BucketPriority.low:
      case BucketPriority.medium:
        return AppColors.moonlight.withValues(alpha: 0.10);
    }
  }

  Future<void> _toggleComplete() {
    final service = BucketListService();
    if (item.status == BucketStatus.completed) {
      return service.markUncomplete(item.id);
    }
    return service.markComplete(item.id, currentUsername);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.velvet,
            shape: AppRadius.shapeX2,
            title: Text(
              'Let go of "${item.title}"?',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 16,
                color: AppColors.roseQuartz,
              ),
            ),
            content: Text(
              'This dream will drift away. This cannot be undone.',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                color: AppColors.petalWhite.withValues(alpha: 0.7),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Keep it',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: AppColors.petalWhite.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Let go',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _DreamDetailSheet(item: item, currentUsername: currentUsername),
    );
  }
}

// ── Card pieces ───────────────────────────────────────────────

/// Big thumb-friendly ring: tap to fulfill / reopen a dream.
class _FulfillRing extends StatelessWidget {
  final bool completed;
  final String title;
  final VoidCallback onTap;

  const _FulfillRing({
    required this.completed,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: completed ? 'Reopen $title' : 'Mark $title fulfilled',
      toggled: completed,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.medium),
          curve: AppMotion.easeOutStrong,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: completed
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.blushGold, AppColors.warmAmber],
                  )
                : null,
            color: completed
                ? null
                : AppColors.moonlight.withValues(alpha: 0.05),
            border: Border.all(
              color: completed
                  ? AppColors.blushGold
                  : AppColors.blushGold.withValues(alpha: 0.45),
              width: 2,
            ),
            boxShadow: completed
                ? [
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            completed ? Icons.check_rounded : Icons.auto_awesome_rounded,
            size: completed ? 24 : 18,
            color: completed
                ? AppColors.inkDeep
                : AppColors.blushGold.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final BucketStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final hue = bucketStatusHue(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.14),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: hue.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bucketStatusIcon(status), size: 10, color: hue),
          const SizedBox(width: 4),
          Text(
            bucketStatusLabel(status).toUpperCase(),
            style: AppTypography.outfitBold.copyWith(
              fontSize: 9,
              letterSpacing: 0.7,
              color: hue,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final BucketCategory category;
  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final hue = bucketCategoryHue(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Text(
        '${category.emoji} ${category.displayName}',
        style: AppTypography.outfitWhite.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.petalWhite.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _AssigneePill extends StatelessWidget {
  final String? username;
  const _AssigneePill({required this.username});

  @override
  Widget build(BuildContext context) {
    final hue = bucketAssigneeHue(username);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: hue.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bucketAssigneeIcon(username), size: 10, color: hue),
          const SizedBox(width: 4),
          Text(
            bucketAssigneeLabel(username),
            style: AppTypography.outfitBold.copyWith(fontSize: 10, color: hue),
          ),
        ],
      ),
    );
  }
}

class _DuePill extends StatelessWidget {
  final BucketItem item;
  const _DuePill({required this.item});

  @override
  Widget build(BuildContext context) {
    final due = item.dueDate!;
    final hue = item.isOverdue
        ? AppColors.error
        : item.isDueSoon
        ? AppColors.warmAmber
        : AppColors.petalWhite;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: item.isOverdue
            ? AppColors.error.withValues(alpha: 0.14)
            : item.isDueSoon
            ? AppColors.warmAmber.withValues(alpha: 0.12)
            : AppColors.moonlight.withValues(alpha: 0.07),
        borderRadius: AppRadius.radiusSm,
        border: item.isOverdue
            ? Border.all(color: AppColors.error.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.isOverdue
                ? Icons.warning_rounded
                : Icons.calendar_today_rounded,
            size: 10,
            color: item.isOverdue || item.isDueSoon
                ? hue
                : AppColors.petalWhite.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            item.isOverdue
                ? 'Overdue · ${DateFormat.MMMd().format(due)}'
                : DateFormat.MMMd().format(due),
            style: AppTypography.outfitBold.copyWith(
              fontSize: 10,
              color: item.isOverdue || item.isDueSoon
                  ? hue
                  : AppColors.petalWhite.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entrance ──────────────────────────────────────────────────

/// Gentle rise-and-fade for new cards. Each dream animates once per app
/// session (tracked by id) so scrolling back never replays it.
class _DreamEntrance extends StatefulWidget {
  final String id;
  final Duration delay;
  final Widget child;

  const _DreamEntrance({
    required this.id,
    required this.delay,
    required this.child,
  });

  static final Set<String> _shown = <String>{};

  @override
  State<_DreamEntrance> createState() => _DreamEntranceState();
}

class _DreamEntranceState extends State<_DreamEntrance> {
  late bool _visible;

  @override
  void initState() {
    super.initState();
    _visible = _DreamEntrance._shown.contains(widget.id) || AppMotion.reduced;
    if (!_visible) {
      Future.delayed(widget.delay, () {
        if (!mounted) return;
        _DreamEntrance._shown.add(widget.id);
        if (_DreamEntrance._shown.length > 300) {
          _DreamEntrance._shown.clear();
        }
        setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.12),
      duration: AppMotion.orZero(AppMotion.medium),
      curve: AppMotion.easeOutExpo,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: AppMotion.orZero(AppMotion.medium),
        child: widget.child,
      ),
    );
  }
}

// ── Detail sheet ──────────────────────────────────────────────

/// Full dream story: hero, journey stepper, tap-to-edit meta, actions.
class _DreamDetailSheet extends StatelessWidget {
  final BucketItem item;
  final String currentUsername;

  const _DreamDetailSheet({required this.item, required this.currentUsername});

  @override
  Widget build(BuildContext context) {
    final hue = bucketStatusHue(item.status);
    final categoryHue = bucketCategoryHue(item.category);
    final isCompleted = item.status == BucketStatus.completed;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.velvet,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.x3),
            ),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.2),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.petalWhite.withValues(alpha: 0.3),
                      borderRadius: AppRadius.radiusFull,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            categoryHue.withValues(alpha: 0.30),
                            categoryHue.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: AppRadius.radiusLg,
                        border: Border.all(
                          color: categoryHue.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: categoryHue.withValues(alpha: 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          item.category.emoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: AppTypography.cormorantBold.copyWith(
                              fontSize: 24,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dreamed up by ${item.createdBy} · ${DateFormat.yMMMd().format(item.createdAt)}',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 11,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          if (item.completedAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '💛 Fulfilled by ${item.completedBy ?? 'us'} · ${DateFormat.yMMMd().format(item.completedAt!)}',
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 11,
                                color: AppColors.success.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _SheetIconButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    item.description,
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const _SectionLabel(label: 'Dream journey'),
                const SizedBox(height: 10),
                _JourneyStepper(
                  status: item.status,
                  onMove: (s) => _moveStatus(context, s),
                ),
                const SizedBox(height: 18),
                const _SectionLabel(label: 'Details — tap to change'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetaTile(
                        label: 'Dreamer',
                        value: bucketAssigneeLabel(item.assignedTo),
                        icon: bucketAssigneeIcon(item.assignedTo),
                        hue: bucketAssigneeHue(item.assignedTo),
                        onTap: () => _cycleAssignee(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetaTile(
                        label: 'Dream date',
                        value: item.dueDate == null
                            ? 'Someday'
                            : DateFormat.MMMd().format(item.dueDate!),
                        icon: item.isOverdue
                            ? Icons.warning_rounded
                            : Icons.calendar_today_rounded,
                        hue: item.isOverdue
                            ? AppColors.error
                            : AppColors.blushGold,
                        onTap: () => _pickDueDate(context),
                        onClear: item.dueDate == null
                            ? null
                            : () => _clearDueDate(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetaTile(
                        label: 'Pace',
                        value: bucketPriorityShortLabel(item.priority),
                        icon: Icons.speed_rounded,
                        hue: bucketPriorityHue(item.priority),
                        onTap: () => _cyclePriority(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryAction(
                        label: isCompleted
                            ? 'Reopen dream'
                            : 'Mark fulfilled 💛',
                        icon: isCompleted
                            ? Icons.refresh_rounded
                            : Icons.check_rounded,
                        filled: !isCompleted,
                        onTap: () async {
                          final svc = BucketListService();
                          if (isCompleted) {
                            await svc.markUncomplete(item.id);
                          } else {
                            await svc.markComplete(item.id, currentUsername);
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SheetIconButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete dream',
                      danger: true,
                      onTap: () async {
                        final yes = await _confirmDeleteSheet(context);
                        if (!yes) return;
                        await BucketListService().delete(item.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${item.category.displayName} · ${bucketStatusLabel(item.status)}',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 10,
                      color: hue.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveStatus(BuildContext context, BucketStatus status) async {
    if (status == item.status) return;
    await BucketListService().moveStatus(
      item.id,
      status,
      completedBy: currentUsername.isEmpty ? null : currentUsername,
    );
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _cycleAssignee(BuildContext context) async {
    await BucketListService().assign(
      item.id,
      bucketNextAssignee(item.assignedTo),
    );
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _cyclePriority(BuildContext context) async {
    final values = BucketPriority.values;
    final next = values[(item.priority.index + 1) % values.length];
    await BucketListService().setPriority(item.id, next);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: item.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.deepRose,
            surface: AppColors.velvet,
            onSurface: AppColors.petalWhite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      await BucketListService().setDueDate(
        item.id,
        DateTime(picked.year, picked.month, picked.day),
      );
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _clearDueDate(BuildContext context) async {
    await BucketListService().setDueDate(item.id, null);
    if (context.mounted) Navigator.pop(context);
  }

  Future<bool> _confirmDeleteSheet(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.velvet,
            shape: AppRadius.shapeX2,
            title: Text(
              'Let go of "${item.title}"?',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 16,
                color: AppColors.roseQuartz,
              ),
            ),
            content: Text(
              'This dream will drift away. This cannot be undone.',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                color: AppColors.petalWhite.withValues(alpha: 0.7),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Keep it',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: AppColors.petalWhite.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Let go',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.outfitBold.copyWith(
        fontSize: 10,
        letterSpacing: 1.4,
        color: AppColors.petalWhite.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Wish → Planned → Fulfilled stepper with a connecting trail.
class _JourneyStepper extends StatelessWidget {
  final BucketStatus status;
  final ValueChanged<BucketStatus> onMove;

  const _JourneyStepper({required this.status, required this.onMove});

  @override
  Widget build(BuildContext context) {
    final stages = BucketStatus.values;
    final current = stages.indexOf(status);
    return Row(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.radiusFull,
                  color: i <= current
                      ? AppColors.blushGold.withValues(alpha: 0.6)
                      : AppColors.moonlight.withValues(alpha: 0.12),
                ),
              ),
            ),
          _stage(stages[i], i, current),
        ],
      ],
    );
  }

  Widget _stage(BucketStatus stage, int index, int current) {
    final hue = bucketStatusHue(stage);
    final reached = index <= current;
    final isCurrent = index == current;
    return Semantics(
      button: true,
      label: 'Move to ${bucketStatusLabel(stage)}',
      toggled: isCurrent,
      child: GestureDetector(
        onTap: isCurrent ? null : () => onMove(stage),
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isCurrent
                ? hue.withValues(alpha: 0.18)
                : reached
                ? hue.withValues(alpha: 0.08)
                : AppColors.twilight,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: isCurrent
                  ? hue
                  : hue.withValues(alpha: reached ? 0.4 : 0.15),
              width: isCurrent ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reached ? bucketStatusIcon(stage) : Icons.circle_outlined,
                size: 18,
                color: reached
                    ? hue
                    : AppColors.petalWhite.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 4),
              Text(
                bucketStatusLabel(stage),
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10,
                  color: reached
                      ? hue
                      : AppColors.petalWhite.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable meta tile (dreamer / date / pace). Optional ✕ clears the value.
class _MetaTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color hue;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _MetaTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.hue,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.moonlight.withValues(alpha: 0.06),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: hue),
                  if (onClear != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onClear,
                      child: Semantics(
                        button: true,
                        label: 'Clear $label',
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 13,
                          color: AppColors.petalWhite.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: hue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 10,
                  color: AppColors.petalWhite.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(
                    colors: [AppColors.deepRose, AppColors.rosePressed],
                  )
                : null,
            color: filled ? null : AppColors.moonlight.withValues(alpha: 0.07),
            borderRadius: AppRadius.radiusLg,
            border: filled
                ? Border.all(color: AppColors.blushGold.withValues(alpha: 0.3))
                : Border.all(color: AppColors.blushGold.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? AppColors.petalWhite : AppColors.blushGold,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  color: filled ? AppColors.petalWhite : AppColors.blushGold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _SheetIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final hue = danger ? AppColors.error : AppColors.petalWhite;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusLg,
            color: danger
                ? AppColors.error.withValues(alpha: 0.10)
                : AppColors.moonlight.withValues(alpha: 0.07),
            border: Border.all(
              color: danger
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.moonlight.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(icon, size: 20, color: hue),
        ),
      ),
    );
  }
}
