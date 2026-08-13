import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_match.dart';
import '../models/academy_question.dart';
import '../services/academy_service.dart';
import '../widgets/score_tracker.dart';
import '../widgets/answer_button.dart';
import '../presentation/widgets/trivia_loading_overlay.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/everglow/everglow_background.dart';

class GameBoardScreen extends StatefulWidget {
  final String matchId;
  final String userId;
  final List<AcademyQuestion> questions;

  const GameBoardScreen({
    super.key,
    required this.matchId,
    required this.userId,
    required this.questions,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final AcademyService _academyService = AcademyService();
  bool _isLocked = false;
  Timer? _lockoutTimer;

  void _handleAnswer(AcademyQuestion question, int selectedIndex) async {
    if (_isLocked) return;

    final isCorrect = selectedIndex == question.correctOptionIndex;

    if (isCorrect) {
      await _academyService.submitAnswer(
        widget.matchId,
        widget.userId,
        question.id,
        true,
      );
    } else {
      setState(() => _isLocked = true);
      _lockoutTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isLocked = false);
      });
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
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
                  color: AppColors.deepRose,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.16,
                ),
                RadialGlow(
                  color: AppColors.softLavender,
                  alignment: Alignment(0.9, 0.8),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('active_matches')
                .doc(widget.matchId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.auroraRose,
                    strokeWidth: 2.5,
                  ),
                );
              }

              final match = GameMatch.fromFirestore(snapshot.data!);

              if (match.status == 'finished') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.pushReplacement('/academy/podium', extra: match);
                  }
                });
                return const Center(
                  child: Text(
                    'Calculating Results...',
                    style: TextStyle(color: AppColors.petalWhite),
                  ),
                );
              }

              final currentQuestion = widget.questions.firstWhere(
                (q) => q.id == match.currentQuestionId,
                orElse: () => widget.questions.first,
              );

              return Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        ScoreTracker(
                          khentScore: match.khentScore,
                          clairScore: match.clairScore,
                          questionIndex: match.questionIndex,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Question ${match.questionIndex + 1}/10',
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 18,
                                    color: AppColors.auroraRose,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.velvet.withValues(
                                          alpha: 0.85,
                                        ),
                                        AppColors.inkDeep.withValues(
                                          alpha: 0.9,
                                        ),
                                      ],
                                    ),
                                    borderRadius: AppRadius.radiusX2,
                                    border: Border.all(
                                      color: AppColors.moonlight.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.deepRose.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 22,
                                        spreadRadius: -6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    currentQuestion.questionText,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.outfitWhite.copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.petalWhite,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                ...List.generate(4, (index) {
                                  return AnswerButton(
                                    text: currentQuestion.options[index],
                                    isLocked: _isLocked,
                                    onTap: () =>
                                        _handleAnswer(currentQuestion, index),
                                  );
                                }),
                                if (_isLocked)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Text(
                                      'Locked out for 2 seconds...',
                                      style: AppTypography.outfitWhite.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (match.isReplenishing)
                    const Positioned.fill(child: TriviaLoadingOverlay()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
