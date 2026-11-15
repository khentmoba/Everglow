import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/motchi_minis_service.dart';
import '../../data/services/study_artifact.dart';
import 'canvas_html_view.dart';

Future<void> openCanvasPreview(BuildContext context, HtmlArtifact app) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= 1024) {
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
              _SaveMiniButton(app: app),
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

class _SaveMiniButton extends StatefulWidget {
  final HtmlArtifact app;

  const _SaveMiniButton({required this.app});

  @override
  State<_SaveMiniButton> createState() => _SaveMiniButtonState();
}

class _SaveMiniButtonState extends State<_SaveMiniButton> {
  bool _saved = false;
  bool _busy = false;

  Future<void> _save() async {
    if (_saved || _busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      final by = context.read<AuthService>().currentUser ?? 'motchi';
      ok = await MotchiMinisService().saveMini(
        title: widget.app.title,
        html: widget.app.html,
        createdBy: by,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Saved to Motchi\'s Minis 🍡' : 'Could not save — try again?',
          style: AppTypography.bodySmall(),
        ),
        backgroundColor: ok ? AppColors.velvet : AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        margin: const EdgeInsets.all(AppSpacing.lg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _saved ? 'Saved to Minis' : 'Save to Minis',
      onPressed: _save,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_add_outlined,
            ),
      color: _saved ? AppColors.blushGold : AppColors.textMuted,
    );
  }
}

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
