import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';

/// Dashboard preview — hero Dreams card with progress ring & wishes.
/// Premium glass styling matching `FeatureSection` without cross-feature import.
class BucketListPreview extends StatefulWidget {
  const BucketListPreview({super.key});

  @override
  State<BucketListPreview> createState() => _BucketListPreviewState();
}

class _BucketListPreviewState extends State<BucketListPreview> {
  bool _hovered = false;
  late final BucketListService _service;
  late Stream<List<BucketItem>> _stream;

  @override
  void initState() {
    super.initState();
    // Cache the stream so dashboard rebuilds don't resubscribe and
    // restart the Firestore listener on every frame.
    _service = BucketListService();
    _stream = _service.watchAll();
  }

  void _retry() {
    setState(() {
      _stream = _service.watchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    const hue = AppColors.blushGold;

    return StreamBuilder<List<BucketItem>>(
      stream: _stream,
      builder: (context, snapshot) {
        // Error (or timeout-closed with no data) must never masquerade as
        // "empty" — the bucket-list screen would still show dreams on tap.
        if (snapshot.hasError ||
            (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done)) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: GestureDetector(
              onTap: () => context.push('/bucket-list'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.04),
                  borderRadius: AppRadius.radiusX2,
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.07),
                  ),
                ),
                child: GestureDetector(
                  onTap: _retry,
                  child: _EmptyAddRow(
                    hue: hue,
                    text:
                        '${firestoreErrorHint(snapshot.error)} — tap here to retry.',
                  ),
                ),
              ),
            ),
          );
        }

        // Waiting for the first snapshot is loading, not empty.
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: GestureDetector(
              onTap: () => context.push('/bucket-list'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.04),
                  borderRadius: AppRadius.radiusX2,
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.07),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: hue.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(hue),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Loading dreams…',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppColors.petalWhite.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final all = snapshot.data!;
        final completed = all
            .where((i) => i.status == BucketStatus.completed)
            .length;
        final total = all.length;
        final progress = total > 0 ? completed / total : 0.0;
        final wishes = all
            .where((i) => i.status == BucketStatus.wish)
            .take(3)
            .toList();

        final subtitle = total == 0
            ? '0 dreams — plant your first star'
            : '$completed of $total dreams fulfilled • ${(progress * 100).round()}%';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: () => context.push('/bucket-list'),
              child: AnimatedContainer(
                duration: AppMotion.orZero(AppMotion.medium),
                curve: AppMotion.easeOutStrong,
                transform: Matrix4.identity()
                  ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.petalWhite.withValues(alpha: 0.06),
                      AppColors.velvet.withValues(alpha: 0.68),
                      AppColors.inkDeep.withValues(alpha: 0.74),
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                  borderRadius: AppRadius.radiusX2,
                  border: Border.all(
                    color: _hovered
                        ? hue.withValues(alpha: 0.48)
                        : AppColors.petalWhite.withValues(alpha: 0.07),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.scrimStrong.withValues(alpha: 0.42),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: hue.withValues(alpha: _hovered ? 0.14 : 0.06),
                      blurRadius: 22,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 22,
                      right: 22,
                      child: Container(
                        height: 1.4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              hue.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const _IconChip(
                                icon: Icons.auto_awesome_rounded,
                                hue: hue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Our Bucket List',
                                      style: AppTypography.cormorantBold
                                          .copyWith(fontSize: 21, height: 1.0),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const _Chevron(hue: hue),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _ProgressRing(progress: progress, hue: hue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 6,
                                        backgroundColor: hue.withValues(
                                          alpha: 0.12,
                                        ),
                                        valueColor:
                                            const AlwaysStoppedAnimation(hue),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      total == 0
                                          ? 'Your story is waiting for its first dream.'
                                          : wishes.isEmpty
                                          ? 'All wishes are becoming memories ✨'
                                          : '${wishes.length} wishing  •  $completed completed',
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 11,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.50,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (total == 0) ...[
                            const SizedBox(height: 14),
                            const _EmptyAddRow(
                              hue: hue,
                              text:
                                  'Add your first dream — “Persian cat”, “Japan together”…',
                            ),
                          ] else if (wishes.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              height: 1,
                              color: AppColors.petalWhite.withValues(alpha: 0.06),
                            ),
                            const SizedBox(height: 12),
                            ...wishes.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: hue.withValues(alpha: 0.12),
                                        borderRadius: AppRadius.radiusSm,
                                        border: Border.all(
                                          color: hue.withValues(alpha: 0.22),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          item.category.emoji,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.outfitWhite
                                            .copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.petalWhite
                                                  .withValues(alpha: 0.88),
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: hue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'wish',
                                        style: AppTypography.outfitWhite
                                            .copyWith(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                              color: hue.withValues(
                                                alpha: 0.95,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final Color hue;
  const _IconChip({required this.icon, required this.hue});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hue.withValues(alpha: 0.26), hue.withValues(alpha: 0.08)],
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: hue, size: 20),
    );
  }
}

class _Chevron extends StatelessWidget {
  final Color hue;
  const _Chevron({required this.hue});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hue.withValues(alpha: 0.10),
        border: Border.all(color: hue.withValues(alpha: 0.35)),
      ),
      child: Icon(Icons.chevron_right_rounded, color: hue, size: 18),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color hue;
  const _ProgressRing({required this.progress, required this.hue});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: progress == 0 ? 0.06 : progress,
              strokeWidth: 3.2,
              backgroundColor: AppColors.petalWhite.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation(hue),
              strokeCap: StrokeCap.round,
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  hue.withValues(alpha: 0.22),
                  hue.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: hue.withValues(alpha: 0.22)),
            ),
            child: Center(
              child: Text(
                '${(progress * 100).round()}%',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 9,
                  color: hue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAddRow extends StatelessWidget {
  final Color hue;
  final String text;
  const _EmptyAddRow({required this.hue, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline_rounded, size: 16, color: hue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                color: AppColors.petalWhite.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
