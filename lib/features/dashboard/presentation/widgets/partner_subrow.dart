import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'shelf_widgets.dart';
import '../../../../core/theme/app_typography.dart';

/// One labeled horizontal rail inside a dashboard shelf, used to render
/// the per-partner sub-rows that split each shelf into "Me" and the
/// partner's contribution. Visual contract:
///
///   ME:        ▭ ▭ ▭ ▭ ▭ ▭        (small uppercase eyebrow + marquee)
///
/// For couple users each dashboard shelf renders two of these back to
/// back — first the viewer's own ("Me"), then their partner's. For
/// non-couple users the parent preview keeps the original single-row
/// layout and does not include this widget.
class PartnerSubrow extends StatelessWidget {
  /// Eyebrow text shown above the rail. Typically `"ME"`, `"KHENT"`,
  /// or `"CLAIR"` — caller is responsible for the right label.
  final String label;

  /// Pre-built [ShelfCard] widgets to render in the marquee. Pass an
  /// empty list to render the empty-state line instead.
  final List<Widget> children;

  /// Accent used to tint the eyebrow and the empty-state line. Should
  /// match the parent shelf's [ShelfAccent] for visual continuity.
  final ShelfAccent accent;

  /// Optional friendly message shown when [children] is empty. Set to
  /// `null` to render the sub-row as a completely empty (invisible)
  /// gap — useful if the parent wants to hide partner sub-rows that
  /// would otherwise be empty.
  final String? emptyMessage;

  /// Pixel height reserved for the marquee. Defaults to 194 to match
  /// the taller 128×186 ShelfCard with hover lift + shadow.
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
            SizedBox(
              height: height,
              child: ShelfMarquee(children: children),
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
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isMe
                  ? accent.color.withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.10),
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
                      : AppTheme.petalWhite.withValues(alpha: 0.72),
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
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
                color: AppTheme.petalWhite.withValues(alpha: 0.48),
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
