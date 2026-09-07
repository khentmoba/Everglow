import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';

/// Non-web fallback: the live preview only runs inside the browser.
class CanvasHtmlView extends StatelessWidget {
  final String html;

  const CanvasHtmlView({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Live preview needs the web app — open Everglow in a browser to play this.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium().copyWith(
            color: AppColors.textMuted,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
