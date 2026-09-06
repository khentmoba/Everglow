import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/study_doc_service.dart';

/// Study — a Notebook-style corner of Everglow for Khent and Clair.
///
/// Sources (up to 3 PDFs) sit on the shelf up top; the chat below is
/// grounded on them. Bubbles show questions and answers only — source
/// text goes to the model, never on screen, so long PDFs can't flood
/// the chat. Everything is session-only: leaving drops sources and turns.
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
  bool _sending = false;
  bool _picking = false;
  bool _hasText = false;
  bool _userScrolledUp = false;

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
    _userScrolledUp =
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.position.pixels > 120;
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
      _focusNode.requestFocus();
    } on StudyDocException catch (e) {
      if (mounted) _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeSource(int index) {
    setState(() => _sources.removeAt(index));
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
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(baseColor: AppColors.inkDeep),
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Study',
                  subtitle: 'your PDFs, Mochi on top',
                  icon: Icons.school_rounded,
                  hue: AppColors.softLavender,
                  onBack: () => context.pop(),
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
            ),
          ),
        ],
      ),
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
                  fontSize: 12,
                  color: enabled ? AppColors.petalWhite : AppColors.textDisabled,
                ),
              ),
              Text(
                'Mochi reads it',
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 10,
                  color: AppColors.textDisabled,
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
                  fontSize: 12,
                  color: AppColors.petalWhite,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(doc.text.length / 1000).toStringAsFixed(1)}k chars'
              '${doc.truncated ? ' · start only' : ''}',
              style: AppTypography.bodySmall().copyWith(
                fontSize: 10,
                color: AppColors.textDisabled,
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 40,
                color: AppColors.softLavender,
              ),
              const SizedBox(height: 12),
              Text(
                _sources.isEmpty
                    ? 'Add a class PDF above,'
                    : 'Sources ready — ask away,',
                style: AppTypography.titleLarge().copyWith(fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _sources.isEmpty
                    ? 'then Mochi will study it with you.'
                    : 'or tap Summarize, Quiz, Flashcards below.',
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _turns.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _turns.length) return const _StreamingBubble();
        final turn = _turns[i];
        return turn.fromUser ? _UserBubble(text: turn.text) : _AnswerBubble(text: turn.text);
      },
    );
  }

  Widget _buildStudyChips() {
    return SingleChildScrollView(
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
                    fontSize: 11,
                    color: AppColors.textMedium,
                  ),
                ),
                backgroundColor: AppColors.surfaceGlass,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusFull),
                onPressed: () => _ask(chip.$2),
              ),
            ),
        ],
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
                  style: AppTypography.bodyMedium(),
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  enabled: !_sending,
                  decoration: InputDecoration(
                    hintText: _sources.isEmpty
                        ? 'Add a PDF first…'
                        : 'Ask about your sources… (Enter to send)',
                    hintStyle: AppTypography.bodyMedium().copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
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
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.deepRose.withValues(alpha: 0.28),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(text, style: AppTypography.bodyMedium()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerBubble extends StatelessWidget {
  final String text;
  const _AnswerBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24, bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: SelectableText(text, style: AppTypography.bodyMedium()),
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
      padding: const EdgeInsets.only(right: 24, bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: ai.draftResponseNotifier,
          builder: (_, draft, _) {
            final text = draft.isEmpty ? 'Mochi is reading…' : draft;
            return Text(
              text,
              style: AppTypography.bodyMedium().copyWith(
                color: draft.isEmpty ? AppColors.textDisabled : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
