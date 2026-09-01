import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/vault/data/services/vault_service.dart';
import 'feature_section.dart';

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
        final mb = (bytes / (1024 * 1024));
        final mbStr = mb < 0.1
            ? '${(bytes / 1024).toStringAsFixed(0)} KB'
            : '${mb.toStringAsFixed(1)} MB';
        final limitMb = 500.0;
        final pct = (mb / limitMb).clamp(0.0, 1.0);

        final subtitle = count == 0
            ? 'No files yet — private drive for tickets & memories'
            : '$count files • $mbStr';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.folder_special_rounded,
            hue: AppColors.auroraTeal,
            title: 'Vault',
            subtitle: subtitle,
            trailing: const SectionChevron(hue: AppColors.auroraTeal),
            onTap: () => context.push('/vault'),
            child: count == 0
                ? const _EmptyVault(hue: AppColors.auroraTeal)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _VaultTypeIcon(
                            icon: Icons.image_rounded,
                            hue: AppColors.auroraTeal,
                            label: 'IMG',
                          ),
                          const SizedBox(width: 8),
                          const _VaultTypeIcon(
                            icon: Icons.picture_as_pdf_rounded,
                            hue: AppColors.warmAmber,
                            label: 'PDF',
                          ),
                          const SizedBox(width: 8),
                          const _VaultTypeIcon(
                            icon: Icons.video_file_rounded,
                            hue: AppColors.softLavender,
                            label: 'VID',
                          ),
                          const Spacer(),
                          Text(
                            mbStr,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct == 0 ? 0.04 : pct,
                          minHeight: 6,
                          backgroundColor: AppColors.petalWhite.withValues(alpha: 0.07),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.auroraTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}% of vault used • ${limitMb.toStringAsFixed(0)} MB limit',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 10,
                          color: AppColors.petalWhite.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _VaultTypeIcon extends StatelessWidget {
  final IconData icon;
  final Color hue;
  final String label;
  const _VaultTypeIcon({
    required this.icon,
    required this.hue,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: hue.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: hue),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 9,
              letterSpacing: 0.6,
              color: hue,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  final Color hue;
  const _EmptyVault({required this.hue});

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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.cloud_upload_rounded, size: 14, color: hue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drop tickets, IDs, receipts',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.petalWhite.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  'Encrypted, just for you two.',
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
