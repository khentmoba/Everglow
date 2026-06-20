import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'shelf_widgets.dart';

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

  /// Pixel height reserved for the marquee. Defaults to 168 to match
  /// the existing dashboard previews.
  final double height;

  const PartnerSubrow({
    Key? key,
    required this.label,
    required this.children,
    required this.accent,
    this.emptyMessage = 'Nothing here yet.',
    this.height = 168,
  }) : super(key: key);

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
    return Row(
      children: [
        Container(
          width: 22,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.color,
                accent.color.withValues(alpha: 0.0),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: accent.color,
            letterSpacing: 1.8,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.outfit(
          color: AppTheme.roseQuartz.withValues(alpha: 0.65),
          fontStyle: FontStyle.italic,
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }
}
