import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_chat_bubble.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_markdown.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/study_artifact.dart';
import '../../data/services/study_doc_service.dart';
import '../../data/services/study_history_service.dart';
import '../widgets/study_artifact_sheet.dart';
import '../widgets/study_history_panel.dart';

part 'study_screen_builders.dart';
part 'study_screen_bubbles.dart';

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
  // Canvas toggle — ON shows the interactive quiz / flashcards buttons,
  // OFF keeps plain text. Defaults OFF so quick questions stay plain
  // chat; toggle it on for the interactive sheet.
  bool _canvasEnabled = false;
  AIService? _aiService;

  /// Same as [setState]; exists so the screen's `part` files (which cannot
  /// call the `@protected` [setState] from extensions) refresh identically.
  void _refresh(void Function() update) => setState(update);

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ai = context.read<AIService>();
      _aiService = ai;
      ai.draftResponseNotifier.addListener(_onDraft);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _aiService ??= context.read<AIService>();
  }

  @override
  void dispose() {
    _input.removeListener(_onTextChanged);
    _scroll.removeListener(_onScroll);
    _input.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    _aiService?.draftResponseNotifier.removeListener(_onDraft);
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
      setState(() => _sources.add(doc));
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
        canvasEnabled: _canvasEnabled,
      );
      if (!mounted) return;
      if (reply.trim().isEmpty) {
        _snack('Motchi came back empty-handed — try asking another way.');
        return;
      }
      setState(() => _turns.add(_StudyTurn.assistant(reply.trim())));
      _scrollToBottom();
      _persistSession();
    } catch (_) {
      if (mounted) _snack('Motchi had trouble — check connection and retry.', isError: true);
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

}
