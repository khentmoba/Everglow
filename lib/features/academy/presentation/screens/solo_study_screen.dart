import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../data/models/academy_question.dart';
import '../../data/services/study_set_service.dart';

class SoloStudyScreen extends StatefulWidget {
  final List<AcademyQuestion> questions;
  final String category;
  final String topic;

  const SoloStudyScreen({
    super.key,
    required this.questions,
    required this.category,
    this.topic = '',
  });

  @override
  State<SoloStudyScreen> createState() => _SoloStudyScreenState();
}

class _SoloStudyScreenState extends State<SoloStudyScreen> {
  final StudySetService _studySets = StudySetService();
  late List<AcademyQuestion> _questions;
  int _currentIndex = 0;
  int _score = 0;
  bool _isAnswered = false;
  bool? _isCorrect;
  int? _lastChosen;
  bool _finished = false;
  bool _isNewBest = false;
  bool _isReloading = false;

  @override
  void initState() {
    super.initState();
    _questions = widget.questions;
  }

  String get _setLabel {
    if (widget.topic.isNotEmpty) return widget.topic;
    final c = widget.category;
    return c.isEmpty ? 'Study' : c[0].toUpperCase() + c.substring(1);
  }

  Future<void> _practiceAgain() async {
    setState(() => _isReloading = true);
    final fresh = await _studySets.buildSoloSet(
      category: widget.category,
      topic: widget.topic,
    );
    if (!mounted) return;
    setState(() {
      _questions = fresh.isNotEmpty ? fresh : widget.questions;
      _currentIndex = 0;
      _score = 0;
      _isAnswered = false;
      _isCorrect = null;
      _lastChosen = null;
      _finished = false;
      _isNewBest = false;
      _isReloading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(0.9, 0.8),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildProgress(),
                Expanded(
                  child: _questions.isEmpty
                      ? _buildEmpty()
                      : _finished
                      ? _buildResults()
                      : _buildQuestion(),
                ),
              ],
            ),
          ),
          if (_isReloading)
            Positioned.fill(
              child: Container(
                color: AppColors.inkDeep.withValues(alpha: 0.7),
                child: Center(
                  child: Text(
                    'Motchi is writing new questions... 🍡',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 15,
                      color: AppColors.auroraGold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          EverglowIconButton.close(onPressed: () => context.pop()),
          Expanded(
            child: Text(
              _setLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.petalWhite.withValues(alpha: 0.85),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.roseGoldGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: AppColors.petalWhite,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_score',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 16,
                    color: AppColors.petalWhite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final total = _questions.isEmpty ? 1 : _questions.length;
    final done = _finished ? total : _currentIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${(_currentIndex + 1).clamp(1, total)}/$total',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color: AppColors.auroraRose,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'no timer · take your time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    color: AppColors.petalWhite.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: AppColors.moonlight.withValues(alpha: 0.12),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.roseGoldGradient,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No questions right now',
              style: AppTypography.cormorantBold.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Motchi is resting — try again in a bit.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to Hub',
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.blushGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final currentQuestion = _questions[_currentIndex];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          _buildQuestionCard(currentQuestion),
          const SizedBox(height: 24),
          ...List.generate(
            currentQuestion.options.length,
            (index) => _buildOption(index, currentQuestion),
          ),
          if (_isAnswered) ...[
            const SizedBox(height: 4),
            _buildFeedback(currentQuestion),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(AcademyQuestion question) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.85),
            AppColors.inkDeep.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepRose.withValues(alpha: 0.14),
            blurRadius: 22,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Text(
        question.questionText,
        textAlign: TextAlign.center,
        style: AppTypography.outfitWhite.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.petalWhite,
        ),
      ),
    );
  }

  Widget _buildOption(int index, AcademyQuestion question) {
    Color? fill;
    Color borderColor = AppColors.moonlight.withValues(alpha: 0.22);
    if (_isAnswered) {
      if (index == question.correctOptionIndex) {
        fill = AppColors.success.withValues(alpha: 0.18);
        borderColor = AppColors.success;
      } else if (_isCorrect == false && index == _lastChosen) {
        fill = AppColors.error.withValues(alpha: 0.18);
        borderColor = AppColors.error;
      } else {
        fill = AppColors.moonlight.withValues(alpha: 0.06);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _isAnswered ? null : () => _handleAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          width: double.infinity,
          decoration: BoxDecoration(
            color: fill ?? AppColors.moonlight.withValues(alpha: 0.10),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              if (_isAnswered && index == question.correctOptionIndex)
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
            ],
          ),
          child: Text(
            question.options[index],
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _isAnswered && index == question.correctOptionIndex
                  ? AppColors.petalWhite
                  : AppColors.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback(AcademyQuestion question) {
    final correct = _isCorrect == true;
    final message = correct
        ? 'Lovely — that\u2019s right! 🍡'
        : 'Almost, love — it was ${question.options[question.correctOptionIndex]}.';
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: (correct ? AppColors.success : AppColors.auroraGold).withValues(
          alpha: 0.10,
        ),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: (correct ? AppColors.success : AppColors.auroraGold)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.petalWhite,
            ),
          ),
          if (question.explanation != null &&
              question.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '🍡 ${question.explanation!}',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.petalWhite.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    final total = _questions.length;
    final ratio = total == 0 ? 0 : _score / total;
    final title = ratio >= 1
        ? 'Perfect, my love! 🍡'
        : ratio >= 0.7
        ? 'So lovely!'
        : ratio >= 0.4
        ? 'Good practice!'
        : 'Every try counts.';
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.cormorantBold.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            '$_score / $total',
            style: AppTypography.cormorantExtraBold.copyWith(
              fontSize: 56,
              color: AppColors.auroraGold,
            ),
          ),
          if (_isNewBest)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '✨ New best in $_setLabel!',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.auroraGold,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            widget.topic.isNotEmpty
                ? 'Motchi loved writing about “${widget.topic}”.'
                : 'Motchi is proud of you.',
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 14,
              color: AppColors.petalWhite.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          _ResultsButton(
            label: 'Practice again',
            icon: Icons.refresh_rounded,
            primary: true,
            onTap: _practiceAgain,
          ),
          const SizedBox(height: 12),
          _ResultsButton(
            label: 'Challenge my love to 1v1',
            icon: Icons.bolt_rounded,
            onTap: () => context.pop('challenge'),
          ),
          const SizedBox(height: 12),
          _ResultsButton(
            label: 'Back to Hub',
            icon: Icons.home_rounded,
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }

  void _handleAnswer(int index) {
    if (_isAnswered) return;
    final question = _questions[_currentIndex];
    final correct = index == question.correctOptionIndex;
    setState(() {
      _isAnswered = true;
      _isCorrect = correct;
      _lastChosen = index;
      if (correct) _score++;
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (_currentIndex + 1 < _questions.length) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _isCorrect = null;
          _lastChosen = null;
        });
      } else {
        _finishSet();
      }
    });
  }

  Future<void> _finishSet() async {
    final isBest = await _studySets.saveSoloResult(
      category: widget.category,
      score: _score,
      total: _questions.length,
    );
    if (!mounted) return;
    setState(() {
      _finished = true;
      _isNewBest = isBest;
    });
  }
}

class _ResultsButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _ResultsButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: primary ? AppTheme.roseGoldGradient : null,
          color: primary ? null : AppColors.moonlight.withValues(alpha: 0.10),
          borderRadius: AppRadius.radiusXl,
          border: Border.all(
            color: primary
                ? AppColors.petalWhite.withValues(alpha: 0.4)
                : AppColors.moonlight.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.petalWhite),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.petalWhite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
