import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';


/// Zone header for distilled dashboard — replaces repetitive FeatureSection
/// headers with a single breathable label per zone.
///
/// 4 zones: Today / Together / Our World / Play
/// Each zone groups 3-5 related previews so the dashboard reads as
/// a story, not a warehouse inventory.
class DashboardZoneHeader extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color hue;
  final Widget? trailing;

  const DashboardZoneHeader({
    super.key,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hue,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 24.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow + rule
          Row(
            children: [
              Container(
                width: 22,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      hue.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: hue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: hue.withValues(alpha: 0.20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 11, color: hue),
                    const SizedBox(width: 6),
                    Text(
                      label.toUpperCase(),
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: hue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.moonlight.withValues(alpha: 0.07),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(
                      title,
                      style: AppTypography.cormorantBold.copyWith(
                        fontSize: 26,
                        height: 1.0,
                        letterSpacing: -0.3,
                        color: AppColors.petalWhite,
                      ),
                    )),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite.withValues(alpha: 0.52),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // ignore: use_null_aware_elements
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

/// Light pair container for 2-across previews on wide screens.
/// Stacks vertically on mobile.
class DashboardPair extends StatelessWidget {
  final Widget left;
  final Widget right;

  const DashboardPair({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: right),
              ],
            ),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: left,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: right,
            ),
          ],
        );
      },
    );
  }
}
