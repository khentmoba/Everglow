part of 'study_artifact_sheet.dart';

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
                    onPressed: _index + 1 < _order.length ? () => _go(1) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepRose,
                      foregroundColor: AppColors.petalWhite,
                      disabledBackgroundColor: AppColors.velvet.withValues(
                        alpha: 0.4,
                      ),
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
          // Plain Text on purpose: SelectableText swallows taps for
          // selection, which would break tap-to-flip on the words
          // themselves (Clair taps the words, not the margins).
          Text(
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
