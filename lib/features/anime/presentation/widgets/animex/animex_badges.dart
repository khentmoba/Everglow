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
class AnimeXBadge extends StatelessWidget {
  final String label;
  final AnimeXBadgeKind kind;
  final bool dot;

  const AnimeXBadge({
    super.key,
    required this.label,
    this.kind = AnimeXBadgeKind.episodes,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (kind) {
      AnimeXBadgeKind.sub => (
        AnimeXTokens.success,
        AnimeXTokens.success.withValues(alpha: 0.15),
      ),
      AnimeXBadgeKind.dub => (
        AnimeXTokens.dubBlue,
        AnimeXTokens.dubBlue.withValues(alpha: 0.15),
      ),
      AnimeXBadgeKind.rating => (
        AnimeXTokens.accentWarm,
        AnimeXTokens.accentWarm.withValues(alpha: 0.15),
      ),
      AnimeXBadgeKind.airing => (
        AnimeXTokens.success,
        AnimeXTokens.success.withValues(alpha: 0.10),
      ),
      AnimeXBadgeKind.finished => (
        AnimeXTokens.textMuted,
        Colors.white.withValues(alpha: 0.06),
      ),
      AnimeXBadgeKind.upcoming => (
        AnimeXTokens.accent,
        AnimeXTokens.accent.withValues(alpha: 0.15),
      ),
      AnimeXBadgeKind.newBadge => (
        AnimeXTokens.success,
        AnimeXTokens.success.withValues(alpha: 0.15),
      ),
      AnimeXBadgeKind.episodes => (
        AnimeXTokens.textSecondary,
        Colors.white.withValues(alpha: 0.08),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: _PulsingDot(color: fg),
            ),
          Text(
            label,
            style: dmSansStyle(
              size: 11,
              color: fg,
              weight: FontWeight.w600,
              letterSpacing: 0.05,
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
