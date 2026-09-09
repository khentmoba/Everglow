import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../data/models/bucket_item.dart';
import '../../data/services/bucket_list_service.dart';

/// Dashboard preview — hero Dreams card with starlight progress & wishes.
/// Atelier glass styling matching keepsakes cluster.
class BucketListPreview extends StatefulWidget {
  final Stream<List<BucketItem>>? itemsStream;
  const BucketListPreview({super.key, this.itemsStream});

  @override
  State<BucketListPreview> createState() => _BucketListPreviewState();
}

class _BucketListPreviewState extends State<BucketListPreview> {
  bool _hovered = false;
  BucketListService? _service;
  StreamSubscription<List<BucketItem>>? _sub;
  Timer? _retryTimer;
  List<BucketItem>? _items;
  Object? _error;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // One subscription for the widget lifetime so dashboard rebuilds don't
    // resubscribe and restart the Firestore listener on every frame.
    // Preview cap (12) is plenty: the card renders progress plus 3 wishes.
    if (widget.itemsStream == null) {
      _service = BucketListService();
    }
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _sub?.cancel();
    _retryTimer?.cancel();
    final stream = widget.itemsStream ?? _service!.watchPreview(limit: 12);
    _sub = stream.listen(
      (data) {
        if (!mounted) return;
        _retryCount = 0;
        setState(() {
          _items = data;
          _error = null;
          _isLoading = false;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        _scheduleSilentRetry(error);
      },
      onDone: () {
        if (!mounted) return;
        if (_isLoading && _items == null) _scheduleSilentRetry(_error);
      },
    );
  }

  void _scheduleSilentRetry(Object? error) {
    if (!mounted) return;
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _error = error ?? _error;
      _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
        if (mounted) _subscribe();
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = error ?? _error;
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
      _retryCount = 0;
    });
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    const hue = AppColors.blushGold;
    final items = _items;

    // Error state
    if (!_isLoading && (_error != null || items == null)) {
      return _buildCardShell(
        hue: hue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              hue: hue,
              title: 'Our Bucket List',
              subtitle: 'Could not load dreams',
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: hue.withValues(alpha: 0.08),
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: hue.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 16, color: hue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${firestoreErrorHint(_error)} — tap to retry.',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppColors.petalWhite.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (items == null) {
      return _buildCardShell(
        hue: hue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              hue: hue,
              title: 'Our Bucket List',
              subtitle: 'Loading our dreams…',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: AppRadius.radiusFull,
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: hue.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(hue),
              ),
            ),
            const SizedBox(height: 12),
            _buildSkeletonTile(hue),
            const SizedBox(height: 7),
            _buildSkeletonTile(hue),
          ],
        ),
      );
    }

    final all = items;
    final completed = all.where((i) => i.status == BucketStatus.completed).length;
    final total = all.length;
    final progress = total > 0 ? completed / total : 0.0;
    final wishes = all.where((i) => i.status == BucketStatus.wish).take(3).toList();

    final subtitle = total == 0
        ? 'Plant your first star together'
        : completed > 0
            ? '$completed of $total fulfilled • ${(progress * 100).round()}%'
            : '$total ${total == 1 ? 'dream' : 'dreams'} wishing to come true';

    return _buildCardShell(
      hue: hue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            hue: hue,
            title: 'Our Bucket List',
            subtitle: subtitle,
          ),
          const SizedBox(height: 12),
          _buildProgressTracker(
            hue: hue,
            progress: progress,
            total: total,
            wishesCount: wishes.length,
            completedCount: completed,
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.petalWhite.withValues(alpha: 0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (total == 0)
            const _EmptyBucketState(hue: hue)
          else if (wishes.isNotEmpty)
            ...wishes.map((item) => _BucketItemRow(item: item, hue: hue))
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'All wishes are becoming memories ✨',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11.5,
                    color: AppColors.petalWhite.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          _buildFooterAffordance(hue),
        ],
      ),
    );
  }

  Widget _buildCardShell({required Color hue, required Widget child}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/bucket-list'),
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.medium),
          curve: AppMotion.easeOutStrong,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: 0.42),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(
              color: _hovered
                  ? hue.withValues(alpha: 0.38)
                  : AppColors.petalWhite.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: hue.withValues(alpha: _hovered ? 0.12 : 0.03),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        hue.withValues(alpha: _hovered ? 0.55 : 0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader({
    required Color hue,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        _IconChip(icon: Icons.auto_awesome_rounded, hue: hue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cormorantBold.copyWith(
                  fontSize: 20,
                  height: 1.1,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.petalWhite.withValues(alpha: 0.50),
                ),
              ),
            ],
          ),
        ),
        _ActionChevron(hue: hue, hovered: _hovered),
      ],
    );
  }

  Widget _buildProgressTracker({
    required Color hue,
    required double progress,
    required int total,
    required int wishesCount,
    required int completedCount,
  }) {
    return Row(
      children: [
        // Mini circular percentage ring
        SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress == 0 ? 0.06 : progress,
                strokeWidth: 2.8,
                backgroundColor: AppColors.petalWhite.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(hue),
                strokeCap: StrokeCap.round,
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 9,
                  color: hue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Linear bar with status labels
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.radiusFull,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: hue.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(hue),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      total == 0
                          ? 'Waiting for our first dream ✨'
                          : wishesCount == 0
                              ? 'All wishes lived together ✨'
                              : '$wishesCount wishing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.petalWhite.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  if (completedCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$completedCount completed ✓',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: hue.withValues(alpha: 0.90),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterAffordance(Color hue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Explore bucket list',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: hue.withValues(alpha: _hovered ? 0.95 : 0.70),
          ),
        ),
        const SizedBox(width: 4),
        AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          transform: Matrix4.identity()
            ..translateByDouble(_hovered ? 2.0 : 0.0, 0.0, 0.0, 1.0),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: hue.withValues(alpha: _hovered ? 0.95 : 0.70),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonTile(Color hue) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.petalWhite.withValues(alpha: 0.03),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.05)),
      ),
    );
  }
}

class _BucketItemRow extends StatefulWidget {
  final BucketItem item;
  final Color hue;

  const _BucketItemRow({required this.item, required this.hue});

  @override
  State<_BucketItemRow> createState() => _BucketItemRowState();
}

class _BucketItemRowState extends State<_BucketItemRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isPlanned = item.status == BucketStatus.planned;
    final isCompleted = item.status == BucketStatus.completed;

    final statusColor = isCompleted
        ? AppColors.auroraTeal
        : isPlanned
            ? AppColors.softLavender
            : AppColors.blushGold;

    final statusLabel = isCompleted
        ? '✓ done'
        : isPlanned
            ? '🗓 plan'
            : '✦ wish';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.orZero(AppMotion.fast),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.hue.withValues(alpha: 0.08)
              : AppColors.petalWhite.withValues(alpha: 0.025),
          borderRadius: AppRadius.radiusSm,
          border: Border.all(
            color: _hovered
                ? widget.hue.withValues(alpha: 0.28)
                : AppColors.petalWhite.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: widget.hue.withValues(alpha: 0.12),
                borderRadius: AppRadius.radiusXs,
                border: Border.all(
                  color: widget.hue.withValues(alpha: 0.22),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.petalWhite.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.category.displayName,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 10,
                      color: AppColors.petalWhite.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                statusLabel,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBucketState extends StatelessWidget {
  final Color hue;
  const _EmptyBucketState({required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.05),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline_rounded, size: 18, color: hue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Plant our first dream together',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.petalWhite.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '“Persian cat”, “Japan together”, “Sunset picnic”…',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10.5,
                    color: AppColors.petalWhite.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hue.withValues(alpha: 0.22),
            hue.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: hue, size: 19),
      ),
    );
  }
}

class _ActionChevron extends StatelessWidget {
  final Color hue;
  final bool hovered;

  const _ActionChevron({required this.hue, this.hovered = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.orZero(AppMotion.fast),
      width: 28,
      height: 28,
      transform: Matrix4.identity()
        ..translateByDouble(hovered ? 2.0 : 0.0, 0.0, 0.0, 1.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hue.withValues(alpha: hovered ? 0.18 : 0.08),
        border: Border.all(color: hue.withValues(alpha: hovered ? 0.45 : 0.25)),
      ),
      child: Center(
        child: Icon(
          Icons.arrow_forward_rounded,
          color: hue.withValues(alpha: hovered ? 1.0 : 0.85),
          size: 14,
        ),
      ),
    );
  }
}
