import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'shelf_widgets.dart';
import '../../../../shared/widgets/everglow/everglow_marquee.dart';
import '../../../../core/theme/app_typography.dart';

class PartnerSubrow extends StatelessWidget {
  final String label;

  final List<Widget> children;

  final ShelfAccent accent;

  final String? emptyMessage;

  final double height;

  const PartnerSubrow({
    super.key,
    required this.label,
    required this.children,
    required this.accent,
    this.emptyMessage = 'Nothing here yet.',
    this.height = 194,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems = children.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubrowLabel(label: label, accent: accent),
          const SizedBox(height: 8),
          if (hasItems)
            EverglowMarquee(
              height: height,
              children: children.take(12).toList(),
            )
          else if (emptyMessage != null)
            _SubrowEmptyLine(message: emptyMessage!, accent: accent)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _SubrowLabel extends StatelessWidget {
  final String label;
  final ShelfAccent accent;
  const _SubrowLabel({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isMe = label.toUpperCase() == 'ME';
    return Row(
      children: [
        Container(
          width: 28,
          height: 1.2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.color.withValues(alpha: 0.0),
                accent.color.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isMe
                ? accent.color.withValues(alpha: 0.14)
                : AppColors.petalWhite.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isMe
                  ? accent.color.withValues(alpha: 0.32)
                  : AppColors.petalWhite.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.color.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isMe
                      ? accent.color
                      : AppColors.petalWhite.withValues(alpha: 0.72),
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.color.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubrowEmptyLine extends StatelessWidget {
  final String message;
  final ShelfAccent accent;
  const _SubrowEmptyLine({required this.message, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.petalWhite.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.petalWhite.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.color.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.nights_stay_outlined,
              size: 13,
              color: accent.color.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.48),
                fontStyle: FontStyle.italic,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}