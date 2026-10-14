import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

/// Shared exits for profiles whose home is Cinema rather than the dashboard.
class MediaSectionMenu extends StatelessWidget {
  const MediaSectionMenu({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    if (!context.select<AuthService, bool>((a) => a.isCinemaOnlyUser)) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip: 'Switch section',
      icon: const Icon(Icons.apps_rounded, color: AppColors.petalWhite),
      color: AppColors.inkDeep,
      onSelected: (route) => context.go(route),
      itemBuilder: (_) => [
        for (final (route, label, icon) in const [
          ('/cinema', 'Cinema', Icons.movie_outlined),
          ('/anime', 'Anime', Icons.animation_outlined),
          ('/manga', 'Mangacelestia', Icons.auto_stories_outlined),
          ('/books', 'Books', Icons.menu_book_outlined),
        ])
          PopupMenuItem(
            value: route,
            enabled: route != currentRoute,
            child: Row(
              children: [
                Icon(icon, color: AppColors.petalWhite),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.petalWhite),
                ),
                if (route == currentRoute) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_rounded, color: AppColors.petalWhite),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
