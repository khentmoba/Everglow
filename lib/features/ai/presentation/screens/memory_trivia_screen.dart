import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';

import '../../data/services/ai_memory_repo.dart';
import '../../domain/memory/memory_retrieval.dart';

/// Memory Trivia — a couple game where every question is generated from
/// a real fact Mochi remembers. Wrong answers teach the correct memory,
/// so losing still makes the relationship smarter.
class MemoryTriviaScreen extends StatefulWidget {
  const MemoryTriviaScreen({super.key});

  @override
  State<MemoryTriviaScreen> createState() => _MemoryTriviaScreenState();
}

class _MemoryTriviaScreenState extends State<MemoryTriviaScreen> {
  final AIMemoryRepository _repo = AIMemoryRepository();
  List<MemoryTriviaQuestion> _questions = [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _loading = true;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _index = 0;
      _score = 0;
      _selected = null;
      _revealed = false;
    });
    await _repo.load();
    if (!mounted) return;
    setState(() {
      _questions = const MemoryTriviaGenerator().generate(
        _repo.facts,
        count: 6,
        random: Random(),
      );
      _loading = false;
    });
  }

  MemoryTriviaQuestion? get _current {
    if (_index >= _questions.length) return null;
    return _questions[_index];
  }

  void _choose(int choice) {
    if (_revealed) return;
    setState(() {
      _selected = choice;
      _revealed = true;
      if (_current!.isCorrect(choice)) _score++;
    });
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _index = _questions.length);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.twilight,
      body: Stack(
        children: [
          const EverglowBackground(
            showPetals: true,
            glows: [
              RadialGlow(
                color: AppColors.auroraRose,
                alignment: Alignment(-0.7, -0.8),
                size: 0.7,
                opacity: 0.14,
              ),
              RadialGlow(
                color: AppColors.auroraTeal,
                alignment: Alignment(0.9, 0.85),
                size: 0.55,
                opacity: 0.10,
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Memory Trivia',
                  subtitle: 'how well do you know your own story?',
                  icon: Icons.quiz_rounded,
                  hue: AppColors.auroraRose,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.auroraRose),
      );
    }
    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x2),
          child: Text(
            'Not enough memories yet. Ask Mochi to remember something first!',
            textAlign: TextAlign.center,
            style: AppTypography.outfitMedium,
          ),
        ),
      );
    }
    if (_index >= _questions.length) {
      return _buildResults();
    }
    return _buildQuestion();
  }

  Widget _buildQuestion() {
    final question = _current!;
    final progress = (_index / _questions.length).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: AppRadius.radiusFull,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceGlass,
              color: AppColors.auroraRose,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Memory ${_index + 1} of ${_questions.length}',
            style: AppTypography.outfitMuted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            question.question,
            style: AppTypography.cormorantHeading.copyWith(
              fontSize: 26,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          ...question.choices.asMap().entries.map((entry) {
            final choiceIndex = entry.key;
            final choice = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ChoiceButton(
                label: choice,
                state: _buttonState(choiceIndex),
                onTap: () => _choose(choiceIndex),
              ),
            );
          }),
          if (_revealed) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.auroraGold.withValues(alpha: 0.12),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: AppColors.auroraGold.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                question.explanation,
                style: AppTypography.outfitMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _index + 1 >= _questions.length ? 'See score' : 'Next memory',
              ),
            ),
          ],
        ],
      ),
    );
  }

  _ChoiceState _buttonState(int index) {
    if (!_revealed) return _ChoiceState.idle;
    final question = _current!;
    if (index == question.answerIndex) return _ChoiceState.correct;
    if (index == _selected) return _ChoiceState.wrong;
    return _ChoiceState.dimmed;
  }

  Widget _buildResults() {
    final perfect = _score == _questions.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              perfect ? '🐱 Perfect! Mochi is proud' : '🌙 Nice try',
              style: AppTypography.cormorantHeading.copyWith(fontSize: 30),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '$_score / ${_questions.length} memories',
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 22,
                color: AppColors.auroraGold,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Play again'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChoiceState { idle, correct, wrong, dimmed }

class _ChoiceButton extends StatelessWidget {
  final String label;
  final _ChoiceState state;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color fill;
    switch (state) {
      case _ChoiceState.correct:
        border = AppColors.success;
        fill = AppColors.success.withValues(alpha: 0.14);
      case _ChoiceState.wrong:
        border = AppColors.error;
        fill = AppColors.error.withValues(alpha: 0.12);
      case _ChoiceState.dimmed:
        border = AppColors.border;
        fill = AppColors.surfaceGlass;
      case _ChoiceState.idle:
        border = AppColors.softLavender.withValues(alpha: 0.5);
        fill = AppColors.surfaceGlass;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: state == _ChoiceState.idle ? onTap : null,
        borderRadius: AppRadius.radiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              if (state == _ChoiceState.correct)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                )
              else if (state == _ChoiceState.wrong)
                const Icon(
                  Icons.cancel_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
              if (state == _ChoiceState.correct ||
                  state == _ChoiceState.wrong)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.outfitWhite.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
