import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import 'everglow_button.dart';

/// Unified error state for ALL screens.
///
/// Shows an icon + message + Retry button + optional "Open in browser" escape.
/// Replaces raw `Text('Error: $e')` and silent failures.
class EverglowErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final String? externalUrl;
  final IconData icon;

  const EverglowErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.externalUrl,
    this.icon = Icons.cloud_off_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.velvet.withValues(alpha: 0.5),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    color: AppColors.error.withValues(alpha: 0.15),
                  ),
                ],
              ),
              child: Icon(icon, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Something went wrong',
              style: AppTypography.headlineSmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.x2),
              EverglowButton(
                label: retryLabel ?? 'Retry',
                icon: Icons.refresh,
                onPressed: onRetry!,
              ),
            ],
            if (externalUrl != null) ...[
              const SizedBox(height: AppSpacing.md),
              EverglowButton.ghost(
                label: 'Open in browser',
                icon: Icons.open_in_new,
                onPressed: () async {
                  final uri = Uri.tryParse(externalUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
