import 'package:flutter/material.dart';

import 'animex_tokens.dart';

/// Quiet shelf heading: the titles and artwork carry the browsing hierarchy.
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AnimeXTokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: dmSansStyle(
                size: 20,
                weight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          if (onViewAll != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: AnimeXTokens.textSecondary,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: dmSansStyle(size: 12, weight: FontWeight.w600),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(viewAllLabel ?? 'View All'),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
