import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_chat_bubble.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_markdown.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/study_doc_service.dart';
import '../../data/services/study_history_service.dart';
import '../widgets/study_history_panel.dart';

/// Study — a Notebook-style corner of Everglow for Khent and Clair.
///
/// Sources (up to 3 PDFs) sit on the shelf up top; the chat below is
/// grounded on them. Bubbles show questions and answers only — source
/// text goes to the model, never on screen, so long PDFs can't flood
/// the chat. Sessions auto-save to Firestore history so leaving and
/// coming back keeps the shelf and turns.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyTurn {
  final bool fromUser;
  final String text;

  const _StudyTurn.user(this.text) : fromUser = true;
  const _StudyTurn.assistant(this.text) : fromUser = false;
}

class _StudyScreenState extends State<StudyScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final StudyDocService _studyDocs = StudyDocService();

  final List<StudyDoc> _sources = [];
  final List<_StudyTurn> _turns = [];
  final StudyHistoryService _history = StudyHistoryService();
  final GlobalKey<StudyHistoryPanelState> _historyKey =
      GlobalKey<StudyHistoryPanelState>();
  String? _sessionId;
  bool _historyOpen = false;
  bool _restoring = false;
  bool _sending = false;
  bool _picking = false;
  bool _hasText = false;
  bool _userScrolledUp = false;
  bool _showJumpButton = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AIService>().draftResponseNotifier.addListener(_onDraft);
    });
  }

  @override
  void dispose() {
    _input.removeListener(_onTextChanged);
    _scroll.removeListener(_onScroll);
    _input.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    try {
      context.read<AIService>().draftResponseNotifier.removeListener(_onDraft);
    } catch (_) {}
    super.dispose();
  }

  void _onTextChanged() {
    final has = _input.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final distance =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    _userScrolledUp = distance > 120;
    final showJump = distance > 320;
    if (showJump != _showJumpButton) {
      setState(() => _showJumpButton = showJump);
    }
  }

  void _onDraft() {
    if (!_userScrolledUp) _scrollToBottom(animated: false);
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animated) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _addSource() async {
    if (_picking || _sources.length >= kMaxStudyDocs) return;
    setState(() => _picking = true);
    try {
      final doc = await _studyDocs.pickAndExtract();
      if (!mounted || doc == null) return; // user cancelled
      setState(() => _sources.add(fitStudyDoc(doc, _sources)));
      _persistSession();
      _focusNode.requestFocus();
    } on StudyDocException catch (e) {
      if (mounted) _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeSource(int index) {
    setState(() => _sources.removeAt(index));
    _persistSession();
  }

  /// Saves the current shelf + turns to Firestore history (fire-and-forget).
  /// Skips empty shelves so the history list never fills with blank entries.
  Future<void> _persistSession() async {
    if (_sources.isEmpty && _turns.isEmpty) return;
    try {
      final turns = [
        for (final t in _turns)
          t.fromUser
              ? StudyHistoryTurn.user(t.text)
              : StudyHistoryTurn.assistant(t.text),
      ];
      final id = await _history.saveSession(
        sessionId: _sessionId,
        sources: List<StudyDoc>.of(_sources),
        turns: turns,
      );
      if (!mounted) return;
      if (id != null && _sessionId == null) {
        setState(() => _sessionId = id);
      }
      _historyKey.currentState?.refresh();
    } catch (_) {
      // History must never break the chat — fail silently.
    }
  }

  void _newStudy() {
    if (_sources.isEmpty && _turns.isEmpty) {
      setState(() => _historyOpen = false);
      return;
    }
    // Current work is already auto-saved on every turn — just clear the desk.
    setState(() {
      _sessionId = null;
      _sources.clear();
      _turns.clear();
      _historyOpen = false;
    });
    _snack('Fresh page — shelf cleared. History kept on the left.');
    _focusNode.requestFocus();
  }

  Future<void> _restoreSession(StudySession session) async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _historyOpen = false;
    });
    try {
      // List payloads already carry full sources + turns; re-fetch to be safe
      // against a stale list entry (e.g. edited on the partner's device).
      final full = await _history.loadSession(session.id) ?? session;
      if (!mounted) return;
      setState(() {
        _sessionId = full.id;
        _sources
          ..clear()
          ..addAll(full.sources);
        _turns
          ..clear()
          ..addAll(
            full.turns.map(
              (t) => t.fromUser
                  ? _StudyTurn.user(t.text)
                  : _StudyTurn.assistant(t.text),
            ),
          );
      });
      _scrollToBottom(animated: false);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _ask(String prompt) async {
    final question = prompt.trim();
    if (question.isEmpty || _sources.isEmpty || _sending) return;
    final prior = [
      for (final turn in _turns)
        {'role': turn.fromUser ? 'user' : 'assistant', 'content': turn.text},
    ];
    final block = buildSourcesBlock(_sources);
    setState(() {
      _turns.add(_StudyTurn.user(question));
      _sending = true;
    });
    _input.clear();
    _scrollToBottom();

    try {
      final auth = context.read<AuthService>();
      final reply = await context.read<AIService>().streamStudyReply(
        history: prior,
        sourcesBlock: block,
        question: question,
        callerName: auth.currentUser,
      );
      if (!mounted) return;
      if (reply.trim().isEmpty) {
        _snack('Mochi came back empty-handed — try asking another way.');
        return;
      }
      setState(() => _turns.add(_StudyTurn.assistant(reply.trim())));
      _scrollToBottom();
      _persistSession();
    } catch (_) {
      if (mounted) _snack('Mochi had trouble — check connection and retry.', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.bodySmall()),
        backgroundColor: isError
            ? AppColors.deepRose.withValues(alpha: 0.9)
            : AppColors.velvet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && _sources.isNotEmpty && !_sending;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(baseColor: AppColors.inkDeep),
          ),
          SafeArea(
            child: isDesktop
                ? Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: _historyOpen ? 320 : 0,
                        child: OverflowBox(
                          maxWidth: 320,
                          minWidth: 320,
                          alignment: Alignment.centerLeft,
                          child: IgnorePointer(
                            ignoring: !_historyOpen,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _historyOpen ? 1 : 0,
                              child: StudyHistoryPanel(
                                key: _historyKey,
                                isOpen: true,
                                activeSessionId: _sessionId,
                                onClose: () =>
                                    setState(() => _historyOpen = false),
                                onNewStudy: _newStudy,
                                onSelect: _restoreSession,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: _buildMainColumn(canSend)),
                    ],
                  )
                : Stack(
                    children: [
                      _buildMainColumn(canSend),
                      StudyHistoryPanel(
                        key: _historyKey,
                        isOpen: _historyOpen,
                        activeSessionId: _sessionId,
                        onClose: () => setState(() => _historyOpen = false),
                        onNewStudy: _newStudy,
                        onSelect: _restoreSession,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainColumn(bool canSend) {
    return Column(
      children: [
        EverglowFeatureHeader(
          title: 'Study',
          subtitle: 'your PDFs, Mochi on top',
          icon: Icons.school_rounded,
          hue: AppColors.softLavender,
          onBack: () => context.pop(),
          actions: [
            _HeaderIconButton(
              icon: Icons.history_rounded,
              tooltip: 'Study history',
              onTap: () => setState(() => _historyOpen = !_historyOpen),
            ),
            _HeaderIconButton(
              icon: Icons.add_rounded,
              tooltip: 'New study',
              onTap: _newStudy,
            ),
          ],
        ),
        if (_restoring)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(AppColors.blushGold),
          ),
        _buildSources(),
        Divider(
          height: 1,
          color: AppColors.blushGold.withValues(alpha: 0.06),
        ),
        Expanded(child: _buildChat()),
        if (_sources.isNotEmpty && !_sending) _buildStudyChips(),
        _buildComposer(canSend),
      ],
    );
  }

  Widget _buildSources() {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        itemCount: _sources.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == _sources.length) return _buildAddCard();
          return _buildSourceCard(i);
        },
      ),
    );
  }

  Widget _buildAddCard() {
    final full = _sources.length >= kMaxStudyDocs;
    final enabled = !full && !_picking;
    return SizedBox(
      width: 132,
      child: GestureDetector(
        onTap: enabled ? _addSource : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.softLavender.withValues(alpha: enabled ? 0.4 : 0.15),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_picking)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.softLavender,
                  ),
                )
              else
                Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: enabled ? AppColors.softLavender : AppColors.textDisabled,
                ),
              const SizedBox(height: 6),
              Text(
                full ? 'Shelf full (3)' : 'Add PDF',
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.petalWhite : AppColors.textMuted,
                ),
              ),
              Text(
                'Mochi reads it',
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceCard(int index) {
    final doc = _sources[index];
    return SizedBox(
      width: 200,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 16,
                  color: AppColors.blushGold,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _removeSource(index),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                doc.fileName,
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.petalWhite,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(doc.text.length / 1000).toStringAsFixed(1)}k chars'
              '${doc.truncated ? ' · start only' : ''}',
              style: AppTypography.bodySmall().copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    if (_turns.isEmpty && !_sending) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softLavender.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.softLavender.withValues(alpha: 0.30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softLavender.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 32,
                  color: AppColors.softLavender,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _sources.isEmpty ? 'Add a class PDF above' : 'Sources ready — ask away',
                style: AppTypography.titleLarge().copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _sources.isEmpty
                    ? 'Mochi will read it with you, then answer\nonly from your pages.'
                    : 'Ask anything, or tap Summarize, Quiz,\nFlashcards below to start.',
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              controller: _scroll,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _turns.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _turns.length) return const _StreamingBubble();
                final turn = _turns[i];
                return turn.fromUser
                    ? _UserBubble(text: turn.text)
                    : _AnswerBubble(text: turn.text);
              },
            ),
          ),
        ),
        if (_showJumpButton)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _scrollToBottom(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panelGlass,
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStudyChips() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              for (final chip in StudyPrompts.chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      chip.$1,
                      style: AppTypography.bodySmall().copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMedium,
                        height: 1.3,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceGlass,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusFull,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    onPressed: _sending ? null : () => _ask(chip.$2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(bool canSend) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        10,
        AppSpacing.lg,
        14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.06)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: AppRadius.radiusX2,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              if (!HardwareKeyboard.instance.isShiftPressed) {
                _ask(_input.text);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focusNode,
                  style: AppTypography.bodyMedium().copyWith(
                    height: 1.5,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHigh,
                  ),
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  enabled: !_sending,
                  decoration: InputDecoration(
                    hintText: _sources.isEmpty
                        ? 'Add a PDF first…'
                        : 'Ask about your sources…',
                    hintStyle: AppTypography.bodyMedium().copyWith(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: GestureDetector(
                  onTap: canSend ? () => _ask(_input.text) : null,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: canSend
                          ? const LinearGradient(
                              colors: [AppColors.blushGold, AppColors.deepRose],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: canSend
                          ? null
                          : AppColors.velvet.withValues(alpha: 0.4),
                      borderRadius: AppRadius.radiusLg,
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.blushGold,
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              color: canSend
                                  ? AppColors.petalWhite
                                  : AppColors.textDisabled,
                              size: 20,
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
      ),
    );
  }
}

/// Small circular action used in the Study header (history / new study).
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusFull,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceGlass,
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

/// User question — global rose bubble shared with Mochi chat.
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 12),
      child: EverglowUserBubble(text: text),
    );
  }
}

/// Mochi answer — the same global assistant bubble Mochi chat uses,
/// so a fix here upgrades both surfaces at once.
class _AnswerBubble extends StatelessWidget {
  final String text;
  const _AnswerBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 12),
      child: EverglowAssistantBubble(
        text: text,
        title: 'Mochi',
        subtitle: 'from your PDFs',
        timeLabel: 'Mochi • grounded only on your pages',
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble();

  @override
  Widget build(BuildContext context) {
    final ai = context.read<AIService>();
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusSm,
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.radiusSm,
              child: Image.asset(
                'assets/images/mochi_avatar.png',
                width: 34,
                height: 34,
                cacheWidth: 102,
                cacheHeight: 102,
                filterQuality: FilterQuality.high,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.moonlight.withValues(alpha: 0.13),
                    AppColors.moonlight.withValues(alpha: 0.07),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: AppColors.panelGlass,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xs),
                  topRight: Radius.circular(AppRadius.xl),
                  bottomLeft: Radius.circular(AppRadius.xl),
                  bottomRight: Radius.circular(AppRadius.xl),
                ),
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.16),
                ),
                boxShadow: [
                  ...AppElevation.e2,
                  BoxShadow(
                    color: AppColors.auroraLilac.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ValueListenableBuilder<String>(
                valueListenable: ai.draftResponseNotifier,
                builder: (_, draft, _) {
                  if (draft.isEmpty) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mochi is reading',
                          style: AppTypography.bodyMedium().copyWith(
                            color: AppColors.textMuted,
                            height: 1.5,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.blushGold,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EverglowMarkdown(
                        text: draft,
                        baseStyle: AppTypography.bodyMedium().copyWith(
                          color: AppColors.textHigh,
                          height: 1.6,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: AppColors.moonlight.withValues(
                            alpha: 0.14,
                          ),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.blushGold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
