import 'package:flutter/material.dart';

import 'animex_tokens.dart';

/// Row heading: accent icon tile + title, a "View All" pill action and a
/// gradient hairline underneath, matching the reference content sections.
class AnimeXSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onViewAll;
  final String? viewAllLabel;

  const AnimeXSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.onViewAll,
    this.viewAllLabel = 'View All',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AnimeXTokens.accent.withValues(alpha: 0.32),
                    AnimeXTokens.accent.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                border: Border.all(
                  color: AnimeXTokens.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(icon, color: AnimeXTokens.accentWarm, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dmSansStyle(
                  size: 20,
                  color: AnimeXTokens.textPrimary,
                  weight: FontWeight.w800,
                  letterSpacing: -0.01,
                ),
              ),
            ),
            if (onViewAll != null)
              _ViewAllPill(label: viewAllLabel!, onTap: onViewAll!),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AnimeXTokens.accent.withValues(alpha: 0.5),
                AnimeXTokens.border,
                Colors.transparent,
              ],
              stops: const [0, 0.35, 0.7],
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _ViewAllPill extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ViewAllPill({required this.label, required this.onTap});

  @override
  State<_ViewAllPill> createState() => _ViewAllPillState();
}

class _ViewAllPillState extends State<_ViewAllPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hover
                ? AnimeXTokens.accent.withValues(alpha: 0.18)
                : AnimeXTokens.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _hover
                  ? AnimeXTokens.accent.withValues(alpha: 0.5)
                  : AnimeXTokens.accent.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: dmSansStyle(
                  size: 12.5,
                  color: AnimeXTokens.accentWarm,
                  weight: FontWeight.w700,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                transform: Matrix4.translationValues(_hover ? 3 : 0, 0, 0),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AnimeXTokens.accentWarm,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
