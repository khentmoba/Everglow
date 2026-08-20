import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class RagPreview extends StatelessWidget {
  const RagPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/rag'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.auroraLilac.withValues(alpha: 0.18))),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.auroraLilac.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.search_rounded, color: AppColors.auroraLilac, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Everglow', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                  const SizedBox(height: 4),
                  Text('Khoj RAG • ask anything: “What was our favorite ramen?”', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.auroraLilac, size: 20),
          ],
        ),
      ),
    );
  }
}
