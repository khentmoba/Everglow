import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'stats_fx.dart';

/// Leaderboard header with total listens pill and animated 1ST champion badge.
///
/// The header always shows the user's name and subtitle. When [totalPlays] is
/// available a pill with the formatted count is shown on the trailing side.
/// When [isLeader] is true the whole header is wrapped in a shimmering gold
/// treatment and a pulsing "1ST" crown badge appears with particle sparkles
/// so the current listening champion is instantly recognisable.
class LeaderboardHeader extends StatelessWidget {
  final String displayName;
  final String username;
  final int totalPlays;
  final bool isLeader;
  final bool isClair;

  const LeaderboardHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.totalPlays,
    required this.isLeader,
    this.isClair = false,
  });

  bool get _isPink => isClair;

  @override
  Widget build(BuildContext context) {
    final hasTotal = totalPlays > 0;
    final formatted = NumberFormat.decimalPattern().format(totalPlays);
    final Color accentGold = AppColors.auroraGold;
    final Color accentPinkLight = AppColors.auroraRose;
    final Color championAccent = _isPink ? accentPinkLight : accentGold;
    final headerRow = LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final titleColumn = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      "$displayName's Top 10",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cormorantBoldWhite.copyWith(
                        fontSize: 21,
                        height: 1.05,
                        shadows: isLeader
                            ? [
                                Shadow(
                                  color: championAccent.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  if (isLeader) ...[
                    const SizedBox(width: 6),
                    _HeaderCrownSparkle(isPink: _isPink),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$username · most listened all-time'.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _isPink ? AppColors.auroraRose : AppColors.blushGold,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        );

        final trailing = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTotal)
              _TotalListensPill(
                countText: formatted,
                isLeader: isLeader,
                isPink: _isPink,
              ),
            if (isLeader) ...[
              SizedBox(height: hasTotal ? 6 : 0),
              _ChampionBadge(isPink: _isPink),
            ],
          ],
        );

        if (isNarrow && hasTotal) {
          // Stack vertically on very narrow widths to avoid overflow.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LeaderboardIcon(isLeader: isLeader, isPink: _isPink),
                  const SizedBox(width: AppSpacing.md),
                  titleColumn,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _LeaderboardIcon(isLeader: isLeader, isPink: _isPink),
            const SizedBox(width: AppSpacing.md),
            titleColumn,
            const SizedBox(width: AppSpacing.md),
            Flexible(child: trailing),
          ],
        );
      },
    );

    if (!isLeader) return headerRow;

    // Champion treatment: soft gold container with animated shimmer and floating sparkles.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.auroraGold.withValues(alpha: 0.20),
                const Color(0xFF6B4E00).withValues(alpha: 0.18),
                AppColors.inkDeep.withValues(alpha: 0.28),
              ],
            ),
            border: Border.all(
              color: championAccent.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: championAccent.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.40),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _ChampionShimmer(color: championAccent),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: headerRow,
              ),
            ],
          ),
        ),
        // Floating sparkles that orbit the champion header.
        Positioned(
          top: -7,
          right: 10,
          child: StatsSparkleBadge(color: championAccent),
        ),
        Positioned(
          top: -5,
          right: 32,
          child: _PulsingDot(color: championAccent, size: 5),
        ),
        Positioned(
          bottom: -5,
          left: 18,
          child: _PulsingDot(color: championAccent, size: 3.5),
        ),
      ],
    );
  }
}

class _LeaderboardIcon extends StatelessWidget {
  final bool isLeader;
  final bool isPink;
  const _LeaderboardIcon({required this.isLeader, this.isPink = false});

  @override
  Widget build(BuildContext context) {
    if (!isLeader) {
      if (isPink) {
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.auroraRose.withValues(alpha: 0.22),
                AppColors.cinemaPink.withValues(alpha: 0.14),
              ],
            ),
            border: Border.all(
              color: AppColors.auroraRose.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.auroraRose.withValues(alpha: 0.18),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(
            Icons.leaderboard_rounded,
            size: 18,
            color: AppColors.auroraRose,
          ),
        );
      }
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.blushGold.withValues(alpha: 0.18),
              AppColors.blushGold.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.leaderboard_rounded,
          size: 18,
          color: AppColors.blushGold,
        ),
      );
    }
    if (isPink) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE4EC), Color(0xFFFF8FAB), Color(0xFFE91E8C)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.78),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.auroraRose.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.emoji_events_rounded,
          size: 20,
          color: Color(0xFF6B0F2A),
        ),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF6CC), Color(0xFFF5C97B), Color(0xFFC49A2B)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.78),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.auroraGold.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.emoji_events_rounded,
        size: 20,
        color: Color(0xFF6B4E00),
      ),
    );
  }
}

class _HeaderCrownSparkle extends StatefulWidget {
  final bool isPink;
  const _HeaderCrownSparkle({this.isPink = false});
  @override
  State<_HeaderCrownSparkle> createState() => _HeaderCrownSparkleState();
}

class _HeaderCrownSparkleState extends State<_HeaderCrownSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.55,
        end: 1,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.9,
          end: 1.1,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 14,
          color: widget.isPink ? AppColors.auroraRose : AppColors.auroraGold,
        ),
      ),
    );
  }
}

class _TotalListensPill extends StatelessWidget {
  final String countText;
  final bool isLeader;
  final bool isPink;
  const _TotalListensPill({required this.countText, required this.isLeader, this.isPink = false});

  @override
  Widget build(BuildContext context) {
    if (isLeader) {
      if (isPink) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.auroraRose.withValues(alpha: 0.22),
                AppColors.cinemaPink.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: AppColors.auroraRose.withValues(alpha: 0.48),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.auroraRose.withValues(alpha: 0.20),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.headset_rounded,
                size: 12,
                color: AppColors.auroraRose,
              ),
              const SizedBox(width: 5),
              Text(
                countText,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  height: 1,
                  color: AppColors.auroraRose,
                  shadows: [
                    Shadow(
                      color: AppColors.auroraRose.withValues(alpha: 0.30),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'listens',
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.auroraRose.withValues(alpha: 0.85),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.auroraGold.withValues(alpha: 0.22),
              AppColors.auroraGold.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: AppColors.auroraGold.withValues(alpha: 0.48),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.auroraGold.withValues(alpha: 0.20),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.headset_rounded,
              size: 12,
              color: AppColors.auroraGold,
            ),
            const SizedBox(width: 5),
            Text(
              countText,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 12,
                height: 1,
                color: AppColors.auroraGold,
                shadows: [
                  Shadow(
                    color: AppColors.auroraGold.withValues(alpha: 0.30),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'listens',
              style: AppTypography.outfitMedium.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.auroraGold.withValues(alpha: 0.85),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }
    if (isPink) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.auroraRose.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: AppColors.auroraRose.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.headset_rounded,
              size: 12,
              color: AppColors.auroraRose,
            ),
            const SizedBox(width: 5),
            Text(
              countText,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 12,
                height: 1,
                color: AppColors.roseQuartz,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'listens',
              style: AppTypography.outfitMedium.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.roseQuartz.withValues(alpha: 0.78),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.headset_rounded,
            size: 12,
            color: AppColors.blushGold.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 5),
          Text(
            countText,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 12,
              height: 1,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'listens',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChampionBadge extends StatefulWidget {
  final bool isPink;
  const _ChampionBadge({this.isPink = false});
  @override
  State<_ChampionBadge> createState() => _ChampionBadgeState();
}

class _ChampionBadgeState extends State<_ChampionBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        final glow = 0.30 + t * 0.22;
        final scale = 1.0 + t * 0.03;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isPink
                    ? const [
                        Color(0xFFFFE4EC),
                        Color(0xFFFF8FAB),
                        Color(0xFFE91E8C),
                      ]
                    : const [
                        Color(0xFFFFF6CC),
                        Color(0xFFF5C97B),
                        Color(0xFFC49A2B),
                      ],
              ),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.78),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isPink ? AppColors.auroraRose : AppColors.auroraGold).withValues(alpha: glow),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppColors.inkDeep.withValues(alpha: 0.28),
                  blurRadius: 8,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (widget.isPink ? const Color(0xFF6B0F2A) : const Color(0xFF6B4E00)).withValues(alpha: 0.14),
                  border: Border.all(
                    color: (widget.isPink ? const Color(0xFF6B0F2A) : const Color(0xFF6B4E00)).withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 10,
                  color: widget.isPink ? const Color(0xFF6B0F2A) : const Color(0xFF6B4E00),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '1ST',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  height: 1,
                  color: widget.isPink ? const Color(0xFF6B0F2A) : const Color(0xFF6B4E00),
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.auto_awesome_rounded,
                size: 9,
                color: widget.isPink ? const Color(0xFF6B0F2A) : const Color(0xFF6B4E00),
              ),
            ],
          ),
          // Subtle shimmer sweep across the badge.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: _ChampionBadgeShimmer(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChampionBadgeShimmer extends StatefulWidget {
  @override
  State<_ChampionBadgeShimmer> createState() => _ChampionBadgeShimmerState();
}

class _ChampionBadgeShimmerState extends State<_ChampionBadgeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _a = Tween<double>(
      begin: -1.2,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_a.value, -0.6),
              end: Alignment(_a.value + 0.32, 0.8),
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.white.withValues(alpha: 0.42),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: const [0, 0.42, 0.5, 0.58, 1],
            ),
          ),
        );
      },
    );
  }
}

class _ChampionShimmer extends StatefulWidget {
  final Color color;
  const _ChampionShimmer({required this.color});
  @override
  State<_ChampionShimmer> createState() => _ChampionShimmerState();
}

class _ChampionShimmerState extends State<_ChampionShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_a.value, -0.7),
              end: Alignment(_a.value + 0.35, 0.8),
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.white.withValues(alpha: 0.10),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: const [0, 0.42, 0.5, 0.58, 1],
            ),
          ),
        );
      },
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({required this.color, required this.size});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.75,
          end: 1.15,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.55),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
