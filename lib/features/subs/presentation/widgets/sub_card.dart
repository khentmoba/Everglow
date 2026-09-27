import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/text_utils.dart';
import '../../data/models/subscription.dart';

/// Hue per payer, so Clair can tell at a glance who pays what.
Color subPayerHue(SubPayer payer) => switch (payer) {
      SubPayer.khent => AppColors.auroraTeal,
      SubPayer.clair => AppColors.auroraRose,
      SubPayer.shared => AppColors.blushGold,
    };

/// One subscription row: name + price, payer chip, renewal countdown.
class SubCard extends StatelessWidget {
  final Subscription sub;
  final VoidCallback onTap;

  const SubCard({super.key, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = sub.daysUntilRenewal();
    final hue = subPayerHue(sub.payer);
    final urgent = days <= 3;
    return Semantics(
      button: true,
      label: '${sub.name}, ${formatPeso(sub.price)}${sub.cycleSuffix}, '
          'renews ${_renewalLabel(days)}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.92),
                AppColors.inkDeep.withValues(alpha: 0.92),
              ],
            ),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(
              color: urgent
                  ? AppColors.error.withValues(alpha: 0.45)
                  : AppColors.moonlight.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              // Price monogram: first letter on a payer-tinted disc.
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hue.withValues(alpha: 0.14),
                  border: Border.all(color: hue.withValues(alpha: 0.45)),
                ),
                child: Text(
                  sub.name.isEmpty ? '✨' : sub.name[0].toUpperCase(),
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 20,
                    color: hue,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name.isEmpty ? 'Unnamed' : sub.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 15,
                        color: AppColors.petalWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${formatPeso(sub.price)}${sub.cycleSuffix}',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 12,
                            color: AppColors.blushGold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: hue.withValues(alpha: 0.12),
                            borderRadius: AppRadius.radiusFull,
                            border: Border.all(
                              color: hue.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            sub.payer.displayName,
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 10,
                              color: hue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RenewalPill(days: days),
            ],
          ),
        ),
      ),
    );
  }
}

/// Countdown pill: "today", "in 3d", or the date when far away.
class _RenewalPill extends StatelessWidget {
  final int days;
  const _RenewalPill({required this.days});

  @override
  Widget build(BuildContext context) {
    final urgent = days <= 3;
    final soon = days <= 7;
    final color = urgent
        ? AppColors.error
        : soon
            ? AppColors.warmAmber
            : AppColors.petalWhite.withValues(alpha: 0.65);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? Icons.alarm_rounded : Icons.refresh_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _renewalLabel(days),
            style: AppTypography.outfitBold.copyWith(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _renewalLabel(int days) {
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in ${days}d';
}
