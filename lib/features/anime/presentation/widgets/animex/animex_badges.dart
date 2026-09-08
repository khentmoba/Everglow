import 'package:flutter/material.dart';

import 'animex_tokens.dart';

enum AnimeXBadgeKind {
  sub,
  dub,
  episodes,
  rating,
  airing,
  finished,
  upcoming,
  newBadge,
}

/// Compact status/quality badge (badge-* classes in the reference UI).
/// Rendered as a frosted-glass pill so it stays legible over artwork.
class AnimeXBadge extends StatelessWidget {
  final String label;
  final AnimeXBadgeKind kind;
  final bool dot;
  final IconData? icon;

  const AnimeXBadge({
    super.key,
    required this.label,
    this.kind = AnimeXBadgeKind.episodes,
    this.dot = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, Color border) = switch (kind) {
      AnimeXBadgeKind.sub => (
        AnimeXTokens.success,
        AnimeXTokens.success.withValues(alpha: 0.18),
        AnimeXTokens.success.withValues(alpha: 0.35),
      ),
      AnimeXBadgeKind.dub => (
        AnimeXTokens.dubBlue,
        AnimeXTokens.dubBlue.withValues(alpha: 0.18),
        AnimeXTokens.dubBlue.withValues(alpha: 0.35),
      ),
      AnimeXBadgeKind.rating => (
        AnimeXTokens.gold,
        const Color(0xB31A1408),
        AnimeXTokens.gold.withValues(alpha: 0.35),
      ),
      AnimeXBadgeKind.airing => (
        AnimeXTokens.success,
        const Color(0xB30B1A12),
        AnimeXTokens.success.withValues(alpha: 0.3),
      ),
      AnimeXBadgeKind.finished => (
        AnimeXTokens.textSecondary,
        const Color(0xB316161D),
        AnimeXTokens.glassBorder,
      ),
      AnimeXBadgeKind.upcoming => (
        AnimeXTokens.accentWarm,
        AnimeXTokens.accent.withValues(alpha: 0.22),
        AnimeXTokens.accent.withValues(alpha: 0.4),
      ),
      AnimeXBadgeKind.newBadge => (
        Colors.white,
        AnimeXTokens.accent.withValues(alpha: 0.85),
        Colors.white.withValues(alpha: 0.25),
      ),
      AnimeXBadgeKind.episodes => (
        Colors.white,
        const Color(0xB30E0E13),
        AnimeXTokens.glassBorder,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ] else if (dot)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: _PulsingDot(color: fg),
            ),
          Text(
            label.toUpperCase(),
            style: dmSansStyle(
              size: 10.5,
              color: fg,
              weight: FontWeight.w700,
              letterSpacing: 0.07,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.45).animate(_ctrl),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Maps an AniList/Jikan status string onto a badge.
AnimeXBadge statusBadge(String? status) {
  final s = (status ?? '').toUpperCase();
  if (s.contains('RELEASING') || s.contains('AIRING')) {
    return const AnimeXBadge(
      label: 'Airing',
      kind: AnimeXBadgeKind.airing,
      dot: true,
    );
  }
  if (s.contains('FINISHED') || s.contains('COMPLETED')) {
    return const AnimeXBadge(label: 'Finished', kind: AnimeXBadgeKind.finished);
  }
  if (s.contains('NOT_YET') || s.contains('UPCOMING')) {
    return const AnimeXBadge(label: 'Upcoming', kind: AnimeXBadgeKind.upcoming);
  }
  return const AnimeXBadge(label: 'Unknown', kind: AnimeXBadgeKind.episodes);
}
