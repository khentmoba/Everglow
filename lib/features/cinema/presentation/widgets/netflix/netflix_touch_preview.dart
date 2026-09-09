import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/media_item.dart';
import 'netflix_hover_preview.dart';

/// Shows the hover preview as a centered dialog for touch screens.
///
/// Desktop gets [NetflixHoverPreview] on mouse hover; phones and tablets
/// have no hover, so a long-press opens the same card (art, actions,
/// metadata) in a dialog instead. No video — just art + info + buttons.
Future<void> showTouchPreview({
  required BuildContext context,
  required MediaItem item,
  required bool inList,
  VoidCallback? onTap,
  VoidCallback? onPlay,
  ValueChanged<bool>? onToggleList,
  ValueChanged<double?>? onRate,
}) {
  HapticFeedback.lightImpact();
  final screenWidth = MediaQuery.sizeOf(context).width;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      final previewWidth = (screenWidth * 0.9).clamp(280.0, 360.0);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: NetflixHoverPreview(
          item: item,
          width: previewWidth,
          inList: inList,
          onTap: () {
            Navigator.of(dialogContext).pop();
            onTap?.call();
          },
          onPlay: onPlay == null
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  onPlay();
                },
          onToggleList: onToggleList,
          onRate: onRate,
        ),
      );
    },
  );
}
