import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// Compact hover preview card shown on desktop when hovering a poster card.
///
/// Clean dark card with title, metadata chips, genres, synopsis, next episode,
/// and action buttons — no banner image, kept intentionally small.
class ShelfHoverPreview extends StatelessWidget {
  final String title;
  final String? synopsis;
  final String? episodeCount;
  final String? format;
  final String? airingStatus;
  final String? year;
  final List<String> genres;
  final int? currentEpisode;
  final Color accent;
  final VoidCallback? onWatch;
  final VoidCallback? onQueue;

  const ShelfHoverPreview({
    super.key,
    required this.title,
    this.synopsis,
    this.episodeCount,
    this.format,
    this.airingStatus,
    this.year,
    this.genres = const [],
    this.currentEpisode,
    this.accent = AppTheme.deepRose,
    this.onWatch,
    this.onQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with accent left border
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Metadata chips (no icons — clean bordered pills)
              _HoverMetaChips(
                episodeCount: episodeCount,
                format: format,
                airingStatus: airingStatus,
                year: year,
              ),

              // Genres as plain text
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  genres.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.3,
                  ),
                ),
              ],

              // Synopsis
              if (synopsis != null && synopsis!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  synopsis!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ],

              // Next episode line
              if (currentEpisode != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 10,
                        color: accent.withValues(alpha: 0.8)),
                    const SizedBox(width: 5),
                    Text(
                      'Episode ${currentEpisode! + 1} next',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

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
      chips.add(_ChipData(label: format!));
    }
    if (episodeCount != null) {
      chips.add(_ChipData(label: '$episodeCount eps'));
    }
    if (year != null && year!.isNotEmpty) {
      chips.add(_ChipData(label: year!));
    }
    if (airingStatus != null && airingStatus!.isNotEmpty) {
      chips.add(_ChipData(label: airingStatus!));
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
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  c.label,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _ChipData {
  final String label;
  const _ChipData({required this.label});
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
            borderRadius: BorderRadius.circular(16),
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
