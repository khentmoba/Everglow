import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../providers/music_stats_provider.dart';
import '../../providers/music_insights_provider.dart';
import '../../../data/models/top_music_track.dart';
import '../../../data/models/top_artist.dart';
import '../../../data/models/top_album.dart';
import '../../../data/models/lastfm_image_utils.dart';
import '../listen_along_popup.dart';
import '../../../data/models/music_status.dart';
import 'package:intl/intl.dart';

class ExpandedLeaderboard extends StatefulWidget {
  const ExpandedLeaderboard({super.key});
  @override
  State<ExpandedLeaderboard> createState() => _ExpandedLeaderboardState();
}

class _ExpandedLeaderboardState extends State<ExpandedLeaderboard>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0 tracks, 1 artists, 2 albums
  String _person = 'khent'; // khent | clair

  @override
  Widget build(BuildContext context) {
    return Consumer2<MusicStatsProvider, MusicInsightsProvider>(
      builder: (context, stats, insights, _) {
        final isLoading =
            stats.isLoading &&
            insights.isLoading &&
            !stats.hasData &&
            !insights.hasAny;
        if (isLoading) {
          return Container(
            height: 320,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: AppRadius.radiusX2,
            ),
          );
        }

        // pick data
        List<dynamic> items = [];
        if (_tab == 0) {
          items = _person == 'khent' ? stats.topTracks : stats.clairTopTracks;
        } else if (_tab == 1) {
          items = _person == 'khent'
              ? insights.khentTopArtists
              : insights.clairTopArtists;
        } else {
          items = _person == 'khent'
              ? insights.khentTopAlbums
              : insights.clairTopAlbums;
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(
              colors: [
                AppColors.velvet.withValues(alpha: 0.92),
                AppColors.inkDeep.withValues(alpha: 0.96),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.blushGold, AppColors.auroraLilac],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.leaderboard_rounded,
                      size: 18,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HALL OF FAME',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: AppColors.blushGold,
                          ),
                        ),
                        Text(
                          'Top tracks • artists • albums (all time)',
                          style: AppTypography.outfitMedium.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // person switch
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        label: 'Khent',
                        selected: _person == 'khent',
                        color: AppColors.auroraTeal,
                        onTap: () => setState(() => _person = 'khent'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _PillButton(
                        label: 'Clair',
                        selected: _person == 'clair',
                        color: AppColors.cinemaPink,
                        onTap: () => setState(() => _person = 'clair'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // tab switch
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.inkDeep.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        icon: Icons.music_note_rounded,
                        label: 'Tracks',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        icon: Icons.person_rounded,
                        label: 'Artists',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        icon: Icons.album_rounded,
                        label: 'Albums',
                        selected: _tab == 2,
                        onTap: () => setState(() => _tab = 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.petalWhite.withValues(alpha: 0.04),
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(
                      color: AppColors.petalWhite.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _tab == 0
                            ? Icons.queue_music_rounded
                            : _tab == 1
                            ? Icons.person_outline_rounded
                            : Icons.album_outlined,
                        size: 22,
                        color: AppColors.roseQuartz,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No ${_tab == 0
                            ? 'tracks'
                            : _tab == 1
                            ? 'artists'
                            : 'albums'} yet',
                        style: AppTypography.outfitMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                      Text(
                        'Play more and your hall of fame will fill.',
                        style: AppTypography.outfitMedium.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < items.length.clamp(0, 10); i++) ...[
                      _buildRow(
                        items[i],
                        _person == 'khent'
                            ? (insights.khentUser.isNotEmpty
                                  ? insights.khentUser
                                  : 'khent')
                            : (insights.clairUser.isNotEmpty
                                  ? insights.clairUser
                                  : 'clair'),
                      ),
                      if (i != (items.length.clamp(0, 10) - 1))
                        const _Hairline(),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(dynamic item, String username) {
    if (item is TopMusicTrack) {
      final isPodium = item.rank <= 3;
      final color = switch (item.rank) {
        1 => AppColors.auroraGold,
        2 => AppColors.rankSilverCool,
        3 => AppColors.rankBronzeWarm,
        _ => AppColors.blushGold,
      };
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => ListenAlongPopup(
            status: MusicStatus(
              username: username,
              trackName: item.trackName,
              artistName: item.artistName,
              albumName: '',
              imageUrl: item.imageUrl,
              isPlaying: false,
              spotifyUrl: item.spotifyUrl,
            ),
          ),
        ),
        child: SizedBox(
          height: isPodium ? 66 : 58,
          child: Row(
            children: [
              _Rank(rank: item.rank),
              const SizedBox(width: 10),
              _Art(url: item.imageUrl, rank: item.rank),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: isPodium ? 14 : 13,
                        color: AppColors.petalWhite,
                      ),
                    ),
                    Text(
                      item.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitMedium.copyWith(
                        fontSize: 11,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    NumberFormat.decimalPattern().format(item.playCount),
                    style: AppTypography.cormorantHeading.copyWith(
                      fontSize: 16,
                      color: isPodium ? color : AppColors.blushGold,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    item.playCount == 1 ? 'play' : 'plays',
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (item is TopArtist) {
      final isPodium = item.rank <= 3;
      final color = switch (item.rank) {
        1 => AppColors.auroraGold,
        2 => AppColors.rankSilverCool,
        3 => AppColors.rankBronzeWarm,
        _ => AppColors.auroraLilac,
      };
      return SizedBox(
        height: isPodium ? 66 : 58,
        child: Row(
          children: [
            _Rank(rank: item.rank),
            const SizedBox(width: 10),
            _Art(url: item.imageUrl, rank: item.rank, isArtist: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: isPodium ? 14 : 13,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  Text(
                    '${item.playCount} plays',
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 11,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Text(
                '#${item.rank}',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (item is TopAlbum) {
      final isPodium = item.rank <= 3;
      return SizedBox(
        height: isPodium ? 66 : 58,
        child: Row(
          children: [
            _Rank(rank: item.rank),
            const SizedBox(width: 10),
            _Art(url: item.imageUrl, rank: item.rank),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: isPodium ? 14 : 13,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  Text(
                    item.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 11,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.playCount}',
              style: AppTypography.cormorantHeading.copyWith(
                fontSize: 16,
                color: AppColors.blushGold,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PillButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.32) : Colors.transparent,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.outfitBold.copyWith(
          fontSize: 12,
          color: selected ? color : AppColors.textMuted,
        ),
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.petalWhite.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? AppColors.petalWhite.withValues(alpha: 0.10)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: selected ? AppColors.petalWhite : AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 11,
              color: selected ? AppColors.petalWhite : AppColors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Rank extends StatelessWidget {
  final int rank;
  const _Rank({required this.rank});
  @override
  Widget build(BuildContext context) {
    if (rank <= 3) {
      final c = switch (rank) {
        1 => AppColors.auroraGold,
        2 => AppColors.rankSilverCool,
        3 => AppColors.rankBronzeWarm,
        _ => AppColors.blushGold,
      };
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.petalWhite, c.withValues(alpha: 0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 10),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 11,
            color: const Color(0xFF2A2340),
          ),
        ),
      );
    }
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.petalWhite.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$rank',
        style: AppTypography.outfitBold.copyWith(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  final String? url;
  final int rank;
  final bool isArtist;
  const _Art({this.url, required this.rank, this.isArtist = false});
  @override
  Widget build(BuildContext context) {
    final u = cleanLastfmImageUrl(url);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: isArtist ? BorderRadius.circular(99) : AppRadius.radiusMd,
        color: AppColors.velvet,
        border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: isArtist ? BorderRadius.circular(99) : AppRadius.radiusMd,
        child: u == null
            ? Icon(
                isArtist ? Icons.person_rounded : Icons.music_note_rounded,
                size: 18,
                color: AppColors.roseQuartz,
              )
            : Image.network(
                u,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  isArtist ? Icons.person_rounded : Icons.music_note_rounded,
                  size: 18,
                  color: AppColors.roseQuartz,
                ),
              ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.petalWhite.withValues(alpha: 0.06));
}
