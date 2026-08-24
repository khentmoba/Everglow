import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/budget/data/services/budget_service.dart';
import 'feature_section.dart';

class BudgetPreview extends StatelessWidget {
  const BudgetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BudgetService();
    final now = DateTime.now();
    return StreamBuilder(
      stream: service.watchMonth(DateTime(now.year, now.month)),
      builder: (context, snap) {
        final txs = snap.data ?? [];
        final byCat = service.byCategory(txs);
        final spent = byCat.values.fold(0.0, (a, b) => a + b);
        final owes = service.computeOwes(txs);
        final khentOwes = owes['khentsgdz'] ?? 0;
        final clairOwes = owes['clairjassen'] ?? 0;
        final settled = khentOwes.abs() < 1 && clairOwes.abs() < 1;
        final owesStr = settled
            ? 'All settled'
            : khentOwes > 0
            ? 'Khent owes ₱${khentOwes.toStringAsFixed(0)}'
            : 'Clair owes ₱${clairOwes.toStringAsFixed(0)}';

        final subtitle = txs.isEmpty
            ? 'No transactions this month'
            : '₱${spent.toStringAsFixed(0)} spent • $owesStr';

        // Category colors for bar segments
        const catColors = [
          AppColors.warmAmber,
          AppColors.auroraRose,
          AppColors.auroraTeal,
          AppColors.softLavender,
          AppColors.auroraGold,
          AppColors.blushGold,
        ];

        final sortedCats = byCat.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCats = sortedCats.take(4).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.account_balance_wallet_rounded,
            hue: AppColors.warmAmber,
            title: 'Budget',
            subtitle: subtitle,
            trailing: const SectionChevron(hue: AppColors.warmAmber),
            onTap: () => context.push('/budget'),
            child: txs.isEmpty
                ? const _EmptyBudget(hue: AppColors.warmAmber)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Segmented bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              for (int i = 0; i < topCats.length; i++)
                                Expanded(
                                  flex: (topCats[i].value * 100).round().clamp(
                                    1,
                                    100,
                                  ),
                                  child: Container(
                                    color: catColors[i % catColors.length],
                                  ),
                                ),
                              if (topCats.isEmpty)
                                Expanded(
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Category pills
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (int i = 0; i < topCats.length; i++)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: catColors[i % catColors.length]
                                    .withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: catColors[i % catColors.length]
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: catColors[i % catColors.length],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    topCats[i].key,
                                    style: AppTypography.outfitBold.copyWith(
                                      fontSize: 10,
                                      color: catColors[i % catColors.length],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '₱${topCats[i].value.toStringAsFixed(0)}',
                                    style: AppTypography.outfitWhite.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.petalWhite.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (!settled) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warmAmber.withValues(alpha: 0.09),
                            borderRadius: AppRadius.radiusSm,
                            border: Border.all(
                              color: AppColors.warmAmber.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.warmAmber.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.handshake_rounded,
                                  size: 12,
                                  color: AppColors.warmAmber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  owesStr,
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 11,
                                    color: AppColors.warmAmber,
                                  ),
                                ),
                              ),
                              Text(
                                '${txs.length} tx',
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10,
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyBudget extends StatelessWidget {
  final Color hue;
  const _EmptyBudget({required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.07),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 18,
            color: hue.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track date nights & groceries',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.petalWhite.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  'Split fairly — no mental math.',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10,
                    color: AppColors.petalWhite.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
