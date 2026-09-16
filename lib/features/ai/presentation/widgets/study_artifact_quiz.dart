part of 'study_artifact_sheet.dart';

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
          _ProgressBar(current: _index + 1, total: widget.questions.length),
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
                ? 'Perfect — Motchi is doing happy spins!'
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
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
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
                ? 'Correct! Motchi is proud 🍡'
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
