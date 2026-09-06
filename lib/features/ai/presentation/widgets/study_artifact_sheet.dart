import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/study_artifact.dart';

/// Study canvas — the Artifacts-style interactive layer for Study replies.
///
/// When Mochi's answer carries a quiz or flashcards, the bubble shows one
/// big obvious button ("Try the quiz ✍️" / "Flip the cards 🃏") instead of
/// raw text. Tapping opens this sheet:
///
/// - Phone / tablet (Clair's world): a near-full bottom sheet she can drag.
/// - Desktop: a centered dialog, same content.
///
/// One code path for both, so a fix here reaches every screen size.
enum StudyArtifactTab { quiz, flashcards }

/// Opens the interactive sheet. Picks tabs automatically when only one
/// artifact kind is present.
Future<void> openStudyArtifactSheet(
  BuildContext context,
  StudyArtifacts artifacts, {
  StudyArtifactTab? initialTab,
}) {
  final tab =
      initialTab ??
      (artifacts.hasQuiz ? StudyArtifactTab.quiz : StudyArtifactTab.flashcards);
  final sheet = StudyArtifactSheet(artifacts: artifacts, initialTab: tab);
  if (MediaQuery.sizeOf(context).width >= 1024) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: _SheetChrome(child: sheet),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, controller) =>
          _SheetChrome(scrollController: controller, child: sheet),
    ),
  );
}

/// The little launcher pill at the top of a Study answer bubble.
/// Renders nothing when the reply has no interactive content.
class StudyArtifactEntry extends StatelessWidget {
  final StudyArtifacts artifacts;

  const StudyArtifactEntry({super.key, required this.artifacts});

  @override
  Widget build(BuildContext context) {
    if (artifacts.isEmpty) return const SizedBox.shrink();
    final buttons = <Widget>[];
    if (artifacts.hasQuiz) {
      buttons.add(
        _LaunchButton(
          icon: Icons.edit_note_rounded,
          label:
              'Try the quiz ✍️ · ${artifacts.quiz.length} question${artifacts.quiz.length == 1 ? '' : 's'}',
          onTap: () => openStudyArtifactSheet(
            context,
            artifacts,
            initialTab: StudyArtifactTab.quiz,
          ),
        ),
      );
    }
    if (artifacts.hasFlashcards) {
      buttons.add(
        _LaunchButton(
          icon: Icons.style_rounded,
          label:
              'Flip the cards 🃏 · ${artifacts.flashcards.length} card${artifacts.flashcards.length == 1 ? '' : 's'}',
          onTap: () => openStudyArtifactSheet(
            context,
            artifacts,
            initialTab: StudyArtifactTab.flashcards,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LaunchButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.radiusXl,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepRose, AppColors.roseDepths],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(
              color: AppColors.petalWhite.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.petalWhite),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium().copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.petalWhite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetChrome extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;

  const _SheetChrome({required this.child, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.x2),
          bottom: Radius.circular(AppRadius.x2),
        ),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (scrollController != null) ...[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.25),
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class StudyArtifactSheet extends StatefulWidget {
  final StudyArtifacts artifacts;
  final StudyArtifactTab initialTab;

  const StudyArtifactSheet({
    super.key,
    required this.artifacts,
    required this.initialTab,
  });

  @override
  State<StudyArtifactSheet> createState() => _StudyArtifactSheetState();
}

class _StudyArtifactSheetState extends State<StudyArtifactSheet> {
  late StudyArtifactTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = widget.artifacts.hasQuiz && widget.artifacts.hasFlashcards;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _tab == StudyArtifactTab.quiz
                      ? 'Quiz time ✍️'
                      : 'Flashcards 🃏',
                  style: AppTypography.titleLarge().copyWith(fontSize: 20),
                ),
              ),
              IconButton(
                tooltip: 'Back to chat',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
        if (showTabs)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: _TabSwitch(
              tab: _tab,
              quizCount: widget.artifacts.quiz.length,
              cardCount: widget.artifacts.flashcards.length,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
        Flexible(
          child: _tab == StudyArtifactTab.quiz
              ? QuizPlayView(questions: widget.artifacts.quiz)
              : FlashcardsPlayView(cards: widget.artifacts.flashcards),
        ),
      ],
    );
  }
}

class _TabSwitch extends StatelessWidget {
  final StudyArtifactTab tab;
  final int quizCount;
  final int cardCount;
  final ValueChanged<StudyArtifactTab> onChanged;

  const _TabSwitch({
    required this.tab,
    required this.quizCount,
    required this.cardCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _tabOption(context, StudyArtifactTab.quiz, 'Quiz · $quizCount'),
          _tabOption(context, StudyArtifactTab.flashcards, 'Cards · $cardCount'),
        ],
      ),
    );
  }

  Widget _tabOption(
    BuildContext context,
    StudyArtifactTab value,
    String label,
  ) {
    final selected = tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.blushGold, AppColors.deepRose],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: AppRadius.radiusFull,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.bodySmall().copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.petalWhite
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quiz ───────────────────────────────────────────────────────

class QuizPlayView extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizPlayView({super.key, required this.questions});

  @override
  State<QuizPlayView> createState() => _QuizPlayViewState();
}

class _QuizPlayViewState extends State<QuizPlayView> {
  int _index = 0;
  int _picked = -1;
  int _score = 0;
  bool _finished = false;

  void _pick(int option) {
    if (_picked != -1) return;
    final correct = option == widget.questions[_index].answerIndex;
    HapticFeedback.lightImpact();
    setState(() {
      _picked = option;
      if (correct) _score++;
    });
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index + 1 >= widget.questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _picked = -1;
      });
    }
  }

  void _retake() {
    HapticFeedback.selectionClick();
    setState(() {
      _index = 0;
      _picked = -1;
      _score = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildScore();
    final q = widget.questions[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressBar(
            current: _index + 1,
            total: widget.questions.length,
          ),
          const SizedBox(height: 14),
          Text(
            'Question ${_index + 1} of ${widget.questions.length}',
            style: AppTypography.bodySmall().copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.blushGold,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q.question,
            style: AppTypography.titleMedium().copyWith(
              fontSize: 17,
              height: 1.45,
              color: AppColors.textHigh,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < q.options.length; i++)
            _OptionButton(
              key: ValueKey('q$_index-opt$i'),
              letter: String.fromCharCode('A'.codeUnitAt(0) + i),
              text: q.options[i],
              state: _picked == -1
                  ? _OptionState.idle
                  : i == q.answerIndex
                      ? _OptionState.correct
                      : i == _picked
                          ? _OptionState.wrong
                          : _OptionState.dimmed,
              onTap: () => _pick(i),
            ),
          if (_picked != -1) ...[
            const SizedBox(height: 4),
            _FeedbackCard(
              correct: _picked == q.answerIndex,
              explanation: q.explanation,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepRose,
                  foregroundColor: AppColors.petalWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusXl,
                  ),
                ),
                child: Text(
                  _index + 1 >= widget.questions.length
                      ? 'See my score 💕'
                      : 'Next →',
                  style: AppTypography.bodyMedium().copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScore() {
    final total = widget.questions.length;
    final perfect = _score == total;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blushGold.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.25),
                  blurRadius: 28,
                ),
              ],
            ),
            child: const Center(
              child: Text('🍡', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$_score of $total',
            style: AppTypography.displaySmall().copyWith(
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            perfect
                ? 'Perfect — Mochi is doing happy spins!'
                : _score * 2 >= total
                    ? 'So close — one more round?'
                    : 'Good start — every try makes it stick.',
            style: AppTypography.bodyMedium().copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _retake,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepRose,
                foregroundColor: AppColors.petalWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusXl,
                ),
              ),
              child: Text(
                'Try again 🔁',
                style: AppTypography.bodyMedium().copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.petalWhite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Back to chat',
              style: AppTypography.bodyMedium().copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionButton extends StatelessWidget {
  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionButton({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = state != _OptionState.idle;
    Color border = AppColors.border;
    Color fill = AppColors.surfaceGlass;
    Color letterBg = AppColors.moonlight.withValues(alpha: 0.12);
    Color letterFg = AppColors.textMuted;
    if (state == _OptionState.correct) {
      border = AppColors.success.withValues(alpha: 0.7);
      fill = AppColors.success.withValues(alpha: 0.14);
      letterBg = AppColors.success;
      letterFg = AppColors.inkDeep;
    } else if (state == _OptionState.wrong) {
      border = AppColors.error.withValues(alpha: 0.7);
      fill = AppColors.error.withValues(alpha: 0.12);
      letterBg = AppColors.error;
      letterFg = AppColors.petalWhite;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: AppRadius.radiusXl,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: AppRadius.radiusXl,
              border: Border.all(color: border, width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: letterBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: state == _OptionState.correct
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.inkDeep,
                          )
                        : state == _OptionState.wrong
                            ? const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.petalWhite,
                              )
                            : Text(
                                letter,
                                style: AppTypography.bodyMedium().copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: letterFg,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      text,
                      style: AppTypography.bodyMedium().copyWith(
                        fontSize: 14.5,
                        height: 1.5,
                        color: state == _OptionState.dimmed
                            ? AppColors.textMuted
                            : AppColors.textHigh,
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

class _FeedbackCard extends StatelessWidget {
  final bool correct;
  final String explanation;

  const _FeedbackCard({required this.correct, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final accent = correct ? AppColors.success : AppColors.blushGold;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.auroraLilac.withValues(alpha: 0.16),
            AppColors.deepRose.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct
                ? 'Correct! Mochi is proud 🍡'
                : 'Not quite — here\'s the gentle fix 💡',
            style: AppTypography.bodyMedium().copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: AppTypography.bodyMedium().copyWith(
                color: AppColors.textMedium,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.radiusFull,
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : current / total,
        minHeight: 6,
        backgroundColor: AppColors.moonlight.withValues(alpha: 0.12),
        valueColor: const AlwaysStoppedAnimation(AppColors.blushGold),
      ),
    );
  }
}

// ─── Flashcards ───────────────────────────────────────────────

class FlashcardsPlayView extends StatefulWidget {
  final List<Flashcard> cards;

  const FlashcardsPlayView({super.key, required this.cards});

  @override
  State<FlashcardsPlayView> createState() => _FlashcardsPlayViewState();
}

class _FlashcardsPlayViewState extends State<FlashcardsPlayView> {
  late List<Flashcard> _order;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.cards);
  }

  void _shuffle() {
    HapticFeedback.selectionClick();
    final rng = math.Random();
    final next = List.of(_order)..shuffle(rng);
    setState(() {
      _order = next;
      _index = 0;
    });
  }

  void _go(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _index = (_index + delta).clamp(0, _order.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _order[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Card ${_index + 1} of ${_order.length}',
                style: AppTypography.bodySmall().copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blushGold,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _shuffle,
                icon: const Icon(Icons.shuffle_rounded, size: 16),
                label: const Text('Shuffle'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FlipCard(
            key: ValueKey('card-$_index-${card.front.hashCode}'),
            front: card.front,
            back: card.back,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the card to flip it',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _index > 0 ? () => _go(-1) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textHigh,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusXl,
                      ),
                    ),
                    child: const Text('← Back'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _index + 1 < _order.length ? () => _go(1) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepRose,
                      foregroundColor: AppColors.petalWhite,
                      disabledBackgroundColor:
                          AppColors.velvet.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusXl,
                      ),
                    ),
                    child: Text(
                      _index + 1 < _order.length ? 'Next →' : 'Done 💕',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// A card that turns around on tap, like real flashcards.
class _FlipCard extends StatefulWidget {
  final String front;
  final String back;

  const _FlipCard({super.key, required this.front, required this.back});

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showingBack = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.selectionClick();
    if (_showingBack) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() => _showingBack = !_showingBack);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _showingBack
          ? 'Flashcard answer. Tap to see question.'
          : 'Flashcard question. Tap to see answer.',
      child: GestureDetector(
        onTap: _flip,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            final angle = _controller.value * math.pi;
            final showBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _face(
                        text: widget.back,
                        hint: 'ANSWER',
                        gradient: const LinearGradient(
                          colors: [AppColors.plum, AppColors.velvet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: AppColors.auroraLilac,
                      ),
                    )
                  : _face(
                      text: widget.front,
                      hint: 'QUESTION',
                      gradient: LinearGradient(
                        colors: [
                          AppColors.moonlight.withValues(alpha: 0.14),
                          AppColors.moonlight.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: AppColors.blushGold,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _face({
    required String text,
    required String hint,
    required Gradient gradient,
    required Color border,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: gradient,
        color: AppColors.panelGlass,
        borderRadius: AppRadius.radiusX2,
        border: Border.all(color: border.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hint,
            style: AppTypography.labelSmall().copyWith(
              color: AppColors.blushGold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium().copyWith(
              fontSize: 17,
              height: 1.55,
              color: AppColors.textHigh,
            ),
          ),
        ],
      ),
    );
  }
}
