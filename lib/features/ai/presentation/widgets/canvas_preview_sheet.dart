import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/study_artifact.dart';
import 'canvas_html_view.dart';

/// Preview canvas — the Google-Canvas moment for Motchi's mini-apps.
///
/// When her reply carries an `html-artifact` block (a game, a page, a tool),
/// the bubble shows one big "Preview 🔍" button instead of raw code.
/// Tapping opens this sheet with the app actually running inside a
/// sandboxed frame:
///
/// - Phone / tablet (Clair's world): a near-full bottom sheet she can drag.
/// - Desktop: a near-full-screen takeover, so games get real room instead
///   of a cramped centered box.
Future<void> openCanvasPreview(BuildContext context, HtmlArtifact app) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= 1024) {
    // Near-full-screen: a fixed-size stage leaves games no dead margins.
    // The sheet fills it via [CanvasPreviewSheet.expanded].
    final stageWidth = size.width - 32;
    final stageHeight = size.height - 32;
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: stageWidth,
          height: stageHeight,
          child: _PreviewChrome(
            child: CanvasPreviewSheet(app: app, expanded: true),
          ),
        ),
      ),
    );
  }
  final sheet = CanvasPreviewSheet(app: app);
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

  /// When true the sheet fills a fixed-size stage (desktop takeover) and
  /// the game frame expands to use it. When false (draggable mobile
  /// sheet) the column wraps its content as before.
  final bool expanded;

  const CanvasPreviewSheet({super.key, required this.app, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
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
                      'Made by Motchi · runs safely in a sandbox',
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
        _PreviewFrame(expanded: expanded, html: app.html),
      ],
    );
  }
}

/// The framed game/app area. In `expanded` mode (fixed desktop stage) it
/// takes all remaining height so the game fills the screen; otherwise it
/// keeps the old wrap-content behavior with a minimum height.
class _PreviewFrame extends StatelessWidget {
  final bool expanded;
  final String html;

  const _PreviewFrame({required this.expanded, required this.html});

  @override
  Widget build(BuildContext context) {
    final frame = Padding(
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
          child: CanvasHtmlView(html: html),
        ),
      ),
    );
    if (!expanded) return Flexible(child: frame);
    return Expanded(child: frame);
  }
}
