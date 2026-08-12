import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/presentation/katana/katana_nav.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';

/// The "Genres" sidebar widget with counts, like the site's directory
/// sidebar.
class KatanaGenresSidebar extends StatelessWidget {
  final List<KatanaGenre> genres;

  const KatanaGenresSidebar({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return KatanaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KatanaSectionHeader(title: 'Genres'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genre = genres[index];
              return InkWell(
                onTap: () => pushGenreDirectory(context, genre.slug, genre.name),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          genre.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            color: KatanaColors.link,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '(${genre.count})',
                        style: KatanaType.small.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
