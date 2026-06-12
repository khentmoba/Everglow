import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/play_zone/models/racing_match.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:provider/provider.dart';

class RacingResultsScreen extends StatelessWidget {
  final RacingMatch match;

  const RacingResultsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    final isHost = match.hostId == uid;
    final myTime = isHost ? match.hostTime : match.participantTime;
    final opponentTime = isHost ? match.participantTime : match.hostTime;
    final isWinner = match.winnerId == uid;
    final isDraw = match.winnerId == 'draw';

    String resultTitle;
    IconData resultIcon;
    Color resultColor;

    if (isDraw) {
      resultTitle = "It's a Draw!";
      resultIcon = Icons.handshake_rounded;
      resultColor = AppTheme.blushGold;
    } else if (isWinner) {
      resultTitle = 'Victory!';
      resultIcon = Icons.emoji_events_rounded;
      resultColor = AppTheme.blushGold;
    } else {
      resultTitle = 'Good Effort!';
      resultIcon = Icons.favorite_rounded;
      resultColor = AppTheme.roseQuartz;
    }

    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  Icon(resultIcon, size: 80, color: resultColor),
                  const SizedBox(height: 16),
                  Text(
                    resultTitle,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTimeCard(
                    label: 'Your Time',
                    time: myTime,
                    isWinner: isWinner,
                  ),
                  const SizedBox(height: 16),
                  _buildTimeCard(
                    label: "Opponent's Time",
                    time: opponentTime,
                    isWinner: !isWinner && !isDraw,
                  ),
                  const Spacer(flex: 1),
                  ElevatedButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepRose,
                      foregroundColor: AppTheme.petalWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(
                      'Return Home',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String label,
    required num? time,
    required bool isWinner,
  }) {
    final displayTime = time != null ? (time / 1000).toStringAsFixed(2) : '--';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWinner
              ? AppTheme.blushGold.withValues(alpha: 0.5)
              : AppTheme.moonlight.withValues(alpha: 0.18),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.petalWhite,
            ),
          ),
          Row(
            children: [
              Text(
                '${displayTime}s',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isWinner ? AppTheme.blushGold : AppTheme.roseQuartz,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded, color: AppTheme.blushGold, size: 20),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
