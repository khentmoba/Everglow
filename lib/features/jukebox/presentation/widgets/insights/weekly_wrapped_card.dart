import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../providers/music_insights_provider.dart';
import '../../providers/music_stats_provider.dart';
import '../../../data/models/top_music_track.dart';
import '../listen_along_popup.dart';
import '../../../data/models/music_status.dart';
import '../../../data/models/lastfm_image_utils.dart';

class WeeklyWrappedCard extends StatelessWidget {
  const WeeklyWrappedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MusicInsightsProvider, MusicStatsProvider>(
      builder: (context, insights, stats, _) {
        if (insights.isLoading && insights.khentWeeklyTracks.isEmpty) {
          return Container(height: 220, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: AppRadius.radiusX2));
        }
        final khentW = insights.khentWeeklyTracks;
        final clairW = insights.clairWeeklyTracks;
        final isEmpty = khentW.isEmpty && clairW.isEmpty;
        // compute weekly totals
        final khentTotal = khentW.fold<int>(0, (s, t) => s + t.playCount);
        final clairTotal = clairW.fold<int>(0, (s, t) => s + t.playCount);
        final now = DateTime.now();
        final weekLabel = DateFormat('MMM d').format(now.subtract(const Duration(days: 6))) + ' – ' + DateFormat('MMM d').format(now);

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(colors: [const Color(0xFF2D1B33).withValues(alpha: 0.96), const Color(0xFF1A0F2A).withValues(alpha: 0.98)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: AppColors.auroraGold.withValues(alpha: 0.18)),
            boxShadow: [BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusX2,
            child: Stack(
              children: [
                Positioned(top: -40, right: -30, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.auroraGold.withValues(alpha: 0.18), Colors.transparent])))),
                Positioned(bottom: -50, left: -40, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.auroraRose.withValues(alpha: 0.14), Colors.transparent])))),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.auroraGold.withValues(alpha: 0.14), border: Border.all(color: AppColors.auroraGold.withValues(alpha: 0.32))),
                            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.auroraGold),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('WEEKLY WRAPPED', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.8, color: AppColors.auroraGold)),
                              Text(weekLabel, style: AppTypography.outfitMedium.copyWith(fontSize: 11, color: AppColors.textMuted)),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.calendar_view_week_rounded, size: 12, color: AppColors.blushGold),
                              const SizedBox(width: 4),
                              Text('7 DAYS', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 0.9, color: AppColors.blushGold)),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: AppRadius.radiusMd, border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                          child: Column(children: [
                            const Icon(Icons.weekend_rounded, size: 22, color: AppColors.roseQuartz),
                            const SizedBox(height: 8),
                            Text('No plays this week yet — press play and your Wrapped will bloom here.', textAlign: TextAlign.center, style: AppTypography.outfitMedium.copyWith(fontSize: 12, color: AppColors.textMedium)),
                          ]),
                        )
                      else
                        LayoutBuilder(builder: (context, c) {
                          final isNarrow = c.maxWidth < 560;
                          if (isNarrow) {
                            return Column(children: [
                              _PersonWeekly(name: 'Khent', tracks: khentW, total: khentTotal, color: AppColors.auroraTeal, weeklyArtists: insights.khentWeeklyArtists.map((a) => a.name).take(2).join(', ')),
                              const SizedBox(height: 14),
                              Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                              const SizedBox(height: 14),
                              _PersonWeekly(name: 'Clair', tracks: clairW, total: clairTotal, color: AppColors.cinemaPink, weeklyArtists: insights.clairWeeklyArtists.map((a) => a.name).take(2).join(', ')),
                              const SizedBox(height: 14),
                              _VersusBar(khent: khentTotal, clair: clairTotal),
                            ]);
                          }
                          return Column(children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: _PersonWeekly(name: 'Khent', tracks: khentW, total: khentTotal, color: AppColors.auroraTeal, weeklyArtists: insights.khentWeeklyArtists.map((a) => a.name).take(2).join(', '))),
                              const SizedBox(width: 16),
                              Expanded(child: _PersonWeekly(name: 'Clair', tracks: clairW, total: clairTotal, color: AppColors.cinemaPink, weeklyArtists: insights.clairWeeklyArtists.map((a) => a.name).take(2).join(', '))),
                            ]),
                            const SizedBox(height: 16),
                            _VersusBar(khent: khentTotal, clair: clairTotal),
                          ]);
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PersonWeekly extends StatelessWidget {
  final String name;
  final List<TopMusicTrack> tracks;
  final int total;
  final Color color;
  final String weeklyArtists;
  const _PersonWeekly({required this.name, required this.tracks, required this.total, required this.color, required this.weeklyArtists});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: AppRadius.radiusLg, border: Border.all(color: color.withValues(alpha: 0.22))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18), border: Border.all(color: color.withValues(alpha: 0.35))), child: Icon(Icons.person_rounded, size: 14, color: color)),
          const SizedBox(width: 8),
          Text(name, style: AppTypography.outfitBold.copyWith(fontSize: 13, color: AppColors.petalWhite)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
            child: Text('$total plays', style: AppTypography.outfitBold.copyWith(fontSize: 10, color: color)),
          ),
        ]),
        if (weeklyArtists.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(weeklyArtists, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitMedium.copyWith(fontSize: 10, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 10),
        if (tracks.isEmpty)
          Text('No scrobbles this week', style: AppTypography.outfitMedium.copyWith(fontSize: 11, color: AppColors.textMuted))
        else
          Column(children: [
            for (var i = 0; i < tracks.length; i++) ...[
              _WrappedRow(track: tracks[i], color: color),
              if (i != tracks.length - 1) const SizedBox(height: 8),
            ],
          ]),
      ]),
    );
  }
}

class _WrappedRow extends StatelessWidget {
  final TopMusicTrack track;
  final Color color;
  const _WrappedRow({required this.track, required this.color});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (_) => ListenAlongPopup(status: MusicStatus(username: '', trackName: track.trackName, artistName: track.artistName, albumName: '', imageUrl: track.imageUrl, isPlaying: false, spotifyUrl: track.spotifyUrl))),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.velvet, border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: () {
              final u = cleanLastfmImageUrl(track.imageUrl);
              if (u == null) return const Icon(Icons.music_note_rounded, size: 14, color: AppColors.roseQuartz);
              return Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, size: 14, color: AppColors.roseQuartz));
            }(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.trackName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitHeading.copyWith(fontSize: 12, color: AppColors.petalWhite)),
          Text(track.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitMedium.copyWith(fontSize: 10, color: AppColors.textMuted)),
        ])),
        const SizedBox(width: 8),
        Text('${track.playCount}x', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: color)),
      ]),
    );
  }
}

class _VersusBar extends StatelessWidget {
  final int khent;
  final int clair;
  const _VersusBar({required this.khent, required this.clair});
  @override
  Widget build(BuildContext context) {
    final total = (khent + clair).clamp(1, 999999);
    final kf = khent / total;
    final cf = clair / total;
    final leader = khent > clair ? 'Khent' : clair > khent ? 'Clair' : 'Tie';
    final leaderColor = khent > clair ? AppColors.auroraTeal : clair > khent ? AppColors.cinemaPink : AppColors.auroraGold;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: AppRadius.radiusMd, border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(children: [
        Row(children: [
          Text('WHO PLAYED MORE?', style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 1.2, color: AppColors.textMuted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: leaderColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99), border: Border.all(color: leaderColor.withValues(alpha: 0.28))),
            child: Text(leader.toUpperCase(), style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 0.8, color: leaderColor)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(children: [
              Expanded(flex: (kf * 100).round().clamp(1, 99), child: Container(color: AppColors.auroraTeal)),
              Expanded(flex: (cf * 100).round().clamp(1, 99), child: Container(color: AppColors.cinemaPink)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('Khent $khent', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.auroraTeal)),
          const Spacer(),
          Text('Clair $clair', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.cinemaPink)),
        ]),
      ]),
    );
  }
}
