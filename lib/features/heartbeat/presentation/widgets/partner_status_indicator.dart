import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../data/models/user_mood.dart';
import '../../data/services/mood_service.dart';
import '../../../../core/services/auth_service.dart';

class PartnerStatusIndicator extends StatelessWidget {
  const PartnerStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final partnerUsername = context.select<AuthService, String>(
      (a) => a.partnerUsername ?? '',
    );
    final partnerName = context.select<AuthService, String>(
      (a) => a.partnerName,
    );

    return StreamBuilder<UserMood?>(
      stream: context.read<MoodService>().watchLatestMood(partnerUsername),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final mood = snapshot.data!;
        if (!mood.isCurrentAt(DateTime.now())) return const SizedBox.shrink();
        final score = mood.moodScore;

        return Tooltip(
          message: '$partnerName is feeling ${mood.moodEmoji}',
          child: InkWell(
            borderRadius: BorderRadius.circular(27),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.velvet,
              builder: (_) => _PartnerCheckIn(
                mood: mood,
                partnerName: partnerName,
                service: context.read<MoodService>(),
                username: context.read<AuthService>().currentUser ?? '',
              ),
            ),
            child: _MoodHeart(score: score, emoji: mood.moodEmoji),
          ),
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
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceAmbientMotion(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
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
              style: TextStyle(fontSize: isAmazing ? 26 : 22, height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerCheckIn extends StatefulWidget {
  final UserMood mood;
  final String partnerName;
  final MoodService service;
  final String username;
  const _PartnerCheckIn({
    required this.mood,
    required this.partnerName,
    required this.service,
    required this.username,
  });
  @override
  State<_PartnerCheckIn> createState() => _PartnerCheckInState();
}

class _PartnerCheckInState extends State<_PartnerCheckIn> {
  bool _saving = false;
  bool _acknowledged = false;
  String? _error;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.partnerName} today',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text('Feeling ${widget.mood.moodEmoji}'),
          if (widget.mood.need != null) ...[
            const SizedBox(height: 12),
            Text(widget.mood.need!.label),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.favorite_outline),
              label: Text(
                _acknowledged || widget.mood.acknowledgedBy != null
                    ? 'You let them know you are here'
                    : _saving
                    ? 'Sending...'
                    : 'I am here for you',
              ),
              onPressed:
                  _saving || _acknowledged || widget.mood.acknowledgedBy != null
                  ? null
                  : () async {
                      setState(() {
                        _saving = true;
                        _error = null;
                      });
                      try {
                        await widget.service.acknowledge(
                          widget.mood,
                          widget.username,
                        );
                        if (mounted) setState(() => _acknowledged = true);
                      } catch (_) {
                        if (mounted) {
                          setState(() => _error = 'Could not send. Try again.');
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
            ),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ),
    ),
  );
}
