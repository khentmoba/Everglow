import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// Rich hover preview card shown on desktop when hovering a poster card.
///
/// Matches WatchPeak's design: banner at top, title with accent left border,
/// metadata chips, synopsis, next episode, and action buttons.
class ShelfHoverPreview extends StatelessWidget {
  final String title;
  final String? bannerUrl;
  final String? synopsis;
  final String? episodeCount;
  final String? format;
  final String? airingStatus;
  final String? year;
  final Color accent;
  final VoidCallback? onWatch;
  final VoidCallback? onQueue;

  const ShelfHoverPreview({
    super.key,
    required this.title,
    this.bannerUrl,
    this.synopsis,
    this.episodeCount,
    this.format,
    this.airingStatus,
    this.year,
    this.accent = AppTheme.deepRose,
    this.onWatch,
    this.onQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner image
            _BannerSection(bannerUrl: bannerUrl, accent: accent),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with accent left border (WatchPeak style)
                  Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: accent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Metadata chips (WatchPeak style)
                  _HoverMetaChips(
                    episodeCount: episodeCount,
                    format: format,
                    airingStatus: airingStatus,
                    year: year,
                  ),

                  // Synopsis
                  if (synopsis != null && synopsis!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      synopsis!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      _HoverButton(
                        label: 'Watch',
                        icon: Icons.play_arrow_rounded,
                        primary: true,
                        accent: accent,
                        onTap: onWatch,
                      ),
                      const SizedBox(width: 8),
                      _HoverButton(
                        label: 'Queue',
                        icon: Icons.add_rounded,
                        primary: false,
                        accent: accent,
                        onTap: onQueue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerSection extends StatelessWidget {
  final String? bannerUrl;
  final Color accent;
  const _BannerSection({required this.bannerUrl, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.12),
            const Color(0xFF141418),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bannerUrl != null && bannerUrl!.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Image.network(
                  bannerUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: 640,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // Gradient fade at bottom
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF141418).withValues(alpha: 0.5),
                    const Color(0xFF141418),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverMetaChips extends StatelessWidget {
  final String? episodeCount;
  final String? format;
  final String? airingStatus;
  final String? year;
  const _HoverMetaChips({
    this.episodeCount,
    this.format,
    this.airingStatus,
    this.year,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <_ChipData>[];
    if (format != null && format!.isNotEmpty) {
      chips.add(_ChipData(icon: Icons.tv_rounded, label: format!));
    }
    if (episodeCount != null) {
      chips.add(_ChipData(
          icon: Icons.movie_rounded, label: '$episodeCount eps'));
    }
    if (year != null && year!.isNotEmpty) {
      chips.add(_ChipData(icon: Icons.calendar_today_rounded, label: year!));
    }
    if (airingStatus != null && airingStatus!.isNotEmpty) {
      chips.add(_ChipData(
          icon: Icons.live_tv_rounded, label: airingStatus!));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: chips
          .map((c) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      c.label,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ChipData {
  final IconData icon;
  final String label;
  const _ChipData({required this.icon, required this.label});
}

class _HoverButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final Color accent;
  final VoidCallback? onTap;

  const _HoverButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.accent,
    this.onTap,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ShelfMotion.orZero(const Duration(milliseconds: 160)),
          curve: ShelfMotion.easeOutStrong,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: widget.primary
                ? (_hovered
                    ? widget.accent
                    : widget.accent.withValues(alpha: 0.85))
                : (_hovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(18),
            border: widget.primary
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
            boxShadow: widget.primary && _hovered
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
