import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_match.dart';
import '../models/academy_question.dart';
import '../services/academy_service.dart';
import '../widgets/score_tracker.dart';
import '../widgets/answer_button.dart';
import '../presentation/widgets/trivia_loading_overlay.dart';
import 'package:go_router/go_router.dart';

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
      backgroundColor: const Color(0xFFFFE6F2),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('active_matches')
            .doc(widget.matchId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final match = GameMatch.fromFirestore(snapshot.data!);

          if (match.status == 'finished') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.pushReplacement('/academy/podium', extra: match);
              }
            });
            return const Center(child: Text('Calculating Results...'));
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
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Question ${match.questionIndex + 1}/10',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                color: const Color(0xFFFF69B4),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Text(
                                currentQuestion.questionText,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            ...List.generate(4, (index) {
                              return AnswerButton(
                                text: currentQuestion.options[index],
                                isLocked: _isLocked,
                                onTap: () => _handleAnswer(currentQuestion, index),
                              );
                            }),
                            if (_isLocked)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Text(
                                  'Locked out for 2 seconds...',
                                  style: GoogleFonts.outfit(
                                    color: Colors.redAccent,
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
                const TriviaLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }
}
