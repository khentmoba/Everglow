import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Fallback screen for unmatched routes.
class AppErrorPage extends StatelessWidget {
  const AppErrorPage({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.petalWhite,
            ),
            const SizedBox(height: 24),
            Text(
              'Page not found',
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: 28,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              uri.toString(),
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 14,
                color: AppColors.petalWhite.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => GoRouter.of(context).go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepRose,
                foregroundColor: AppColors.petalWhite,
              ),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
