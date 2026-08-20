import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/vault/data/services/vault_service.dart';

class VaultPreview extends StatelessWidget {
  const VaultPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = VaultService();
    return FutureBuilder<Map<String, int>>(
      future: service.getStorageStats(),
      builder: (context, snap) {
        final count = snap.data?['count'] ?? 0;
        final bytes = snap.data?['bytes'] ?? 0;
        final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
        return GestureDetector(
          onTap: () => context.push('/vault'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.18))),
            child: Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.auroraTeal.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.folder_special_rounded, color: AppColors.auroraTeal, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vault', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                      const SizedBox(height: 4),
                      Text(count == 0 ? 'No files yet — private drive for tickets & memories' : '$count files • $mb MB', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.auroraTeal, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
