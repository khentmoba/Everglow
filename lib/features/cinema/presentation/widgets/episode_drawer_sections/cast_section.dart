import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'drawer_helpers.dart';

/// Renders the horizontal cast/voice-actor rail. Shows a loading
/// skeleton while fetching, an empty-state message when no cast is
/// available, or a horizontal scrollable list of circular avatar cards.
class CastSection extends StatelessWidget {
  final List<Map<String, dynamic>> cast;
  final bool isLoading;
  final bool isAnimeSourced;

  const CastSection({
    super.key,
    required this.cast,
    required this.isLoading,
    required this.isAnimeSourced,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return buildLoader();
    if (cast.isEmpty) return buildEmptySection('No cast info available');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final m = cast[i];
              final hasPhoto =
                  (m['profilePath'] ?? '').toString().isNotEmpty;
              final character = (m['character'] ?? '').toString();
              final name = (m['name'] ?? '').toString();
              return SizedBox(
                width: 80,
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.shimmerBase,
                        border: Border.all(
                            color: AppColors.roseQuartz
                                .withValues(alpha: 0.2),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: hasPhoto
                            ? Image.network(m['profilePath'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    buildCastInitial(name))
                            : buildCastInitial(name),
                      ),
                    ),
                    const SizedBox(height: 7),
                    // For anime: character name is primary (bold), VA is secondary.
                    // For cinema: VA name is primary, character/role is secondary.
                    if (isAnimeSourced && character.isNotEmpty) ...[
                      Text(
                        character,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: AppColors.petalWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (name.isNotEmpty)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: AppColors.mutedPurple,
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ] else ...[
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: AppColors.petalWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (character.isNotEmpty)
                        Text(
                          character,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: AppColors.mutedPurple,
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
