import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_typography.dart';

class ScoreTracker extends StatelessWidget {
  final int khentScore;
  final int clairScore;
  final int questionIndex;

  const ScoreTracker({
    super.key,
    required this.khentScore,
    required this.clairScore,
    required this.questionIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlayerScore('Khent', khentScore, Colors.blue[300]!),
          Column(
            children: [
              Text(
                'VS',
                style: AppTypography.outfitWhite.copyWith(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFFFF69B4)),
              ),
              const SizedBox(height: 4),
              Container(
                height: 4,
                width: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6F2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (questionIndex / 10).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF69B4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildPlayerScore('Clair', clairScore, Colors.pink[300]!),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String name, int score, Color color) {
    return Column(
      children: [
        Text(
          name,
          style: AppTypography.outfitBold.copyWith(fontSize: 16, color: Colors.black54),
        ),
        Text(
          score.toString(),
          style: AppTypography.outfitWhite.copyWith(fontSize: 32, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}
