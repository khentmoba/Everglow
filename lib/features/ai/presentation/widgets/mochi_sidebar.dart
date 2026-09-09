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

/// Sidebar showing Mochi's conversation history and feature shortcuts.
/// Mobile/Tablet: backdrop scrim + smooth slide-in drawer with swipe to dismiss.
/// Desktop (≥ 1024): persistent collapsible rail.
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

class _MochiSidebarState extends State<MochiSidebar>
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
  void didUpdateWidget(MochiSidebar oldWidget) {
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
    final topPad = desktop ? 0.0 : MediaQuery.paddingOf(context).top;
    final bottomPad = desktop ? 0.0 : MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.twilight,
        border: Border(
          right: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.12),
            width: 1,
          ),
          left: desktop
              ? BorderSide(
                  color: AppColors.blushGold.withValues(alpha: 0.06),
                  width: 1,
                )
              : BorderSide.none,
        ),
        boxShadow: desktop
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, topPad),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.blushGold.withValues(alpha: 0.07),
          ),
          _buildNewChatButton(),
          _buildMochiHub(context),
          _buildSearch(context),
          _buildHistoryHeader(),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blushGold.withValues(alpha: 0.75),
                    ),
                  )
                : sessions.isEmpty
                ? _buildEmpty(query.isNotEmpty)
                : _buildSessionList(),
          ),
          _buildFooter(bottomPad),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double topPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12 + topPad, 12, 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    'assets/images/mochi_avatar.png',
                    width: 36,
                    height: 36,
                    cacheWidth: kIsWeb ? null : 108,
                    cacheHeight: kIsWeb ? null : 108,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.twilight, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mochi',
                      style: AppTypography.titleMedium().copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHigh,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blushGold.withValues(alpha: 0.14),
                        borderRadius: AppRadius.radiusFull,
                      ),
                      child: Text(
                        '🐾 CAT',
                        style: AppTypography.labelSmall().copyWith(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.blushGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Chat & Memories',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Close sidebar',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClose,
                borderRadius: AppRadius.radiusSm,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: AppRadius.radiusSm,
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMedium,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onNewChat,
          borderRadius: AppRadius.radiusLg,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blushGold, AppColors.deepRose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.radiusLg,
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.add_rounded,
                  color: AppColors.petalWhite,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New conversation',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.petalWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.petalWhite.withValues(alpha: 0.85),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMochiHub(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: _HubTile(
              icon: Icons.wb_twilight_rounded,
              label: 'Today',
              accent: AppColors.auroraGold,
              onTap: () {
                if (!desktop) onClose();
                context.push('/mochi-today');
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _HubTile(
              icon: Icons.menu_book_rounded,
              label: 'Memories',
              accent: AppColors.roseQuartz,
              onTap: () {
                if (!desktop) onClose();
                context.push('/mochi-memory');
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _HubTile(
              icon: Icons.psychology_rounded,
              label: 'Trivia',
              accent: AppColors.auroraLilac,
              onTap: () {
                if (!desktop) onClose();
                context.push('/mochi-trivia');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: TextField(
        controller: searchCtl,
        onChanged: onQueryChanged,
        style: AppTypography.bodySmall().copyWith(color: AppColors.textHigh),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: AppTypography.bodySmall().copyWith(
            color: AppColors.textDisabled,
            fontSize: 12.5,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 17,
            color: query.isNotEmpty ? AppColors.blushGold : AppColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchCtl.clear();
                    onQueryChanged('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceGlass,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8.5,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.12),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
      child: Row(
        children: [
          Text(
            'History',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.textMuted.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: AppRadius.radiusFull,
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              '${sessions.length}',
              style: AppTypography.labelSmall().copyWith(
                color: AppColors.blushGold,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              'filtered',
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textDisabled,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.textMuted,
              size: 17,
            ),
            tooltip: 'Refresh conversations',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.textMuted.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${entry.value.length}',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map(
              (session) => _SessionItem(
                session: session,
                isActive: session.id == activeId,
                onTap: () => onSwitch(session),
                onDelete: () => onDelete(session),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEmpty(bool searching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.pets_rounded,
              color: AppColors.blushGold.withValues(alpha: 0.45),
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              searching
                  ? 'No matches for “$query”.'
                  : 'No conversations yet.\nStart chatting to see history here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textMuted,
                height: 1.4,
                fontSize: 12,
              ),
            ),
            if (searching) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  searchCtl.clear();
                  onQueryChanged('');
                },
                icon: const Icon(Icons.clear_rounded, size: 14),
                label: const Text('Clear search'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.blushGold,
                  textStyle: AppTypography.labelSmall(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + bottomPad),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 12,
            color: AppColors.textDisabled,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Private to Khent & Clair',
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textDisabled,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.cloud_done_rounded,
            size: 12,
            color: AppColors.success.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 4),
          Text(
            'Synced',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.textDisabled,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
              width: 0.9,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTypography.labelSmall().copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
    final isLive = session.id == '__live__';
    final timeStr = DateFormat('h:mm a').format(session.createdAt);
    final now = DateTime.now();
    final isToday =
        now.day == session.createdAt.day &&
        now.month == session.createdAt.month &&
        now.year == session.createdAt.year;
    final dateStr = isLive
        ? 'Active now'
        : (isToday ? timeStr : DateFormat('MMM d').format(session.createdAt));

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.blushGold.withValues(alpha: 0.13)
                  : (isLive ? AppColors.surfaceGlass : Colors.transparent),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: isActive
                    ? AppColors.blushGold.withValues(alpha: 0.35)
                    : (isLive
                          ? AppColors.blushGold.withValues(alpha: 0.18)
                          : Colors.transparent),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive)
                  Container(
                    width: 3,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6, top: 2),
                    decoration: BoxDecoration(
                      color: AppColors.blushGold,
                      borderRadius: AppRadius.radiusFull,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blushGold.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.blushGold.withValues(alpha: 0.16)
                        : (isActive
                              ? AppColors.blushGold.withValues(alpha: 0.12)
                              : AppColors.surfaceGlass),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLive
                        ? Icons.auto_awesome_rounded
                        : (session.hasSummary
                              ? Icons.summarize_rounded
                              : Icons.chat_bubble_outline_rounded),
                    size: 14,
                    color: isLive
                        ? AppColors.blushGold
                        : (isActive
                              ? AppColors.blushGold
                              : AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              style: AppTypography.bodySmall().copyWith(
                                color: isActive
                                    ? AppColors.textHigh
                                    : AppColors.textMedium,
                                fontWeight: isActive || isLive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: AppRadius.radiusFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'LIVE',
                                    style: AppTypography.labelSmall().copyWith(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (session.summary != null &&
                          session.summary!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          session.summary!.trim(),
                          style: AppTypography.bodySmall().copyWith(
                            color: AppColors.textMuted.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (session.hasSummary &&
                              (session.summary == null ||
                                  session.summary!.trim().isEmpty))
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blushGold.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'summary',
                                style: AppTypography.bodySmall().copyWith(
                                  color: AppColors.blushGold,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              '$dateStr · ${session.messageCount} msg${session.messageCount == 1 ? '' : 's'}',
                              style: AppTypography.bodySmall().copyWith(
                                color: AppColors.textDisabled,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Delete conversation',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onDelete,
                      borderRadius: AppRadius.radiusSm,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.textDisabled,
                          size: 15,
                        ),
                      ),
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
