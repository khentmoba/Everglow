import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/study_artifact.dart';
import 'canvas_html_view.dart';

/// Preview canvas — the Google-Canvas moment for Mochi's mini-apps.
///
/// When her reply carries an `html-artifact` block (a game, a page, a tool),
/// the bubble shows one big "Preview 🔍" button instead of raw code.
/// Tapping opens this sheet with the app actually running inside a
/// sandboxed frame:
///
/// - Phone / tablet (Clair's world): a near-full bottom sheet she can drag.
/// - Desktop: a centered wide dialog, same content.
Future<void> openCanvasPreview(BuildContext context, HtmlArtifact app) {
  final sheet = CanvasPreviewSheet(app: app);
  if (MediaQuery.sizeOf(context).width >= 1024) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: _PreviewChrome(child: sheet),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, controller) => _PreviewChrome(child: sheet),
    ),
  );
}

class _PreviewChrome extends StatelessWidget {
  final Widget child;

  const _PreviewChrome({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.x2),
          bottom: Radius.circular(AppRadius.x2),
        ),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class CanvasPreviewSheet extends StatelessWidget {
  final HtmlArtifact app;

  const CanvasPreviewSheet({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.moonlight.withValues(alpha: 0.25),
            borderRadius: AppRadius.radiusFull,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.title,
                      style: AppTypography.titleLarge().copyWith(fontSize: 20),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Made by Mochi · runs safely in a sandbox',
                      style: AppTypography.bodySmall().copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Back to chat',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ClipRRect(
              borderRadius: AppRadius.radiusLg,
              child: Container(
                constraints: const BoxConstraints(minHeight: 320),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.border),
                ),
                child: CanvasHtmlView(html: app.html),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
