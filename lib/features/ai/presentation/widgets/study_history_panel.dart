import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/study_history_service.dart';

/// Slide-in history panel for Mochi Study.
///
/// Mobile: backdrop + drawer. Desktop (≥ 1024): persistent rail.
/// Mirrors [MochiSidebar] grouping/search so the two histories feel like one.
class StudyHistoryPanel extends StatefulWidget {
  final bool isOpen;
  final String? activeSessionId;
  final VoidCallback onClose;
  final VoidCallback onNewStudy;
  final ValueChanged<StudySession> onSelect;

  const StudyHistoryPanel({
    super.key,
    required this.isOpen,
    required this.activeSessionId,
    required this.onClose,
    required this.onNewStudy,
    required this.onSelect,
  });

  @override
  State<StudyHistoryPanel> createState() => StudyHistoryPanelState();
}

class StudyHistoryPanelState extends State<StudyHistoryPanel> {
  final StudyHistoryService _history = StudyHistoryService();
  final TextEditingController _searchCtl = TextEditingController();
  List<StudySession> _sessions = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(StudyHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) refresh();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final sessions = await _history.listSessions(limit: 30);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(StudySession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: Text(
          'Delete study session?',
          style: AppTypography.titleMedium().copyWith(
            color: AppColors.textHigh,
          ),
        ),
        content: Text(
          '“${session.title}” will be permanently deleted.',
          style: AppTypography.bodySmall().copyWith(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      await _history.deleteSession(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Study deleted', style: AppTypography.bodySmall()),
          backgroundColor: AppColors.surfaceGlass,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete — try again.',
              style: AppTypography.bodySmall(),
            ),
            backgroundColor: AppColors.deepRose.withValues(alpha: 0.9),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
      await refresh();
    }
  }

  List<StudySession> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sessions;
    return _sessions
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.sourceNames.any((n) => n.toLowerCase().contains(q)),
        )
        .toList();
  }

  Map<String, List<StudySession>> _groupByDate(List<StudySession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final lastMonth = today.subtract(const Duration(days: 30));
    final groups = <String, List<StudySession>>{};
    for (final session in sessions) {
      final d = session.updatedAt;
      final day = DateTime(d.year, d.month, d.day);
      final String group;
      if (!day.isBefore(today)) {
        group = 'Today';
      } else if (!day.isBefore(yesterday)) {
        group = 'Yesterday';
      } else if (!day.isBefore(lastWeek)) {
        group = 'Last 7 days';
      } else if (!day.isBefore(lastMonth)) {
        group = 'Last 30 days';
      } else {
        group = 'Older';
      }
      groups.putIfAbsent(group, () => []).add(session);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    if (isDesktop) {
      return _Panel(
        searchCtl: _searchCtl,
        query: _query,
        onQueryChanged: (v) => setState(() => _query = v),
        sessions: _filtered,
        isLoading: _isLoading,
        isDeleting: _isDeleting,
        grouped: _groupByDate(_filtered),
        activeId: widget.activeSessionId,
        onNewStudy: widget.onNewStudy,
        onClose: widget.onClose,
        onSelect: widget.onSelect,
        onDelete: _delete,
        onRefresh: refresh,
        desktop: true,
      );
    }
    if (!widget.isOpen) return const SizedBox.shrink();
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _Panel(
            searchCtl: _searchCtl,
            query: _query,
            onQueryChanged: (v) => setState(() => _query = v),
            sessions: _filtered,
            isLoading: _isLoading,
            isDeleting: _isDeleting,
            grouped: _groupByDate(_filtered),
            activeId: widget.activeSessionId,
            onNewStudy: widget.onNewStudy,
            onClose: widget.onClose,
            onSelect: widget.onSelect,
            onDelete: _delete,
            onRefresh: refresh,
            desktop: false,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final TextEditingController searchCtl;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<StudySession> sessions;
  final bool isLoading;
  final bool isDeleting;
  final Map<String, List<StudySession>> grouped;
  final String? activeId;
  final VoidCallback onNewStudy;
  final VoidCallback onClose;
  final ValueChanged<StudySession> onSelect;
  final ValueChanged<StudySession> onDelete;
  final VoidCallback onRefresh;
  final bool desktop;

  const _Panel({
    required this.searchCtl,
    required this.query,
    required this.onQueryChanged,
    required this.sessions,
    required this.isLoading,
    required this.isDeleting,
    required this.grouped,
    required this.activeId,
    required this.onNewStudy,
    required this.onClose,
    required this.onSelect,
    required this.onDelete,
    required this.onRefresh,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: desktop ? 320 : 300,
      decoration: BoxDecoration(
        color: AppColors.twilight,
        border: Border(
          right: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.1)),
          left: desktop
              ? BorderSide(color: AppColors.blushGold.withValues(alpha: 0.06))
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          _header(context),
          Divider(
            height: 1,
            color: AppColors.blushGold.withValues(alpha: 0.06),
          ),
          _search(context),
          _newButton(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  'History',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRefresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  tooltip: 'Refresh',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blushGold.withValues(alpha: 0.65),
                    ),
                  )
                : sessions.isEmpty
                ? _empty(query.isNotEmpty)
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              entry.key,
                              style: AppTypography.bodySmall().copyWith(
                                color: AppColors.textMuted.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...entry.value.map(
                            (s) => _Item(
                              session: s,
                              isActive: s.id == activeId,
                              deleting: isDeleting,
                              onTap: () => onSelect(s),
                              onDelete: () => onDelete(s),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          if (desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Text(
                'Study sessions are shared — you both see the same shelf history.',
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.softLavender.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.softLavender.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 15,
              color: AppColors.softLavender,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Study history',
            style: AppTypography.titleMedium().copyWith(fontSize: 16),
          ),
          const Spacer(),
          InkWell(
            onTap: onClose,
            borderRadius: AppRadius.radiusSm,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _search(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: searchCtl,
        onChanged: onQueryChanged,
        style: AppTypography.bodySmall().copyWith(color: AppColors.textMedium),
        decoration: InputDecoration(
          hintText: 'Search studies',
          hintStyle: AppTypography.bodySmall().copyWith(
            color: AppColors.textDisabled,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchCtl.clear();
                    onQueryChanged('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceGlass,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }

  Widget _newButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: GestureDetector(
        onTap: onNewStudy,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.blushGold, AppColors.deepRose],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.add_rounded,
                color: AppColors.petalWhite,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'New study',
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.petalWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.edit_rounded,
                color: AppColors.petalWhite.withValues(alpha: 0.9),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(bool searching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: AppColors.textDisabled,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              searching
                  ? 'No matches for “$query”.'
                  : 'No study sessions yet.\nAsk Mochi about a PDF to start one.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final StudySession session;
  final bool isActive;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _Item({
    required this.session,
    required this.isActive,
    required this.deleting,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = _dateLabel(session.updatedAt);
    final sourcesPreview = session.sourceNames.isEmpty
        ? 'No sources'
        : session.sourceNames.length == 1
        ? session.sourceNames.first
        : '${session.sourceNames.first} +${session.sourceNames.length - 1}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.blushGold.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: AppRadius.radiusLg,
              border: isActive
                  ? Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.30),
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: AppTypography.bodySmall().copyWith(
                          color: isActive
                              ? AppColors.textHigh
                              : AppColors.textMedium,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sourcesPreview,
                        style: AppTypography.bodySmall().copyWith(
                          color: AppColors.softLavender.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr · ${session.messageCount} messages',
                        style: AppTypography.bodySmall().copyWith(
                          color: AppColors.textDisabled,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: deleting ? null : onDelete,
                  borderRadius: AppRadius.radiusSm,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textDisabled,
                      size: 16,
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

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        now.day == date.day && now.month == date.month && now.year == date.year;
    if (isToday) return DateFormat('h:mm a').format(date);
    return DateFormat('MMM d').format(date);
  }
}
