import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/garden_provider.dart';
import 'lily_painter.dart';

class DailyBloom extends StatefulWidget {
  const DailyBloom({super.key});

  @override
  State<DailyBloom> createState() => _DailyBloomState();
}

class _DailyBloomState extends State<DailyBloom> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  bool _showTooltip = false;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  void _toggleTooltip() {
    setState(() {
      _showTooltip = !_showTooltip;
    });
    if (_showTooltip) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showTooltip = false);
      });
    }
  }

  String _getTooltipMessage(int stage) {
    switch (stage) {
      case 0:
      case 1:
        return "A tiny sprout! Keep visiting to help it grow. 🌱";
      case 2:
      case 3:
        return "A bud is forming! Your love is working. 🌸";
      case 4:
        return "It's starting to bloom! Almost there. ✨";
      case 5:
        return "Magnificent! Your lily is in full bloom. 💖";
      default:
        return "Your lily is feeling loved! 🌸";
    }
  }

  // For stage change pulse
  double _scale = 1.0;

  @override
  void didUpdateWidget(DailyBloom oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This doesn't catch provider changes, using Consumer logic instead
  }

  void _triggerPulse() {
    setState(() => _scale = 1.2);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GardenProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;
        final stage = stats?.currentStage ?? 0;

        // Check for level-up to trigger pulse (simple approach)
        // In a real app, we might store previousStage in state
        
        return Column(
          children: [
            SizedBox(
              height: 260, // Increased height to accommodate tooltip + lily
              width: double.infinity,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Tooltip - Positioned at the top of the Stack
                  if (_showTooltip)
                    Positioned(
                      top: 0,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, -10 * (1 - value)),
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.pink[50],
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.pink.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.pink[100]!, width: 1),
                                ),
                                child: Text(
                                  _getTooltipMessage(stage),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.pink[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Lily - Positioned at the bottom of the Stack
                  Positioned(
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () {
                        _toggleTooltip();
                        _triggerPulse();
                      },
                      child: AnimatedScale(
                        scale: _scale,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: AnimatedBuilder(
                          animation: _breathingController,
                          builder: (context, child) {
                            return SizedBox(
                              height: 180,
                              width: 180,
                              child: AnimatedSwitcher(
                                duration: const Duration(seconds: 1),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(scale: animation, child: child),
                                  );
                                },
                                child: CustomPaint(
                                  key: ValueKey(stage),
                                  size: const Size(180, 180),
                                  painter: LilyPainter(
                                    stage: stage,
                                    animationValue: _breathingController.value,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Interaction Stats
            if (stats != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(Icons.flash_on, '${stats.streakCount} day streak'),
                    const SizedBox(width: 12),
                    _buildStatChip(Icons.favorite, '${stats.totalInteractions} interactions'),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.pink[50]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.pink[300]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.pink[900],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
