import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/app_network_image.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../drawer_helpers.dart';
import '../../netflix/netflix_colors.dart';

/// Cast rail for the enhanced Cinema drawer. Anime items show the
/// character first and the voice actor underneath.
class CinemaCastSection extends StatelessWidget {
  final List<Map<String, dynamic>> cast;
  final bool isLoading;
  final bool isAnimeSourced;

  const CinemaCastSection({
    super.key,
    required this.cast,
    required this.isLoading,
    required this.isAnimeSourced,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: NetflixColors.accent,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    if (cast.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'No cast info available',
          style: AppTypography.outfitWhite.copyWith(
            color: NetflixColors.textMuted,
            fontSize: 13,
          ),
        ),
      );
    }

    return SizedBox(
      height: 228,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: cast.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, i) =>
            _CastMemberCard(member: cast[i], isAnimeSourced: isAnimeSourced),
      ),
    );
  }
}

class _CastMemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool isAnimeSourced;

  const _CastMemberCard({required this.member, required this.isAnimeSourced});

  @override
  Widget build(BuildContext context) {
    final m = member;
    final hasPhoto = (m['profilePath'] ?? '').toString().isNotEmpty;
    final character = (m['character'] ?? '').toString();
    final name = (m['name'] ?? '').toString();
    final primary = isAnimeSourced && character.isNotEmpty ? character : name;
    final secondary = isAnimeSourced && character.isNotEmpty ? name : character;

    return SizedBox(
      width: 128,
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NetflixColors.surfaceElevated,
              border: Border.all(color: NetflixColors.hairline),
            ),
            child: ClipOval(
              child: hasPhoto
                  ? AppNetworkImage(
                      imageUrl: m['profilePath'],
                      fit: BoxFit.cover,
                      cacheWidth: 150,
                      errorWidget: _buildInitial(primary),
                    )
                  : _buildInitial(primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            primary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 15.5,
              height: 1.18,
            ),
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              secondary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: NetflixColors.textSecondary,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitial(String label) {
    return Container(
      color: NetflixColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(
        getInitial(label),
        style: AppTypography.cormorantBold.copyWith(
          fontSize: 42,
          color: NetflixColors.textSecondary,
        ),
      ),
    );
  }
}
