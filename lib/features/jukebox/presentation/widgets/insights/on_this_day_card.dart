import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../providers/music_insights_provider.dart';
import '../../../data/models/music_status.dart';
import '../listen_along_popup.dart';
import '../../../data/models/lastfm_image_utils.dart';

class OnThisDayMusicCard extends StatelessWidget {
  const OnThisDayMusicCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicInsightsProvider>(
      builder: (context, p, _) {
        if (p.isLoading &&
            p.khentOnThisDay.isEmpty &&
            p.clairOnThisDay.isEmpty) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: AppRadius.radiusX2,
            ),
          );
        }
        final now = DateTime.now();
        final lastYear = DateTime(now.year - 1, now.month, now.day);
        final label = DateFormat('MMMM d, y').format(lastYear);
        final annLabel = 'Feb 14 • Anniversary Soundtrack';

        final hasOtd =
            p.khentOnThisDay.isNotEmpty || p.clairOnThisDay.isNotEmpty;
        final hasAnn =
            p.khentAnniversary.isNotEmpty || p.clairAnniversary.isNotEmpty;

        if (!hasOtd && !hasAnn) {
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
            ),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 28,
                  color: AppColors.blushGold,
                ),
                const SizedBox(height: 10),
                Text(
                  'NO ECHO FROM THE PAST YET',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: AppColors.blushGold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A year ago today you were maybe just discovering new songs — your time capsule will bloom as history grows.',
                  textAlign: TextAlign.center,
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(
              colors: [
                AppColors.silk.withValues(alpha: 0.96),
                AppColors.inkDeep.withValues(alpha: 0.96),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.14),
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.blushGold, AppColors.auroraGold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: AppColors.petalWhite.withValues(alpha: 0.7),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.goldShadow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TIME CAPSULE',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: AppColors.blushGold,
                          ),
                        ),
                        Text(
                          'What you were listening to',
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
              if (hasOtd) ...[
                _DayBlock(
                  title: 'A YEAR AGO TODAY',
                  subtitle: label,
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.auroraLilac,
                  khent: p.khentOnThisDay,
                  clair: p.clairOnThisDay,
                ),
                if (hasAnn) const SizedBox(height: 16),
              ],
              if (hasAnn)
                _DayBlock(
                  title: 'ANNIVERSARY ECHO',
                  subtitle: annLabel,
                  icon: Icons.favorite_rounded,
                  color: AppColors.auroraRose,
                  khent: p.khentAnniversary,
                  clair: p.clairAnniversary,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DayBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<MusicStatus> khent;
  final List<MusicStatus> clair;
  const _DayBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.khent,
    required this.clair,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = khent.isNotEmpty || clair.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.petalWhite.withValues(alpha: 0.03),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                  border: Border.all(color: color.withValues(alpha: 0.32)),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasAny)
            Text(
              'No scrobbles that day — a quiet moment in time.',
              style: AppTypography.outfitMedium.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 520;
                if (narrow) {
                  return Column(
                    children: [
                      _PersonDay(
                        name: 'Khent',
                        tracks: khent,
                        color: AppColors.auroraTeal,
                      ),
                      const SizedBox(height: 12),
                      _PersonDay(
                        name: 'Clair',
                        tracks: clair,
                        color: AppColors.cinemaPink,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PersonDay(
                        name: 'Khent',
                        tracks: khent,
                        color: AppColors.auroraTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PersonDay(
                        name: 'Clair',
                        tracks: clair,
                        color: AppColors.cinemaPink,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PersonDay extends StatelessWidget {
  final String name;
  final List<MusicStatus> tracks;
  final Color color;
  const _PersonDay({
    required this.name,
    required this.tracks,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              name.toUpperCase(),
              style: AppTypography.outfitBold.copyWith(
                fontSize: 10,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '· ${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
              style: AppTypography.outfitMedium.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tracks.isEmpty)
          Text(
            '—',
            style: AppTypography.outfitMedium.copyWith(
              color: AppColors.textMuted,
            ),
          )
        else
          Column(
            children: tracks
                .take(3)
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => ListenAlongPopup(status: t),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.velvet,
                              border: Border.all(
                                color: AppColors.petalWhite.withValues(alpha: 0.08),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: () {
                                final u = cleanLastfmImageUrl(t.imageUrl);
                                if (u == null) {
                                  return const Icon(
                                    Icons.music_note_rounded,
                                    size: 16,
                                    color: AppColors.roseQuartz,
                                  );
                                }
                                return Image.network(
                                  u,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.music_note_rounded,
                                    size: 16,
                                    color: AppColors.roseQuartz,
                                  ),
                                );
                              }(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.trackName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.outfitHeading.copyWith(
                                    fontSize: 12,
                                    color: AppColors.petalWhite,
                                  ),
                                ),
                                Text(
                                  t.artistName,
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
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
