import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import 'feature_section.dart';

class RagPreview extends StatelessWidget {
  const RagPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FeatureSection(
        icon: Icons.search_rounded,
        hue: AppColors.auroraLilac,
        title: 'Ask Everglow',
        subtitle: 'Khoj RAG • “What was our favorite ramen?”',
        trailing: const SectionChevron(hue: AppColors.auroraLilac),
        onTap: () => context.push('/rag'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Faux search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.petalWhite.withValues(alpha: 0.06),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: AppColors.auroraLilac.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.auroraLilac.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: AppColors.auroraLilac.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ask anything about your memories…',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.petalWhite.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.auroraLilac.withValues(alpha: 0.22),
                          AppColors.auroraLilac.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.auroraLilac.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 10,
                          color: AppColors.auroraLilac,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ASK',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 9,
                            letterSpacing: 0.7,
                            color: AppColors.auroraLilac,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Suggestion chips
            const Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _SuggestionChip(
                  icon: Icons.favorite_rounded,
                  label: 'Our song?',
                  hue: AppColors.auroraRose,
                ),
                _SuggestionChip(
                  icon: Icons.restaurant_rounded,
                  label: 'Favorite ramen',
                  hue: AppColors.warmAmber,
                ),
                _SuggestionChip(
                  icon: Icons.calendar_month_rounded,
                  label: 'First date',
                  hue: AppColors.auroraLilac,
                ),
                _SuggestionChip(
                  icon: Icons.photo_rounded,
                  label: 'Beach photos',
                  hue: AppColors.auroraTeal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color hue;
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.hue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hue.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: hue),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.petalWhite.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
