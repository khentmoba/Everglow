import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/app_network_image.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../drawer_helpers.dart';

/// Large cast rail for the enhanced Cinema drawer. Each member gets a
/// 112px avatar wrapped in a rose-to-lilac gradient ring with a soft
/// glow, a bold readable name (15.5px), and an italic role/character
/// label (12.5px). Anime items flip the hierarchy so the character is
/// primary and the voice actor is secondary.
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
              color: AppColors.deepRose,
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
            color: AppColors.mutedPurple,
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

class _CastMemberCard extends StatefulWidget {
  final Map<String, dynamic> member;
  final bool isAnimeSourced;

  const _CastMemberCard({required this.member, required this.isAnimeSourced});

  @override
  State<_CastMemberCard> createState() => _CastMemberCardState();
}

class _CastMemberCardState extends State<_CastMemberCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final hasPhoto = (m['profilePath'] ?? '').toString().isNotEmpty;
    final character = (m['character'] ?? '').toString();
    final name = (m['name'] ?? '').toString();
    final primary = widget.isAnimeSourced && character.isNotEmpty
        ? character
        : name;
    final secondary = widget.isAnimeSourced && character.isNotEmpty
        ? name
        : character;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 128,
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.auroraRose,
                      AppColors.softLavender,
                      AppColors.blushGold,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.shimmerBase,
                    border: Border.all(
                      color: AppColors.inkDeep.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
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
                    color: AppColors.mutedPurple,
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitial(String label) {
    return Container(
      color: avatarColor(label).withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(
        getInitial(label),
        style: AppTypography.cormorantBold.copyWith(
          fontSize: 42,
          color: avatarColor(label),
        ),
      ),
    );
  }
}
