import 'package:flutter/material.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/music_status.dart';
import '../../providers/music_stats_provider.dart';
import '../listen_along_popup.dart';
import '../../../data/models/lastfm_image_utils.dart';

class MergedTimeline extends StatelessWidget {
  const MergedTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicStatsProvider>(
      builder: (context, p, _) {
        if (p.isLoading && !p.hasData) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: AppRadius.radiusX2,
            ),
          );
        }
        final khent = p.recentTracks;
        final clair = p.clairRecentTracks;
        final merged = <_TimelineEntry>[];
        for (final t in khent) {
          merged.add(
            _TimelineEntry(
              status: t,
              owner: 'Khent',
              color: AppColors.auroraTeal,
            ),
          );
        }
        for (final t in clair) {
          merged.add(
            _TimelineEntry(
              status: t,
              owner: 'Clair',
              color: AppColors.cinemaPink,
            ),
          );
        }
        merged.sort((a, b) {
          // now playing first, then by timestamp desc
          if (a.status.isPlaying && !b.status.isPlaying) return -1;
          if (!a.status.isPlaying && b.status.isPlaying) return 1;
          final at =
              a.status.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt =
              b.status.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });
        final limited = merged.take(10).toList();

        if (limited.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(
              colors: [
                AppColors.velvet.withValues(alpha: 0.86),
                AppColors.inkDeep.withValues(alpha: 0.90),
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
                blurRadius: 20,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.auroraTeal, AppColors.auroraLilac],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: AppColors.petalWhite.withValues(alpha: 0.7),
                      ),
                    ),
                    child: const Icon(
                      Icons.timeline_rounded,
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
                          'OUR SOUNDTRACK',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: AppColors.blushGold,
                          ),
                        ),
                        Text(
                          'Merged live feed • most recent first',
                          style: AppTypography.outfitMedium.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _LegendDot(color: AppColors.auroraTeal, label: 'Khent'),
                  const SizedBox(width: 8),
                  const _LegendDot(color: AppColors.cinemaPink, label: 'Clair'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Spine + entries
              Stack(
                children: [
                  // vertical spine
                  Positioned(
                    left: 19,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.auroraTeal.withValues(alpha: 0.0),
                            AppColors.auroraTeal.withValues(alpha: 0.35),
                            AppColors.cinemaPink.withValues(alpha: 0.35),
                            AppColors.cinemaPink.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (var i = 0; i < limited.length; i++)
                        _TimelineRow(
                          entry: limited[i],
                          isLast: i == limited.length - 1,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
          ],
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: AppTypography.outfitBold.copyWith(
          fontSize: 10,
          letterSpacing: 0.8,
          color: AppColors.petalWhite,
        ),
      ),
    ],
  );
}

class _TimelineEntry {
  final MusicStatus status;
  final String owner;
  final Color color;
  _TimelineEntry({
    required this.status,
    required this.owner,
    required this.color,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEntry entry;
  final bool isLast;
  const _TimelineRow({required this.entry, required this.isLast});

  String _timeLabel() {
    if (entry.status.isPlaying) return 'now';
    final ts = entry.status.timestamp;
    if (ts == null) return 'heard';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'yesterday';
    return DateFormat('MMM d').format(ts);
  }

  @override
  Widget build(BuildContext context) {
    final isLive = entry.status.isPlaying;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // dot
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Container(
              width: isLive ? 16 : 12,
              height: isLive ? 16 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.color,
                border: Border.all(
                  color: AppColors.petalWhite.withValues(alpha: 0.85),
                  width: isLive ? 2 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: entry.color.withValues(alpha: 0.5),
                    blurRadius: isLive ? 14 : 8,
                  ),
                ],
              ),
              child: isLive
                  ? Container(
                      margin: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.petalWhite,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          // card
          Expanded(
            child: GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => ListenAlongPopup(status: entry.status),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isLive
                      ? entry.color.withValues(alpha: 0.10)
                      : AppColors.petalWhite.withValues(alpha: 0.05),
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: isLive
                        ? entry.color.withValues(alpha: 0.35)
                        : AppColors.petalWhite.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _Art(imageUrl: entry.status.imageUrl),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: entry.color.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: entry.color.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  entry.owner.toUpperCase(),
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 8,
                                    letterSpacing: 0.9,
                                    color: entry.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isLive) const _LivePill(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.status.trackName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 13.5,
                              color: AppColors.petalWhite,
                            ),
                          ),
                          Text(
                            entry.status.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitMedium.copyWith(
                              fontSize: 11.5,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: isLive
                              ? AppColors.warmAmber
                              : AppColors.textMuted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeLabel(),
                          style: AppTypography.outfitMedium.copyWith(
                            fontSize: 10.5,
                            color: isLive
                                ? AppColors.warmAmber
                                : AppColors.textMuted,
                            fontWeight: isLive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Art extends StatelessWidget {
  final String? imageUrl;
  const _Art({this.imageUrl});
  @override
  Widget build(BuildContext context) {
    final url = cleanLastfmImageUrl(imageUrl);
    return Container(
      width: 44,
      height: 44,
      color: AppColors.velvet,
      child: url != null
          ? AppNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              cacheWidth: 150,
              errorWidget: const Icon(
                Icons.music_note_rounded,
                size: 18,
                color: AppColors.roseQuartz,
              ),
            )
          : const Icon(
              Icons.music_note_rounded,
              size: 18,
              color: AppColors.roseQuartz,
            ),
    );
  }
}

class _LivePill extends StatefulWidget {
  const _LivePill();
  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.55, end: 1).animate(_c),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warmAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warmAmber,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 8,
              letterSpacing: 1.0,
              color: AppColors.warmAmber,
            ),
          ),
        ],
      ),
    ),
  );
}
