import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'package:intl/intl.dart';
import '../../domain/models/milestone.dart';
import '../../data/services/milestone_service.dart';
import './memory_detail_view.dart';
import '../../../../core/theme/app_typography.dart';
import 'milestone_photo.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({super.key});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
    initialPage: 0,
  );
  Timer? _autoScrollTimer;
  Timer? _retryTimer;
  StreamSubscription<List<Milestone>>? _sub;
  final MilestoneService _milestoneService = MilestoneService();
  int _milestonesCount = 0;
  List<Milestone> _milestones = const [];
  bool _hasError = false;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _startAutoScroll();
  }

  void _subscribe() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _sub = _milestoneService.milestonesPreview(limit: 12).listen(
      (data) {
        if (!mounted) return;
        _retryCount = 0;
        setState(() {
          _milestones = data;
          _milestonesCount = data.length;
          _hasError = false;
          _isLoading = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        if (_retryCount < _maxRetries) {
          _retryCount++;
          _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
            if (mounted) _subscribe();
          });
        } else {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      },
      onDone: () {
        if (!mounted) return;
        if (_milestones.isEmpty && !_hasError) {
          if (_retryCount < _maxRetries) {
            _retryCount++;
            _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
              if (mounted) _subscribe();
            });
          } else {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        }
      },
    );
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(AppMotion.carouselHold, (timer) {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      final count = _milestonesCount;
      if (count <= 1) return;
      double currentPage = 0;
      try {
        if (_pageController.position.hasContentDimensions) {
          currentPage = _pageController.page ?? 0;
        }
      } catch (_) {
        return;
      }
      final current = currentPage.round();
      final clampedCurrent = current.clamp(0, count - 1);
      final next = (clampedCurrent + 1) % count;
      if (next == 0) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _retryTimer?.cancel();
    _sub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildCarousel() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 32,
              color: AppColors.roseQuartz.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load memories',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.roseQuartz.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _subscribe();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.deepRose.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: AppColors.petalWhite,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Retry',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite,
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

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.deepRose.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading memories...',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.roseQuartz.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final milestones = _milestones;
    if (milestones.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: PageView.builder(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        allowImplicitScrolling: false,
        padEnds: true,
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final milestone = milestones[index];
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.hasClients) {
                try {
                  if (_pageController.position.hasContentDimensions) {
                    final page = _pageController.page;
                    if (page != null) {
                      value = (page - index).abs();
                      value = (1 - (value * 0.15)).clamp(0.0, 1.0);
                    }
                  } else {
                    value = (index == 0) ? 1.0 : 0.85;
                  }
                } catch (_) {
                  value = (index == 0) ? 1.0 : 0.85;
                }
              } else {
                value = (index == 0) ? 1.0 : 0.85;
              }

              return Center(
                child: Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value.clamp(0.5, 1.0),
                    child: _MilestoneCarouselCard(milestone: milestone),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.06),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(
                    color: AppColors.moonlight.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 10,
                      color: AppColors.auroraRose,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FOR CLAIR',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 10,
                        letterSpacing: 3.0,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.blushGold.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      'LIVING ARCHIVE',
                      style: AppTypography.cormorantBlack.copyWith(
                        fontSize: 26,
                        letterSpacing: 3.0,
                        color: AppColors.petalWhite,
                        shadows: [
                          BoxShadow(
                            color: AppColors.deepRose.withValues(alpha: 0.45),
                            blurRadius: 14,
                          ),
                          const BoxShadow(
                            color: AppColors.scrimMedium,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.blushGold.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'little moments, kept forever',
                style: AppTypography.handwrittenTitle().copyWith(
                  fontSize: 19,
                  color: AppColors.blushGold.withValues(alpha: 0.92),
                ),
              ),
              if (_milestones.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '♡ ${_milestones.length} frame${_milestones.length == 1 ? '' : 's'} kept ♡',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    color: AppColors.roseQuartz.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 520, child: _buildCarousel()),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MilestoneCarouselCard extends StatefulWidget {
  final Milestone milestone;
  const _MilestoneCarouselCard({required this.milestone});

  @override
  State<_MilestoneCarouselCard> createState() => _MilestoneCarouselCardState();
}

class _MilestoneCarouselCardState extends State<_MilestoneCarouselCard> {
  final PageController _imgController = PageController();
  Timer? _imgTimer;
  int _currentImg = 0;

  @override
  void initState() {
    super.initState();
    _startImgScroll();
  }

  void _startImgScroll() {
    _imgTimer = Timer.periodic(AppMotion.carouselHold, (timer) {
      if (!mounted) return;
      if (!_imgController.hasClients) return;
      if (widget.milestone.imageUrls.length <= 1) return;
      try {
        if (!_imgController.position.hasContentDimensions) return;
        final current = _imgController.page?.round() ?? _currentImg;
        final next = current + 1;
        if (next >= widget.milestone.imageUrls.length) {
          _imgController.animateToPage(
            0,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          );
        } else {
          _imgController.nextPage(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          );
        }
      } catch (_) {
        return;
      }
    });
  }

  @override
  void dispose() {
    _imgTimer?.cancel();
    _imgController.dispose();
    super.dispose();
  }

  void _openMemory() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return MemoryDetailOverlay(milestone: widget.milestone);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
    final imageCount = milestone.imageUrls.length;

    return Semantics(
      button: true,
      label: 'Open memory ${milestone.title}',
      child: GestureDetector(
        onTap: _openMemory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: RepaintBoundary(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  height: 500,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.silk, AppColors.velvet, AppColors.inkDeep],
                stops: [0.0, 0.55, 1.0],
              ),
              borderRadius: AppRadius.radiusX3,
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.32),
              ),
              boxShadow: kIsWeb
                  ? AppElevation.e3
                  : [
                      ...AppElevation.e3,
                      ...AppElevation.glowRose,
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.10),
                        blurRadius: 14,
                        spreadRadius: -6,
                      ),
                    ],
            ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusX3,
            child: Column(
              children: [
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                _buildFilmStripEdge(isTop: true),

                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (milestone.imageUrls.isEmpty)
                        Container(
                          color: AppColors.deepRose.withValues(alpha: 0.08),
                          child: Center(
                            child: Icon(
                              Icons.image_rounded,
                              color: AppColors.roseQuartz.withValues(
                                alpha: 0.3,
                              ),
                              size: 32,
                            ),
                          ),
                        )
                      else
                        PageView.builder(
                          controller: _imgController,
                          padEnds: false,
                          itemCount: imageCount,
                          onPageChanged: (i) => setState(() => _currentImg = i),
                          itemBuilder: (context, idx) =>
                              MilestonePhoto(path: milestone.imageUrls[idx]),
                        ),

                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 72,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.inkDeep.withValues(alpha: 0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.inkDeep.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inkDeep.withValues(alpha: 0.62),
                            borderRadius: AppRadius.radiusFull,
                            border: Border.all(
                              color: AppColors.moonlight.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                milestone.category.emoji,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                milestone.category.displayName.toUpperCase(),
                                style: AppTypography.outfitHeading.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.92,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (imageCount > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inkDeep.withValues(alpha: 0.62),
                              borderRadius: AppRadius.radiusFull,
                              border: Border.all(
                                color: AppColors.moonlight.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_rounded,
                                  size: 11,
                                  color: AppColors.blushGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_currentImg + 1} / $imageCount',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.auroraGold,
                            borderRadius: AppRadius.radiusFull,
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.scrimMedium,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 13,
                                color: AppColors.inkDeep,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                DateFormat(
                                  'MMM d, yyyy',
                                ).format(milestone.date).toUpperCase(),
                                style: AppTypography.outfitHeading.copyWith(
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                  color: AppColors.inkDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (imageCount > 1 && imageCount <= 6)
                        Positioned(
                          right: 12,
                          bottom: 18,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(imageCount, (i) {
                              final active = i == _currentImg;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(left: 5),
                                width: active ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.auroraGold
                                      : AppColors.moonlight.withValues(
                                          alpha: 0.4,
                                        ),
                                  borderRadius: AppRadius.radiusFull,
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cormorantBoldWhite.copyWith(
                            fontSize: 22,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.auroraGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                milestone.author != null
                                    ? 'Memory by ${milestone.author} ♡'
                                    : 'Kept with love ♡',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.3,
                                  color: AppColors.blushGold.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          milestone.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite.withValues(alpha: 0.78),
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open our story',
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 12,
                                    letterSpacing: 0.4,
                                    color: AppColors.blushGold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppColors.blushGold,
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: AppColors.auroraRose,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                _buildFilmStripEdge(isTop: false),
              ],
            ),
          ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilmStripEdge({required bool isTop}) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FilmStripEdgePainter(isTop: isTop),
        child: const SizedBox(height: 30, width: double.infinity),
      ),
    );
  }
}

class _FilmStripEdgePainter extends CustomPainter {
  const _FilmStripEdgePainter({required this.isTop});

  final bool isTop;

  static final Paint _bgPaint = Paint()
    ..color = AppColors.inkDeep.withValues(alpha: 0.6);
  static final Paint _borderPaint = Paint()
    ..color = AppColors.blushGold.withValues(alpha: 0.16)
    ..strokeWidth = 1.0;
  static final Paint _holeFillPaint = Paint()
    ..color = AppColors.moonlight.withValues(alpha: 0.2);
  static final Paint _holeStrokePaint = Paint()
    ..color = AppColors.moonlight.withValues(alpha: 0.14)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _bgPaint);
    final lineY = isTop ? size.height - 0.5 : 0.5;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), _borderPaint);

    const padX = 14.0;
    const holeW = 22.0;
    const holeH = 10.0;
    const count = 8;
    final usable = size.width - padX * 2 - holeW * count;
    final stepGap = usable / (count - 1);
    final top = (size.height - holeH) * 0.5;
    const radius = Radius.circular(3);

    for (var i = 0; i < count; i++) {
      final left = padX + i * (holeW + stepGap);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, holeW, holeH),
        radius,
      );
      canvas.drawRRect(rrect, _holeFillPaint);
      canvas.drawRRect(rrect, _holeStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmStripEdgePainter oldDelegate) =>
      oldDelegate.isTop != isTop;
}
