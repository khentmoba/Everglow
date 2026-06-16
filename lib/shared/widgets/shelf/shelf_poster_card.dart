import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// Shared poster card used across the four inside screens.
///
/// Honors the motion-craft + component-forge rules:
///   * Lifts (`translateY(-3px)`) and gently scales on hover /
///     press instead of a single `scale(1.5)` jump.
///   * Focus ring is drawn explicitly for keyboard users — without
///     it, focus order is invisible on touch-only devices.
///   * Animations snap to their end state when
///     `prefers-reduced-motion` is set.
///   * Wrapped in a `Semantics` button with a real label so screen
///     readers announce it correctly.
class ShelfPosterCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final IconData? badgeIcon;
  final double? rankNumber;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const ShelfPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.badgeIcon,
    this.rankNumber,
    this.onTap,
    this.semanticLabel,
  });

  @override
  State<ShelfPosterCard> createState() => _ShelfPosterCardState();
}

class _ShelfPosterCardState extends State<ShelfPosterCard> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.badgeColor ?? AppTheme.deepRose;
    final disabled = widget.onTap == null;

    // Compose the announcement: "Movie, title, year, badge"
    final announcement = [
      if (widget.badge != null) widget.badge!,
      widget.title,
      if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
        widget.subtitle!,
    ].join(', ');

    final card = AnimatedContainer(
      duration: ShelfMotion.orZero(ShelfMotion.medium),
      curve: ShelfMotion.easeOutStrong,
      transform: Matrix4.identity()
        ..translate(
          0.0,
          _hovered && !_pressed && !disabled ? -3.0 : 0.0,
        )
        ..scale(
          _pressed
              ? 0.96
              : (_hovered && !disabled ? 1.04 : 1.0),
        ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.55),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : _hovered && !disabled
                ? [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.4),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.imageUrl.isNotEmpty)
              Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Placeholder(
                  title: widget.title,
                  accent: badgeColor,
                ),
              )
            else
              _Placeholder(title: widget.title, accent: badgeColor),

            // Title gradient overlay — always present so users can
            // read the card without tapping.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.92),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (widget.subtitle != null &&
                        widget.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AppTheme.blushGold
                              .withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (widget.badge != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.badgeIcon != null) ...[
                        Icon(widget.badgeIcon,
                            color: Colors.white, size: 9),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        widget.badge!,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.rankNumber != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        AppTheme.velvet.withValues(alpha: 0.85),
                    border: Border.all(
                      color: AppTheme.blushGold
                          .withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.rankNumber}',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.blushGold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      button: !disabled,
      enabled: !disabled,
      label: widget.semanticLabel ?? announcement,
      child: FocusableActionDetector(
        enabled: !disabled,
        onShowFocusHighlight: (show) =>
            setState(() => _focused = show && !disabled),
        mouseCursor: disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: disabled
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: disabled
              ? null
              : (_) {
                  setState(() => _pressed = false);
                  widget.onTap!();
                },
          onTapCancel: () => setState(() => _pressed = false),
          child: MouseRegion(
            cursor: disabled
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onEnter: disabled
                ? null
                : (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: card,
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final Color accent;
  const _Placeholder({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D1B33),
            AppTheme.twilight,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: accent.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
