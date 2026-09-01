import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Slow diagonal light sweep used on podium rows and champion surfaces.
class StatsShimmer extends StatefulWidget {
  final Color color;
  const StatsShimmer({super.key, required this.color});
  @override
  State<StatsShimmer> createState() => _StatsShimmerState();
}

class _StatsShimmerState extends State<StatsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _a = Tween<double>(
      begin: -1.2,
      end: 1.8,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (c, _) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(_a.value, -0.6),
          end: Alignment(_a.value + 0.35, 0.8),
          colors: [
            Colors.transparent,
            Colors.transparent,
            AppColors.petalWhite.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [0, 0.42, 0.5, 0.58, 1],
        ),
      ),
    ),
  );
}

class StatsSparkleBadge extends StatefulWidget {
  final Color color;
  const StatsSparkleBadge({super.key, required this.color});
  @override
  State<StatsSparkleBadge> createState() => _StatsSparkleBadgeState();
}

class _StatsSparkleBadgeState extends State<StatsSparkleBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: 0.55,
      end: 1,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: ScaleTransition(
      scale: Tween<double>(
        begin: 0.88,
        end: 1.08,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 13,
        color: widget.color.withValues(alpha: 0.95),
      ),
    ),
  );
}