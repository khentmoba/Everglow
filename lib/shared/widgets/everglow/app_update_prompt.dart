import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import '../../../core/system/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Wraps the whole app and shows a warm "fresh version" banner when
/// [AppUpdateService] spots a newer build on the server.
///
/// Long-lived tabs would otherwise run yesterday's app forever: entry points
/// are `no-cache` but an already-loaded tab never re-fetches them. The banner
/// nudges a one-tap reload instead.
class AppUpdatePrompt extends StatelessWidget {
  final Widget child;

  const AppUpdatePrompt({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppUpdateService()..start(),
      child: Stack(
        children: [
          child,
          const Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: 92,
            child: _UpdateBanner(),
          ),
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  void _reload() {
    if (kIsWeb) web.window.location.reload();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AppUpdateService>();
    if (!service.updateAvailable) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        borderRadius: AppRadius.radiusLg,
        color: AppColors.deepRose,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const Text('💗', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'A fresh Everglow just landed — reload to see it.',
                  style: AppTypography.bodyMedium().copyWith(
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
              TextButton(
                onPressed: _reload,
                child: Text(
                  'Reload',
                  style: AppTypography.bodyMedium().copyWith(
                    color: AppColors.blushGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: service.dismiss,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.petalWhite,
                ),
                tooltip: 'Later',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
