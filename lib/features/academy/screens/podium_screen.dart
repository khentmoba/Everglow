import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/everglow/everglow_background.dart';
import '../../../core/services/auth_service.dart';
import '../models/game_match.dart';

class PodiumScreen extends StatefulWidget {
  final GameMatch match;

  const PodiumScreen({super.key, required this.match});

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    )..play();
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

    final title = isDraw
        ? "It's a Draw!"
        : (isWinner ? 'Victory!' : 'Good Effort!');
    final subtitle = isDraw
        ? 'Both of you are amazing!'
        : (isWinner ? 'You dominated the match!' : 'Better luck next time!');

    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraGold,
                  alignment: Alignment(0, -0.7),
                  size: 1.0,
                  opacity: 0.16,
                ),
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(-0.8, 0.9),
                  size: 0.8,
                  opacity: 0.14,
                ),
              ],
              showPetals: true,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPodiumIcon(isWinner, isDraw),
                const SizedBox(height: 30),
                Text(
                  title,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: AppColors.auroraRose,
                    shadows: [
                      Shadow(
                        color: AppColors.auroraGold.withValues(alpha: 0.6),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 18,
                    color: AppColors.roseQuartz.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 50),
                _buildFinalScores(),
                const SizedBox(height: 60),
                _ReturnButton(onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.auroraRose,
                AppColors.auroraGold,
                AppColors.auroraLilac,
                AppColors.petalWhite,
              ],
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
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.9),
            AppColors.inkDeep.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(
          color: AppColors.auroraGold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.auroraGold.withValues(alpha: 0.35),
            blurRadius: 34,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(
        isDraw
            ? Icons.handshake_rounded
            : (isWinner
                  ? Icons.emoji_events_rounded
                  : Icons.sentiment_satisfied_rounded),
        size: 80,
        color: AppColors.auroraGold,
        shadows: [
          Shadow(
            color: AppColors.auroraGold.withValues(alpha: 0.6),
            blurRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildFinalScores() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildScoreDisplay('Khent', widget.match.khentScore),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            '-',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0x66FFF5F5),
            ),
          ),
        ),
        _buildScoreDisplay('Clair', widget.match.clairScore),
      ],
    );
  }

  Widget _buildScoreDisplay(String name, int score) {
    return Column(
      children: [
        Text(
          name,
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        Text(
          score.toString(),
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: AppColors.auroraGold,
            shadows: [
              Shadow(
                color: AppColors.auroraGold.withValues(alpha: 0.5),
                blurRadius: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReturnButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ReturnButton({required this.onPressed});

  @override
  State<_ReturnButton> createState() => _ReturnButtonState();
}

class _ReturnButtonState extends State<_ReturnButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..scaleByDouble(
              _hovered ? 1.04 : 1.0,
              _hovered ? 1.04 : 1.0,
              _hovered ? 1.04 : 1.0,
              1.0,
            ),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppTheme.roseGoldGradient,
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: AppColors.petalWhite.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Text(
            'Return to Hub',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.petalWhite,
            ),
          ),
        ),
      ),
    );
  }
}
