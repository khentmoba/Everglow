import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Recent microphone levels, painted without rebuilding the chat.
class MotchiVoiceWaveform extends StatelessWidget {
  final ValueListenable<List<double>> levels;

  const MotchiVoiceWaveform({super.key, required this.levels});

  @override
  Widget build(BuildContext context) {
    final reduced =
        AppMotion.reduced || MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(100, 36),
                painter: _VoicePainter(levels, reduced: reduced),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Listening · English',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.roseQuartz,
                    ),
                  ),
                  Text('Tap Stop to review', style: AppTypography.bodySmall()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoicePainter extends CustomPainter {
  final ValueListenable<List<double>> levels;
  final bool reduced;

  _VoicePainter(this.levels, {required this.reduced}) : super(repaint: levels);

  @override
  void paint(Canvas canvas, Size size) {
    final values = levels.value;
    if (values.isEmpty) return;
    final step = size.width / values.length;
    final active = values.last > 0.03;
    final paint = Paint()
      ..color = reduced && !active ? AppColors.textMuted : AppColors.roseQuartz;
    for (var i = 0; i < values.length; i++) {
      final height = reduced ? 4.0 : 4 + values[i].clamp(0.0, 1.0) * 28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * step, (size.height - height) / 2, 3, height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoicePainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.reduced != reduced;
}
