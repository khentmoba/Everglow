import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Reusable empty/loading/error/offline state widgets for feature screens.
/// Use these instead of ad-hoc inline states for consistency.

/// Centered loading spinner with optional message.
class EverglowLoadingState extends StatelessWidget {
  final String? message;
  const EverglowLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.deepRose,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                color: AppColors.roseQuartz.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state with retry button.
class EverglowErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const EverglowErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.roseQuartz.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 14,
                color: AppColors.roseQuartz.withValues(alpha: 0.8),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Try again', style: AppTypography.outfitBold),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepRose,
                  foregroundColor: AppColors.petalWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline state with connectivity message.
class EverglowOfflineState extends StatelessWidget {
  final VoidCallback? onRetry;

  const EverglowOfflineState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EverglowErrorState(
      message:
          'You appear to be offline.\nCheck your connection and try again.',
      onRetry: onRetry,
    );
  }
}

/// Empty state with icon and message.
class EverglowEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EverglowEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.roseQuartz.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 14,
                color: AppColors.roseQuartz.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}