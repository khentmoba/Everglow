import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/user_mood.dart';
import '../../data/services/mood_service.dart';
import '../../../../core/services/auth_service.dart';

class PartnerStatusIndicator extends StatelessWidget {
  const PartnerStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final partnerUsername = authService.partnerUsername ?? '';
    final partnerName = authService.partnerName;

    return StreamBuilder<UserMood?>(
      stream: context.read<MoodService>().watchLatestMood(partnerUsername),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final mood = snapshot.data!;
        final score = mood.moodScore;

        return Tooltip(
          message: '$partnerName is feeling ${mood.moodEmoji}',
          child: _MoodHeart(score: score, emoji: mood.moodEmoji),
        );
      },
    );
  }
}

class _MoodHeart extends StatefulWidget {
  final int score;
  final String emoji;

  const _MoodHeart({required this.score, required this.emoji});

  @override
  State<_MoodHeart> createState() => _MoodHeartState();
}

class _MoodHeartState extends State<_MoodHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStressed = widget.score <= 2;
    final isAmazing = widget.score == 5;

    // 54px glass circle: matches kTopActionsSize in dashboard_overlays so
    // the partner heart sits level with the mood / canvas / chat buttons.
    // Only the inner emoji pulses — the outer ring never moves.
    return RepaintBoundary(
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            if (isAmazing)
              const BoxShadow(
                color: Colors.pinkAccent,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            if (isStressed)
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Text(
              widget.emoji,
              style: TextStyle(
                fontSize: isAmazing ? 26 : 22,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
