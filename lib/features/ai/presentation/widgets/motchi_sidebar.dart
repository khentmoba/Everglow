import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/services/ai_service.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';

part 'motchi_sidebar_panel.dart';
part 'motchi_sidebar_tiles.dart';

/// Sidebar showing Motchi's conversation history and feature shortcuts.
/// Mobile/Tablet: backdrop scrim + smooth slide-in drawer with swipe to dismiss.
/// Desktop (≥ 1024): persistent collapsible rail.
class MotchiSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onNewChat;
  final VoidCallback? onSearchPlaceholder;

  const MotchiSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onNewChat,
    this.onSearchPlaceholder,
  });

  @override
  State<MotchiSidebar> createState() => _MotchiSidebarState();
}

class _MotchiSidebarState extends State<MotchiSidebar>
    with SingleTickerProviderStateMixin {
  List<AISession> _archived = [];
  bool _isLoading = true;
  String? _activeSessionId;
  String _query = '';
  final TextEditingController _searchCtl = TextEditingController();
  AIService? _ai;
  StreamSubscription<List<AISession>>? _sessionsSub;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.orZero(const Duration(milliseconds: 250)),
      value: widget.isOpen ? 1.0 : 0.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppMotion.drawer,
            reverseCurve: Curves.easeInCubic,
          ),
        );
  }

  @override
  void didUpdateWidget(MotchiSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ai = context.read<AIService>();
    if (identical(ai, _ai)) return;
    _ai?.removeListener(_onAiChanged);
    _sessionsSub?.cancel();
    _ai = ai;
    ai.addListener(_onAiChanged);
    // Live Firestore stream: archives and deletes push a fresh list on
    // their own, so the sidebar never needs a manual refresh.
    _sessionsSub = ai
        .watchSessions(limit: 50)
        .listen(_onSessionsData, onError: _onSessionsError);
  }

  @override
  void dispose() {
    _controller.dispose();
    _ai?.removeListener(_onAiChanged);
    _sessionsSub?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSessionsData(List<AISession> sessions) {
    if (!mounted) return;
    setState(() {
      _archived = sessions;
      _isLoading = false;
      _reconcileActiveId(_liveSession != null);
    });
  }

  void _onSessionsError(Object _) {
    if (mounted) setState(() => _isLoading = false);
  }

  /// The in-memory conversation isn't archived yet — AIService only calls
  /// notifyListeners, so rebuild the synthetic entry on every change.
  void _onAiChanged() {
    if (!mounted) return;
    setState(() => _reconcileActiveId(_liveSession != null));
  }

  /// Synthetic entry for the conversation being typed in right now.
  AISession? get _liveSession {
    final live = _ai?.assistantConversation;
    if (live == null || live.messages.isEmpty) return null;
    final preview = live.messages
        .firstWhere((m) => m.role == 'user', orElse: () => live.messages.first)
        .content;
    final title = preview.length > 56
        ? '${preview.substring(0, 56)}…'
        : preview;
    return AISession(
      id: '__live__',
      feature: live.feature,
      messageCount: live.messages.length,
      hasSummary: false,
      summary: null,
      createdAt: live.updatedAt,
      title: title.isEmpty ? 'Current conversation' : title,
    );
  }

  /// Archived sessions plus the live entry on top (unless it duplicates
  /// the most recent archived snapshot).
  List<AISession> get _sessions {
    final live = _liveSession;
    if (live == null) return _archived;
    final hasLiveDup = _archived.any(
      (s) => s.messageCount == live.messageCount && s.title == live.title,
    );
    if (hasLiveDup) return _archived;
    return [live, ..._archived];
  }

  void _reconcileActiveId(bool hasLiveMessages) {
    if (!hasLiveMessages && _activeSessionId == '__live__') {
      _activeSessionId = null;
      return;
    }
    if (_activeSessionId == null) {
      if (hasLiveMessages) _activeSessionId = '__live__';
      return;
    }
    if (_activeSessionId != '__live__' &&
        !_archived.any((s) => s.id == _activeSessionId)) {
      _activeSessionId = hasLiveMessages ? '__live__' : null;
    }
  }

  Future<void> _loadSessions() async {
    final ai = _ai ?? context.read<AIService>();
    setState(() => _isLoading = true);
    try {
      final sessions = await ai.listSessions(limit: 50);
      if (mounted) {
        setState(() {
          _archived = sessions;
          _isLoading = false;
          _reconcileActiveId(_liveSession != null);
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
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusX2,
          side: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.16),
                borderRadius: AppRadius.radiusSm,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete conversation?',
                style: AppTypography.titleMedium().copyWith(
                  color: AppColors.textHigh,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete this conversation from your history.',
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.labelMedium().copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.deepRose,
              foregroundColor: AppColors.petalWhite,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (session.id == '__live__') {
        final ai = context.read<AIService>();
        await ai.clearConversation('assistant', archive: false);
        if (mounted) {
          setState(() => _activeSessionId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Conversation deleted',
                style: AppTypography.bodySmall(),
              ),
              backgroundColor: AppColors.velvet,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final ai = context.read<AIService>();
        await ai.deleteSession(session.id);
        if (mounted && _activeSessionId == session.id) {
          setState(() => _activeSessionId = null);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Conversation deleted',
                style: AppTypography.bodySmall(),
              ),
              backgroundColor: AppColors.velvet,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete: $e',
              style: AppTypography.bodySmall(),
            ),
            backgroundColor: AppColors.deepRose.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  List<AISession> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sessions;
    return _sessions
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              (s.summary ?? '').toLowerCase().contains(q),
        )
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!widget.isOpen && _controller.isDismissed) {
          return const SizedBox.shrink();
        }

        final screenWidth = MediaQuery.sizeOf(context).width;
        final double panelWidth = screenWidth < 400
            ? math.max(280.0, screenWidth * 0.82)
            : math.min(340.0, screenWidth * 0.82);

        return PopScope(
          canPop: !widget.isOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              widget.onClose();
            }
          },
          child: Stack(
            children: [
              // Tinted scrim overlay (no heavy blur over big area per web stability policy)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      color: AppColors.inkDeep.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
              // Slide-in drawer with horizontal swipe-to-dismiss
              SlideTransition(
                position: _slideAnimation,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (details.primaryDelta != null &&
                          details.primaryDelta! < 0) {
                        final delta = details.primaryDelta! / panelWidth;
                        _controller.value = (_controller.value + delta).clamp(
                          0.0,
                          1.0,
                        );
                      }
                    },
                    onHorizontalDragEnd: (details) {
                      if (_controller.value < 0.65 ||
                          (details.primaryVelocity ?? 0) < -280) {
                        widget.onClose();
                      } else {
                        _controller.forward();
                      }
                    },
                    child: SizedBox(
                      width: panelWidth,
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
