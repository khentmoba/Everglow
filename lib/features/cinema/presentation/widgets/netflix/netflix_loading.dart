import 'package:flutter/material.dart';

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/everglow/everglow_skeleton.dart';
import 'netflix_colors.dart';

Widget _bar({required double width, double height = 16}) => EverglowSkeleton(
  width: width,
  height: height,
  radius: 4,
  animateOnPhone: true,
  baseColor: NetflixColors.surfaceElevated,
  highlightColor: NetflixColors.hairline,
);

/// Keep the large surfaces still; only small bars repaint during loading.
class NetflixLoadingBillboard extends StatelessWidget {
  const NetflixLoadingBillboard({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = AppBreakpoint.isDesktop(context);
    final height = desktop
        ? 560.0
        : (MediaQuery.sizeOf(context).height * 0.58).clamp(380.0, 540.0);
    return Semantics(
      label: 'Loading featured movies',
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NetflixColors.surface, NetflixColors.background],
          ),
        ),
        alignment: Alignment.bottomLeft,
        padding: EdgeInsets.fromLTRB(desktop ? 48 : 16, 80, 16, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finding your next watch',
              style: AppTypography.outfitHeading.copyWith(
                color: NetflixColors.textSecondary,
                fontSize: desktop ? 24 : 20,
              ),
            ),
            const SizedBox(height: 18),
            _bar(width: desktop ? 320 : 220, height: 28),
            const SizedBox(height: 12),
            _bar(width: 160),
            const SizedBox(height: 24),
            Row(
              children: [
                _bar(width: 104, height: 44),
                const SizedBox(width: 12),
                _bar(width: 120, height: 44),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NetflixLoadingRow extends StatelessWidget {
  final String title;

  const NetflixLoadingRow({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final desktop = AppBreakpoint.isDesktop(context);
    final pad = desktop ? 48.0 : 16.0;
    final width = desktop ? 172.0 : 124.0;
    return Semantics(
      label: 'Loading $title',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 26, pad, 12),
              child: Text(
                title,
                style: AppTypography.outfitHeading.copyWith(
                  color: NetflixColors.textPrimary,
                  fontSize: desktop ? 20 : 17,
                  letterSpacing: 0,
                ),
              ),
            ),
            SizedBox(
              height: width * 1.5 + 6,
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: desktop ? 6 : 7,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, _) => Container(
                  width: width,
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.bottomLeft,
                  decoration: BoxDecoration(
                    color: NetflixColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _bar(width: width - 24, height: 6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
