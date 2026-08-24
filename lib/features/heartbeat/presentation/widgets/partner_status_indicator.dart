import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
            ],
          ),
          child: Text(
            widget.emoji,
            style: TextStyle(fontSize: isAmazing ? 28 : 20),
          ),
        ),
      ),
    );
  }
}
