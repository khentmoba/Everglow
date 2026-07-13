import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/services/ai_service.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';

/// Sidebar showing Mochi's conversation history, grouped by date.
class MochiSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onNewChat;

  const MochiSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onNewChat,
  });

  @override
  State<MochiSidebar> createState() => _MochiSidebarState();
}

class _MochiSidebarState extends State<MochiSidebar> {
  List<AISession> _sessions = [];
  bool _isLoading = true;
  String? _activeSessionId;

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

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final ai = context.read<AIService>();
      final sessions = await ai.listSessions(limit: 50);
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

    if (confirmed == true) {
      final ai = context.read<AIService>();
      await ai.deleteSession(session.id);
      await _loadSessions();
    }
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
    if (!widget.isOpen) return const SizedBox.shrink();

    final grouped = _groupByDate(_sessions);

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: GestureDetector(
          onTap: () {}, // Prevent close when tapping sidebar
          child: Container(
            width: 280,
            decoration: BoxDecoration(
              color: AppColors.twilight,
              border: Border(
                right: BorderSide(
                  color: AppColors.blushGold.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                // Header
                _buildHeader(),
                Divider(height: 1, color: AppColors.blushGold.withValues(alpha: 0.06)),

                // New chat button
                _buildNewChatButton(),

                // Session list
                Expanded(
                  child: _isLoading
                      ? _buildLoading()
                      : _sessions.isEmpty
                          ? _buildEmpty()
                          : _buildSessionList(grouped),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: widget.onNewChat,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.add_rounded, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 10),
              Text(
                'New conversation',
                style: AppTypography.bodySmall().copyWith(color: AppColors.textMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.blushGold.withValues(alpha: 0.65),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No conversations yet.\nStart chatting to see history here.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionList(Map<String, List<AISession>> grouped) {
    return ListView(
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
              isActive: session.id == _activeSessionId,
              onTap: () => _switchSession(session),
              onDelete: () => _deleteSession(session),
            )),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusLg,
              border: isActive
                  ? Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.65),
                      width: 1,
                    )
                  : null,
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
                              isActive ? FontWeight.w500 : FontWeight.normal,
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
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.textDisabled,
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
