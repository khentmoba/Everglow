import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/academy_question.dart';
import '../services/academy_service.dart';
import 'package:everglow/services/auth_service.dart';

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
  bool? _isCorrect;
  bool _isAnswered = false;
  final AcademyService _academyService = AcademyService();

  void _handleAnswer(int selectedIndex) {
    if (_isAnswered) return;

    setState(() {
      _isAnswered = true;
      _isCorrect = selectedIndex == widget.questions[_currentIndex].correctOptionIndex;
      if (_isCorrect!) _score += 10;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (_currentIndex < widget.questions.length - 1) {
          setState(() {
            _currentIndex++;
            _isAnswered = false;
            _isCorrect = null;
          });
        } else {
          _finishSession();
        }
      }
    });
  }

  void _finishSession() async {
    final userId = context.read<AuthService>().currentUser ?? 'guest';
    await _academyService.updateStudyPoints(userId, _score);
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Study Complete!'),
          content: Text('You earned $_score Study Points!'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Solo Screen
              },
              child: const Text('Return to Hub'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6F2),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Question ${_currentIndex + 1}/${widget.questions.length}',
                      style: GoogleFonts.outfit(fontSize: 18, color: Colors.pink[300]),
                    ),
                    const SizedBox(height: 20),
                    _buildQuestionCard(currentQuestion),
                    const SizedBox(height: 40),
                    ...List.generate(4, (index) => _buildOption(index, currentQuestion)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFFFF69B4)),
          ),
          Text(
            'Score: $_score',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFFF69B4)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(AcademyQuestion question) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Text(
        question.questionText,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOption(int index, AcademyQuestion question) {
    Color color = Colors.white;
    if (_isAnswered) {
      if (index == question.correctOptionIndex) {
        color = Colors.green[100]!;
      } else if (_isCorrect == false && index == question.correctOptionIndex) {
        // Show correct one even if user failed
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _handleAnswer(index),
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _isAnswered && index == question.correctOptionIndex ? Colors.green : Colors.white,
              width: 2,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
          ),
          child: Text(
            question.options[index],
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
