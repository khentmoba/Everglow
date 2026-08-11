import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../models/game_match.dart';
import '../services/academy_service.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/core/theme/app_typography.dart';

class PodiumScreen extends StatefulWidget {
  final GameMatch match;

  const PodiumScreen({super.key, required this.match});

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen> {
  late ConfettiController _confettiController;
  final AcademyService _academyService = AcademyService();
  bool _pointsAwarded = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 10));
    _confettiController.play();
    _awardBonusPoints();
  }

  void _awardBonusPoints() async {
    if (_pointsAwarded) return;
    
    final userId = context.read<AuthService>().currentUser ?? 'guest';
    int bonus = 0;

    if (widget.match.winnerId == 'draw') {
      bonus = 25;
    } else if (widget.match.winnerId == userId) {
      bonus = 50;
    }

    if (bonus > 0) {
      await _academyService.updateStudyPoints(userId, bonus);
    }
    
    setState(() => _pointsAwarded = true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final isWinner = widget.match.winnerId == authService.currentUser;
    final isDraw = widget.match.winnerId == 'draw';

    String title = isDraw ? 'It\'s a Draw!' : (isWinner ? 'Victory!' : 'Good Effort!');
    String subtitle = isDraw 
        ? 'Both of you are amazing!' 
        : (isWinner ? 'You dominated the match!' : 'Better luck next time!');

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6F2),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPodiumIcon(isWinner, isDraw),
                const SizedBox(height: 30),
                Text(
                  title,
                  style: AppTypography.outfitWhite.copyWith(fontSize: 42, fontWeight: FontWeight.w900, color: const Color(0xFFFF69B4)),
                ),
                Text(
                  subtitle,
                  style: AppTypography.outfitWhite.copyWith(fontSize: 18, color: Colors.pink[300]),
                ),
                const SizedBox(height: 50),
                _buildFinalScores(),
                const SizedBox(height: 60),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF69B4),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: Text(
                    'Return to Hub',
                    style: AppTypography.outfitWhite.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.pink, Colors.white, Colors.pinkAccent, Colors.blue],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumIcon(bool isWinner, bool isDraw) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: Icon(
        isDraw ? Icons.handshake_rounded : (isWinner ? Icons.emoji_events_rounded : Icons.sentiment_satisfied_rounded),
        size: 80,
        color: const Color(0xFFFF69B4),
      ),
    );
  }

  Widget _buildFinalScores() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildScoreDisplay('Khent', widget.match.khentScore),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text('-', style: AppTypography.outfitWhite.copyWith(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black26)),
        ),
        _buildScoreDisplay('Clair', widget.match.clairScore),
      ],
    );
  }

  Widget _buildScoreDisplay(String name, int score) {
    return Column(
      children: [
        Text(name, style: AppTypography.outfitWhite.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        Text(score.toString(), style: AppTypography.outfitWhite.copyWith(fontSize: 48, fontWeight: FontWeight.w900, color: const Color(0xFFFF69B4))),
      ],
    );
  }
}
