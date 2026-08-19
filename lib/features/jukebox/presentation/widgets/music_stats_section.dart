import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/music_status.dart';
import '../../data/models/top_music_track.dart';
import '../../data/models/lastfm_image_utils.dart';
import '../providers/music_stats_provider.dart';
import 'listen_along_popup.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';

/// Dashboard music stats for both people: each user's all-time top-10
/// leaderboard followed by their five most recent scrobbles.
class MusicStatsSection extends StatelessWidget {
  const MusicStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicStatsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.hasData) {
          return const _MusicStatsSkeleton();
        }

        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.86),
                AppColors.inkDeep.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MusicStatsBlock(
                displayName: 'Khent',
                username: provider.username,
                topTracks: provider.topTracks,
                recentTracks: provider.recentTracks,
              ),
              const SizedBox(height: AppSpacing.x2),
              const _SectionDivider(),
              const SizedBox(height: AppSpacing.x2),
              _MusicStatsBlock(
                displayName: 'Clair',
                username: provider.clairUsername,
                topTracks: provider.clairTopTracks,
                recentTracks: provider.clairRecentTracks,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicStatsBlock extends StatelessWidget {
  final String displayName;
  final String username;
  final List<TopMusicTrack> topTracks;
  final List<MusicStatus> recentTracks;

  const _MusicStatsBlock({
    required this.displayName,
    required this.username,
    required this.topTracks,
    required this.recentTracks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.leaderboard_rounded,
          title: "$displayName's Top 10",
          subtitle: '$username · most listened all-time',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (topTracks.isEmpty)
          const _EmptyStats()
        else
          Builder(builder: (context) {
            final maxPlays = topTracks.isEmpty
                ? 1
                : topTracks.map((t) => t.playCount).reduce((a, b) => a > b ? a : b);
            return Column(
              children: [
                for (var i = 0; i < topTracks.length; i++) ...[
                  _TopTrackRow(track: topTracks[i], username: username, maxPlays: maxPlays),
                  if (i != topTracks.length - 1)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: topTracks[i].rank <= 3 ? 7 : 0),
                      child: const _Hairline(),
                    ),
                ],
              ],
            );
          }),
        const SizedBox(height: AppSpacing.x2),
        const _SectionDivider(),
        const SizedBox(height: AppSpacing.x2),
        _SectionHeader(
          icon: Icons.history_rounded,
          title: 'Recently Heard',
          subtitle: "$username's latest 5 scrobbles",
        ),
        const SizedBox(height: AppSpacing.lg),
        if (recentTracks.isEmpty)
          const _EmptyStats()
        else
          for (var i = 0; i < recentTracks.length; i++) ...[
            _RecentTrackRow(status: recentTracks[i]),
            if (i != recentTracks.length - 1) const _Hairline(),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.blushGold.withValues(alpha: 0.18),
                AppColors.blushGold.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: AppColors.blushGold),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cormorantBoldWhite.copyWith(
                  fontSize: 21,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blushGold,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopTrackRow extends StatelessWidget {
  final TopMusicTrack track;
  final String username;
  final int maxPlays;

  const _TopTrackRow({
    required this.track,
    required this.username,
    required this.maxPlays,
  });

  bool get _isPodium => track.rank <= 3;

  Color get _podiumColor => switch (track.rank) {
    1 => AppColors.auroraGold,
    2 => const Color(0xFFB9BBFF),
    3 => const Color(0xFFE8A87C),
    _ => AppColors.blushGold,
  };

  @override
  Widget build(BuildContext context) {
    final rowCore = SizedBox(
      height: _isPodium ? 66 : 62,
      child: Row(
        children: [
          _RankBadge(rank: track.rank),
          const SizedBox(width: AppSpacing.md),
          _PodiumArtwork(imageUrl: track.imageUrl, rank: track.rank),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        track.trackName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: _isPodium ? 15.5 : 14.5,
                          height: 1.15,
                          color: AppColors.petalWhite,
                          shadows: _isPodium
                              ? [Shadow(color: _podiumColor.withValues(alpha: 0.35), blurRadius: 12)]
                              : null,
                        ),
                      ),
                    ),
                    if (_isPodium) ...[
                      const SizedBox(width: 6),
                      _PodiumTag(rank: track.rank),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 12.5,
                    height: 1.15,
                    color: _isPodium ? AppColors.petalWhite.withValues(alpha: 0.88) : AppColors.textMedium,
                  ),
                ),
                if (_isPodium) ...[
                  const SizedBox(height: 6),
                  _PlayBar(fraction: (track.playCount / (maxPlays == 0 ? 1 : maxPlays)).clamp(0.08, 1.0), color: _podiumColor),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _PlayCountPill(playCount: track.playCount, color: _podiumColor, isPodium: _isPodium),
        ],
      ),
    );

    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openTrack(context),
      child: rowCore,
    );

    if (!_isPodium) return row;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: switch (track.rank) {
                1 => [AppColors.auroraGold.withValues(alpha: 0.22), const Color(0xFF6B4E00).withValues(alpha: 0.22), AppColors.inkDeep.withValues(alpha: 0.35)],
                2 => [const Color(0xFFD8D6F0).withValues(alpha: 0.22), const Color(0xFF3A3566).withValues(alpha: 0.22), AppColors.inkDeep.withValues(alpha: 0.32)],
                3 => [const Color(0xFFE8A87C).withValues(alpha: 0.22), const Color(0xFF6B3A14).withValues(alpha: 0.22), AppColors.inkDeep.withValues(alpha: 0.30)],
                _ => [Colors.transparent, Colors.transparent],
              },
            ),
            border: Border.all(color: _podiumColor.withValues(alpha: 0.48), width: 1.25),
            boxShadow: [
              BoxShadow(color: _podiumColor.withValues(alpha: track.rank == 1 ? 0.28 : 0.18), blurRadius: track.rank == 1 ? 22 : 16, offset: const Offset(0, 8)),
              BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: _Shimmer(color: _podiumColor))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: row),
            ],
          ),
        ),
        if (track.rank == 1) Positioned(top: -6, right: 8, child: _SparkleBadge(color: _podiumColor)),
      ],
    );
  }

  void _openTrack(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ListenAlongPopup(
        status: MusicStatus(
          username: username,
          trackName: track.trackName,
          artistName: track.artistName,
          albumName: 'No Album',
          imageUrl: track.imageUrl,
          isPlaying: false,
          spotifyUrl: track.spotifyUrl,
        ),
      ),
    );
  }
}

class _PodiumTag extends StatelessWidget {
  final int rank;
  const _PodiumTag({required this.rank});
  @override
  Widget build(BuildContext context) {
    final c = switch (rank) {
      1 => AppColors.auroraGold,
      2 => const Color(0xFFB9BBFF),
      3 => const Color(0xFFE8A87C),
      _ => AppColors.blushGold,
    };
    final label = switch (rank) { 1 => '#1', 2 => '#2', 3 => '#3', _ => '#$rank' };
    final extra = rank == 1 ? ' TOP' : '';
    final icon = switch (rank) { 1 => Icons.emoji_events_rounded, 2 => Icons.workspace_premium_rounded, 3 => Icons.military_tech_rounded, _ => Icons.star_rounded };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99), border: Border.all(color: c.withValues(alpha: 0.48))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 10, color: c), const SizedBox(width: 3), Text('$label$extra', style: AppTypography.outfitBold.copyWith(fontSize: 8, color: c, letterSpacing: 0.9))]),
    );
  }
}

class _PlayBar extends StatelessWidget {
  final double fraction;
  final Color color;
  const _PlayBar({required this.fraction, required this.color});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [Container(height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(99))), FractionallySizedBox(widthFactor: fraction, child: Container(height: 4, decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.45)]), borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)])))]);
  }
}

class _PlayCountPill extends StatelessWidget {
  final int playCount;
  final Color color;
  final bool isPodium;
  const _PlayCountPill({required this.playCount, required this.color, required this.isPodium});
  @override
  Widget build(BuildContext context) {
    if (!isPodium) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(NumberFormat.decimalPattern().format(playCount), style: AppTypography.cormorantHeading.copyWith(fontSize: 18, height: 1.0, color: AppColors.blushGold)), const SizedBox(height: 3), Text(playCount == 1 ? 'play' : 'plays', style: AppTypography.outfitMedium.copyWith(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1.3))]);
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.08)]), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: 0.40)), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 14)]), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(NumberFormat.decimalPattern().format(playCount), style: AppTypography.cormorantHeading.copyWith(fontSize: 15, height: 1.0, color: color, shadows: [Shadow(color: color.withValues(alpha: 0.35), blurRadius: 10)])), const SizedBox(height: 2), Text(playCount == 1 ? 'play' : 'plays', style: AppTypography.outfitMedium.copyWith(fontSize: 8, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.85), letterSpacing: 1.1))]));
  }
}

class _Shimmer extends StatefulWidget {
  final Color color;
  const _Shimmer({required this.color});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}
class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(); _a = Tween<double>(begin: -1.2, end: 1.8).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _a, builder: (c, _) => Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment(_a.value, -0.6), end: Alignment(_a.value + 0.35, 0.8), colors: [Colors.transparent, Colors.transparent, Colors.white.withValues(alpha: 0.08), Colors.transparent, Colors.transparent], stops: const [0, 0.42, 0.5, 0.58, 1]))));
}

class _SparkleBadge extends StatefulWidget {
  final Color color;
  const _SparkleBadge({required this.color});
  @override
  State<_SparkleBadge> createState() => _SparkleBadgeState();
}
class _SparkleBadgeState extends State<_SparkleBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween<double>(begin: 0.55, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: ScaleTransition(scale: Tween<double>(begin: 0.88, end: 1.08).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: Icon(Icons.auto_awesome_rounded, size: 13, color: widget.color.withValues(alpha: 0.95))));
}

class _PodiumArtwork extends StatelessWidget {
  final String? imageUrl;
  final int rank;
  const _PodiumArtwork({this.imageUrl, required this.rank});
  @override
  Widget build(BuildContext context) {
    final isPodium = rank <= 3;
    final borderColor = switch (rank) { 1 => AppColors.auroraGold.withValues(alpha: 0.90), 2 => const Color(0xFFD8D6F0).withValues(alpha: 0.75), 3 => const Color(0xFFE8A87C).withValues(alpha: 0.75), _ => AppColors.moonlight.withValues(alpha: 0.14) };
    final size = isPodium ? 50.0 : 46.0;
    final art = Container(width: size, height: size, decoration: BoxDecoration(borderRadius: AppRadius.radiusMd, color: AppColors.velvet, border: Border.all(color: borderColor, width: isPodium ? 1.6 : 1), boxShadow: isPodium ? [BoxShadow(color: borderColor.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 4))] : null), child: ClipRRect(borderRadius: AppRadius.radiusMd, child: Stack(fit: StackFit.expand, children: [Builder(builder: (_) { final url = cleanLastfmImageUrl(imageUrl); if (url == null) return const _ArtworkFallback(); return Image.network(url, fit: BoxFit.cover, cacheWidth: 200, errorBuilder: (c, e, s) => const _ArtworkFallback()); }), if (isPodium) Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.10), Colors.transparent])))])));
    if (!isPodium) return art;
    return Stack(clipBehavior: Clip.none, children: [art, Positioned(top: -7, right: -7, child: Container(width: 20, height: 20, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: switch (rank) { 1 => [const Color(0xFFFFF3B0), AppColors.auroraGold], 2 => [const Color(0xFFF0F0FF), const Color(0xFFB8B9D6)], 3 => [const Color(0xFFFFD7B5), const Color(0xFFC47A3A)], _ => [Colors.white, Colors.white] }), border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.2), boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.55), blurRadius: 8)]), child: Icon(switch (rank) { 1 => Icons.emoji_events_rounded, 2 => Icons.workspace_premium_rounded, 3 => Icons.military_tech_rounded, _ => Icons.star_rounded }, size: 11, color: rank == 1 ? const Color(0xFF6B4E00) : const Color(0xFF2A2340))))]);
  }
}

class _RecentTrackRow extends StatelessWidget {
  final MusicStatus status;

  const _RecentTrackRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isLive = status.isPlaying;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showDialog(
        context: context,
        builder: (context) => ListenAlongPopup(status: status),
      ),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            _TrackArtwork(imageUrl: status.imageUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          status.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitHeading.copyWith(
                            fontSize: 15,
                            height: 1.15,
                            color: AppColors.petalWhite,
                          ),
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const _LiveBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 12.5,
                      height: 1.15,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isLive ? AppColors.warmAmber : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  _timeLabel(),
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 11.5,
                    height: 1.0,
                    fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
                    color: isLive ? AppColors.warmAmber : AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel() {
    if (status.isPlaying) return 'now';
    final timestamp = status.timestamp;
    if (timestamp == null) return 'heard';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});
  @override
  Widget build(BuildContext context) {
    if (rank <= 3) return _PodiumBadge(rank: rank);
    return Container(
      width: 32, height: 32, alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.moonlight.withValues(alpha: 0.08), border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.5), width: 1)),
      child: Text('$rank', style: AppTypography.cormorantHeading.copyWith(fontSize: 16, height: 1.0, color: AppColors.textMuted)),
    );
  }
}
class _PodiumBadge extends StatelessWidget {
  final int rank;
  const _PodiumBadge({required this.rank});
  @override
  Widget build(BuildContext context) {
    final (Color glow, List<Color> grad, IconData icon) = switch (rank) {
      1 => (AppColors.auroraGold, [const Color(0xFFFFF6CC), const Color(0xFFF5C97B), const Color(0xFFC49A2B)], Icons.emoji_events_rounded),
      2 => (const Color(0xFFB9BBFF), [Colors.white, const Color(0xFFD8D6F0), const Color(0xFF9A98C2)], Icons.workspace_premium_rounded),
      3 => (const Color(0xFFE8A87C), [const Color(0xFFFFE0C2), const Color(0xFFE8A87C), const Color(0xFF8B5A2B)], Icons.military_tech_rounded),
      _ => (AppColors.blushGold, [Colors.white, Colors.white], Icons.star_rounded),
    };
    final size = rank == 1 ? 36.0 : 34.0;
    return Container(
      width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.2),
        boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.55), blurRadius: rank == 1 ? 16 : 12, offset: const Offset(0, 4)), BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.35), blurRadius: 8)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 12, color: const Color(0xFF2A2340)), Text('$rank', style: AppTypography.cormorantHeading.copyWith(fontSize: 11, height: 0.9, color: const Color(0xFF2A2340), fontWeight: FontWeight.w800))]),
    );
  }
}

class _TrackArtwork extends StatelessWidget {
  final String? imageUrl;

  const _TrackArtwork({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = cleanLastfmImageUrl(imageUrl);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusMd,
        color: AppColors.velvet,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusMd,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (context, error, stack) =>
                    const _ArtworkFallback(),
              )
            : const _ArtworkFallback(),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.velvet,
      child: const Icon(
        Icons.music_note_rounded,
        size: 21,
        color: AppColors.roseQuartz,
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warmAmber.withValues(alpha: 0.16),
        borderRadius: AppRadius.radiusXs,
        border: Border.all(
          color: AppColors.warmAmber.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.warmAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 8.5,
              color: AppColors.warmAmber,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.moonlight.withValues(alpha: 0.14),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.blushGold.withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            size: 26,
            color: AppColors.roseQuartz,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No music stats yet',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 13,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicStatsSkeleton extends StatelessWidget {
  const _MusicStatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.86),
            AppColors.inkDeep.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: AppRadius.radiusX2,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EverglowSkeleton(width: 170, height: 18, radius: 8),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: [
                const EverglowSkeleton(width: 46, height: 46, radius: 14),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EverglowSkeleton(
                        width: double.infinity,
                        height: 13,
                        radius: 6,
                      ),
                      SizedBox(height: 8),
                      EverglowSkeleton(width: 120, height: 11, radius: 5),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const EverglowSkeleton(width: 46, height: 11, radius: 5),
              ],
            ),
            if (i != 3) const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }
}
