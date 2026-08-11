import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/shared/widgets/everglow/everglow_background.dart';
import '../models/academy_question.dart';

class SoloStudyScreen extends StatefulWidget {
  final List<AcademyQuestion> questions;
  final String category;

  const SoloStudyScreen({
    super.key,
    required this.questions,
    required this.category,
  });

  @override
  State<SoloStudyScreen> createState() => _SoloStudyScreenState();
}

class _SoloStudyScreenState extends State<SoloStudyScreen> {
  int _currentIndex = 0;
  int _score = 0;
  bool _isAnswered = false;
  bool? _isCorrect;
  int? _lastChosen;

  void _showResults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusX2),
        title: Text(
          'Study Complete',
          textAlign: TextAlign.center,
          style: AppTypography.cormorantBold.copyWith(fontSize: 26),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_score / ${widget.questions.length}',
              style: AppTypography.cormorantExtraBold.copyWith(
                fontSize: 44,
                color: AppColors.auroraGold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _score == widget.questions.length
                  ? 'Perfect score, my love!'
                  : 'Great practice!',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentIndex];

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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Question ${_currentIndex + 1}/${widget.questions.length}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 18,
                            color: AppColors.auroraRose,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildQuestionCard(currentQuestion),
                        const SizedBox(height: 32),
                        ...List.generate(
                          4,
                          (index) => _buildOption(index, currentQuestion),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: AppColors.roseQuartz),
            tooltip: 'Close',
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
          const SizedBox(width: 48),
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
          fontSize: 22,
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
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: _isAnswered ? null : () => _handleAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
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
              fontSize: 17,
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

  void _handleAnswer(int index) {
    if (_isAnswered) return;
    final question = widget.questions[_currentIndex];
    final correct = index == question.correctOptionIndex;
    setState(() {
      _isAnswered = true;
      _isCorrect = correct;
      _lastChosen = index;
      if (correct) _score++;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_currentIndex + 1 < widget.questions.length) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _isCorrect = null;
          _lastChosen = null;
        });
      } else {
        _showResults();
      }
    });
  }
}
