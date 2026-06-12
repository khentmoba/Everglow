import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/garden_provider.dart';
import 'lily_painter.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
        
        return Column(
          children: [
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Tooltip
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
                                constraints: const BoxConstraints(maxWidth: 220),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.velvet,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.3), width: 1.5),
                                ),
                                child: Text(
                                  _getTooltipMessage(stage),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.roseQuartz,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Lily
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
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.moonlight.withValues(alpha: 0.15), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.blushGold),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.petalWhite.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
