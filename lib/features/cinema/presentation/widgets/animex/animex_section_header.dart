import 'package:flutter/material.dart';

import 'animex_buttons.dart';
import 'animex_tokens.dart';

/// Row heading: accent icon + title, "View All" action and a hairline
/// divider underneath, matching the reference content sections.
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
            Icon(icon, color: AnimeXTokens.accent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dmSansStyle(
                  size: 16.8,
                  color: AnimeXTokens.textPrimary,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            if (onViewAll != null)
              AnimeXGhostButton(
                label: viewAllLabel!,
                icon: Icons.arrow_forward_rounded,
                color: AnimeXTokens.accent,
                onTap: onViewAll,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: AnimeXTokens.border),
        const SizedBox(height: 16),
      ],
    );
  }
}
