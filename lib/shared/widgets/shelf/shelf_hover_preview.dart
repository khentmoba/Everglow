import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// Rich hover preview card shown on desktop when hovering a poster card.
///
/// Displays a banner image, full title, metadata chips, synopsis, and
/// action buttons — giving the same depth of information as WatchPeak's
/// hover overlay.
///
/// Intended to be shown via [OverlayEntry] positioned relative to the
/// source card using [LayerLink] / [CompositedTransformTarget].
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
        width: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1228),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.petalWhite,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Metadata chips
                  _HoverMetaChips(
                    episodeCount: episodeCount,
                    format: format,
                    airingStatus: airingStatus,
                    year: year,
                  ),

                  // Synopsis
                  if (synopsis != null && synopsis!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      synopsis!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

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
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.15),
            const Color(0xFF1C1228),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bannerUrl != null && bannerUrl!.isNotEmpty)
              Image.network(
                bannerUrl!,
                fit: BoxFit.cover,
                cacheWidth: 600,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            // Gradient fade at bottom
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1C1228).withValues(alpha: 0.6),
                    const Color(0xFF1C1228),
                  ],
                  stops: const [0.0, 0.65, 1.0],
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
    final chips = <String>[];
    if (format != null && format!.isNotEmpty) chips.add(format!);
    if (episodeCount != null) chips.add('$episodeCount eps');
    if (airingStatus != null && airingStatus!.isNotEmpty) {
      chips.add(airingStatus!);
    }
    if (year != null && year!.isNotEmpty) chips.add(year!);

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips
          .map((c) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  c,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ))
          .toList(),
    );
  }
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              Icon(widget.icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
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
