import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/services/ai_service.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';

/// Sidebar showing Mochi's conversation history, grouped by date.
/// Mobile: backdrop + slide-in drawer. Desktop (≥ 1024): persistent rail.
/// Uses LayoutBuilder + your existing breakpoint so there's never a jump.
class MochiSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onNewChat;
  final VoidCallback? onSearchPlaceholder;

  const MochiSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onNewChat,
    this.onSearchPlaceholder,
  });

  @override
  State<MochiSidebar> createState() => _MochiSidebarState();
}

class _MochiSidebarState extends State<MochiSidebar> {
  List<AISession> _sessions = [];
  bool _isLoading = true;
  String? _activeSessionId;
  String _query = '';
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void didUpdateWidget(MochiSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _loadSessions();
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final ai = context.read<AIService>();
      var sessions = await ai.listSessions(limit: 50);
      final live = ai.assistantConversation;
      if (live != null && live.messages.isNotEmpty) {
        final preview = live.messages.firstWhere(
          (m) => m.role == 'user',
          orElse: () => live.messages.first,
        ).content;
        final title = preview.length > 56 ? '${preview.substring(0, 56)}…' : preview;
        final liveSession = AISession(
          id: '__live__',
          feature: live.feature,
          messageCount: live.messages.length,
          hasSummary: false,
          summary: null,
          createdAt: live.updatedAt,
          title: title.isEmpty ? 'Current conversation' : title,
        );
        final hasLiveDup = sessions.isNotEmpty &&
            sessions.first.messageCount == live.messages.length &&
            sessions.first.title == liveSession.title;
        if (!hasLiveDup) sessions = [liveSession, ...sessions];
        _activeSessionId ??= '__live__';
      }
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _switchSession(AISession session) async {
    if (session.id == '__live__') {
      if (!mounted) return;
      setState(() => _activeSessionId = session.id);
      widget.onClose();
      return;
    }
    final ai = context.read<AIService>();
    await ai.switchSession(session.id);
    if (!mounted) return;
    setState(() => _activeSessionId = session.id);
    widget.onClose();
  }

  Future<void> _deleteSession(AISession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: Text('Delete conversation?',
            style: AppTypography.titleMedium().copyWith(color: AppColors.textHigh)),
        content: Text(
          'This will permanently delete this conversation.',
          style: AppTypography.bodySmall().copyWith(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (session.id == '__live__') {
        final ai = context.read<AIService>();
        await ai.clearConversation('assistant');
      } else {
        final ai = context.read<AIService>();
        await ai.deleteSession(session.id);
      }
      await _loadSessions();
    }
  }

  List<AISession> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sessions;
    return _sessions
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.summary ?? '').toLowerCase().contains(q))
        .toList();
  }

  Map<String, List<AISession>> _groupByDate(List<AISession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final lastMonth = today.subtract(const Duration(days: 30));

    final groups = <String, List<AISession>>{};

    for (final session in sessions) {
      final date = session.createdAt;
      final sessionDate = DateTime(date.year, date.month, date.day);

      String group;
      if (!sessionDate.isBefore(today)) {
        group = 'Today';
      } else if (!sessionDate.isBefore(yesterday)) {
        group = 'Yesterday';
      } else if (!sessionDate.isBefore(lastWeek)) {
        group = 'Last 7 days';
      } else if (!sessionDate.isBefore(lastMonth)) {
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
    // Desktop: persistent rail, always visible. Mobile/tablet: overlay drawer that only
    // renders when open (matches your screenshot's existing behavior).
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    if (isDesktop) {
      return _SidebarPanel(
        searchCtl: _searchCtl,
        query: _query,
        onQueryChanged: (v) => setState(() => _query = v),
        sessions: _filtered,
        isLoading: _isLoading,
        grouped: _groupByDate(_filtered),
        activeId: _activeSessionId,
        onNewChat: widget.onNewChat,
        onClose: widget.onClose,
        onSwitch: _switchSession,
        onDelete: _deleteSession,
        onRefresh: _loadSessions,
        desktop: true,
      );
    }

    if (!widget.isOpen) return const SizedBox.shrink();

    return Stack(children: [
      GestureDetector(
        onTap: widget.onClose,
        child: Container(color: Colors.black.withValues(alpha: 0.5)),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: _SidebarPanel(
          searchCtl: _searchCtl,
          query: _query,
          onQueryChanged: (v) => setState(() => _query = v),
          sessions: _filtered,
          isLoading: _isLoading,
          grouped: _groupByDate(_filtered),
          activeId: _activeSessionId,
          onNewChat: widget.onNewChat,
          onClose: widget.onClose,
          onSwitch: _switchSession,
          onDelete: _deleteSession,
          onRefresh: _loadSessions,
          desktop: false,
        ),
      ),
    ]);
  }
}

class _SidebarPanel extends StatelessWidget {
  final TextEditingController searchCtl;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<AISession> sessions;
  final bool isLoading;
  final Map<String, List<AISession>> grouped;
  final String? activeId;
  final VoidCallback onNewChat;
  final VoidCallback onClose;
  final ValueChanged<AISession> onSwitch;
  final ValueChanged<AISession> onDelete;
  final VoidCallback onRefresh;
  final bool desktop;

  const _SidebarPanel({
    required this.searchCtl,
    required this.query,
    required this.onQueryChanged,
    required this.sessions,
    required this.isLoading,
    required this.grouped,
    required this.activeId,
    required this.onNewChat,
    required this.onClose,
    required this.onSwitch,
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
          _buildHeader(context),
          Divider(height: 1, color: AppColors.blushGold.withValues(alpha: 0.06)),
          _buildSearch(context),
          _buildNewChatButton(),
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
                  icon: Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 18),
                  tooltip: 'Refresh',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
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
                    ? _buildEmpty(query.isNotEmpty)
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: grouped.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Text(
                                  entry.key,
                                  style: AppTypography.bodySmall().copyWith(
                                    color: AppColors.textMuted.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ...entry.value.map((session) => _SessionItem(
                                    session: session,
                                    isActive: session.id == activeId,
                                    onTap: () => onSwitch(session),
                                    onDelete: () => onDelete(session),
                                  )),
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
                'Conversations are private to you two — synced via Firestore.',
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.radiusSm,
            child: Image.asset(
              'assets/images/mochi_avatar.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Mochi',
            style: AppTypography.titleMedium().copyWith(fontSize: 16),
          ),
          const Spacer(),
          if (!desktop)
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            Tooltip(
              message: 'Close',
              child: InkWell(
                onTap: onClose,
                borderRadius: AppRadius.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: searchCtl,
        onChanged: onQueryChanged,
        style: AppTypography.bodySmall().copyWith(color: AppColors.textMedium),
        decoration: InputDecoration(
          hintText: 'Search conversations',
          hintStyle: AppTypography.bodySmall().copyWith(color: AppColors.textDisabled),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchCtl.clear();
                    onQueryChanged('');
                  },
                  icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceGlass,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            borderSide: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.35)),
          ),
        ),
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: GestureDetector(
        onTap: onNewChat,
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
              Icon(Icons.add_rounded, color: AppColors.petalWhite, size: 18),
              const SizedBox(width: 10),
              Text(
                'New conversation',
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.petalWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.edit_rounded, color: AppColors.petalWhite.withValues(alpha: 0.9), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool searching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.textDisabled, size: 28),
            const SizedBox(height: 10),
            Text(
              searching
                  ? 'No matches for “$query”.'
                  : 'No conversations yet.\nStart chatting to see history here.',
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

class _SessionItem extends StatelessWidget {
  final AISession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionItem({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(session.createdAt);
    final isToday = DateTime.now().day == session.createdAt.day &&
        DateTime.now().month == session.createdAt.month &&
        DateTime.now().year == session.createdAt.year;
    final dateStr = isToday ? timeStr : DateFormat('MMM d').format(session.createdAt);

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
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (session.hasSummary)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blushGold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'summary',
                              style: AppTypography.bodySmall().copyWith(
                                color: AppColors.blushGold,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            '$dateStr · ${session.messageCount} messages',
                            style: AppTypography.bodySmall().copyWith(
                              color: AppColors.textDisabled,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onDelete,
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
}
