import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/desktop_app_action.dart';
import '../../../../shared/widgets/everglow/everglow_app_bar.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';

class DesktopAppScreen extends StatelessWidget {
  const DesktopAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EverglowScaffold(
      centerMaxWidth: 560,
      appBar: EverglowAppBar(
        title: 'Desktop App',
        onBackPressed: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.card,
        child: Column(
          children: [
            const Icon(
              Icons.desktop_windows_rounded,
              size: 48,
              color: AppColors.blushGold,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text('Everglow for Windows', style: AppTypography.headlineMedium()),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Download the desktop app or check for updates here whenever you need them.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(),
            ),
            const SizedBox(height: AppSpacing.x2),
            const DesktopAppAction(),
          ],
        ),
      ),
    );
  }
}
